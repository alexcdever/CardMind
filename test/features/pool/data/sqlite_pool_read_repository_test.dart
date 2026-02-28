// input: 写入池读模型实体并按 name 查询或按更新时间列出。
// output: 返回结果按 updatedAtMicros 倒序，且默认过滤 dissolved 池。
// pos: 池 SQLite 读仓测试，保障池列表排序与生命周期过滤行为。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/features/pool/data/sqlite_pool_read_repository.dart';
import 'package:cardmind/features/pool/domain/pool_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('list returns pools ordered by updatedAt desc', () async {
    final repo = SqlitePoolReadRepository.inMemory();

    await repo.upsertPool(
      const PoolEntity(
        poolId: 'older',
        name: 'Older',
        dissolved: false,
        updatedAtMicros: 10,
      ),
    );
    await repo.upsertPool(
      const PoolEntity(
        poolId: 'newer',
        name: 'Newer',
        dissolved: false,
        updatedAtMicros: 20,
      ),
    );

    final rows = await repo.listPools();
    expect(rows.first.poolId, 'newer');
  });

  test('list excludes dissolved pools by default', () async {
    final repo = SqlitePoolReadRepository.inMemory();

    await repo.upsertPool(
      const PoolEntity(
        poolId: 'gone',
        name: 'Gone',
        dissolved: true,
        updatedAtMicros: 1,
      ),
    );

    final visible = await repo.listPools();
    expect(visible, isEmpty);

    final all = await repo.listPools(includeDissolved: true);
    expect(all.map((e) => e.poolId), contains('gone'));
  });
}
