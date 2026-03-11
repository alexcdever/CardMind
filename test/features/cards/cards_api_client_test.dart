// input: 卡片控制器接收 fake ApiClient 与 fake 读仓后执行 create/delete/restore 动作。
// output: 断言控制器只通过 ApiClient 调后端，并在动作后刷新查询结果。
// pos: 覆盖卡片控制器改接 ApiClient 主路径，防止回退到直接写仓。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/features/cards/card_api_client.dart';
import 'package:cardmind/features/cards/cards_controller.dart';
import 'package:cardmind/features/cards/domain/card_note_projection.dart';
import 'package:cardmind/features/cards/data/cards_read_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCardsReadRepository implements CardsReadRepository {
  int searchCalls = 0;
  List<CardNoteProjection> rows = const <CardNoteProjection>[];

  @override
  Future<List<CardNoteProjection>> search(
    String query, {
    bool includeDeleted = false,
  }) async {
    searchCalls += 1;
    return rows;
  }

  @override
  Future<void> upsertProjection(CardNoteProjection row) {
    throw UnimplementedError('controller should reload query instead');
  }
}

class _FakeCardApiClient implements CardApiClient {
  int createCalls = 0;
  int deleteCalls = 0;
  int restoreCalls = 0;
  String? lastCreatedId;

  @override
  Future<void> createCardNote({
    required String id,
    required String title,
    required String body,
  }) async {
    createCalls += 1;
    lastCreatedId = id;
  }

  @override
  Future<void> deleteCardNote({required String id}) async {
    deleteCalls += 1;
  }

  @override
  Future<void> restoreCardNote({required String id}) async {
    restoreCalls += 1;
  }
}

void main() {
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
      final apiClient = _FakeCardApiClient();
      final controller = CardsController(
        readRepository: readRepository,
        apiClient: apiClient,
      );

      await controller.create('local-id', 'Title', 'Body');

      expect(apiClient.createCalls, 1);
      expect(apiClient.lastCreatedId, 'local-id');
      expect(readRepository.searchCalls, 1);
      expect(controller.items.single.id, 'server-id');
    },
  );
}
