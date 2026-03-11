// input: 通过投影 worker 写入卡片/池事件，再通过 SQLite 读仓执行查询。
// output: 断言 Flutter 查询只消费读模型结果，而不是依赖写侧仓的直读路径。
// pos: 覆盖读模型查询主路径，防止主流程绕过 SQLite 投影。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/features/cards/data/sqlite_cards_read_repository.dart';
import 'package:cardmind/features/cards/domain/card_note.dart';
import 'package:cardmind/features/pool/data/sqlite_pool_read_repository.dart';
import 'package:cardmind/features/pool/domain/pool_entity.dart';
import 'package:cardmind/features/shared/data/app_database.dart';
import 'package:cardmind/features/shared/projection/loro_projection_event.dart';
import 'package:cardmind/features/shared/projection/loro_projection_worker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'card and pool queries should be served from sqlite read model only',
    () async {
      final database = AppDatabase();
      final worker = LoroProjectionWorker.forDatabase(database);
      final cardReadRepository = SqliteCardsReadRepository(database: database);
      final poolReadRepository = SqlitePoolReadRepository(database: database);

      await worker.handle(
        LoroProjectionEvent.cardUpsert(
          const CardNote(
            id: 'card-1',
            title: 'Projected card',
            body: 'from projection',
            deleted: false,
            updatedAtMicros: 10,
          ),
        ),
      );
      await worker.handle(
        LoroProjectionEvent.poolUpsert(
          const PoolEntity(
            poolId: 'pool-1',
            name: 'Projected pool',
            dissolved: false,
            updatedAtMicros: 20,
          ),
        ),
      );

      final cards = await cardReadRepository.search('Projected');
      final pools = await poolReadRepository.listPools(query: 'Projected');

      expect(cards.map((row) => row.id), contains('card-1'));
      expect(pools.map((row) => row.poolId), contains('pool-1'));
    },
  );
}
