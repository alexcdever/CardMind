// input: 写入两条不同 updatedAtMicros 的卡片投影并执行 search 查询。
// output: 返回结果按 updatedAtMicros 倒序，且默认过滤 deleted 条目。
// pos: 卡片 SQLite 读仓测试，保障查询排序与软删除过滤行为。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/features/cards/card_api_client.dart';
import 'package:cardmind/features/cards/cards_controller.dart';
import 'package:cardmind/features/cards/data/loro_cards_write_repository.dart';
import 'package:cardmind/features/cards/data/sqlite_cards_read_repository.dart';
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
        apiClient: LegacyCardApiClient(
          readRepository: readRepo,
          writeRepository: writeRepo,
        ),
      );

      const noteId = '019-card-test';
      await controller.createDraft(noteId, 'Title', 'Body');

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
        apiClient: LegacyCardApiClient(
          readRepository: SqliteCardsReadRepository(database: database),
          writeRepository: LoroCardsWriteRepository.inMemory(),
        ),
      );

      await controller.createDraft('in-memory-id', 'InMemoryTitle', 'Body');

      final rows = await database.searchCards('InMemoryTitle');
      expect(rows.map((e) => e.id), contains('in-memory-id'));
    },
  );
}
