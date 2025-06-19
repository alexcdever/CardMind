import 'package:cardmind/shared/util/logger.dart';
import 'package:sqlite_crdt/sqlite_crdt.dart';
import '../model/network_node.dart';

/// 节点数据访问对象
/// 负责节点相关的数据库操作
class NetworkNodeDao {
  final SqliteCrdt _db;
  final _logger = AppLogger.getLogger('NetworkNodeDao');

  /// 构造函数
  NetworkNodeDao(this._db);

  /// 创建节点
  Future<NetworkNode?> createNode(
      String nodeId, String displayName, String ip, int port) async {
    try {
      _logger.info('创建节点: ID=$nodeId, 名称=$displayName');
      final now = DateTime.now().toIso8601String();

      await _db.execute('''
        INSERT INTO network_nodes (node_id, display_name, ip, port, is_online, is_local, last_seen)
        VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)
      ''', [nodeId, displayName, ip, port, true, false, now]);

      final result = await _db.query('SELECT last_insert_rowid() as id');
      final id = result.first['id'] as int;

      _logger.info('创建节点成功: ID=$id, 节点ID=$nodeId');

      return NetworkNode(
        id: id,
        nodeId: nodeId,
        displayName: displayName,
        ip: ip,
        port: port,
        isOnline: true,
        isLocal: false,
        lastSeen: DateTime.parse(now),
      );
    } catch (e, stack) {
      _logger.severe('创建节点失败: 错误=$e', e, stack);
      return null;
    }
  }

  /// 更新节点在线状态
  Future<bool> updateNodeStatus(String nodeId, bool isOnline) async {
    try {
      final now = DateTime.now().toIso8601String();
      await _db.execute('''
        UPDATE network_nodes 
        SET is_online = ?1, last_seen = ?2
        WHERE node_id = ?3
      ''', [isOnline, now, nodeId]);

      _logger.info('更新节点状态成功: 节点ID=$nodeId, 在线状态=$isOnline');
      return true;
    } catch (e, stack) {
      _logger.severe('更新节点状态失败: 节点ID=$nodeId, 错误=$e', e, stack);
      return false;
    }
  }

  /// 获取所有节点
  Future<List<NetworkNode>> getAllNodes() async {
    try {
      final results =
          await _db.query('SELECT * FROM network_nodes WHERE is_deleted = 0');
      _logger.info('获取所有节点: ${results.length} 条记录');
      return results.map(_mapToNode).toList();
    } catch (e, stack) {
      _logger.severe('获取所有节点失败: 错误=$e', e, stack);
      return [];
    }
  }

  /// 根据ID获取节点
  Future<NetworkNode?> getNodeById(String nodeId) async {
    try {
      final results = await _db.query(
          'SELECT * FROM network_nodes WHERE is_deleted = 0 AND node_id = ?1',
          [nodeId]);

      if (results.isEmpty) {
        _logger.warning('获取节点失败: 节点不存在: ID=$nodeId');
        return null;
      }

      _logger.info('获取节点成功: 节点ID=$nodeId');
      return _mapToNode(results.first);
    } catch (e, stack) {
      _logger.severe('获取节点失败: 节点ID=$nodeId, 错误=$e', e, stack);
      return null;
    }
  }

  /// 删除节点
  Future<bool> deleteNode(String nodeId) async {
    try {
      await _db.execute('''
        DELETE FROM network_nodes WHERE node_id = ?1
      ''', [nodeId]);

      _logger.info('删除节点成功: 节点ID=$nodeId');
      return true;
    } catch (e, stack) {
      _logger.severe('删除节点失败: 节点ID=$nodeId, 错误=$e', e, stack);
      return false;
    }
  }

  /// 将数据库记录映射为节点对象
  NetworkNode _mapToNode(Map<String, dynamic> record) {
    return NetworkNode(
      id: record['id'] as int,
      nodeId: record['node_id'] as String,
      displayName: record['display_name'] as String,
      ip: record['ip'] as String,
      port: record['port'] as int,
      isOnline: record['is_online'] == 1,
      isLocal: record['is_local'] == 1,
      lastSeen: DateTime.parse(record['last_seen'] as String),
    );
  }
}
