import 'package:sqlite_crdt/sqlite_crdt.dart';
import 'package:uuid/uuid.dart';
import '../utils/logger.dart';
import '../utils/node_key_manager.dart';
import '../domain/models/node.dart';
import '../data/dao/node_dao.dart';
import '../data/database/database_manager.dart';
import 'network_discovery_service.dart';
import 'network_sync_service.dart';

/// 节点管理服务
/// 负责节点的创建、管理和同步
class NodeService {
  final _logger = AppLogger.getLogger('NodeService');
  final NodeKeyManager _keyManager = NodeKeyManager.getInstance();
  final NetworkDiscoveryService _discoveryService = NetworkDiscoveryService.getInstance();
  
  late NodeDao _nodeDao;
  late NetworkSyncService _syncService;
  
  // 本地节点信息
  String? _localNodeId;
  Node? _localNode;
  
  // 服务状态
  bool _isInitialized = false;
  bool _isDiscoveryRunning = false;
  bool _isServerRunning = false;
  
  // 单例实例
  static NodeService? _instance;
  
  // 私有构造函数
  NodeService._();
  
  /// 获取 NodeService 实例
  static Future<NodeService> getInstance() async {
    if (_instance == null) {
      _instance = NodeService._();
      await _instance!._init();
    }
    return _instance!;
  }
  
  /// 初始化节点服务
  Future<void> _init() async {
    try {
      _logger.info('初始化节点服务');
      
      // 获取数据库实例
      final dbManager = await DatabaseManager.getInstance();
      
      // 创建节点 DAO
      _nodeDao = NodeDao(dbManager.database);
      
      // 获取网络同步服务
      _syncService = await NetworkSyncService.getInstance();
      
      _isInitialized = true;
      _logger.info('节点服务初始化成功');
    } catch (e, stack) {
      _logger.severe('节点服务初始化失败', e, stack);
      rethrow;
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
      _logger.warning('无法创建本地节点：服务未初始化');
      return null;
    }
    
    try {
      _logger.info('创建本地节点：$nodeName');
      
      // 生成节点 ID
      final nodeId = _keyManager.generateNodeId();
      
      // 生成密钥对
      final keyPair = await _keyManager.generateNodeKeyPair();
      
      // 获取公钥指纹
      final fingerprint = await _keyManager.getPublicKeyFingerprint(keyPair);
      
      // 存储密钥对
      await _keyManager.storeNodeKeyPair(nodeId, keyPair);
      
      // 创建节点记录
      final node = await _nodeDao.createNode(
        nodeId,
        nodeName,
        fingerprint,
        true, // 本地节点始终是受信任的
      );
      
      if (node == null) {
        throw Exception('创建节点记录失败');
      }
      
      // 存储本地节点信息
      _localNodeId = nodeId;
      _localNode = node;
      
      _logger.info('本地节点创建成功：ID=$nodeId, 名称=$nodeName');
      return node;
    } catch (e, stack) {
      _logger.severe('创建本地节点失败', e, stack);
      return null;
    }
  }
  
  /// 获取本地节点
  /// 
  /// 返回：本地节点，如果不存在则返回 null
  Future<Node?> getLocalNode() async {
    if (!_isInitialized) {
      _logger.warning('无法获取本地节点：服务未初始化');
      return null;
    }
    
    try {
      // 如果已经加载了本地节点，直接返回
      if (_localNode != null) {
        return _localNode;
      }
      
      _logger.info('获取本地节点');
      
      // 获取所有节点
      final nodes = await _nodeDao.getAllNodes();
      
      // 查找本地节点（第一个创建的节点）
      if (nodes.isNotEmpty) {
        _localNode = nodes.first;
        _localNodeId = _localNode!.nodeId;
        _logger.info('获取本地节点成功：ID=${_localNode!.nodeId}, 名称=${_localNode!.nodeName}');
        return _localNode;
      }
      
      _logger.warning('未找到本地节点');
      return null;
    } catch (e, stack) {
      _logger.severe('获取本地节点失败', e, stack);
      return null;
    }
  }
  
