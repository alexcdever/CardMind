import 'package:cardmind/shared/utils/logger.dart';
import 'package:sqlite_crdt/sqlite_crdt.dart';
import '../data/dao/card_dao.dart';
import '../data/database/database_manager.dart';

/// 同步服务类
/// 处理数据同步和冲突解决的业务逻辑
class SyncService {
  final _logger = AppLogger.getLogger('SyncService');
  final SqliteCrdt _db;
  late CardDao _cardDao;

  /// 构造函数
  /// 
  /// 初始化同步服务类，需要提供 SqliteCrdt 实例
  SyncService(this._db) {
    _cardDao = CardDao(_db);
  }
  
  /// 私有构造函数
  SyncService._private(this._db) {
    _cardDao = CardDao(_db);
  }
  
  /// 单例实例
  static SyncService? _instance;
  
  /// 获取同步服务实例
  static Future<SyncService> getInstance() async {
    if (_instance == null) {
      final db = await DatabaseManager.getInstance();
      _instance = SyncService._private(db.database);
    }
    return _instance!;
  }

  /// 获取 CardDao 实例
  CardDao get cardDao => _cardDao;

  /// 获取 SqliteCrdt 实例
  SqliteCrdt get database => _db;

  /// 与其他节点同步数据
  /// 
  /// 参数：
  /// - remoteDb: 远程数据库实例
  /// 
  /// 返回：同步是否成功
  Future<bool> synchronize(SqliteCrdt remoteDb) async {
    try {
      // 获取本地更改集
      final localChangeset = await _db.getChangeset();
      
      // 获取远程更改集
      final remoteChangeset = await remoteDb.getChangeset();
      
      // 应用远程更改到本地（使用 merge 方法替代 applyChangeset）
      await _db.merge(remoteChangeset);
      
      // 应用本地更改到远程（使用 merge 方法替代 applyChangeset）
      await remoteDb.merge(localChangeset);
      
      _logger.info('数据同步成功');
      return true;
    } catch (e, stack) {
      _logger.severe('数据同步失败', e, stack);
      return false;
    }
  }
  
  /// 获取版本向量
  /// 
  /// 返回：当前节点的版本向量
  Future<Map<String, dynamic>> getVersionVector() async {
    try {
      // 由于 SqliteCrdt 没有 getVersionVector 方法，我们使用空 Map 作为替代
      // 在实际应用中，版本向量可能通过其他方式获取或不需要
      _logger.info('获取版本向量');
      return {};
    } catch (e, stack) {
      _logger.severe('获取版本向量失败', e, stack);
      return {};
    }
  }
}
