import 'package:logging/logging.dart';
import 'package:cardmind/shared/data/model/network_node.dart';
import 'package:cardmind/shared/util/logger.dart';

/// 节点管理服务
class NodeManagementService {
  final Logger _logger = AppLogger.getLogger('NodeManagementService');
  final List<NetworkNode> _nodes = [];
  final List<String> _blacklist = [];

  /// 添加节点到网络
  Future<void> addNode(NetworkNode node) async {
    if (_blacklist.contains(node.nodeId)) {
      _logger.warning('尝试添加黑名单节点: ${node.nodeId}');
      return;
    }

    if (!_nodes.any((n) => n.nodeId == node.nodeId)) {
      _nodes.add(node);
      _logger.info('已添加节点: ${node.nodeId}');
    }
  }

  /// 从网络移除节点
  Future<void> removeNode(String nodeId) async {
    _nodes.removeWhere((node) => node.nodeId == nodeId);
    _logger.info('已移除节点: $nodeId');
  }

  /// 添加到黑名单
  Future<void> blacklistNode(String nodeId) async {
    if (!_blacklist.contains(nodeId)) {
      _blacklist.add(nodeId);
      _logger.info('已添加节点到黑名单: $nodeId');
    }
  }

  /// 获取所有节点
  List<NetworkNode> getNodes() => List.unmodifiable(_nodes);

  /// 获取节点连接状态
  bool isNodeConnected(String nodeId) {
    return _nodes.any((node) => node.nodeId == nodeId);
  }

  /// 更新节点信息
  Future<void> updateNode(NetworkNode updatedNode) async {
    final index = _nodes.indexWhere((n) => n.nodeId == updatedNode.nodeId);
    if (index != -1) {
      _nodes[index] = updatedNode;
      _logger.fine('已更新节点信息: ${updatedNode.nodeId}');
    }
  }
}
