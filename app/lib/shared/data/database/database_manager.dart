import 'package:sqlite_crdt/sqlite_crdt.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../../utils/logger.dart';

/// 数据库管理类
/// 负责数据库的初始化、连接和关闭
class DatabaseManager {
  static final _logger = AppLogger.getLogger('DatabaseManager');
  static DatabaseManager? _instance;
  late SqliteCrdt _db;
  int get schemaVersion => 2;

  /// 获取数据库实例（单例模式）
  static Future<DatabaseManager> getInstance() async {
    if (_instance == null) {
      _instance = DatabaseManager._();
      await _instance!._init();
    }
    return _instance!;
  }

  DatabaseManager._();

  /// 获取 SqliteCrdt 实例
  SqliteCrdt get database => _db;

  /// 初始化数据库
  Future<void> _init() async {
    try {
      // 使用应用程序支持目录而不是用户文档目录
      final appSupportDir = await getApplicationSupportDirectory();
      final dbPath = path.join(appSupportDir.path, 'cardmind.db');

      _logger.info('初始化数据库: $dbPath');

      // 创建 SqliteCrdt 实例
      _db = await SqliteCrdt.open(
        dbPath,
        version: schemaVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );

      _logger.info('数据库初始化成功');
    } catch (e, stack) {
      _logger.severe('数据库初始化失败: $e', e, stack);
      rethrow;
    }
  }

  /// 数据库创建回调
  Future<void> _onCreate(dynamic db, int version) async {
    _logger.info('创建数据库，版本: $version');

    // 创建卡片表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    
    // 创建节点表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS nodes (
        node_id TEXT PRIMARY KEY,
        node_name TEXT NOT NULL,
        pubkey_fingerprint TEXT NOT NULL,
        is_trusted INTEGER NOT NULL,
        last_sync TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  /// 数据库升级回调
  Future<void> _onUpgrade(dynamic db, int oldVersion, int newVersion) async {
    _logger.info('数据库升级: $oldVersion -> $newVersion');

    // 版本 1 到版本 2 的迁移
    if (oldVersion < 2 && newVersion >= 2) {
      // 添加节点表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS nodes (
          node_id TEXT PRIMARY KEY,
          node_name TEXT NOT NULL,
          pubkey_fingerprint TEXT NOT NULL,
          is_trusted INTEGER NOT NULL,
          last_sync TEXT,
          created_at TEXT NOT NULL
        )
      ''');
    }
  }

  /// 关闭数据库连接
  Future<void> close() async {
    await _db.close();
    _instance = null;
  }
}
