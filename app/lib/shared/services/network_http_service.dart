import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../utils/logger.dart';
import '../utils/node_key_manager.dart';
import '../data/dao/node_dao.dart';
import '../data/database/database_manager.dart';
import '../domain/models/network_discovered_node.dart';
import '../services/sync_service.dart';

/// 同步会话状态
enum SyncSessionState {
  /// 初始状态
  initial,

  /// 已连接
  connected,

  /// 已验证
  authenticated,

  /// 同步中
  syncing,

  /// 同步完成
  completed,

  /// 失败
  failed,

  /// 已关闭
  closed,
}

/// 同步会话
/// 表示与远程节点的同步会话
class SyncSession {
  /// 会话ID
  final String sessionId;

  /// 远程节点
  final NetworkDiscoveredNode remoteNode;

  /// WebSocket 通道
  final WebSocketChannel channel;

  /// 会话状态
  SyncSessionState state;

  /// 开始时间
  final DateTime startTime;

  /// 结束时间
  DateTime? endTime;

  /// 错误信息
  String? errorMessage;

  /// 构造函数
  SyncSession({
    required this.sessionId,
    required this.remoteNode,
    required this.channel,
    this.state = SyncSessionState.initial,
  }) : startTime = DateTime.now();

  /// 关闭会话
  Future<void> close() async {
    state = SyncSessionState.closed;
    endTime = DateTime.now();
    await channel.sink.close();
  }

  @override
  String toString() {
    return 'SyncSession(sessionId: $sessionId, remoteNode: $remoteNode, state: $state)';
  }
}

/// 网络同步服务
/// 负责节点之间的数据同步
class NetworkHttpService {
  final _logger = AppLogger.getLogger('NetworkHttpService');

  // 本地节点信息
  String? _nodeId;
  String? _nodeName;
  String? _pubkeyFingerprint;

  // 服务器
  HttpServer? _server;
  int? _port;

  // 连接状态变化事件流
  final StreamController<List<String>> _connectionStateController =
      StreamController<List<String>>.broadcast();

  /// 节点连接状态变化事件流
  Stream<List<String>> get onConnectionStateChanged =>
      _connectionStateController.stream;

  // 活动会话
  final Map<String, SyncSession> _activeSessions = {};

  // 心跳检测定时器
  final Map<String, Timer> _heartbeatTimers = {};

  // 心跳检测间隔（毫秒）
  static const int _heartbeatInterval = 10000;

  // 同步服务
  final SyncService _syncService;

  // 节点密钥管理器
  final NodeKeyManager _keyManager = NodeKeyManager.getInstance();

  // 单例实例
  static NetworkHttpService? _instance;

  /// 私有构造函数
  NetworkHttpService._(this._syncService);

  /// 获取 NetworkSyncService 实例
  static Future<NetworkHttpService> getInstance() async {
    if (_instance == null) {
      final syncService = await SyncService.getInstance();
      _instance = NetworkHttpService._(syncService);
    }
    return _instance!;
  }

  /// 初始化网络同步服务
  ///
  /// 参数：
  /// - nodeId：本地节点ID
  /// - nodeName：本地节点名称
  /// - pubkeyFingerprint：本地节点公钥指纹
  /// - port：服务端口（如果为null，则使用网络发现服务提供的端口）
  ///
  /// 返回：初始化是否成功
  Future<bool> initialize(
      String nodeId, String nodeName, String pubkeyFingerprint,
      [int? port]) async {
    try {
      _logger.info('初始化网络同步服务');
      _logger
          .info('本地节点信息 - ID: $nodeId, 名称: $nodeName, 指纹: $pubkeyFingerprint');

      // 存储本地节点信息
      _nodeId = nodeId;
      _nodeName = nodeName;
      _pubkeyFingerprint = pubkeyFingerprint;
      _port = port;

      // 本地节点信息仅在内存中维护，不再保存到数据库

      // 初始化成功后，通知连接状态变化
      _connectionStateController.add(_activeSessions.keys.toList());

      _logger.info('网络同步服务初始化成功，本地节点状态：在线');
      return true;
    } catch (e, stack) {
      _logger.severe('网络同步服务初始化失败，本地节点状态：离线', e, stack);
      return false;
    }
  }

