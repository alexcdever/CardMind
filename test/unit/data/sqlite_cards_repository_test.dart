// input: 写入两条不同 updatedAtMicros 的卡片投影并执行 search 查询。
// output: 返回结果按 updatedAtMicros 倒序，且默认过滤 deleted 条目。
// pos: 卡片 SQLite 读仓测试，保障查询排序与软删除过滤行为。修改本文件需同步更新文件头。
import 'package:cardmind/features/cards/data/sqlite_cards_read_repository.dart';
import 'package:cardmind/features/cards/domain/card_note_projection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('search returns notes ordered by updatedAt desc', () async {
    final repo = SqliteCardsReadRepository.inMemory();

    await repo.upsertProjection(
      const CardNoteProjection(
        id: 'older',
        title: 'A',
        body: 'B',
        deleted: false,
        updatedAtMicros: 10,
      ),
    );
    await repo.upsertProjection(
      const CardNoteProjection(
        id: 'newer',
        title: 'C',
        body: 'D',
        deleted: false,
        updatedAtMicros: 20,
      ),
    );

    final rows = await repo.search('');
    expect(rows.first.id, 'newer');
  });

  test('search excludes deleted by default', () async {
    final repo = SqliteCardsReadRepository.inMemory();

    await repo.upsertProjection(
      const CardNoteProjection(
        id: 'd1',
        title: 'Deleted',
        body: 'x',
        deleted: true,
        updatedAtMicros: 10,
      ),
    );

    final visible = await repo.search('');
    expect(visible, isEmpty);
  });

  test(
    'search matches title and body case-insensitively for active notes',
    () async {
      final repo = SqliteCardsReadRepository.inMemory();

      await repo.upsertProjection(
        const CardNoteProjection(
          id: 'active-title',
          title: 'Alpha KEYWORD',
          body: 'other body',
          deleted: false,
          updatedAtMicros: 30,
        ),
      );
      await repo.upsertProjection(
        const CardNoteProjection(
          id: 'active-body',
          title: 'beta title',
          body: 'contains KeyWord in body',
          deleted: false,
          updatedAtMicros: 20,
        ),
      );
      await repo.upsertProjection(
        const CardNoteProjection(
          id: 'deleted-match',
          title: 'keyword deleted',
          body: 'keyword',
          deleted: true,
          updatedAtMicros: 10,
        ),
      );

      final rows = await repo.search('keyword');
      final ids = rows.map((e) => e.id).toSet();

      expect(ids, contains('active-title'));
      expect(ids, contains('active-body'));
      expect(ids, isNot(contains('deleted-match')));
    },
  );
}
