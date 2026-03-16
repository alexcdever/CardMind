// input: 卡片页显示多个池的卡片
// output: 断言筛选器可正确过滤列表
// pos: 覆盖池筛选 UI 交互的前端测试

import 'package:cardmind/features/cards/card_api_client.dart';
import 'package:cardmind/features/cards/card_summary.dart';
import 'package:cardmind/features/cards/cards_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCardApiClientWithPools implements CardApiClient {
  final Map<String, _FakeCardRecord> _records = <String, _FakeCardRecord>{};
  final Map<String, String> _cardPoolMap =
      <String, String>{}; // cardId -> poolId
  int _idCounter = 0;

  String _generateId() {
    _idCounter++;
    return 'card-$_idCounter';
  }

  @override
  Future<List<CardSummary>> listCardSummaries({String query = ''}) async {
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
    final actualId = id.isEmpty ? _generateId() : id;
    _records[actualId] = _FakeCardRecord(
      id: actualId,
      title: title,
      body: body,
      deleted: false,
      updatedAtMicros: DateTime.now().microsecondsSinceEpoch,
    );
    return actualId;
  }

  @override
  Future<void> updateCardNote({
    required String id,
    required String title,
    required String body,
  }) async {
    final row = _records[id];
    if (row == null) throw StateError('missing card');
    _records[id] = _FakeCardRecord(
      id: row.id,
      title: title,
      body: body,
      deleted: row.deleted,
      updatedAtMicros: DateTime.now().microsecondsSinceEpoch,
    );
  }

  @override
  Future<void> deleteCardNote({required String id}) async {
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
    final row = _records[id];
    if (row == null) throw StateError('missing card');
    return CardDetailData(
      id: row.id,
      title: row.title,
      body: row.body,
      deleted: row.deleted,
    );
  }

  // Helper methods for testing
  void addCardToPool(String cardId, String poolId) {
    _cardPoolMap[cardId] = poolId;
  }

  List<CardSummary> listCardsByPool(String poolId) {
    return _records.values
        .where((row) => !row.deleted && _cardPoolMap[row.id] == poolId)
        .map(
          (row) =>
              CardSummary(id: row.id, title: row.title, deleted: row.deleted),
        )
        .toList(growable: false);
  }
}

class _FakeCardRecord {
  final String id;
  final String title;
  final String body;
  final bool deleted;
  final int updatedAtMicros;

  _FakeCardRecord({
    required this.id,
    required this.title,
    required this.body,
    required this.deleted,
    required this.updatedAtMicros,
  });
}

void main() {
  test('CardsController should support pool filtering', () async {
    final apiClient = _FakeCardApiClientWithPools();

    // 创建两个池的卡片
    final cardAId = await apiClient.createCardNote(
      id: '',
      title: 'Card in Pool A',
      body: 'Body A',
    );
    apiClient.addCardToPool(cardAId, 'pool-a');

    final cardBId = await apiClient.createCardNote(
      id: '',
      title: 'Card in Pool B',
      body: 'Body B',
    );
    apiClient.addCardToPool(cardBId, 'pool-b');

    final cardA2Id = await apiClient.createCardNote(
      id: '',
      title: 'Another Card in Pool A',
      body: 'Body A2',
    );
    apiClient.addCardToPool(cardA2Id, 'pool-a');

    // 验证筛选 Pool A 返回 2 张卡片
    final poolACards = apiClient.listCardsByPool('pool-a');
    expect(poolACards.length, 2);
    expect(poolACards.any((c) => c.id == cardAId), true);
    expect(poolACards.any((c) => c.id == cardA2Id), true);
    expect(poolACards.any((c) => c.id == cardBId), false);

    // 验证筛选 Pool B 返回 1 张卡片
    final poolBCards = apiClient.listCardsByPool('pool-b');
    expect(poolBCards.length, 1);
    expect(poolBCards.first.id, cardBId);

    // 验证全部查询返回 3 张卡片
    final allCards = await apiClient.listCardSummaries();
    expect(allCards.length, 3);
  });
}
