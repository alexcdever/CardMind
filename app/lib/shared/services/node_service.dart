import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../data/dao/node_dao.dart';
import '../data/database/database_manager.dart';
import '../domain/models/network_discovered_node.dart';
import '../domain/models/node.dart';
import '../domain/models/node_info.dart';
import '../utils/logger.dart';
import '../utils/node_key_manager.dart';
import 'network_discovery_service.dart';
import 'network_sync_service.dart';

/// 节点服务
/// 负责节点的创建、管理和发现
class NodeService {
  final _logger = AppLogger.getLogger('NodeService');
  static NodeService? _instance;
  late NodeDao _nodeDao;
  bool _isInitialized = false;

  // 密钥管理器
  final NodeKeyManager _keyManager = NodeKeyManager.getInstance();

  // 网络发现服务
  final NetworkDiscoveryService _discoveryService =
      NetworkDiscoveryService.getInstance();

  // 网络同步服务
  NetworkSyncService? _syncService;

  // 发现状态
  bool _isDiscoveryRunning = false;
  bool _isServerRunning = false;

  // 连接状态
  final List<String> _connectedNodeIds = [];
  late final StreamController<List<String>> _nodeConnectionController;

  /// 节点连接状态变化事件流
  Stream<List<String>> get onNodeConnectionChanged =>
      _nodeConnectionController.stream;

  /// 私有构造函数
  NodeService._() {
    _nodeConnectionController = StreamController<List<String>>.broadcast();
  }

  /// 获取节点服务实例
  static Future<NodeService> getInstance() async {
    if (_instance == null) {
      _instance = NodeService._();
      await _instance!._init();
    }
    return _instance!;
  }

  /// 判断服务是否已初始化
  bool get isInitialized => _isInitialized;

  /// 初始化节点服务
  Future<void> _init() async {
    try {
      _logger.info('初始化节点服务');

      try {
        // 获取数据库实例
        final dbManager = await DatabaseManager.getInstance();
        _logger.info('数据库管理器获取成功');

        // 创建节点 DAO
        _nodeDao = NodeDao(dbManager.database);
        _logger.info('节点DAO创建成功');
      } catch (e, stack) {
        _logger.severe('数据库初始化失败', e, stack);
        _isInitialized = false;
        return; // 如果数据库初始化失败，直接返回
      }

      // 只有在数据库初始化成功后，才尝试初始化网络同步服务
      try {
        // 尝试初始化网络同步服务
        _syncService = await NetworkSyncService.getInstance();
        _logger.info('网络同步服务初始化成功');

        // 监听同步服务的连接状态变化
        _syncService?.onConnectionStateChanged.listen((connectedNodes) {
          _connectedNodeIds.clear();
          _connectedNodeIds.addAll(connectedNodes);
          _nodeConnectionController.add(List.from(_connectedNodeIds));
        });

        // 如果是本地节点，将其添加到已连接节点列表
        final localNode = await getLocalNode();
        if (localNode != null) {
          _connectedNodeIds.add(localNode.nodeId);
          _nodeConnectionController.add(List.from(_connectedNodeIds));
        }
      } catch (e, stack) {
        // 记录错误但继续初始化
        _logger.warning('网络同步服务初始化失败，将以离线模式运行: $e', e, stack);
        // 设置为 null，表示离线模式
        _syncService = null;
      }

      _isInitialized = true;
      _logger.info('节点服务初始化成功');

      // 自动启动网络发现
      await startDiscovery();
      _logger.info('网络发现已自动启动');
    } catch (e, stack) {
      _logger.severe('节点服务初始化失败: $e', e, stack);
      _isInitialized = false;
      // 不重新抛出异常，而是标记初始化失败
    }
  }

  /// 创建本地节点
  ///
  /// 参数：
  /// - nodeName：节点名称
  ///
  /// 返回：创建的节点，如果创建失败则返回 null
  Future<Node?> createLocalNode(String nodeName) async {
    if (!_isInitialized) {
      _logger.warning('节点服务未初始化');
      return null;
    }

    try {
      _logger.info('创建本地节点: $nodeName');

      // 生成节点ID
      final nodeId = const Uuid().v4();

      // 生成密钥对
      final keyPair = await _keyManager.generateNodeKeyPair();

      // 获取公钥指纹
      final fingerprint = await _keyManager.getPublicKeyFingerprint(keyPair);

      // 提取公钥并编码为Base64
      final publicKey = await keyPair.extractPublicKey();
      final publicKeyBytes = (publicKey as dynamic).bytes as List<int>;
      final publicKeyBase64 = base64Encode(publicKeyBytes);

      // 存储密钥对
      await _keyManager.storeNodeKeyPair(nodeId, keyPair);

      // 创建节点
      return await _nodeDao.createNode(
        nodeId,
        nodeName,
        fingerprint,
        true, // 本地节点默认受信任
        publicKeyBase64,
        isLocalNode: true,
      );
    } catch (e, stack) {
      _logger.severe('创建本地节点失败: $e', e, stack);
      return null;
    }
  }