  /// 添加受信任节点
  /// 
  /// 参数：
  /// - nodeName：节点名称
  /// - fingerprint：公钥指纹
  /// 
  /// 返回：添加的节点，如果添加失败则返回 null
  Future<Node?> addTrustedNode(String nodeName, String fingerprint) async {
    if (!_isInitialized) {
      _logger.warning('无法添加受信任节点：服务未初始化');
      return null;
    }
    
    try {
      _logger.info('添加受信任节点：$nodeName, 指纹=$fingerprint');
      
      // 检查是否已存在相同指纹的节点
      final existingNode = await _nodeDao.getNodeByFingerprint(fingerprint);
      
      if (existingNode != null) {
        _logger.warning('节点已存在：指纹=$fingerprint');
        
        // 如果节点存在但不受信任，则更新为受信任
        if (!existingNode.isTrusted) {
          await _nodeDao.updateNode(
            existingNode.nodeId,
            nodeName, // 更新名称
            true, // 设置为受信任
          );
          
          _logger.info('节点已更新为受信任：ID=${existingNode.nodeId}');
          
          // 获取更新后的节点
          return await _nodeDao.getNodeById(existingNode.nodeId);
        }
        
        return existingNode;
      }
      
      // 生成节点 ID
      final nodeId = const Uuid().v4();
      
      // 创建节点记录
      final node = await _nodeDao.createNode(
        nodeId,
        nodeName,
        fingerprint,
        true, // 设置为受信任
      );
      
      _logger.info('受信任节点添加成功：ID=$nodeId, 名称=$nodeName');
      return node;
    } catch (e, stack) {
      _logger.severe('添加受信任节点失败', e, stack);
      return null;
    }
  }
  
  /// 获取所有节点
  /// 
  /// 返回：节点列表
  Future<List<Node>> getAllNodes() async {
    if (!_isInitialized) {
      _logger.warning('无法获取所有节点：服务未初始化');
      return [];
    }
    
    try {
      _logger.info('获取所有节点');
      return await _nodeDao.getAllNodes();
    } catch (e, stack) {
      _logger.severe('获取所有节点失败', e, stack);
      return [];
    }
  }
  
  /// 获取所有受信任节点
  /// 
  /// 返回：受信任节点列表
  Future<List<Node>> getTrustedNodes() async {
    if (!_isInitialized) {
      _logger.warning('无法获取受信任节点：服务未初始化');
      return [];
    }
    
    try {
      _logger.info('获取所有受信任节点');
      return await _nodeDao.getTrustedNodes();
    } catch (e, stack) {
      _logger.severe('获取受信任节点失败', e, stack);
      return [];
    }
  }
  
  /// 删除节点
  /// 
  /// 参数：
  /// - nodeId：节点 ID
  /// 
  /// 返回：删除是否成功
  Future<bool> deleteNode(String nodeId) async {
    if (!_isInitialized) {
      _logger.warning('无法删除节点：服务未初始化');
      return false;
    }
    
    // 不允许删除本地节点
    if (nodeId == _localNodeId) {
      _logger.warning('不能删除本地节点');
      return false;
    }
    
    try {
      _logger.info('删除节点：ID=$nodeId');
      return await _nodeDao.deleteNode(nodeId);
    } catch (e, stack) {
      _logger.severe('删除节点失败：ID=$nodeId', e, stack);
      return false;
    }
  }
  
  /// 启动网络发现
  /// 
  /// 返回：是否成功启动
  Future<bool> startDiscovery() async {
    if (!_isInitialized) {
      _logger.warning('无法启动网络发现：服务未初始化');
      return false;
    }
    
    if (_isDiscoveryRunning) {
      _logger.warning('网络发现已经在运行');
      return true;
    }
    
    try {
      _logger.info('启动网络发现');
      
      // 获取本地节点
      final localNode = await getLocalNode();
      
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
      
      // 初始化网络同步服务
      await _syncService.initialize(
        localNode.nodeId,
        localNode.nodeName,
        localNode.pubkeyFingerprint,
        port,
      );
      
      // 启动同步服务器
      final (serverSuccess, _) = await _syncService.startServer();
      
      if (!serverSuccess) {
        _logger.warning('启动同步服务器失败');
        await _discoveryService.stopBroadcast();
        return false;
      }
      
      _isDiscoveryRunning = true;
      _isServerRunning = true;
      
      _logger.info('网络发现启动成功：端口=$port');
      return true;
    } catch (e, stack) {
      _logger.severe('启动网络发现失败', e, stack);
      return false;
    }
  }
  
