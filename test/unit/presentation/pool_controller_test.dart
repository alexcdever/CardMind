// input: fake PoolApiClient 与可选 SyncService 在不同池状态下执行命令。
// output: 断言 PoolController 的创建、加入、审批、拒绝与同步恢复分支正确。
// pos: PoolController 单元测试。修改本文件需同步更新所属 DIR.md。
import 'package:cardmind/bridge_generated/api.dart' as frb;
import 'package:cardmind/features/pool/pool_api_client.dart';
import 'package:cardmind/features/pool/pool_controller.dart';
import 'package:cardmind/features/pool/pool_state.dart';
import 'package:cardmind/features/sync/sync_service.dart';
import 'package:cardmind/features/sync/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePoolApiClient implements PoolApiClient {
  PoolJoinResult joinResult = const PoolJoinResult.joined(poolName: 'Joined');
  PoolViewData? joinedView = const PoolViewData(
    poolName: 'Joined',
    isOwner: false,
    currentIdentityLabel: 'joiner@test',
    memberLabels: <String>['owner@test', 'joiner@test'],
  );

  @override
  Future<PoolCreateResult> createPool() async => const PoolCreateResult(
    poolName: 'Created',
    isOwner: true,
    currentIdentityLabel: 'owner@test',
    memberLabels: <String>['owner@test'],
  );

  @override
  Future<PoolDetailData> getPoolDetail(String poolId) async =>
      const PoolDetailData(
        poolName: 'Detail',
        isOwner: true,
        currentIdentityLabel: 'owner@test',
        memberLabels: <String>['owner@test'],
      );

  @override
  Future<PoolViewData?> getJoinedPoolView() async => joinedView;

  @override
  Future<PoolJoinResult> joinByCode(String code) async => joinResult;
}

class _NoopGateway implements SyncGateway {
  @override
  Future<void> syncConnect({
    required BigInt networkId,
    required String target,
  }) async {}

  @override
  Future<void> syncDisconnect({required BigInt networkId}) async {}

  @override
  Future<void> syncJoinPool({
    required BigInt networkId,
    required String poolId,
  }) async {}

  @override
  Future<frb.SyncResultDto> syncPull({required BigInt networkId}) async =>
      const frb.SyncResultDto(
        state: 'ok',
        writeState: 'write_saved',
        projectionState: 'projection_ready',
        syncState: 'connected',
        continuityState: 'same_path',
        contentState: 'content_safe',
        nextAction: 'none',
        code: null,
      );

  @override
  Future<frb.SyncResultDto> syncPush({required BigInt networkId}) async =>
      const frb.SyncResultDto(
        state: 'ok',
        writeState: 'write_saved',
        projectionState: 'projection_ready',
        syncState: 'connected',
        continuityState: 'same_path',
        contentState: 'content_safe',
        nextAction: 'none',
        code: null,
      );

  @override
  Future<frb.SyncStatusDto> syncStatus({required BigInt networkId}) async =>
      const frb.SyncStatusDto(
        state: 'connected',
        writeState: 'write_saved',
        projectionState: 'projection_ready',
        syncState: 'connected',
        continuityState: 'same_path',
        contentState: 'content_safe',
        nextAction: 'none',
        code: null,
      );
}

class _FakeSyncService extends SyncService {
  _FakeSyncService() : super(gateway: _NoopGateway(), networkId: BigInt.one);

  SyncStatus retryStatus = const SyncStatus.connected();
  SyncStatus reconnectStatus = const SyncStatus.connected();
  int retryCalls = 0;
  int reconnectCalls = 0;
  String? reconnectTarget;

  @override
  Future<SyncStatus> retry() async {
    retryCalls += 1;
    return retryStatus;
  }

  @override
  Future<SyncStatus> reconnect(String target) async {
    reconnectCalls += 1;
    reconnectTarget = target;
    return reconnectStatus;
  }
}