  /// 确保本地节点存在
  ///
  /// 如果本地节点不存在，则创建一个默认的本地节点
  ///
  /// 返回：本地节点，如果创建失败则返回 null
  Future<Node?> ensureLocalNodeExists() async {
    if (!_isInitialized) {
      _logger.warning('节点服务未初始化');
      return null;
    }

    try {
      // 获取本地节点
      final nodes = await _nodeDao.getAllNodes();
      final localNode = nodes.where((node) => node.isLocalNode).firstOrNull;

      // 如果本地节点存在，直接返回
      if (localNode != null) {
        return localNode;
      }

      // 如果本地节点不存在，创建一个默认的本地节点
      _logger.info('本地节点不存在，创建默认本地节点');

      // 生成设备名称作为节点名称
      String nodeName;
      try {
        // 尝试获取设备名称
        final deviceInfoPlugin = DeviceInfoPlugin();
        if (Platform.isAndroid) {
          final androidInfo = await deviceInfoPlugin.androidInfo;
          nodeName = '${androidInfo.model}的节点';
        } else if (Platform.isIOS) {
          final iosInfo = await deviceInfoPlugin.iosInfo;
          nodeName = '${iosInfo.name}的节点';
        } else if (Platform.isWindows) {
          final windowsInfo = await deviceInfoPlugin.windowsInfo;
          nodeName = '${windowsInfo.computerName}的节点';
        } else if (Platform.isMacOS) {
          final macOsInfo = await deviceInfoPlugin.macOsInfo;
          nodeName = '${macOsInfo.computerName}的节点';
        } else {
          // 默认节点名称
          nodeName = '本地节点_${DateTime.now().millisecondsSinceEpoch}';
        }
      } catch (e) {
        // 如果获取设备信息失败，使用默认名称
        nodeName = '本地节点_${DateTime.now().millisecondsSinceEpoch}';
        _logger.warning('获取设备信息失败，使用默认节点名称：$nodeName');
      }

      return await createLocalNode(nodeName);
    } catch (e, stack) {
      _logger.severe('确保本地节点存在失败: $e', e, stack);
      return null;
    }
  }

  /// 添加受信任节点
  ///
  /// 参数：
  /// - nodeName：节点名称
  /// - fingerprint：公钥指纹
  /// - publicKey：公钥
  ///
  /// 返回：添加的节点，如果添加失败则返回 null
  Future<Node?> addTrustedNode(
      String nodeName, String fingerprint, String publicKey) async {
    if (!_isInitialized) {
      _logger.warning('节点服务未初始化');
      return null;
    }

    try {
      _logger.info('添加受信任节点: $nodeName');

      // 检查是否已存在相同指纹的节点
      final existingNode = await _nodeDao.getNodeByFingerprint(fingerprint);

      if (existingNode != null) {
        _logger.warning('节点已存在：指纹=$fingerprint');

        // 如果节点存在但不受信任，则更新为受信任
        if (!existingNode.isTrusted) {
          // 创建更新后的节点对象
          final updatedNode = existingNode.copyWith(
            nodeName: nodeName, // 更新名称
            isTrusted: true, // 设置为受信任
            publicKey: publicKey, // 更新公钥
          );

          // 更新节点
          await _nodeDao.updateNode(updatedNode);

          _logger.info('节点已更新为受信任：ID=${existingNode.nodeId}');

          // 获取更新后的节点
          return await _nodeDao.getNodeById(existingNode.nodeId);
        }

        return existingNode;
      }

      // 生成节点ID
      final nodeId = const Uuid().v4();

      // 创建节点
      return await _nodeDao.createNode(
        nodeId,
        nodeName,
        fingerprint,
        true, // 受信任
        publicKey,
      );
    } catch (e, stack) {
      _logger.severe('添加受信任节点失败: $e', e, stack);
      return null;
    }
  }

  /// 获取受信任节点列表
  ///
  /// 返回：受信任节点列表
  Future<List<Node>> getTrustedNodes() async {
    if (!_isInitialized) {
      _logger.warning('节点服务未初始化');
      return [];
    }

    try {
      return await _nodeDao.getTrustedNodes();
    } catch (e, stack) {
      _logger.severe('获取受信任节点列表失败: $e', e, stack);
      return [];
    }
  }

