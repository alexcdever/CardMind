// input: 写入两条不同 updatedAtMicros 的卡片投影并执行 search 查询。
// output: 返回结果按 updatedAtMicros 倒序，且默认过滤 deleted 条目。
// pos: 卡片 SQLite 读仓测试，保障查询排序与软删除过滤行为。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/features/cards/data/sqlite_cards_read_repository.dart';
import 'package:cardmind/features/cards/cards_controller.dart';
import 'package:cardmind/features/cards/data/loro_cards_write_repository.dart';
import 'package:cardmind/features/cards/domain/card_note_projection.dart';
import 'package:cardmind/features/shared/data/app_database.dart';
import 'dart:io';
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

  test(
    'search excludes deleted by default and includes when requested',
    () async {
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

      final all = await repo.search('', includeDeleted: true);
      expect(all.map((e) => e.id), contains('d1'));
    },
  );

  test(
    'card create persists to loro files and query returns from sqlite projection',
    () async {
      final root = Directory.systemTemp.createTempSync('cards-loro');
      final database = AppDatabase();
      final readRepo = SqliteCardsReadRepository(database: database);
      final writeRepo = LoroCardsWriteRepository(
        basePath: '${root.path}/data/loro',
      );
      final controller = CardsController(
        readRepository: readRepo,
        writeRepository: writeRepo,
      );

      const noteId = '019-card-test';
      await controller.create(noteId, 'Title', 'Body');

      final snapshot = File(
        '${root.path}/data/loro/card-note/$noteId/snapshot',
      );
      final update = File('${root.path}/data/loro/card-note/$noteId/update');
      expect(snapshot.existsSync(), isTrue);
      expect(update.existsSync(), isTrue);

      final rows = await readRepo.search('Title');
      expect(rows.map((e) => e.id), contains(noteId));
    },
  );

  test(
    'controller create works with inMemory write repository factory',
    () async {
      final database = AppDatabase();
      final controller = CardsController(
        readRepository: SqliteCardsReadRepository(database: database),
        writeRepository: LoroCardsWriteRepository.inMemory(),
      );

      await controller.create('in-memory-id', 'InMemoryTitle', 'Body');

      final rows = await database.searchCards(
        'InMemoryTitle',
        includeDeleted: true,
      );
      expect(rows.map((e) => e.id), contains('in-memory-id'));
    },
  );
}