  /// 启动同步服务器
  ///
  /// 参数：
  /// - port：服务端口（如果为null，则使用初始化时提供的端口）
  ///
  /// 返回：服务器是否成功启动，以及使用的端口
  Future<(bool, int?)> startServer([int? port]) async {
    if (_nodeId == null || _nodeName == null || _pubkeyFingerprint == null) {
      _logger.warning('无法启动服务器：服务未初始化，本地节点状态：离线');
      return (false, null);
    }

    try {
      // 使用提供的端口或初始化时的端口
      final serverPort = port ?? _port;

      if (serverPort == null) {
        _logger.warning('无法启动服务器：未指定端口，本地节点状态：离线');
        return (false, null);
      }

      _logger.info('启动同步服务器：端口=$serverPort，本地节点状态：正在启动');

      // 创建 HTTP 服务器
      _server = await HttpServer.bind(InternetAddress.anyIPv4, serverPort);
      _port = serverPort;

      // 处理 WebSocket 升级请求
      _server!.listen((request) {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          _handleWebSocketRequest(request);
        } else {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.close();
        }
      });

      // 本地节点状态仅在内存中维护，不再保存到数据库

      _logger.info('同步服务器启动成功：端口=$_port，本地节点状态：在线');
      return (true, _port);
    } catch (e, stack) {
      _logger.severe('启动同步服务器失败，本地节点状态：离线', e, stack);
      return (false, null);
    }
  }

  /// 停止同步服务器
  Future<void> stopServer() async {
    try {
      if (_server != null) {
        _logger.info('停止同步服务器，本地节点状态：正在关闭');

        // 关闭所有活动会话
        for (var session in _activeSessions.values) {
          await session.close();
        }
        _activeSessions.clear();

        // 本地节点状态仅在内存中维护，不再保存到数据库

        // 关闭服务器
        await _server!.close(force: true);
        _server = null;

        _logger.info('同步服务器已停止，本地节点状态：离线');
      }
    } catch (e, stack) {
      _logger.severe('停止同步服务器失败，本地节点状态：未知', e, stack);
    }
  }

  /// 连接到远程节点
  ///
  /// 参数：
  /// - remoteNode：远程节点
  ///
  /// 返回：同步会话，如果连接失败则返回 null
  Future<SyncSession?> connectToNode(NetworkDiscoveredNode remoteNode) async {
    if (_nodeId == null || _nodeName == null || _pubkeyFingerprint == null) {
      _logger.warning('无法连接到节点：服务未初始化');
      return null;
    }

    try {
      _logger.info(
          '连接到节点：${remoteNode.nodeName} (${remoteNode.host}:${remoteNode.port})');

      // 创建 WebSocket 连接
      final uri = Uri.parse('ws://${remoteNode.host}:${remoteNode.port}/sync');
      final channel = IOWebSocketChannel.connect(uri);

      // 创建会话
      final sessionId = '${_nodeId!}_${DateTime.now().millisecondsSinceEpoch}';
      final session = SyncSession(
        sessionId: sessionId,
        remoteNode: remoteNode,
        channel: channel,
        state: SyncSessionState.connected,
      );

      // 存储会话
      _activeSessions[sessionId] = session;

      // 启动心跳检测
      _startHeartbeat(session);

      // 发送认证请求
      await _sendAuthRequest(session);

      // 处理消息
      channel.stream.listen(
        (message) => _handleMessage(session, message),
        onError: (error) => _handleError(session, error),
        onDone: () => _handleDone(session),
      );

      _logger.info('连接到节点成功：${remoteNode.nodeName}');
      return session;
    } catch (e, stack) {
      _logger.severe('连接到节点失败：${remoteNode.nodeName}', e, stack);
      return null;
    }
  }

  /// 与远程节点同步数据
  ///
  /// 参数：
  /// - session：同步会话
  ///
  /// 返回：同步是否成功
  Future<bool> synchronizeWithNode(SyncSession session) async {
    if (session.state != SyncSessionState.authenticated) {
      _logger.warning('无法同步数据：会话未认证');
      return false;
    }

    try {
      _logger.info('开始与节点同步数据：${session.remoteNode.nodeName}');

      // 更新会话状态
      session.state = SyncSessionState.syncing;

      // 获取本地更改集
      final localChangeset = await _syncService.database.getChangeset();

      // 发送同步请求
      final syncRequest = {
        'type': 'sync_request',
        'changeset': base64Encode(jsonEncode(localChangeset).codeUnits),
        'timestamp': DateTime.now().toIso8601String(),
      };

      session.channel.sink.add(jsonEncode(syncRequest));

      // 等待同步响应（在消息处理中完成）

      _logger.info('同步请求已发送：${session.remoteNode.nodeName}');
      return true;
    } catch (e, stack) {
      _logger.severe('发送同步请求失败：${session.remoteNode.nodeName}', e, stack);
      session.state = SyncSessionState.failed;
      session.errorMessage = e.toString();
      return false;
    }
  }

  /// 启动心跳检测
  void _startHeartbeat(SyncSession session) {
    // 取消已存在的心跳定时器
    _heartbeatTimers[session.sessionId]?.cancel();

    // 创建新的心跳定时器
    _heartbeatTimers[session.sessionId] = Timer.periodic(
      Duration(milliseconds: _heartbeatInterval),
      (_) => _sendHeartbeat(session),
    );
  }

  /// 发送心跳包
  void _sendHeartbeat(SyncSession session) {
    if (session.state == SyncSessionState.authenticated) {
      try {
        final heartbeat = {
          'type': 'heartbeat',
          'timestamp': DateTime.now().toIso8601String(),
        };
        session.channel.sink.add(jsonEncode(heartbeat));
      } catch (e) {
        _logger.warning('发送心跳包失败：${session.remoteNode.nodeName}');
        closeSession(session.sessionId);
      }
    }
  }

  /// 关闭同步会话
  ///
  /// 参数：
  /// - sessionId：会话ID
  Future<void> closeSession(String sessionId) async {
    try {
      final session = _activeSessions[sessionId];
      if (session != null) {
        _logger.info('关闭同步会话：$sessionId');

        // 取消心跳定时器
        _heartbeatTimers[sessionId]?.cancel();
        _heartbeatTimers.remove(sessionId);

        // 关闭会话
        await session.close();

        // 从活动会话中移除
        _activeSessions.remove(session.sessionId);

        // 通知连接状态变化
        _connectionStateController.add(_activeSessions.keys.toList());
      }

      /// 处理会话完成

      /// 关闭服务
    } catch (e, stack) {
      _logger.severe('关闭同步会话失败：$sessionId', e, stack);
    }
  }

  /// 处理 WebSocket 升级请求
  void _handleWebSocketRequest(HttpRequest request) async {
    try {
      _logger.info(
          '收到 WebSocket 连接请求：${request.connectionInfo?.remoteAddress.address}');

      // 升级到 WebSocket 连接
      final socket = await WebSocketTransformer.upgrade(request);

      // 创建通道
      final channel = IOWebSocketChannel(socket);

      // 创建会话
      final remoteAddress =
          request.connectionInfo?.remoteAddress.address ?? 'unknown';
      final remotePort = request.connectionInfo?.remotePort ?? 0;

      // 创建一个临时的远程节点（稍后会通过认证更新）
      final tempNode = NetworkDiscoveredNode(
        nodeId: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        nodeName: 'Unknown',
        pubkeyFingerprint: '',
        host: remoteAddress,
        port: remotePort,
      );

      final sessionId = 'server_${DateTime.now().millisecondsSinceEpoch}';
      final session = SyncSession(
        sessionId: sessionId,
        remoteNode: tempNode,
        channel: channel,
        state: SyncSessionState.connected,
      );

      // 存储会话
      _activeSessions[sessionId] = session;

      // 处理消息
      channel.stream.listen(
        (message) => _handleMessage(session, message),
        onError: (error) => _handleError(session, error),
        onDone: () => _handleDone(session),
      );

      _logger.info('WebSocket 连接已建立：$sessionId');
    } catch (e, stack) {
      _logger.severe('处理 WebSocket 连接请求失败', e, stack);
    }
  }

  /// 发送认证请求
  Future<void> _sendAuthRequest(SyncSession session) async {
    try {
      // 准备认证数据
      final authData = {
        'nodeId': _nodeId,
        'nodeName': _nodeName,
        'fingerprint': _pubkeyFingerprint,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // 将认证数据转换为字节
      final authDataBytes = utf8.encode(jsonEncode(authData));

      // 签名认证数据
      final signature = await _keyManager.signData(_nodeId!, authDataBytes);

      if (signature == null) {
        throw Exception('签名认证数据失败');
      }

      // 发送认证请求
      final authRequest = {
        'type': 'auth_request',
        'data': authData,
        'signature': signature,
      };

      session.channel.sink.add(jsonEncode(authRequest));

      _logger.info('发送认证请求：${session.remoteNode.nodeName}');
    } catch (e, stack) {
      _logger.severe('发送认证请求失败：${session.remoteNode.nodeName}', e, stack);
      session.state = SyncSessionState.failed;
      session.errorMessage = e.toString();
    }
  }

  /// 处理收到的消息
  void _handleMessage(SyncSession session, dynamic message) async {
    try {
      _logger.info('收到消息：${session.remoteNode.nodeName}');

      // 解析消息
      final Map<String, dynamic> data = jsonDecode(message);
      final String type = data['type'];

      switch (type) {
        case 'auth_request':
          await _handleAuthRequest(session, data);
          break;
        case 'auth_response':
          await _handleAuthResponse(session, data);
          break;
        case 'sync_request':
          await _handleSyncRequest(session, data);
          break;
        case 'sync_response':
          await _handleSyncResponse(session, data);
          break;
        case 'heartbeat':
          // 重置心跳定时器
          _startHeartbeat(session);
          break;
        default:
          _logger.warning('收到未知类型的消息：$type');
      }
    } catch (e, stack) {
      _logger.severe('处理消息失败', e, stack);
      session.state = SyncSessionState.failed;
      session.errorMessage = e.toString();
    }
  }

  /// 处理认证请求
  Future<void> _handleAuthRequest(
      SyncSession session, Map<String, dynamic> data) async {
    try {
      _logger.info('处理认证请求：${session.remoteNode.nodeName}');

      // 获取认证数据
      final Map<String, dynamic> authData = data['data'];
      final String signature = data['signature'];

      // 验证认证数据
      final String remoteNodeId = authData['nodeId'];
      final String remoteNodeName = authData['nodeName'];
      final String remoteFingerprint = authData['fingerprint'];
      final String? remotePublicKey = authData['publicKey']; // 获取远程节点的公钥

      // 如果收到了远程节点的公钥，先存储它，再验证签名
      if (remotePublicKey != null) {
        await _storeRemoteNodePublicKey(
            remoteNodeId, remoteNodeName, remoteFingerprint, remotePublicKey);
      }

      // 验证签名
      final bool isSignatureValid =
          await _verifyAuthSignature(authData, signature, remoteFingerprint);
      if (!isSignatureValid) {
        _logger.warning('认证请求签名验证失败：${session.remoteNode.nodeName}');
        throw Exception('签名验证失败，可能存在安全风险');
      }

      // 更新会话中的远程节点信息
      final updatedNode = NetworkDiscoveredNode(
        nodeId: remoteNodeId,
        nodeName: remoteNodeName,
        pubkeyFingerprint: remoteFingerprint,
        host: session.remoteNode.host,
        port: session.remoteNode.port,
      );

      // 更新会话
      _activeSessions[session.sessionId] = SyncSession(
        sessionId: session.sessionId,
        remoteNode: updatedNode,
        channel: session.channel,
        state: SyncSessionState.authenticated,
      );

      // 如果收到了远程节点的公钥，则存储它
      if (remotePublicKey != null) {
        await _storeRemoteNodePublicKey(
            remoteNodeId, remoteNodeName, remoteFingerprint, remotePublicKey);
      }

      // 准备认证响应
      final localNodeId = _nodeId;
      final localNodeName = _nodeName;
      final localFingerprint = _pubkeyFingerprint;

      // 获取本地节点的公钥
      final localPublicKey = await _getLocalNodePublicKey();

      // 构建认证响应数据
      final responseData = {
        'nodeId': localNodeId,
        'nodeName': localNodeName,
        'fingerprint': localFingerprint,
        'publicKey': localPublicKey, // 包含本地节点的公钥
      };

      // 签名认证响应数据
      final nodeKeyManager = NodeKeyManager.getInstance();
      final responseSignature = await nodeKeyManager.signData(
          localNodeId!, utf8.encode(jsonEncode(responseData)));

      // 发送认证响应
      final response = {
        'type': 'auth_response',
        'data': responseData,
        'signature': responseSignature,
      };

      session.channel.sink.add(jsonEncode(response));
      _logger.info('发送认证响应：${session.remoteNode.nodeName}');
    } catch (e, stack) {
      _logger.severe('处理认证请求失败', e, stack);

      // 发送失败响应
      final authResponse = {
        'type': 'auth_response',
        'status': 'error',
        'message': e.toString(),
      };

      session.channel.sink.add(jsonEncode(authResponse));

      // 更新会话状态
      session.state = SyncSessionState.failed;
      session.errorMessage = e.toString();
    }
  }

  /// 验证认证请求的签名
  ///
  /// 参数：
  /// - authData：认证数据
  /// - signature：签名（base64编码）
  /// - fingerprint：公钥指纹
  ///
  /// 返回：签名是否有效
  Future<bool> _verifyAuthSignature(
    Map<String, dynamic> authData,
    String signature,
    String fingerprint,
  ) async {
    try {
      // 获取节点密钥管理器
      final nodeKeyManager = NodeKeyManager.getInstance();

      // 获取远程节点的公钥
      // 注意：这里需要从指纹获取公钥，或者从数据库中获取已知节点的公钥
      final List<int>? publicKeyBytes =
          await _getPublicKeyFromFingerprint(fingerprint);

      if (publicKeyBytes == null) {
        _logger.warning('无法获取公钥：fingerprint=$fingerprint');
        return false;
      }

      // 将认证数据转换为字节数组
      final List<int> dataBytes = utf8.encode(jsonEncode(authData));

      // 验证签名
      return await nodeKeyManager.verifySignature(
        publicKeyBytes,
        dataBytes,
        signature,
      );
    } catch (e, stack) {
      _logger.severe('验证认证签名失败', e, stack);
      return false;
    }
  }

  /// 从公钥指纹获取公钥
  ///
  /// 参数：
  /// - fingerprint：公钥指纹
  ///
  /// 返回：公钥字节，如果不存在则返回 null
  Future<List<int>?> _getPublicKeyFromFingerprint(String fingerprint) async {
    try {
      // 从数据库获取已知节点信息
      final databaseManager = await DatabaseManager.getInstance();
      final nodeDao = NodeDao(databaseManager.database);
      final node = await nodeDao.getNodeByFingerprint(fingerprint);

      if (node != null && node.publicKey != null) {
        // 如果节点存在且有公钥，则返回公钥字节
        _logger.info('找到节点公钥：fingerprint=$fingerprint');
        return base64Decode(node.publicKey!);
      }

      _logger.warning('未找到节点公钥：fingerprint=$fingerprint');
      return null;
    } catch (e, stack) {
      _logger.severe('获取公钥失败：fingerprint=$fingerprint', e, stack);
      return null;
    }
  }

  /// 存储远程节点的公钥
  ///
  /// 参数：
  /// - nodeId：节点ID
  /// - nodeName：节点名称
  /// - fingerprint：公钥指纹
  /// - publicKey：公钥（Base64编码）
  Future<void> _storeRemoteNodePublicKey(
    String nodeId,
    String nodeName,
    String fingerprint,
    String publicKey,
  ) async {
    try {
      _logger.info('存储远程节点公钥：nodeId=$nodeId, fingerprint=$fingerprint');

      final databaseManager = await DatabaseManager.getInstance();
      final nodeDao = NodeDao(databaseManager.database);

      // 检查节点是否已存在
      final existingNode = await nodeDao.getNodeByFingerprint(fingerprint);

      if (existingNode != null) {
        // 如果节点已存在，则更新公钥
        final updatedNode = existingNode.copyWith(
          publicKey: publicKey,
        );
        await nodeDao.updateNode(updatedNode);
        _logger.info('更新节点公钥成功：nodeId=$nodeId');
      } else {
        // 如果节点不存在，则创建新节点
        await nodeDao.createNode(
          nodeId,
          nodeName,
          fingerprint,
          false, // 默认不信任
          publicKey,
        );
        _logger.info('创建节点并存储公钥成功：nodeId=$nodeId');
      }
    } catch (e, stack) {
      _logger.severe('存储远程节点公钥失败：nodeId=$nodeId', e, stack);
    }
  }

  /// 获取本地节点的公钥
  ///
  /// 返回：本地节点的公钥（Base64编码），如果获取失败则返回 null
  Future<String?> _getLocalNodePublicKey() async {
    try {
      if (_nodeId == null) {
        _logger.warning('获取本地节点公钥失败：本地节点ID为空');
        return null;
      }

      final keyManager = NodeKeyManager.getInstance();

      // 获取本地节点的密钥对
      final keyPair = await keyManager.getNodeKeyPair(_nodeId!);

      if (keyPair != null) {
        // 提取公钥
        final publicKey = await keyPair.extractPublicKey();

        // 获取公钥字节
        final publicKeyBytes = (publicKey as dynamic).bytes as List<int>;

        // 编码为 Base64
        return base64Encode(publicKeyBytes);
      }

      _logger.warning('获取本地节点公钥失败：未找到密钥对');
      return null;
    } catch (e, stack) {
      _logger.severe('获取本地节点公钥失败', e, stack);
      return null;
    }
  }

  /// 处理认证响应
  Future<void> _handleAuthResponse(
      SyncSession session, Map<String, dynamic> data) async {
    try {
      _logger.info('处理认证响应：${session.remoteNode.nodeName}');

      // 获取认证状态
      final String status = data['status'];

      if (status == 'success') {
        // 获取远程节点信息
        final Map<String, dynamic> remoteData = data['data'];
        final String remoteNodeId = remoteData['nodeId'];
        final String remoteNodeName = remoteData['nodeName'];
        final String remoteFingerprint = remoteData['fingerprint'];

        // 更新会话中的远程节点信息
        final updatedNode = NetworkDiscoveredNode(
          nodeId: remoteNodeId,
          nodeName: remoteNodeName,
          pubkeyFingerprint: remoteFingerprint,
          host: session.remoteNode.host,
          port: session.remoteNode.port,
        );

        // 更新会话
        _activeSessions[session.sessionId] = SyncSession(
          sessionId: session.sessionId,
          remoteNode: updatedNode,
          channel: session.channel,
          state: SyncSessionState.authenticated,
        );

        _logger.info('认证成功：${updatedNode.nodeName}');

        // 自动开始同步
        await synchronizeWithNode(_activeSessions[session.sessionId]!);
      } else {
        // 认证失败
        final String message = data['message'] ?? '未知错误';

        _logger.warning('认证失败：$message');

        // 更新会话状态
        session.state = SyncSessionState.failed;
        session.errorMessage = message;
      }
    } catch (e, stack) {
      _logger.severe('处理认证响应失败', e, stack);
      session.state = SyncSessionState.failed;
      session.errorMessage = e.toString();
    }
  }

  /// 处理同步请求
  Future<void> _handleSyncRequest(
      SyncSession session, Map<String, dynamic> data) async {
    try {
      _logger.info('处理同步请求：${session.remoteNode.nodeName}');

      // 检查会话状态
      if (session.state != SyncSessionState.authenticated &&
          session.state != SyncSessionState.syncing) {
        throw Exception('会话未认证');
      }

      // 获取远程更改集
      final String changesetBase64 = data['changeset'];
      final String remoteChangeset = utf8.decode(base64Decode(changesetBase64));

      // 应用远程更改
      await _syncService.database.merge(jsonDecode(remoteChangeset));

      // 获取本地更改集
      final localChangeset = await _syncService.database.getChangeset();

      // 发送同步响应
      final syncResponse = {
        'type': 'sync_response',
        'status': 'success',
        'changeset': base64Encode(jsonEncode(localChangeset).codeUnits),
        'timestamp': DateTime.now().toIso8601String(),
      };

      session.channel.sink.add(jsonEncode(syncResponse));

      // 更新会话状态
      session.state = SyncSessionState.completed;

      _logger.info('同步请求处理成功：${session.remoteNode.nodeName}');
    } catch (e, stack) {
      _logger.severe('处理同步请求失败', e, stack);

      // 发送失败响应
      final syncResponse = {
        'type': 'sync_response',
        'status': 'error',
        'message': e.toString(),
      };

      session.channel.sink.add(jsonEncode(syncResponse));

      // 更新会话状态
      session.state = SyncSessionState.failed;
      session.errorMessage = e.toString();
    }
  }

  /// 处理同步响应
  Future<void> _handleSyncResponse(
      SyncSession session, Map<String, dynamic> data) async {
    try {
      _logger.info('处理同步响应：${session.remoteNode.nodeName}');

      // 获取同步状态
      final String status = data['status'];

      if (status == 'success') {
        // 获取远程更改集
        final String changesetBase64 = data['changeset'];
        final String remoteChangeset =
            utf8.decode(base64Decode(changesetBase64));

        // 应用远程更改
        await _syncService.database.merge(jsonDecode(remoteChangeset));

        // 更新会话状态
        session.state = SyncSessionState.completed;

        _logger.info('同步成功：${session.remoteNode.nodeName}');
      } else {
        // 同步失败
        final String message = data['message'] ?? '未知错误';

        _logger.warning('同步失败：$message');

        // 更新会话状态
        session.state = SyncSessionState.failed;
        session.errorMessage = message;
      }
    } catch (e, stack) {
      _logger.severe('处理同步响应失败', e, stack);
      session.state = SyncSessionState.failed;
      session.errorMessage = e.toString();
    }
  }

  /// 处理错误
  void _handleError(SyncSession session, dynamic error) {
    _logger.severe('会话错误：${session.remoteNode.nodeName}', error);
    session.state = SyncSessionState.failed;
    session.errorMessage = error.toString();
  }

  /// 处理连接关闭
  void _handleDone(SyncSession session) {
    _logger.info('会话关闭：${session.remoteNode.nodeName}');
    session.state = SyncSessionState.closed;
    session.endTime = DateTime.now();
    _activeSessions.remove(session.sessionId);
  }

  /// 关闭服务
  Future<void> close() async {
    try {
      _logger.info('关闭网络同步服务');

      // 停止服务器
      await stopServer();

      // 关闭所有活动会话
      for (final session in _activeSessions.values.toList()) {
        await session.close();
      }
      _activeSessions.clear();

      // 关闭连接状态控制器
      await _connectionStateController.close();

      _logger.info('网络同步服务已关闭');
    } catch (e, stack) {
      _logger.severe('关闭网络同步服务失败', e, stack);
    }
  }

  /// 执行网络同步服务自检
  ///
  /// 返回：自检结果，包含各个组件的状态和可能的错误信息
  Future<Map<String, dynamic>> selfCheck() async {
    final result = <String, dynamic>{
      'initialized':
          _nodeId != null && _nodeName != null && _pubkeyFingerprint != null,
      'server': {
        'status': 'unknown',
        'error': null,
        'port': _port,
      },
      'sessions': {
        'status': 'unknown',
        'error': null,
        'active_count': _activeSessions.length,
      },
    };

    try {
      _logger.info('执行网络同步服务自检');

      // 检查服务器状态
      if (_server != null) {
        result['server']['status'] = 'ok';
      } else {
        // 尝试启动服务器
        final (success, port) = await startServer();
        if (success) {
          result['server']['status'] = 'ok';
          result['server']['port'] = port;
          await stopServer(); // 测试完成后停止服务器
        } else {
          result['server']['status'] = 'failed';
          result['server']['error'] = '无法启动服务器';
        }
      }

      // 检查会话状态
      if (_activeSessions.isNotEmpty) {
        result['sessions']['status'] = 'ok';
      } else {
        result['sessions']['status'] = 'no_active_sessions';
      }

      _logger.info('网络同步服务自检完成，结果: $result');
      return result;
    } catch (e, stack) {
      _logger.severe('网络同步服务自检失败', e, stack);
      return {
        ...result,
        'error': e.toString(),
        'stack': stack.toString(),
      };
    }
  }
}
