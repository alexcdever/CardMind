import 'package:cardmind/features/cards/card_api_client.dart';
import 'package:cardmind/features/cards/card_summary.dart';
import 'package:cardmind/features/cards/cards_controller.dart';
import 'package:cardmind/features/pool/pool_api_client.dart';
import 'package:cardmind/features/pool/pool_controller.dart';
import 'package:cardmind/features/pool/pool_state.dart';

class TestCardApiClient implements CardApiClient {
  final Map<String, _TestCardRecord> _rows = <String, _TestCardRecord>{};

  @override
  Future<List<CardSummary>> listCardSummaries({
    String query = '',
    bool includeDeleted = false,
  }) async {
    final lowered = query.toLowerCase();
    final rows =
        _rows.values
            .where((row) {
              if (!includeDeleted && row.deleted) return false;
              if (lowered.isEmpty) return true;
              return row.title.toLowerCase().contains(lowered) ||
                  row.body.toLowerCase().contains(lowered);
            })
            .toList(growable: false)
          ..sort((a, b) => b.updatedAtMicros.compareTo(a.updatedAtMicros));
    return rows
        .map(
          (row) =>
              CardSummary(id: row.id, title: row.title, deleted: row.deleted),
        )
        .toList(growable: false);
  }

  @override
  Future<void> createCardNote({
    required String id,
    required String title,
    required String body,
  }) async {
    _rows[id] = _TestCardRecord(
      id: id,
      title: title,
      body: body,
      deleted: false,
      updatedAtMicros: DateTime.now().microsecondsSinceEpoch,
    );
  }

  @override
  Future<void> deleteCardNote({required String id}) async {
    final row = _rows[id]!;
    _rows[id] = _TestCardRecord(
      id: row.id,
      title: row.title,
      body: row.body,
      deleted: true,
      updatedAtMicros: DateTime.now().microsecondsSinceEpoch,
    );
  }

  @override
  Future<void> restoreCardNote({required String id}) async {
    final row = _rows[id]!;
    _rows[id] = _TestCardRecord(
      id: row.id,
      title: row.title,
      body: row.body,
      deleted: false,
      updatedAtMicros: DateTime.now().microsecondsSinceEpoch,
    );
  }
}

CardsController buildTestCardsController() {
  return CardsController(apiClient: TestCardApiClient());
}

class TestPoolApiClient implements PoolApiClient {
  @override
  Future<PoolCreateResult> createPool() async {
    return const PoolCreateResult(poolName: 'Server Pool', isOwner: true);
  }

  @override
  Future<PoolJoinResult> joinByCode(String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (code == 'ok') {
      return const PoolJoinResult.joined(poolName: 'Joined Pool');
    }
    return const PoolJoinResult.error('ADMIN_OFFLINE');
  }

  @override
  Future<PoolViewData?> getJoinedPoolView() async {
    return const PoolViewData(poolName: 'Joined Pool', isOwner: true);
  }
}

PoolController buildTestPoolController({
  PoolState initialState = const PoolState.notJoined(),
}) {
  return PoolController(
    initialState: initialState,
    apiClient: TestPoolApiClient(),
  );
}

class _TestCardRecord {
  const _TestCardRecord({
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
