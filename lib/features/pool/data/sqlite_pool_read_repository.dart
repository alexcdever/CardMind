/// # SQLite 池读模型仓储实现
///
/// 基于 SQLite 读模型实现池列表检索与投影写入。
/// 负责暴露 Flutter 唯一池查询入口并接收投影写入。
///
/// ## 外部依赖
/// - 依赖 [PoolReadRepository] 接口定义。
/// - 依赖 [PoolEntity] 定义池实体数据结构。
/// - 依赖 [AppDatabase] 提供底层数据库访问。
library sqlite_pool_read_repository;

import 'package:cardmind/features/pool/data/pool_read_repository.dart';
import 'package:cardmind/features/pool/domain/pool_entity.dart';
import 'package:cardmind/features/shared/data/app_database.dart';

/// SQLite 实现的池读模型仓储。
///
/// 通过 [AppDatabase] 提供池查询与投影写入能力。
/// 这是 Flutter 层池查询的唯一入口，所有池读操作都应通过此类。
class SqlitePoolReadRepository implements PoolReadRepository {
  /// 创建仓储实例。
  ///
  /// [database] 为必需的数据库访问实例。
  SqlitePoolReadRepository({required AppDatabase database})
    : _database = database;

  /// 创建内存模式仓储实例。
  ///
  /// 使用默认的 [AppDatabase] 实例，适用于测试场景。
  factory SqlitePoolReadRepository.inMemory() {
    return SqlitePoolReadRepository(database: AppDatabase());
  }

  /// 底层数据库访问实例。
  final AppDatabase _database;

  /// Flutter 池查询统一走 SQLite 读模型。
  ///
  /// [query] 为可选的搜索关键词。
  /// [includeDissolved] 控制是否包含已解散的池。
  /// 转发到 [_database.listPools] 执行。
  @override
  Future<List<PoolEntity>> listPools({
    String query = '',
    bool includeDissolved = false,
  }) {
    return _database.listPools(
      query: query,
      includeDissolved: includeDissolved,
    );
  }

  /// 投影 worker 负责把写侧变化投递到读模型。
  ///
  /// [pool] 为要写入的池实体数据，转发到 [_database.upsertPool]。
  @override
  Future<void> upsertPool(PoolEntity pool) {
    return _database.upsertPool(pool);
  }
}
