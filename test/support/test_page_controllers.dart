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
    String? poolId,
  }) async {
    final lowered = query.toLowerCase();
    final rows =
        _rows.values
            .where((row) {
              if (row.deleted) return false;
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
  Future<String> createCardNote({
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
    return id;
  }

  @override
  Future<void> updateCardNote({
    required String id,
    required String title,
    required String body,
  }) async {
    final row = _rows[id];
    if (row == null) {
      throw StateError('missing existing card $id');
    }
    _rows[id] = _TestCardRecord(
      id: row.id,
      title: title,
      body: body,
      deleted: row.deleted,
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

  @override
  Future<CardDetailData> getCardDetail({required String id}) async {
    final row = _rows[id];
    if (row == null) {
      throw StateError('missing existing card $id');
    }
    return CardDetailData(
      id: row.id,
      title: row.title,
      body: row.body,
      deleted: row.deleted,
    );
  }
}

CardsController buildTestCardsController() {
  return CardsController(apiClient: TestCardApiClient());
}

class TestPoolApiClient implements PoolApiClient {
  @override
  Future<PoolCreateResult> createPool() async {
    return const PoolCreateResult(
      poolId: 'pool-created',
      poolName: 'Server Pool',
      isDissolved: false,
      isOwner: true,
      currentIdentityLabel: 'owner@test',
      memberLabels: <String>['owner@test'],
    );
  }

  @override
  Future<PoolJoinResult> joinByCode(String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (code == 'joined-pool-code' || code == 'test-pool-code') {
      return const PoolJoinResult.joined(poolName: 'Joined Pool');
    }
    return const PoolJoinResult.error('ADMIN_OFFLINE');
  }

  @override
  Future<PoolViewData?> getJoinedPoolView() async {
    return const PoolViewData(
      poolId: 'pool-joined',
      poolName: 'Joined Pool',
      isDissolved: false,
      isOwner: true,
      currentIdentityLabel: 'owner@test',
      memberLabels: <String>['owner@test'],
      joinRequests: <JoinRequestData>[],
    );
  }

  @override
  Future<PoolDetailData> getPoolDetail(String poolId) async {
    return const PoolDetailData(
      poolId: 'pool-detail',
      poolName: 'Joined Pool',
      isDissolved: false,
      isOwner: true,
      currentIdentityLabel: 'owner@test',
      memberLabels: <String>['owner@test'],
      joinRequests: <JoinRequestData>[],
    );
  }

  @override
  Future<void> leavePool(String poolId) async {}

  @override
  Future<PoolDetailData> dissolvePool(String poolId) async {
    return const PoolDetailData(
      poolId: 'pool-detail',
      poolName: 'Joined Pool',
      isDissolved: true,
      isOwner: true,
      currentIdentityLabel: 'owner@test',
      memberLabels: <String>['owner@test'],
      joinRequests: <JoinRequestData>[],
    );
  }

  @override
  Future<List<JoinRequestData>> submitJoinRequest(String poolId) async =>
      const <JoinRequestData>[];

  @override
  Future<List<JoinRequestData>> approveJoinRequest(
    String poolId,
    String requestId,
  ) async => const <JoinRequestData>[];

  @override
  Future<List<JoinRequestData>> rejectJoinRequest(
    String poolId,
    String requestId,
  ) async => const <JoinRequestData>[];

  @override
  Future<List<JoinRequestData>> cancelJoinRequest(
    String poolId,
    String requestId,
  ) async => const <JoinRequestData>[];
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
