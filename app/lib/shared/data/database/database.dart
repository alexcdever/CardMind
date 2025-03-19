// ignore_for_file: depend_on_referenced_packages
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'tables.dart';
import 'card_dao.dart';
import 'database_backup.dart';

part 'database.g.dart';

/// 数据库文件名
const _kDatabaseName = 'CardMind.db';

/// 应用数据库类
/// 使用 drift 包进行数据库操作
@DriftDatabase(tables: [Cards], daos: [CardDao])
class AppDatabase extends _$AppDatabase {
  /// 数据库文件路径
  final String dbPath;

  /// 构造函数
  AppDatabase._create(this.dbPath) : super(_openConnection(dbPath));

  /// 工厂构造函数
  static Future<AppDatabase> create() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dbFolder.path, _kDatabaseName);
    return AppDatabase._create(dbPath);
  }

  /// 数据库版本号
  @override
  int get schemaVersion => 2;  // 升级到版本2，因为添加了syncId字段

  /// 数据库迁移策略
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        // 创建所有表
        await m.createAll();
        print('数据库首次创建完成');
      },
      onUpgrade: (m, from, to) async {
        // 版本升级时的迁移逻辑
        if (from == 1 && to == 2) {  // 明确指定从版本1升级到版本2
          // 先备份数据库
          print('开始备份数据库...');
          await DatabaseBackup.backup(dbPath);
          print('数据库备份完成');
          
          // 添加syncId字段
          await m.addColumn(cards, cards.syncId);
          print('已添加syncId字段');

          // 初始化所有已有记录的syncId
          await customStatement(
            'UPDATE cards SET sync_id = null WHERE sync_id IS NOT null'
          );
          print('已初始化现有记录的syncId字段');
        }
      },
      onDowngrade: (m, from, to) async {
        // 版本降级时的迁移逻辑
        if (from == 2 && to == 1) {
          // 从版本2降级到版本1
          // 先备份数据库
          print('开始备份数据库...');
          await DatabaseBackup.backup(dbPath);
          print('数据库备份完成');

          // 删除syncId字段
          await customStatement('ALTER TABLE cards DROP COLUMN sync_id');
          print('已删除syncId字段');
        }
      },
      beforeOpen: (details) async {
        // 只记录数据库状态，不进行数据操作
        if (details.wasCreated) {
          print('数据库首次创建');
        } else if (details.hadUpgrade) {
          print('数据库已升级到版本 ${details.versionNow}，从版本 ${details.versionBefore}');
        } else if (details.hadDowngrade) {
          print('数据库已降级到版本 ${details.versionNow}，从版本 ${details.versionBefore}');
        }
      },
    );
  }

  /// 关闭数据库连接
  @override
  Future<void> close() async {
    await super.close();
  }
}

/// 打开数据库连接
LazyDatabase _openConnection(String dbPath) {
  return LazyDatabase(() async {
    final file = File(dbPath);
    return NativeDatabase.createInBackground(file);
  });
}
