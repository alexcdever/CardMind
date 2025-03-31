import 'package:cardmind/shared/utils/logger.dart';
import 'package:sqlite_crdt/sqlite_crdt.dart';
import '../../domain/models/card.dart';

/// 卡片数据访问对象
/// 负责卡片相关的数据库操作
class CardDao {
  final SqliteCrdt _db;
  final _logger = AppLogger.getLogger('CardDao');

  /// 构造函数
  CardDao(this._db);

  /// 创建卡片
  ///
  /// 参数：
  /// - title：标题
  /// - content：内容
  ///
  /// 返回：创建的卡片，如果创建失败则返回 null
  Future<Card?> createCard(String title, String content) async {
    try {
      _logger.info('创建卡片: 标题=$title');
      final now = DateTime.now().toIso8601String();

      // 使用 execute 方法执行插入操作
      await _db.execute('''
        INSERT INTO cards (title, content, created_at, updated_at)
        VALUES (?1, ?2, ?3, ?4)
      ''', [title, content, now, now]);
      
      // 获取最后插入的 ID
      final result = await _db.query('SELECT last_insert_rowid() as id');
      final id = result.first['id'] as int;
      
      _logger.info('创建卡片成功: ID=$id, 标题=$title');
      
      // 返回创建的卡片
      return Card(
        id: id,
        title: title,
        content: content,
        createdAt: DateTime.parse(now),
        updatedAt: DateTime.parse(now),
      );
    } catch (e, stack) {
      _logger.severe('创建卡片失败: 错误=$e', e, stack);
      return null;
    }
  }

  /// 更新卡片
  ///
  /// 参数：
  /// - id：卡片 ID
  /// - title：新标题
  /// - content：新内容
  ///
  /// 返回：更新是否成功
  Future<bool> updateCard(int id, String title, String content) async {
    try {
      _logger.info('尝试更新卡片: ID=$id, 标题=$title');
      
      // 首先检查卡片是否存在
      final checkResult = await _db.query(
        'SELECT id FROM cards WHERE id = ?1', 
        [id]
      );
      
      if (checkResult.isEmpty) {
        _logger.severe('更新卡片失败：卡片不存在: ID=$id');
        return false;
      }
      
      // 使用 UPDATE 语句更新卡片
      final now = DateTime.now().toIso8601String();
      await _db.execute('''
        UPDATE cards SET title = ?1, content = ?2, updated_at = ?3
        WHERE id = ?4
      ''', [title, content, now, id]);
      
      _logger.info('更新卡片成功：ID=$id, 标题=$title');
      return true;
    } catch (e, stack) {
      _logger.severe('更新卡片失败：ID=$id, 错误=$e', e, stack);
      return false;
    }
  }

  /// 获取所有卡片
  ///
  /// 返回：卡片列表
  Future<List<Card>> getAllCards() async {
    try {
      // 使用 query 方法查询所有卡片
      final results = await _db.query(
        'SELECT * FROM cards ORDER BY updated_at DESC'
      );
      _logger.info('获取所有卡片：${results.length} 条记录');
      return results.map(_mapToCard).toList();
    } catch (e, stack) {
      _logger.severe('获取所有卡片失败: 错误=$e', e, stack);
      return [];
    }
  }

  /// 根据 ID 获取卡片
  ///
  /// 参数：
  /// - id：卡片 ID
  ///
  /// 返回：卡片，如果不存在则返回 null
  Future<Card?> getCardById(int id) async {
    try {
      // 使用 query 方法查询特定卡片
      final results = await _db.query(
        'SELECT * FROM cards WHERE id = ?1',
        [id]
      );

      if (results.isEmpty) {
        _logger.warning('获取卡片失败：卡片不存在: ID=$id');
        return null;
      }

      _logger.info('获取卡片成功：ID=$id');
      return _mapToCard(results.first);
    } catch (e, stack) {
      _logger.severe('获取卡片失败: ID=$id, 错误=$e', e, stack);
      return null;
    }
  }

  /// 删除卡片
  ///
  /// 参数：
  /// - id：卡片 ID
  ///
  /// 返回：删除是否成功
  Future<bool> deleteCard(int id) async {
    try {
      // 使用 DELETE 语句删除卡片
      await _db.execute('''
        DELETE FROM cards WHERE id = ?1
      ''', [id]);
      
      _logger.info('删除卡片成功：ID=$id');
      return true;
    } catch (e, stack) {
      _logger.severe('删除卡片失败: ID=$id, 错误=$e', e, stack);
      return false;
    }
  }

  /// 搜索卡片
  ///
  /// 参数：
  /// - query：搜索关键词
  ///
  /// 返回：匹配的卡片列表
  Future<List<Card>> searchCards(String query) async {
    try {
      // 使用 query 方法搜索卡片
      final results = await _db.query('''
        SELECT * FROM cards 
        WHERE title LIKE ?1 OR content LIKE ?2
        ORDER BY updated_at DESC
      ''', ['%$query%', '%$query%']);
      
      _logger.info('搜索卡片：关键词="$query", 找到 ${results.length} 条记录');
      return results.map(_mapToCard).toList();
    } catch (e, stack) {
      _logger.severe('搜索卡片失败: 关键词="$query", 错误=$e', e, stack);
      return [];
    }
  }
  
  /// 将数据库记录映射为卡片对象
  Card _mapToCard(Map<String, dynamic> record) {
    return Card(
      id: record['id'] as int,
      title: record['title'] as String,
      content: record['content'] as String,
      createdAt: DateTime.parse(record['created_at'] as String),
      updatedAt: DateTime.parse(record['updated_at'] as String),
    );
  }
}
