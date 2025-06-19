import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:cardmind/shared/data/model/network_node.dart';
import 'package:cardmind/shared/service/network_auth_service.dart';
import 'package:logging/logging.dart';
import 'package:cardmind/shared/util/logger.dart';

/// WebSocket服务管理
/// 负责节点间实时通信
class WebSocketService {
  final NetworkAuthService _authService;
  final Logger _logger = AppLogger.getLogger('WebSocketService');

  // 当前活跃连接
  final Map<String, WebSocketChannel> _connections = {};

  WebSocketService(this._authService);

  /// 连接到指定节点
  Future<void> connect(NetworkNode node) async {
    if (_connections.containsKey(node.nodeId)) return;

    try {
      final uri = Uri.parse('ws://${node.ip}:${node.port}/ws');
      final channel = WebSocketChannel.connect(uri);

      // 发送认证信息
      channel.sink.add(await _authService.generateNodeCredentials());

      // 监听消息
      channel.stream.listen(
        (data) => handleMessage(data),
        onError: (error) => _handleError(error, node),
        onDone: () => _handleDisconnect(node),
      );

      _connections[node.nodeId] = channel;
      _logger.info('已连接到节点: ${node.nodeId}');
    } catch (e) {
      _logger.severe('连接节点失败: ${node.nodeId} - ${e.toString()}');
    }
  }

  /// 断开连接
  Future<void> disconnect(String nodeId) async {
    await _connections[nodeId]?.sink.close();
    _connections.remove(nodeId);
  }

  /// 发送消息
  void sendMessage(String nodeId, dynamic message) {
    _connections[nodeId]?.sink.add(message);
  }

  /// 处理接收到的消息
  void handleMessage(dynamic data) {
    try {
      final message = jsonDecode(data);
      _logger.fine('收到消息: ${message['type']}');

      switch (message['type']) {
        case 'sync':
          _handleSyncMessage(message);
          break;
        case 'node':
          _handleNodeMessage(message);
          break;
        default:
          _logger.warning('未知消息类型: ${message['type']}');
      }
    } catch (e) {
      _logger.severe('消息解析错误: $e');
    }
  }

  /// 处理同步消息
  void _handleSyncMessage(Map<String, dynamic> message) {
    // TODO: 实现同步消息处理
  }

  /// 处理节点消息
  void _handleNodeMessage(Map<String, dynamic> message) {
    // TODO: 实现节点消息处理
  }

  /// 处理连接错误
  void _handleError(dynamic error, NetworkNode node) {
    _logger.severe('与${node.nodeId}的连接错误 - ${error.toString()}');
    _connections.remove(node.nodeId);
  }

  /// 处理连接断开
  void _handleDisconnect(NetworkNode node) {
    _logger.info('与${node.nodeId}的连接已断开');
    _connections.remove(node.nodeId);
  }

  /// 关闭所有连接
  Future<void> dispose() async {
    for (final channel in _connections.values) {
      await channel.sink.close();
    }
    _connections.clear();
  }
}
