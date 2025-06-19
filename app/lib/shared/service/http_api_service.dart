import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:cardmind/shared/data/model/network_node.dart';
import 'package:cardmind/shared/service/network_auth_service.dart';
import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:cardmind/shared/service/websocket_service.dart';
import 'package:cardmind/shared/service/node_management_service.dart';
import 'package:cardmind/shared/util/logger.dart';

/// HTTP API服务
class HttpApiService {
  final NetworkAuthService _authService;
  final WebSocketService _wsService;
  final int _port;
  final Logger _logger = AppLogger.getLogger('HttpApiService');

  HttpApiService(this._authService, this._wsService, this._port);

  Future<void> start() async {
    final app = Router();

    // 节点管理API
    app.get('/nodes', _getNodes);
    app.post('/nodes/join', _joinNetwork);
    app.post('/nodes/leave', _leaveNetwork);

    // WebSocket端点 - 使用正确的ConnectionCallback类型
    app.get('/ws', (Request request) {
      return webSocketHandler((WebSocketChannel channel, _) {
        _logger.info('WebSocket连接已建立');
        channel.stream.listen(
          (data) => _wsService.handleMessage(data),
          onError: (error) => _logger.severe('WebSocket错误: $error'),
          onDone: () => _logger.info('WebSocket连接已关闭'),
        );
      })(request);
    });

    // 数据同步API
    app.get('/sync/status', _getSyncStatus);
    app.post('/sync/request', _requestSync);

    final server = await shelf_io.serve(app, '0.0.0.0', _port);
    _logger.info('HTTP API服务已启动，端口: ${server.port}');
  }

// 获取节点列表
  Future<Response> _getNodes(Request request) async {
    // TODO: 实现节点列表查询
    return Response.ok('[]');
  }

  // 加入网络
  Future<Response> _joinNetwork(Request request) async {
    try {
      final body = await request.readAsString();
      final node = NetworkNode.fromJson(jsonDecode(body));

      // 1. 验证节点身份
      if (!await _authService.verifyNode(node)) {
        _logger.warning('节点验证失败: ${node.nodeId}');
        return Response.forbidden('节点验证失败');
      }

      // 2. 添加到节点管理
      // 通过WebSocket连接到新节点
      await _wsService.connect(node);
      _logger.info('已批准节点加入: ${node.nodeId}');

      return Response.ok(jsonEncode({'status': 'approved'}));
    } catch (e) {
      _logger.severe('加入网络请求处理错误: $e');
      return Response.internalServerError(body: '服务器错误');
    }
  }

  // 离开网络
  Future<Response> _leaveNetwork(Request request) async {
    // TODO: 实现离开网络逻辑
    return Response.ok('{}');
  }

  // 获取同步状态
  Future<Response> _getSyncStatus(Request request) async {
    // TODO: 实现同步状态查询
    return Response.ok('{}');
  }

  // 请求数据同步
  Future<Response> _requestSync(Request request) async {
    // TODO: 实现数据同步请求
    return Response.ok('{}');
  }
}
