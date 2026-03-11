// input: 接收 AppDatabase 与池查询/投影参数。
// output: 基于 SQLite 读模型实现池列表检索与投影写入。
// pos: 池 SQLite 读仓实现，负责暴露 Flutter 唯一池查询入口并接收投影写入。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
import 'package:cardmind/features/pool/data/pool_read_repository.dart';
import 'package:cardmind/features/pool/domain/pool_entity.dart';
import 'package:cardmind/features/shared/data/app_database.dart';

class SqlitePoolReadRepository implements PoolReadRepository {
  SqlitePoolReadRepository({required AppDatabase database})
    : _database = database;

  factory SqlitePoolReadRepository.inMemory() {
    return SqlitePoolReadRepository(database: AppDatabase());
  }

  final AppDatabase _database;

  /// Flutter 池查询统一走 SQLite 读模型。
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
  @override
  Future<void> upsertPool(PoolEntity pool) {
    return _database.upsertPool(pool);
  }
}
