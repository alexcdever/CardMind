// input: LegacyCardApiClient 接收各种边界输入（不存在的 id、空值等）。
// output: 验证边界条件处理正确（抛出异常或正常执行）。
// pos: 覆盖卡片 API 客户端边界条件，防止空值导致未定义行为。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/features/cards/card_api_client.dart';
import 'package:cardmind/features/cards/card_summary.dart';
import 'package:cardmind/features/cards/data/cards_read_repository.dart';
import 'package:cardmind/features/cards/data/cards_write_repository.dart';
import 'package:cardmind/features/cards/domain/card_note.dart';
import 'package:cardmind/features/cards/domain/card_note_projection.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCardsReadRepository implements CardsReadRepository {
  final List<CardNoteProjection> _rows = <CardNoteProjection>[];

  @override
  Future<List<CardNoteProjection>> search(String query) async {
    return _rows
        .where(
          (row) =>
              !row.deleted &&
              (query.isEmpty ||
                  row.title.toLowerCase().contains(query.toLowerCase())),
        )
        .toList(growable: false);
  }

  @override
  Future<void> upsertProjection(CardNoteProjection row) async {
    _rows.removeWhere((r) => r.id == row.id);
    _rows.add(row);
  }
}

class _FakeCardsWriteRepository implements CardsWriteRepository {
  final Map<String, CardNote> _notes = <String, CardNote>{};

  @override
  Future<CardNote?> getById(String id) async => _notes[id];

  @override
  Future<void> upsert(CardNote note) async {
    _notes[note.id] = note;
  }

  @override
  Future<void> delete(String id) async {
    _notes.remove(id);
  }
}

void main() {
  group('LegacyCardApiClient', () {
    late _FakeCardsReadRepository readRepo;
    late _FakeCardsWriteRepository writeRepo;
    late LegacyCardApiClient client;

    setUp(() {
      readRepo = _FakeCardsReadRepository();
      writeRepo = _FakeCardsWriteRepository();
      client = LegacyCardApiClient(
        readRepository: readRepo,
        writeRepository: writeRepo,
      );
    });

    group('createCardNote', () {
      test('creates card with provided id', () async {
        final id = await client.createCardNote(
          id: 'test-id',
          title: 'Test Title',
          body: 'Test Body',
        );

        expect(id, 'test-id');
        final note = await writeRepo.getById('test-id');
        expect(note, isNotNull);
        expect(note!.title, 'Test Title');
      });
    });

    group('updateCardNote', () {
      test('throws StateError when card does not exist', () async {
        expect(
          () => client.updateCardNote(
            id: 'non-existent-id',
            title: 'New Title',
            body: 'New Body',
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('cannot update missing card'),
            ),
          ),
        );
      });

      test('updates existing card', () async {
        await client.createCardNote(
          id: 'test-id',
          title: 'Original Title',
          body: 'Original Body',
        );

        await client.updateCardNote(
          id: 'test-id',
          title: 'Updated Title',
          body: 'Updated Body',
        );

        final note = await writeRepo.getById('test-id');
        expect(note!.title, 'Updated Title');
        expect(note.body, 'Updated Body');
      });
    });

    group('deleteCardNote', () {
      test('gracefully handles non-existent card id', () async {
        // Should not throw when deleting non-existent card
        await client.deleteCardNote(id: 'non-existent-id');

        final note = await writeRepo.getById('non-existent-id');
        expect(note, isNull);
      });

      test('marks existing card as deleted', () async {
        await client.createCardNote(
          id: 'test-id',
          title: 'Test Title',
          body: 'Test Body',
        );

        await client.deleteCardNote(id: 'test-id');

        final note = await writeRepo.getById('test-id');
        expect(note!.deleted, isTrue);
      });
    });

    group('restoreCardNote', () {
      test('gracefully handles non-existent card id', () async {
        // Should not throw when restoring non-existent card
        await client.restoreCardNote(id: 'non-existent-id');

        final note = await writeRepo.getById('non-existent-id');
        expect(note, isNull);
      });

      test('restores previously deleted card', () async {
        await client.createCardNote(
          id: 'test-id',
          title: 'Test Title',
          body: 'Test Body',
        );
        await client.deleteCardNote(id: 'test-id');

        await client.restoreCardNote(id: 'test-id');

        final note = await writeRepo.getById('test-id');
        expect(note!.deleted, isFalse);
      });
    });

    group('getCardDetail', () {
      test('throws StateError when card does not exist', () async {
        expect(
          () => client.getCardDetail(id: 'non-existent-id'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('cannot load missing card'),
            ),
          ),
        );
      });

      test('returns card detail when card exists', () async {
        await client.createCardNote(
          id: 'test-id',
          title: 'Test Title',
          body: 'Test Body',
        );

        final detail = await client.getCardDetail(id: 'test-id');

        expect(detail.id, 'test-id');
        expect(detail.title, 'Test Title');
        expect(detail.body, 'Test Body');
        expect(detail.deleted, isFalse);
      });
    });

    group('listCardSummaries', () {
      test('returns empty list when no cards exist', () async {
        final summaries = await client.listCardSummaries();
        expect(summaries, isEmpty);
      });

      test('returns only non-deleted cards', () async {
        await client.createCardNote(
          id: 'id-1',
          title: 'Title 1',
          body: 'Body 1',
        );
        await client.createCardNote(
          id: 'id-2',
          title: 'Title 2',
          body: 'Body 2',
        );
        await client.deleteCardNote(id: 'id-1');

        final summaries = await client.listCardSummaries();

        expect(summaries.length, 1);
        expect(summaries.first.id, 'id-2');
      });

      test('filters by query string', () async {
        await client.createCardNote(
          id: 'id-1',
          title: 'Apple Pie',
          body: 'Recipe',
        );
        await client.createCardNote(
          id: 'id-2',
          title: 'Banana Bread',
          body: 'Recipe',
        );

        final summaries = await client.listCardSummaries(query: 'apple');

        expect(summaries.length, 1);
        expect(summaries.first.id, 'id-1');
      });
    });
  });
}
