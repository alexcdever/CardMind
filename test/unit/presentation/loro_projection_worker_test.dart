// input: 构造 LoroProjectionEvent 并交给 LoroProjectionWorker 处理。
// output: 断言 worker 将事件分发到 cards/pool 投影处理器并触发读仓 upsert。
// pos: 投影 worker 测试，保障 Loro 订阅事件到 SQLite 投影分发链路。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/features/cards/data/cards_read_repository.dart';
import 'package:cardmind/features/cards/domain/card_note.dart';
import 'package:cardmind/features/cards/domain/card_note_projection.dart';
import 'package:cardmind/features/cards/projection/cards_projection_handler.dart';
import 'package:cardmind/features/pool/data/pool_read_repository.dart';
import 'package:cardmind/features/pool/domain/pool_entity.dart';
import 'package:cardmind/features/pool/projection/pool_projection_handler.dart';
import 'package:cardmind/features/shared/projection/loro_projection_event.dart';
import 'package:cardmind/features/shared/projection/loro_projection_worker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('on card-updated event, projection worker upserts sqlite row', () async {
    final readRepo = _FakeCardsReadRepository();
    final worker = LoroProjectionWorker(
      cardsHandler: CardsProjectionHandler(readRepo),
    );

    await worker.handle(
      LoroProjectionEvent.cardUpsert(
        CardNote(
          id: 'card-1',
          title: 'A',
          body: 'B',
          deleted: false,
          updatedAtMicros: 1,
        ),
      ),
    );

    expect(readRepo.upsertedIds, contains('card-1'));
  });

  test('on pool-updated event, projection worker upserts sqlite row', () async {
    final readRepo = _FakePoolReadRepository();
    final worker = LoroProjectionWorker(
      poolHandler: PoolProjectionHandler(readRepo),
    );

    await worker.handle(
      LoroProjectionEvent.poolUpsert(
        const PoolEntity(
          poolId: 'pool-1',
          name: 'P',
          dissolved: false,
          updatedAtMicros: 1,
        ),
      ),
    );

    expect(readRepo.upsertedPoolIds, contains('pool-1'));
  });
}

class _FakeCardsReadRepository implements CardsReadRepository {
  final List<String> upsertedIds = <String>[];

  @override
  Future<List<CardNoteProjection>> search(
    String query, {
    bool includeDeleted = false,
  }) async {
    return const <CardNoteProjection>[];
  }

  @override
  Future<void> upsertProjection(CardNoteProjection row) async {
    upsertedIds.add(row.id);
  }
}

class _FakePoolReadRepository implements PoolReadRepository {
  final List<String> upsertedPoolIds = <String>[];

  @override
  Future<List<PoolEntity>> listPools({
    String query = '',
    bool includeDissolved = false,
  }) async {
    return const <PoolEntity>[];
  }

  @override
  Future<void> upsertPool(PoolEntity pool) async {
    upsertedPoolIds.add(pool.poolId);
  }
}