  /// 停止网络发现
  Future<void> stopDiscovery() async {
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
      
      if (_isServerRunning) {
        _logger.info('停止同步服务器');
        
        // 停止同步服务器
        await _syncService.stopServer();
        
        _isServerRunning = false;
        _logger.info('同步服务器已停止');
      }
    } catch (e, stack) {
      _logger.severe('停止网络发现失败', e, stack);
    }
  }
  
  /// 发现网络中的节点
  /// 
  /// 返回：发现的节点流
  Stream<DiscoveredNode> discoverNodes() {
    if (!_isInitialized || !_isDiscoveryRunning) {
      _logger.warning('无法发现节点：服务未初始化或网络发现未启动');
      return Stream.empty();
    }
    
    try {
      _logger.info('开始发现节点');
      return _discoveryService.discoverNodes();
    } catch (e, stack) {
      _logger.severe('发现节点失败', e, stack);
      return Stream.empty();
    }
  }
  
  /// 连接到发现的节点
  /// 
  /// 参数：
  /// - discoveredNode：发现的节点
  /// 
  /// 返回：同步是否成功
  Future<bool> connectAndSync(DiscoveredNode discoveredNode) async {
    if (!_isInitialized || !_isDiscoveryRunning) {
      _logger.warning('无法连接到节点：服务未初始化或网络发现未启动');
      return false;
    }
    
    try {
      _logger.info('连接到节点：${discoveredNode.nodeName}');
      
      // 检查节点是否受信任
      final trustedNode = await _nodeDao.getNodeByFingerprint(discoveredNode.pubkeyFingerprint);
      
      if (trustedNode == null || !trustedNode.isTrusted) {
        _logger.warning('节点不受信任：${discoveredNode.nodeName}');
        return false;
      }
      
      // 连接到节点
      final session = await _syncService.connectToNode(discoveredNode);
      
      if (session == null) {
        _logger.warning('连接到节点失败：${discoveredNode.nodeName}');
        return false;
      }
      
      // 与节点同步
      final success = await _syncService.synchronizeWithNode(session);
      
      if (success) {
        // 更新节点同步时间
        await _nodeDao.updateNodeSyncTime(trustedNode.nodeId, DateTime.now());
        _logger.info('与节点同步成功：${discoveredNode.nodeName}');
      } else {
        _logger.warning('与节点同步失败：${discoveredNode.nodeName}');
      }
      
      return success;
    } catch (e, stack) {
      _logger.severe('连接到节点失败：${discoveredNode.nodeName}', e, stack);
      return false;
    }
  }
  
  /// 生成节点二维码数据
  /// 
  /// 返回：二维码数据
  Future<String?> generateQRCodeData() async {
    if (!_isInitialized) {
      _logger.warning('无法生成二维码：服务未初始化');
      return null;
    }
    
    try {
      _logger.info('生成节点二维码数据');
      
      // 获取本地节点
      final localNode = await getLocalNode();
      
      if (localNode == null) {
        _logger.warning('无法生成二维码：本地节点不存在');
        return null;
      }
      
      // 创建二维码数据
      final qrData = {
        'nodeId': localNode.nodeId,
        'nodeName': localNode.nodeName,
        'fingerprint': localNode.pubkeyFingerprint,
        'type': 'cardmind_node',
      };
      
      _logger.info('节点二维码数据生成成功');
      return Uri(
        scheme: 'cardmind',
        host: 'node',
        queryParameters: qrData,
      ).toString();
    } catch (e, stack) {
      _logger.severe('生成节点二维码数据失败', e, stack);
      return null;
    }
  }
  
  /// 解析节点二维码数据
  /// 
  /// 参数：
  /// - qrData：二维码数据
  /// 
  /// 返回：解析的节点信息，如果解析失败则返回 null
  Future<Map<String, String>?> parseQRCodeData(String qrData) async {
    try {
      _logger.info('解析节点二维码数据');
      
      // 解析 URI
      final uri = Uri.parse(qrData);
      
      // 检查 scheme 和 host
      if (uri.scheme != 'cardmind' || uri.host != 'node') {
        _logger.warning('无效的二维码数据：scheme=${uri.scheme}, host=${uri.host}');
        return null;
      }
      
      // 获取查询参数
      final params = uri.queryParameters;
      
      // 检查必要参数
      if (!params.containsKey('nodeId') || 
          !params.containsKey('nodeName') || 
          !params.containsKey('fingerprint') ||
          !params.containsKey('type') ||
          params['type'] != 'cardmind_node') {
        _logger.warning('无效的二维码数据：缺少必要参数');
        return null;
      }
      
      _logger.info('节点二维码数据解析成功');
      return {
        'nodeId': params['nodeId']!,
        'nodeName': params['nodeName']!,
        'fingerprint': params['fingerprint']!,
      };
    } catch (e, stack) {
      _logger.severe('解析节点二维码数据失败', e, stack);
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
      await _syncService.close();
      
      _isInitialized = false;
      _logger.info('节点服务已关闭');
    } catch (e, stack) {
      _logger.severe('关闭节点服务失败', e, stack);
    }
  }
}
