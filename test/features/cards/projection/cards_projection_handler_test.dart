// input: 将 CardNote 写模型传入 CardsProjectionHandler。
// output: 断言 handler 把写模型映射为 CardNoteProjection 并写入读仓。
// pos: 卡片投影处理器测试，保障卡片写侧事件可正确投影到 SQLite 读侧。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/features/cards/data/cards_read_repository.dart';
import 'package:cardmind/features/cards/domain/card_note.dart';
import 'package:cardmind/features/cards/domain/card_note_projection.dart';
import 'package:cardmind/features/cards/projection/cards_projection_handler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('handler maps card note into projection row', () async {
    final repo = _FakeCardsReadRepository();
    final handler = CardsProjectionHandler(repo);

    await handler.onCardUpsert(
      const CardNote(
        id: 'c1',
        title: 'T',
        body: 'B',
        deleted: true,
        updatedAtMicros: 9,
      ),
    );

    expect(repo.last?.id, 'c1');
    expect(repo.last?.deleted, isTrue);
    expect(repo.last?.updatedAtMicros, 9);
  });
}

class _FakeCardsReadRepository implements CardsReadRepository {
  CardNoteProjection? last;

  @override
  Future<List<CardNoteProjection>> search(
    String query, {
    bool includeDeleted = false,
  }) async {
    return const <CardNoteProjection>[];
  }

  @override
  Future<void> upsertProjection(CardNoteProjection row) async {
    last = row;
  }
}