void main() {
  test('createPool_transitionsToJoinedOwnerState', () async {
    final controller = PoolController(apiClient: _FakePoolApiClient());

    await controller.createPool();

    expect(controller.state, isA<PoolJoined>());
    expect((controller.state as PoolJoined).poolName, 'Created');
  });

  test('joinByCode_successWithoutJoinedView_usesFallbacks', () async {
    final client = _FakePoolApiClient()
      ..joinedView = null
      ..joinResult = const PoolJoinResult.joined(poolName: 'Fallback Pool');
    final controller = PoolController(
      apiClient: client,
      reconnectTarget: 'peer-x',
    );

    await controller.joinByCode('ok');

    final joined = controller.state as PoolJoined;
    expect(joined.poolName, 'Fallback Pool');
    expect(joined.currentIdentityLabel, 'peer-x');
    expect(joined.memberLabels, <String>['peer-x']);
  });

  test('joinByCode_failure_transitionsToErrorState', () async {
    final client = _FakePoolApiClient()
      ..joinResult = const PoolJoinResult.error('ADMIN_OFFLINE');
    final controller = PoolController(apiClient: client);

    await controller.joinByCode('bad');

    expect(controller.state, isA<PoolError>());
    expect((controller.state as PoolError).code, 'ADMIN_OFFLINE');
    expect(controller.joining, isFalse);
  });

  test('editPoolInfo_ignoresNonJoinedState', () {
    final controller = PoolController(apiClient: _FakePoolApiClient());

    controller.editPoolInfo('  New Name  ');

    expect(controller.state, const PoolState.notJoined());
  });

  test('approve_ignoresNonJoinedState', () {
    final controller = PoolController(apiClient: _FakePoolApiClient());

    controller.approve('request');

    expect(controller.state, const PoolState.notJoined());
  });

  test('reject_marksFirstFailureAndRemovesAfterRetry', () {
    final controller = PoolController(
      apiClient: _FakePoolApiClient(),
      initialState: const PoolState.joined(
        pending: <PoolPendingRequest>[
          PoolPendingRequest(
            id: 'req',
            displayName: 'req@test',
            rejectShouldFail: true,
          ),
        ],
      ),
    );

    controller.reject('req');
    var joined = controller.state as PoolJoined;
    expect(joined.pending.single.error, contains('拒绝失败'));
    expect(joined.approvalMessage, isNull);

    controller.reject('req');
    joined = controller.state as PoolJoined;
    expect(joined.pending, isEmpty);
    expect(joined.approvalMessage, '拒绝已完成');
  });

  test('retrySync_ignoresMissingSyncService', () async {
    final controller = PoolController(apiClient: _FakePoolApiClient());

    await controller.retrySync();

    expect(controller.syncStatus.kind, SyncStatusKind.connected);
  });

  test('retrySync_updatesSyncStatusFromService', () async {
    final syncService = _FakeSyncService()
      ..retryStatus = const SyncStatus.degraded('REQUEST_TIMEOUT');
    final controller = PoolController(
      apiClient: _FakePoolApiClient(),
      syncService: syncService,
    );

    await controller.retrySync();

    expect(syncService.retryCalls, 1);
    expect(controller.syncStatus.kind, SyncStatusKind.degraded);
    expect(controller.syncStatus.code, 'REQUEST_TIMEOUT');
  });

  test('reconnectSync_ignoresMissingSyncService', () async {
    final controller = PoolController(apiClient: _FakePoolApiClient());

    await controller.reconnectSync();

    expect(controller.syncStatus.kind, SyncStatusKind.connected);
  });

  test('reconnectSync_setsConnectingThenUsesServiceResult', () async {
    final syncService = _FakeSyncService()
      ..reconnectStatus = const SyncStatus.error('REQUEST_TIMEOUT');
    final controller = PoolController(
      apiClient: _FakePoolApiClient(),
      syncService: syncService,
      reconnectTarget: 'peer-y',
    );
    final seen = <SyncStatusKind>[];
    controller.addListener(() {
      seen.add(controller.syncStatus.kind);
    });

    await controller.reconnectSync();

    expect(syncService.reconnectCalls, 1);
    expect(syncService.reconnectTarget, 'peer-y');
    expect(controller.syncStatus.kind, SyncStatusKind.error);
    expect(seen, contains(SyncStatusKind.connecting));
  });
}
