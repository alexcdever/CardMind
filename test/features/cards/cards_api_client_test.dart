// input: 卡片控制器接收 fake ApiClient 与 fake 读仓后执行 create/delete/restore 动作。
// output: 断言控制器只通过 ApiClient 调后端，并在动作后刷新查询结果。
// pos: 覆盖卡片控制器改接 ApiClient 主路径，防止回退到直接写仓。修改本文件需同步更新文件头与所属 DIR.md。
import 'dart:io';

import 'package:cardmind/bridge_generated/api.dart' as frb;
import 'package:cardmind/bridge_generated/frb_generated.dart';
import 'package:cardmind/features/cards/card_api_client.dart';
import 'package:cardmind/features/cards/card_summary.dart';
import 'package:cardmind/features/cards/cards_controller.dart';
import 'package:cardmind/features/cards/domain/card_note_projection.dart';
import 'package:cardmind/features/cards/data/cards_read_repository.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCardsReadRepository implements CardsReadRepository {
  int searchCalls = 0;
  List<CardNoteProjection> rows = const <CardNoteProjection>[];

  @override
  Future<List<CardNoteProjection>> search(String query) async {
    searchCalls += 1;
    return rows;
  }

  @override
  Future<void> upsertProjection(CardNoteProjection row) {
    throw UnimplementedError('controller should reload query instead');
  }
}

class _FakeCardApiClient implements CardApiClient {
  _FakeCardApiClient(this.readRepository);

  final _FakeCardsReadRepository readRepository;
  int createCalls = 0;
  int updateCalls = 0;
  int deleteCalls = 0;
  int restoreCalls = 0;
  String? lastCreatedId;
  String? lastUpdatedId;

  @override
  Future<String> createCardNote({
    required String id,
    required String title,
    required String body,
  }) async {
    createCalls += 1;
    lastCreatedId = id;
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
  }

  @override
  Future<void> deleteCardNote({required String id}) async {
    deleteCalls += 1;
  }

  @override
  Future<void> restoreCardNote({required String id}) async {
    restoreCalls += 1;
  }

  @override
  Future<CardDetailData> getCardDetail({required String id}) async {
    final row = readRepository.rows.firstWhere((item) => item.id == id);
    return CardDetailData(
      id: row.id,
      title: row.title,
      body: row.body,
      deleted: row.deleted,
    );
  }

  @override
  Future<List<CardSummary>> listCardSummaries({
    String query = '',
    String? poolId,
  }) async {
    final rows = await readRepository.search(query);
    return rows
        .map(
          (row) =>
              CardSummary(id: row.id, title: row.title, deleted: row.deleted),
        )
        .toList(growable: false);
  }
}

bool _rustLibInitialized = false;

Future<void> _ensureRustLibInitialized() async {
  if (_rustLibInitialized) {
    return;
  }

  final dylib = File(
    'rust/target/release/libcardmind_rust.dylib',
  ).absolute.path;
  await RustLib.init(externalLibrary: ExternalLibrary.open(dylib));
  _rustLibInitialized = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('frb card api client should not require storeId constructor state', () {
    final client = FrbCardApiClient();

    expect(client, isA<CardApiClient>());
  });

  test(
    'frb card api client supports delete and restore without handle state',
    () async {
      final root = await Directory.systemTemp.createTemp('cardmind-card-api-');
      await _ensureRustLibInitialized();
      await frb.resetAppConfigForTests();
      await frb.initAppConfig(appDataDir: root.path);

      try {
        final created = await frb.createCardNote(
          title: 'title',
          content: 'body',
        );
        final client = FrbCardApiClient();

        await client.deleteCardNote(id: created.id);
        final deleted = await frb.getCardNoteDetail(cardId: created.id);

        await client.restoreCardNote(id: created.id);
        final restored = await frb.getCardNoteDetail(cardId: created.id);

        expect(deleted.deleted, isTrue);
        expect(restored.deleted, isFalse);
      } finally {
        await frb.resetAppConfigForTests();
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'flutter should consume backend-filtered card summaries instead of local filtering',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'cardmind-card-query-',
      );
      await _ensureRustLibInitialized();
      await frb.resetAppConfigForTests();
      await frb.initAppConfig(appDataDir: root.path);

      try {
        final alpha = await frb.createCardNote(
          title: 'Alpha KEYWORD',
          content: 'body',
        );
        await frb.createCardNote(
          title: 'Body host',
          content: 'contains keyword',
        );
        final deleted = await frb.createCardNote(
          title: 'keyword deleted',
          content: 'body',
        );
        await frb.deleteCardNote(cardId: deleted.id);

        final client = FrbCardApiClient();
        final active = await client.listCardSummaries(query: 'keyword');
        expect(active.map((item) => item.id), contains(alpha.id));
        expect(active.map((item) => item.id), isNot(contains(deleted.id)));
        expect(active.map((item) => item.id), isNot(contains(deleted.id)));
      } finally {
        await frb.resetAppConfigForTests();
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'cards controller should create through api client then reload query',
    () async {
      final readRepository = _FakeCardsReadRepository()
        ..rows = const <CardNoteProjection>[
          CardNoteProjection(
            id: 'server-id',
            title: 'From sqlite',
            body: 'body',
            deleted: false,
            updatedAtMicros: 1,
          ),
        ];
      final apiClient = _FakeCardApiClient(readRepository);
      final controller = CardsController(apiClient: apiClient);

      await controller.createDraft('local-id', 'Title', 'Body');

      expect(apiClient.createCalls, 1);
      expect(apiClient.lastCreatedId, 'local-id');
      expect(readRepository.searchCalls, 1);
      expect(controller.items.single.id, 'server-id');
    },
  );

  test(
    'saving an existing selected card should call update not create',
    () async {
      final readRepository = _FakeCardsReadRepository()
        ..rows = const <CardNoteProjection>[
          CardNoteProjection(
            id: 'existing-id',
            title: 'Updated from sqlite',
            body: 'body',
            deleted: false,
            updatedAtMicros: 1,
          ),
        ];
      final apiClient = _FakeCardApiClient(readRepository);
      final controller = CardsController(apiClient: apiClient);

      await controller.save('existing-id', 'Updated title', 'Updated body');

      expect(apiClient.updateCalls, 1);
      expect(apiClient.lastUpdatedId, 'existing-id');
      expect(apiClient.createCalls, 0);
      expect(readRepository.searchCalls, 1);
      expect(controller.items.single.id, 'existing-id');
    },
  );
}