  /// 删除节点
  ///
  /// 参数：
  /// - nodeId：节点ID
  ///
  /// 返回：是否删除成功
  Future<bool> deleteNode(String nodeId) async {
    if (!_isInitialized) {
      _logger.warning('节点服务未初始化');
      return false;
    }

    try {
      // 检查是否为本地节点
      final node = await _nodeDao.getNodeById(nodeId);
      if (node == null) {
        _logger.warning('节点不存在: $nodeId');
        return false;
      }

      if (node.isLocalNode) {
        _logger.warning('不能删除本地节点');
        return false;
      }

      // 删除节点
      return await _nodeDao.deleteNode(nodeId);
    } catch (e, stack) {
      _logger.severe('删除节点失败: $e', e, stack);
      return false;
    }
  }

  /// 启动网络发现
  ///
  /// 返回：是否启动成功
  Future<bool> startDiscovery() async {
    if (!_isInitialized) {
      _logger.warning('节点服务未初始化');
      return false;
    }

    if (_isDiscoveryRunning) {
      _logger.warning('网络发现已经在运行');
      return true;
    }

    try {
      _logger.info('启动网络发现');

      // 获取本地节点
      final nodes = await _nodeDao.getAllNodes();
      final localNode = nodes.where((node) => node.isLocalNode).firstOrNull;

      if (localNode == null) {
        _logger.warning('无法启动网络发现：本地节点不存在');
        return false;
      }

      // 初始化网络发现服务
      await _discoveryService.initialize(
        localNode.nodeId,
        localNode.nodeName,
        localNode.pubkeyFingerprint,
      );

      // 启动服务广播
      final (success, port) = await _discoveryService.startBroadcast();

      if (!success) {
        _logger.warning('启动服务广播失败');
        return false;
      }

      // 启动节点发现
      _discoveryService.discoverNodes().listen((discoveredNode) {
        _logger.info('发现新节点：${discoveredNode.toString()}');
      });

      // 初始化网络同步服务
      if (_syncService != null) {
        await _syncService!.initialize(
          localNode.nodeId,
          localNode.nodeName,
          localNode.pubkeyFingerprint,
          port,
        );

        // 启动同步服务器
        final (serverSuccess, _) = await _syncService!.startServer();

        if (!serverSuccess) {
          _logger.warning('启动同步服务器失败');
          await _discoveryService.stopBroadcast();
          return false;
        }
      }

      _isDiscoveryRunning = true;
      _isServerRunning = true;

      _logger.info('网络发现启动成功：端口=$port');
      return true;
    } catch (e, stack) {
      _logger.severe('启动网络发现失败: $e', e, stack);
      return false;
    }
  }

  /// 停止网络发现
  Future<void> stopDiscovery() async {
    if (!_isInitialized) {
      _logger.warning('节点服务未初始化');
      return;
    }

    try {
      if (_isDiscoveryRunning) {
        _logger.info('停止网络发现');

        // 停止服务广播
        await _discoveryService.stopBroadcast();

        // 停止发现
        await _discoveryService.stopDiscovery();

        _isDiscoveryRunning = false;
        _logger.info('网络发现已停止');
      }

      if (_isServerRunning && _syncService != null) {
        _logger.info('停止同步服务器');

        // 停止同步服务器
        await _syncService!.stopServer();

        _isServerRunning = false;
        _logger.info('同步服务器已停止');
      }
    } catch (e, stack) {
      _logger.severe('停止网络发现失败: $e', e, stack);
    }
  }

  /// 发现节点
  ///
  /// 返回：发现的节点流
  Stream<NetworkDiscoveredNode> discoverNodes() {
    if (!_isInitialized || !_isDiscoveryRunning) {
      _logger.warning('无法发现节点：服务未初始化或网络发现未启动');
      return Stream.empty();
    }

    try {
      _logger.info('开始发现节点');

      // 直接返回NetworkDiscoveryService的节点流
      return _discoveryService.discoverNodes();
    } catch (e, stack) {
      _logger.severe('发现节点失败: $e', e, stack);
      return Stream.empty();
    }
  }

