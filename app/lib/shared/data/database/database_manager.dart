import 'package:sqlite_crdt/sqlite_crdt.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:io';
import '../../utils/logger.dart';

/// 数据库管理类
/// 负责数据库的初始化、连接和关闭
class DatabaseManager {
  static final _logger = AppLogger.getLogger('DatabaseManager');
  static DatabaseManager? _instance;
  
  // 使用Completer来控制初始化完成的状态
  static final Completer<void> _initCompleter = Completer<void>();
  
  // 初始化状态标志
  static bool _isInitializing = false;
  static bool _isInitialized = false;
  
  late SqliteCrdt _db;
  static const int schemaVersion = 4;

  /// 获取数据库实例（单例模式）
  static Future<DatabaseManager> getInstance() async {
    // 如果实例不存在，创建新实例并开始初始化
    if (_instance == null) {
      _instance = DatabaseManager._();
      
      // 如果尚未开始初始化，则开始初始化
      if (!_isInitializing) {
        _isInitializing = true;
        _instance!._init().then((_) {
          _isInitialized = true;
          _initCompleter.complete();
        }).catchError((error, stackTrace) {
          _logger.severe('数据库初始化失败', error, stackTrace);
          _initCompleter.completeError(error, stackTrace);
          _instance = null; // 重置实例，以便下次重试
          _isInitializing = false;
        });
      }
    }
    
    // 等待初始化完成
    if (!_isInitialized) {
      _logger.info('等待数据库初始化完成...');
      await _initCompleter.future;
      _logger.info('数据库初始化已完成，返回实例');
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
        id TEXT PRIMARY KEY,
        node_name TEXT NOT NULL,
        pubkey_fingerprint TEXT NOT NULL,
        public_key TEXT,
        is_trusted INTEGER NOT NULL,
        is_local_node INTEGER NOT NULL DEFAULT 0,
        last_sync TEXT,
        created_at TEXT NOT NULL
      )
    ''');
  }

  /// 数据库升级回调
  Future<void> _onUpgrade(dynamic db, int oldVersion, int newVersion) async {
    _logger.info('数据库升级: $oldVersion -> $newVersion');

    // 备份数据库
    await _backupDatabase();

    // 版本 1 到版本 2 的迁移
    if (oldVersion < 2 && newVersion >= 2) {
      // 添加节点表
      await db.execute('''
        CREATE TABLE IF NOT EXISTS nodes (
          id TEXT PRIMARY KEY,
          node_name TEXT NOT NULL,
          pubkey_fingerprint TEXT NOT NULL,
          is_trusted INTEGER NOT NULL,
          last_sync TEXT,
          created_at TEXT NOT NULL
        )
      ''');
    }

    // 版本 2 到版本 3 的迁移
    if (oldVersion < 3 && newVersion >= 3) {
      // 添加公钥字段
      _logger.info('添加 public_key 字段到 nodes 表');
      await db.execute('ALTER TABLE nodes ADD COLUMN public_key TEXT');
    }

    // 版本 3 到版本 4 的迁移
    if (oldVersion < 4 && newVersion >= 4) {
      // 添加 is_local_node 字段
      _logger.info('添加 is_local_node 字段到 nodes 表');
      await db.execute(
          'ALTER TABLE nodes ADD COLUMN is_local_node INTEGER NOT NULL DEFAULT 0');
    }
  }

  /// 备份数据库
  ///
  /// 在数据库升级前进行备份，使用时间戳命名备份文件，保留多个备份版本
  Future<String?> _backupDatabase() async {
    try {
      // 获取应用支持目录
      final appSupportDir = await getApplicationSupportDirectory();

      // 数据库文件路径
      final dbPath = path.join(appSupportDir.path, 'cardmind.db');

      // 检查数据库文件是否存在
      final dbFile = File(dbPath);
      if (!await dbFile.exists()) {
        _logger.info('数据库文件不存在，跳过备份');
        return null;
      }

      // 创建备份目录
      final backupDir = Directory(path.join(appSupportDir.path, 'backups'));
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      // 使用时间戳创建备份文件名
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final backupPath =
          path.join(backupDir.path, 'cardmind_backup_$timestamp.db');

      _logger.info('备份数据库: $dbPath -> $backupPath');

      // 复制数据库文件
      // 注意：我们不需要关闭数据库，直接复制文件即可
      // 在 SQLite 中，即使数据库文件正在使用，也可以安全地复制
      await dbFile.copy(backupPath);

      _logger.info('数据库备份成功: $backupPath');
      return backupPath;
    } catch (e, stack) {
      _logger.severe('数据库备份失败', e, stack);
      return null;
    }
  }

  /// 关闭数据库连接
  Future<void> close() async {
    await _db.close();
    _instance = null;
  }
}
