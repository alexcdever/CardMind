import 'package:cardmind/shared/utils/logger.dart';
import 'package:sqlite_crdt/sqlite_crdt.dart';
import '../../domain/models/node.dart';

/// 节点数据访问对象
/// 负责节点相关的数据库操作
class NodeDao {
  final SqliteCrdt _db;
  final _logger = AppLogger.getLogger('NodeDao');

  /// 构造函数
  NodeDao(this._db);

  /// 创建节点
  ///
  /// 参数：
  /// - nodeId：节点ID
  /// - nodeName：节点名称
  /// - pubkeyFingerprint：公钥指纹
  /// - isTrusted：是否是受信任节点
  ///
  /// 返回：创建的节点，如果创建失败则返回 null
  Future<Node?> createNode(
    String nodeId,
    String nodeName,
    String pubkeyFingerprint,
    bool isTrusted,
  ) async {
    try {
      _logger.info('创建节点: ID=$nodeId, 名称=$nodeName');
      final now = DateTime.now().toIso8601String();

      // 使用 execute 方法执行插入操作
      await _db.execute('''
        INSERT INTO nodes (node_id, node_name, pubkey_fingerprint, is_trusted, created_at)
        VALUES (?1, ?2, ?3, ?4, ?5)
      ''', [nodeId, nodeName, pubkeyFingerprint, isTrusted ? 1 : 0, now]);
      
      _logger.info('创建节点成功: ID=$nodeId, 名称=$nodeName');
      
      // 返回创建的节点
      return Node(
        nodeId: nodeId,
        nodeName: nodeName,
        pubkeyFingerprint: pubkeyFingerprint,
        isTrusted: isTrusted,
        createdAt: DateTime.parse(now),
      );
    } catch (e, stack) {
      _logger.severe('创建节点失败: 错误=$e', e, stack);
      return null;
    }
  }

  /// 更新节点
  ///
  /// 参数：
  /// - nodeId：节点ID
  /// - nodeName：新节点名称
  /// - isTrusted：是否是受信任节点
  ///
  /// 返回：更新是否成功
  Future<bool> updateNode(
    String nodeId,
    String nodeName,
    bool isTrusted,
  ) async {
    try {
      _logger.info('尝试更新节点: ID=$nodeId, 名称=$nodeName');
      
      // 首先检查节点是否存在
      final checkResult = await _db.query(
        'SELECT node_id FROM nodes WHERE node_id = ?1', 
        [nodeId]
      );
      
      if (checkResult.isEmpty) {
        _logger.warning('更新节点失败：节点不存在: ID=$nodeId');
        return false;
      }
      
      // 使用 UPDATE 语句更新节点
      await _db.execute('''
        UPDATE nodes SET node_name = ?1, is_trusted = ?2
        WHERE node_id = ?3
      ''', [nodeName, isTrusted ? 1 : 0, nodeId]);
      
      _logger.info('更新节点成功：ID=$nodeId, 名称=$nodeName');
      return true;
    } catch (e, stack) {
      _logger.severe('更新节点失败：ID=$nodeId, 错误=$e', e, stack);
      return false;
    }
  }

  /// 更新节点同步时间
  ///
  /// 参数：
  /// - nodeId：节点ID
  /// - lastSync：最后同步时间
  ///
  /// 返回：更新是否成功
  Future<bool> updateNodeSyncTime(String nodeId, DateTime lastSync) async {
    try {
      _logger.info('更新节点同步时间: ID=$nodeId, 时间=${lastSync.toIso8601String()}');
      
      // 首先检查节点是否存在
      final checkResult = await _db.query(
        'SELECT node_id FROM nodes WHERE node_id = ?1', 
        [nodeId]
      );
      
      if (checkResult.isEmpty) {
        _logger.warning('更新节点同步时间失败：节点不存在: ID=$nodeId');
        return false;
      }
      
      // 使用 UPDATE 语句更新节点同步时间
      await _db.execute('''
        UPDATE nodes SET last_sync = ?1
        WHERE node_id = ?2
      ''', [lastSync.toIso8601String(), nodeId]);
      
      _logger.info('更新节点同步时间成功：ID=$nodeId');
      return true;
    } catch (e, stack) {
      _logger.severe('更新节点同步时间失败：ID=$nodeId, 错误=$e', e, stack);
      return false;
    }
  }