  /// 连接并同步
  ///
  /// 参数：
  /// - discoveredNode：发现的节点
  ///
  /// 返回：是否连接成功
  Future<bool> connectAndSync(NetworkDiscoveredNode discoveredNode) async {
    if (!_isInitialized || !_isDiscoveryRunning) {
      _logger.warning('无法连接到节点：服务未初始化或网络发现未启动');
      return false;
    }

    if (_syncService == null) {
      _logger.warning('无法连接到节点：同步服务未初始化');
      return false;
    }

    try {
      _logger.info('连接到节点：${discoveredNode.nodeName}');

      // 检查节点是否受信任
      final trustedNode =
          await _nodeDao.getNodeByFingerprint(discoveredNode.pubkeyFingerprint);

      if (trustedNode == null || !trustedNode.isTrusted) {
        _logger.warning('节点不受信任：${discoveredNode.nodeName}');
        return false;
      }

      // 使用同一个 NetworkDiscoveredNode 对象，不需要转换
      final session = await _syncService!.connectToNode(discoveredNode);

      if (session == null) {
        _logger.warning('连接到节点失败：${discoveredNode.nodeName}');
        return false;
      }

      // 与节点同步
      final success = await _syncService!.synchronizeWithNode(session);

      if (success) {
        // 更新节点同步时间
        final updatedNode = trustedNode.copyWith(
          lastSync: DateTime.now(),
        );
        await _nodeDao.updateNode(updatedNode);
        _logger.info('与节点同步成功：${discoveredNode.nodeName}');
      } else {
        _logger.warning('与节点同步失败：${discoveredNode.nodeName}');
      }

      return success;
    } catch (e, stack) {
      _logger.severe('连接到节点失败：${discoveredNode.nodeName}: $e', e, stack);
      return false;
    }
  }

  /// 生成二维码数据
  ///
  /// 返回：二维码数据，如果生成失败则返回 null
  Future<String?> generateQRCodeData() async {
    if (!_isInitialized) {
      _logger.warning('节点服务未初始化');
      return null;
    }

    try {
      // 获取本地节点
      final nodes = await _nodeDao.getAllNodes();
      final localNode = nodes.where((node) => node.isLocalNode).firstOrNull;

      if (localNode == null) {
        _logger.warning('本地节点不存在');
        return null;
      }

      // 从网络发现服务获取当前的主机地址和端口号
      final host = _discoveryService.getCurrentHost();
      final port = _discoveryService.getCurrentPort();

      // 创建节点信息
      final nodeInfo = NodeInfo(
        nodeId: localNode.nodeId,
        nodeName: localNode.nodeName,
        pubkeyFingerprint: localNode.pubkeyFingerprint,
        publicKey: localNode.publicKey,
        host: host,
        port: port,
      );

      // 将节点信息转换为JSON
      final jsonData = jsonEncode(nodeInfo.toJson());
      _logger.info('节点信息的json数据：$jsonData');

      // 返回Base64编码的JSON数据
      return base64Encode(utf8.encode(jsonData));
    } catch (e, stack) {
      _logger.severe('生成二维码数据失败: $e', e, stack);
      return null;
    }
  }

  /// 解析二维码数据
  ///
  /// 参数：
  /// - qrData：二维码数据
  ///
  /// 返回：节点信息，如果解析失败则返回 null
  Future<NodeInfo?> parseQRCodeData(String qrData) async {
    if (!_isInitialized) {
      _logger.warning('节点服务未初始化');
      return null;
    }

    try {
      // 解码Base64数据
      final jsonData = utf8.decode(base64Decode(qrData));

      // 解析JSON数据
      final Map<String, dynamic> data = jsonDecode(jsonData);

      // 创建节点信息
      return NodeInfo.fromJson(data);
    } catch (e, stack) {
      _logger.severe('解析二维码数据失败: $e', e, stack);
      return null;
    }
  }

  /// 关闭服务
  Future<void> close() async {
    try {
      _logger.info('关闭节点服务');

      // 停止网络发现
      await stopDiscovery();

      // 关闭网络发现服务
      await _discoveryService.close();

      // 关闭网络同步服务
      if (_syncService != null) {
        await _syncService!.close();
      }

      _isInitialized = false;
      _logger.info('节点服务已关闭');
    } catch (e, stack) {
      _logger.severe('关闭节点服务失败: $e', e, stack);
    }
  }

  /// 获取本地节点
  ///
  /// 返回：本地节点，如果获取失败则返回 null
  Future<Node?> getLocalNode() async {
    if (!_isInitialized) {
      _logger.warning('节点服务未初始化');
      return null;
    }

    try {
      final nodes = await _nodeDao.getAllNodes();
      return nodes.where((node) => node.isLocalNode).firstOrNull;
    } catch (e, stack) {
      _logger.severe('获取本地节点失败: $e', e, stack);
      return null;
    }
  }
}
