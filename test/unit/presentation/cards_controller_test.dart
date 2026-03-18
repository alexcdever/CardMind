// input: CardsController 接收各种边界输入（null id、空字符串等）。
// output: 验证边界条件处理正确（抛出异常或正常执行）。
// pos: 覆盖卡片控制器边界条件，防止空值导致未定义行为。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/features/cards/cards_controller.dart';
import 'package:cardmind/features/cards/card_api_client.dart';
import 'package:cardmind/features/cards/card_summary.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCardApiClient implements CardApiClient {
  final Map<String, _FakeCardRecord> _records = <String, _FakeCardRecord>{};
  int createCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;
  int restoreCalls = 0;
  int getDetailCalls = 0;
  String? lastUpdatedId;

  @override
  Future<List<CardSummary>> listCardSummaries({
    String query = '',
    String? poolId,
  }) async {
    final lowered = query.toLowerCase();
    return _records.values
        .where((row) {
          if (row.deleted) return false;
          if (lowered.isEmpty) return true;
          return row.title.toLowerCase().contains(lowered) ||
              row.body.toLowerCase().contains(lowered);
        })
        .map(
          (row) =>
              CardSummary(id: row.id, title: row.title, deleted: row.deleted),
        )
        .toList(growable: false);
  }

  @override
  Future<String> createCardNote({
    required String id,
    required String title,
    required String body,
  }) async {
    createCalls += 1;
    _records[id] = _FakeCardRecord(
      id: id,
      title: title,
      body: body,
      deleted: false,
      updatedAtMicros: DateTime.now().microsecondsSinceEpoch,
    );
    return id;
  }

  @override
  Future<void> updateCardNote({
    required String id,
    required String title,
    required String body,
  }) async {
    updateCalls += 1;
    lastUpdatedId = id;
    final existing = _records[id];
    if (existing == null) {
      throw StateError('missing existing card');
    }
    _records[id] = _FakeCardRecord(
      id: id,
      title: title,
      body: body,
      deleted: existing.deleted,
      updatedAtMicros: DateTime.now().microsecondsSinceEpoch,
    );
  }

  @override
  Future<void> deleteCardNote({required String id}) async {
    deleteCalls += 1;
    final row = _records[id];
    if (row != null) {
      _records[id] = _FakeCardRecord(
        id: row.id,
        title: row.title,
        body: row.body,
        deleted: true,
        updatedAtMicros: DateTime.now().microsecondsSinceEpoch,
      );
    }
  }

  @override
  Future<void> restoreCardNote({required String id}) async {
    restoreCalls += 1;
    final row = _records[id];
    if (row != null) {
      _records[id] = _FakeCardRecord(
        id: row.id,
        title: row.title,
        body: row.body,
        deleted: false,
        updatedAtMicros: DateTime.now().microsecondsSinceEpoch,
      );
    }
  }

  @override
  Future<CardDetailData> getCardDetail({required String id}) async {
    getDetailCalls += 1;
    final existing = _records[id];
    if (existing == null) {
      throw StateError('missing existing card');
    }
    return CardDetailData(
      id: existing.id,
      title: existing.title,
      body: existing.body,
      deleted: existing.deleted,
    );
  }
}

class _FakeCardRecord {
  const _FakeCardRecord({
    required this.id,
    required this.title,
    required this.body,
    required this.deleted,
    required this.updatedAtMicros,
  });

  final String id;
  final String title;
  final String body;
  final bool deleted;
  final int updatedAtMicros;
}

void main() {
  group('CardsController', () {
    late _FakeCardApiClient fakeApiClient;
    late CardsController controller;

    setUp(() {
      fakeApiClient = _FakeCardApiClient();
      controller = CardsController(apiClient: fakeApiClient);
    });

    group('save', () {
      test('throws StateError when id is null', () async {
        expect(
          () => controller.save(null, 'title', 'body'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('save requires an existing card id'),
            ),
          ),
        );
      });

      test('throws StateError when card does not exist', () async {
        expect(
          () => controller.save('non-existent-id', 'title', 'body'),
          throwsA(isA<StateError>()),
        );
      });

      test('completes successfully when card exists', () async {
        await controller.createDraft(
          'test-id',
          'Initial Title',
          'Initial Body',
        );

        await controller.save('test-id', 'Updated Title', 'Updated Body');

        expect(fakeApiClient.updateCalls, 1);
        expect(fakeApiClient.lastUpdatedId, 'test-id');
      });
    });

    group('delete', () {
      test('succeeds when card does not exist', () async {
        await controller.delete('non-existent-id');
        expect(fakeApiClient.deleteCalls, 1);
      });

      test('marks existing card as deleted', () async {
        await controller.createDraft('test-id', 'Title', 'Body');

        await controller.delete('test-id');

        final items = controller.items;
        expect(items.isEmpty, true);
      });
    });

    group('restore', () {
      test('succeeds when card does not exist', () async {
        await controller.restore('non-existent-id');
        expect(fakeApiClient.restoreCalls, 1);
      });

      test('restores previously deleted card', () async {
        await controller.createDraft('test-id', 'Title', 'Body');
        await controller.delete('test-id');

        await controller.restore('test-id');

        expect(fakeApiClient.restoreCalls, 1);
      });
    });

    group('getCardDetail', () {
      test('throws StateError when card does not exist', () async {
        expect(
          () => controller.getCardDetail('non-existent-id'),
          throwsA(isA<StateError>()),
        );
      });

      test('returns card detail when card exists', () async {
        await controller.createDraft('test-id', 'Title', 'Body');

        final detail = await controller.getCardDetail('test-id');

        expect(detail.id, 'test-id');
        expect(detail.title, 'Title');
        expect(detail.body, 'Body');
      });
    });

    group('load', () {
      test('returns empty list when no cards exist', () async {
        await controller.load();
        expect(controller.items, isEmpty);
      });

      test('returns cards after creation', () async {
        await controller.createDraft('id-1', 'Title 1', 'Body 1');
        await controller.createDraft('id-2', 'Title 2', 'Body 2');

        await controller.load();

        expect(controller.items.length, 2);
      });

      test('excludes deleted cards from results', () async {
        await controller.createDraft('id-1', 'Title 1', 'Body 1');
        await controller.createDraft('id-2', 'Title 2', 'Body 2');
        await controller.delete('id-1');

        await controller.load();

        expect(controller.items.length, 1);
        expect(controller.items.first.id, 'id-2');
      });
    });
  });
}
