// input: 写入池读模型实体并按 name 查询或按更新时间列出。
// output: 返回结果按 updatedAtMicros 倒序，且默认过滤 dissolved 池。
// pos: 池 SQLite 读仓测试，保障池列表排序与生命周期过滤行为。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/features/pool/data/sqlite_pool_read_repository.dart';
import 'package:cardmind/features/pool/application/pool_command_service.dart';
import 'package:cardmind/features/pool/data/loro_pool_write_repository.dart';
import 'package:cardmind/features/pool/domain/pool_entity.dart';
import 'package:cardmind/features/shared/data/app_database.dart';
import 'dart:io';
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

  test(
    'pool create persists to loro files and query returns from sqlite projection',
    () async {
      final root = Directory.systemTemp.createTempSync('pool-loro');
      final database = AppDatabase();
      final readRepo = SqlitePoolReadRepository(database: database);
      final writeRepo = LoroPoolWriteRepository(
        basePath: '${root.path}/data/loro',
      );
      final service = PoolCommandService(writeRepo);

      const poolId = '019-pool-test';
      await service.createPool(
        poolId: poolId,
        name: 'Pool Title',
        ownerId: 'owner-1',
        ownerName: 'owner@test',
      );

      final pool = await writeRepo.getPoolById(poolId);
      expect(pool, isNotNull);
      await readRepo.upsertPool(pool!);

      final snapshot = File(
        '${root.path}/data/loro/pool-meta/$poolId/snapshot',
      );
      final update = File('${root.path}/data/loro/pool-meta/$poolId/update');
      expect(snapshot.existsSync(), isTrue);
      expect(update.existsSync(), isTrue);

      final rows = await readRepo.listPools(query: 'Pool');
      expect(rows.map((e) => e.poolId), contains(poolId));
    },
  );
}