  /// 获取所有节点
  ///
  /// 返回：节点列表
  Future<List<Node>> getAllNodes() async {
    try {
      // 使用 query 方法查询所有节点
      final results = await _db.query(
        'SELECT * FROM nodes ORDER BY created_at DESC'
      );
      _logger.info('获取所有节点：${results.length} 条记录');
      return results.map(_mapToNode).toList();
    } catch (e, stack) {
      _logger.severe('获取所有节点失败: 错误=$e', e, stack);
      return [];
    }
  }

  /// 获取所有受信任节点
  ///
  /// 返回：受信任节点列表
  Future<List<Node>> getTrustedNodes() async {
    try {
      // 使用 query 方法查询所有受信任节点
      final results = await _db.query(
        'SELECT * FROM nodes WHERE is_trusted = 1 ORDER BY created_at DESC'
      );
      _logger.info('获取所有受信任节点：${results.length} 条记录');
      return results.map(_mapToNode).toList();
    } catch (e, stack) {
      _logger.severe('获取所有受信任节点失败: 错误=$e', e, stack);
      return [];
    }
  }

  /// 根据 ID 获取节点
  ///
  /// 参数：
  /// - nodeId：节点 ID
  ///
  /// 返回：节点，如果不存在则返回 null
  Future<Node?> getNodeById(String nodeId) async {
    try {
      // 使用 query 方法查询特定节点
      final results = await _db.query(
        'SELECT * FROM nodes WHERE node_id = ?1',
        [nodeId]
      );

      if (results.isEmpty) {
        _logger.warning('获取节点失败：节点不存在: ID=$nodeId');
        return null;
      }

      _logger.info('获取节点成功：ID=$nodeId');
      return _mapToNode(results.first);
    } catch (e, stack) {
      _logger.severe('获取节点失败: ID=$nodeId, 错误=$e', e, stack);
      return null;
    }
  }

  /// 根据公钥指纹获取节点
  ///
  /// 参数：
  /// - fingerprint：公钥指纹
  ///
  /// 返回：节点，如果不存在则返回 null
  Future<Node?> getNodeByFingerprint(String fingerprint) async {
    try {
      // 使用 query 方法查询特定节点
      final results = await _db.query(
        'SELECT * FROM nodes WHERE pubkey_fingerprint = ?1',
        [fingerprint]
      );

      if (results.isEmpty) {
        _logger.warning('获取节点失败：节点不存在: 指纹=$fingerprint');
        return null;
      }

      _logger.info('获取节点成功：指纹=$fingerprint');
      return _mapToNode(results.first);
    } catch (e, stack) {
      _logger.severe('获取节点失败: 指纹=$fingerprint, 错误=$e', e, stack);
      return null;
    }
  }

  /// 删除节点
  ///
  /// 参数：
  /// - nodeId：节点 ID
  ///
  /// 返回：删除是否成功
  Future<bool> deleteNode(String nodeId) async {
    try {
      // 使用 DELETE 语句删除节点
      await _db.execute('''
        DELETE FROM nodes WHERE node_id = ?1
      ''', [nodeId]);
      
      _logger.info('删除节点成功：ID=$nodeId');
      return true;
    } catch (e, stack) {
      _logger.severe('删除节点失败: ID=$nodeId, 错误=$e', e, stack);
      return false;
    }
  }
  
  /// 将数据库记录映射为节点对象
  Node _mapToNode(Map<String, dynamic> record) {
    return Node(
      nodeId: record['node_id'] as String,
      nodeName: record['node_name'] as String,
      pubkeyFingerprint: record['pubkey_fingerprint'] as String,
      isTrusted: (record['is_trusted'] as int) == 1,
      lastSync: record['last_sync'] != null 
          ? DateTime.parse(record['last_sync'] as String) 
          : null,
      createdAt: DateTime.parse(record['created_at'] as String),
    );
  }
}
