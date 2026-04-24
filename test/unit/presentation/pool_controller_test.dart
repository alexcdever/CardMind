// input: fake PoolApiClient 与可选 SyncService 在不同池状态下执行命令。
// output: 断言 PoolController 的创建、加入、审批、拒绝与同步恢复分支正确。
// pos: PoolController 单元测试。修改本文件需同步更新所属 DIR.md。
import 'package:cardmind/bridge_generated/api.dart' as frb;
import 'package:cardmind/bridge_generated/models/api_error.dart';
import 'package:cardmind/features/pool/pool_api_client.dart';
import 'package:cardmind/features/pool/pool_controller.dart';
import 'package:cardmind/features/pool/pool_state.dart';
import 'package:cardmind/features/sync/sync_service.dart';
import 'package:cardmind/features/sync/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePoolApiClient implements PoolApiClient, PoolRuntimeApiClient {
  PoolJoinResult joinResult = const PoolJoinResult.joined(poolName: 'Joined');
  PoolViewData? joinedView = const PoolViewData(
    poolId: 'pool-joined',
    poolName: 'Joined',
    isDissolved: false,
    isOwner: false,
    currentIdentityLabel: 'joiner@test',
    memberLabels: <String>['owner@test', 'joiner@test'],
  );
  Object? leaveError;
  Object? leavePartialCleanupError;
  Object? joinedViewError;
  String? leftPoolId;
  bool dissolveCalled = false;
  List<JoinRequestData> joinRequestResults = const <JoinRequestData>[];
  final Set<String> rejectFailOnceRequestIds = <String>{};
  PoolRuntimeViewData runtimeView = const PoolRuntimeViewData(
    summary: PoolRuntimeSummaryData(
      memberCount: 2,
      connectedCount: 1,
      syncingCount: 1,
      offlineCount: 0,
      memberCountText: '2 nodes',
      runtimeStatusText: '1 online / 1 syncing',
    ),
    members: <PoolMemberRuntimeData>[
      PoolMemberRuntimeData(
        endpointId: 'owner@test',
        nickname: 'Owner Device',
        os: 'macOS',
        role: 'admin',
        status: 'connected',
        isCurrentDevice: true,
      ),
      PoolMemberRuntimeData(
        endpointId: 'phone@test',
        nickname: 'Phone',
        os: 'iOS',
        role: 'member',
        status: 'syncing',
        isCurrentDevice: false,
      ),
    ],
    invites: <PoolInviteData>[
      PoolInviteData(
        inviteId: 'invite-1',
        inviteCode: 'invite://created',
        createdByEndpointId: 'owner@test',
      ),
    ],
  );
  int runtimeViewCalls = 0;
  int createInviteCalls = 0;
  String? revokedInviteId;

  @override
  Future<PoolCreateResult> createPool() async => const PoolCreateResult(
    poolId: 'pool-created',
    poolName: 'Created',
    isDissolved: false,
    isOwner: true,
    currentIdentityLabel: 'owner@test',
    memberLabels: <String>['owner@test'],
    inviteCode: 'invite://created',
  );

  @override
  Future<PoolDetailData> getPoolDetail(String poolId) async =>
      const PoolDetailData(
        poolId: 'pool-detail',
        poolName: 'Detail',
        isDissolved: false,
        isOwner: true,
        currentIdentityLabel: 'owner@test',
        memberLabels: <String>['owner@test'],
      );

  @override
  Future<PoolViewData?> getJoinedPoolView() async {
    if (joinedViewError != null) {
      throw joinedViewError!;
    }
    return joinedView;
  }

  @override
  Future<PoolJoinResult> joinByCode(String code) async => joinResult;

  @override
  Future<void> leavePool(String poolId) async {
    leftPoolId = poolId;
    if (leavePartialCleanupError != null) {
      throw leavePartialCleanupError!;
    }
    if (leaveError != null) {
      throw leaveError!;
    }
  }

  @override
  Future<PoolDetailData> dissolvePool(String poolId) async {
    dissolveCalled = true;
    return const PoolDetailData(
      poolId: 'pool-joined',
      poolName: 'Joined',
      isDissolved: true,
      isOwner: true,
      currentIdentityLabel: 'owner@test',
      memberLabels: <String>['owner@test'],
      joinRequests: <JoinRequestData>[],
    );
  }

  @override
  Future<List<JoinRequestData>> submitJoinRequest(String poolId) async =>
      joinRequestResults;

  @override
  Future<List<JoinRequestData>> approveJoinRequest(
    String poolId,
    String requestId,
  ) async => joinRequestResults;

  @override
  Future<List<JoinRequestData>> rejectJoinRequest(
    String poolId,
    String requestId,
  ) async {
    if (rejectFailOnceRequestIds.remove(requestId)) {
      throw ApiError(code: 'UNAVAILABLE', message: 'temporary reject failure');
    }
    return joinRequestResults;
  }

  @override
  Future<List<JoinRequestData>> cancelJoinRequest(
    String poolId,
    String requestId,
  ) async => joinRequestResults;

  @override
  Future<PoolRuntimeViewData> getPoolRuntimeView(String poolId) async {
    runtimeViewCalls += 1;
    return runtimeView;
  }

  @override
  Future<PoolRuntimeViewData> createInvite(String poolId) async {
    createInviteCalls += 1;
    return runtimeView;
  }

  @override
  Future<PoolRuntimeViewData> revokeInvite(
    String poolId,
    String inviteId,
  ) async {
    revokedInviteId = inviteId;
    runtimeView = const PoolRuntimeViewData(
      summary: PoolRuntimeSummaryData(
        memberCount: 2,
        connectedCount: 1,
        syncingCount: 1,
        offlineCount: 0,
        memberCountText: '2 nodes',
        runtimeStatusText: '1 online / 1 syncing',
      ),
      members: <PoolMemberRuntimeData>[
        PoolMemberRuntimeData(
          endpointId: 'owner@test',
          nickname: 'Owner Device',
          os: 'macOS',
          role: 'admin',
          status: 'connected',
          isCurrentDevice: true,
        ),
        PoolMemberRuntimeData(
          endpointId: 'phone@test',
          nickname: 'Phone',
          os: 'iOS',
          role: 'member',
          status: 'syncing',
          isCurrentDevice: false,
        ),
      ],
      invites: <PoolInviteData>[],
    );
    return runtimeView;
  }
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
        queryConvergenceState: 'ready',
        instanceContinuityState: 'ready',
        localContentSafety: 'safe',
        recoveryStage: 'stable',
        allowedOperations: ['view', 'continue_edit'],
        forbiddenOperations: [],
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
        queryConvergenceState: 'ready',
        instanceContinuityState: 'ready',
        localContentSafety: 'safe',
        recoveryStage: 'stable',
        allowedOperations: ['view', 'continue_edit'],
        forbiddenOperations: [],
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
        queryConvergenceState: 'ready',
        instanceContinuityState: 'ready',
        localContentSafety: 'safe',
        recoveryStage: 'stable',
        allowedOperations: ['view', 'continue_edit'],
        forbiddenOperations: [],
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
    expect((controller.state as PoolJoined).inviteCode, 'invite://created');
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
    expect(joined.poolId, 'default-pool');
    expect(joined.currentIdentityLabel, 'peer-x');
    expect(joined.memberLabels, <String>['peer-x']);
  });

  test('joinByCode_pending_transitionsToJoinPendingState', () async {
    final client = _FakePoolApiClient()
      ..joinResult = const PoolJoinResult.pending(
        poolId: 'pool-pending',
        poolName: 'Pending Pool',
        requestId: 'req-1',
        applicantIdentityLabel: 'joiner@test',
      );
    final controller = PoolController(apiClient: client);

    await controller.joinByCode('invite');

    final pending = controller.state as PoolJoinPending;
    expect(pending.poolId, 'pool-pending');
    expect(pending.poolName, 'Pending Pool');
    expect(pending.requestId, 'req-1');
    expect(controller.noticeMessage, '加入申请已提交，等待管理员审批');
    expect(controller.joining, isFalse);
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

  test('joinByCode_failure_preservesBackendMessageInNotice', () async {
    final client = _FakePoolApiClient()
      ..joinResult = const PoolJoinResult.error(
        'INTERNAL',
        errorMessage: 'iroh join failed: endpoint closed',
      );
    final controller = PoolController(apiClient: client);

    await controller.joinByCode('bad');

    expect(controller.state, isA<PoolError>());
    expect((controller.state as PoolError).code, 'INTERNAL');
    expect(controller.noticeMessage, 'iroh join failed: endpoint closed');
  });

  test('joinByCode_joinedViewApiError_transitionsToErrorState', () async {
    final client = _FakePoolApiClient()
      ..joinResult = const PoolJoinResult.joined(poolName: 'Joined')
      ..joinedViewError = ApiError(
        code: 'PROJECTION_NOT_CONVERGED',
        message: 'retry_get_joined_pool_view',
      );
    final controller = PoolController(apiClient: client);

    await controller.joinByCode('ok');

    expect(controller.state, isA<PoolError>());
    expect((controller.state as PoolError).code, 'PROJECTION_NOT_CONVERGED');
    expect(controller.noticeMessage, 'retry_get_joined_pool_view');
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

  test('confirmExit_keepsJoinedStateWhenLastAdminCannotLeave', () async {
    final client = _FakePoolApiClient()
      ..leaveError = ApiError(
        code: 'INVALID_ARGUMENT',
        message: 'last admin cannot leave pool',
      );
    final controller = PoolController(
      apiClient: client,
      initialState: const PoolState.joined(
        poolId: 'pool-joined',
        poolName: 'Joined',
        isOwner: true,
        currentIdentityLabel: 'owner@test',
        memberLabels: <String>['owner@test', 'member@test'],
      ),
    );

    await controller.confirmExit();

    final joined = controller.state as PoolJoined;
    expect(joined.poolId, 'pool-joined');
    expect(controller.noticeMessage, contains('唯一的管理员'));
    expect(client.leftPoolId, 'pool-joined');
  });

  test('dissolvePool_marksJoinedStateAsReadOnly', () async {
    final client = _FakePoolApiClient();
    final controller = PoolController(
      apiClient: client,
      initialState: const PoolState.joined(
        poolId: 'pool-joined',
        poolName: 'Joined',
        isOwner: true,
        isDissolved: false,
        currentIdentityLabel: 'owner@test',
        memberLabels: <String>['owner@test'],
      ),
    );

    await controller.dissolvePool();

    final joined = controller.state as PoolJoined;
    expect(client.dissolveCalled, isTrue);
    expect(joined.isDissolved, isTrue);
    expect(controller.noticeMessage, contains('只读状态'));
  });

  test('submitJoinRequest_updatesPendingRequestsFromApi', () async {
    final client = _FakePoolApiClient()
      ..joinRequestResults = const <JoinRequestData>[
        JoinRequestData(
          requestId: 'req-1',
          displayName: 'member@test',
          status: 'pending',
        ),
      ];
    final controller = PoolController(
      apiClient: client,
      initialState: const PoolState.joined(poolId: 'pool-joined'),
    );

    await controller.submitJoinRequest();

    final pending = controller.state as PoolJoinPending;
    expect(pending.poolId, 'pending-request-pool');
    expect(pending.requestId, 'req-1');
    expect(pending.applicantIdentityLabel, 'member@test');
    expect(controller.noticeMessage, contains('等待管理员审批'));
  });

  test('approve_usesApiResultToRefreshPendingList', () async {
    final client = _FakePoolApiClient()
      ..joinRequestResults = const <JoinRequestData>[];
    final controller = PoolController(
      apiClient: client,
      initialState: const PoolState.joined(
        poolId: 'pool-joined',
        pending: <PoolPendingRequest>[
          PoolPendingRequest(id: 'req-1', displayName: 'member@test'),
        ],
      ),
    );

    await controller.approve('req-1');

    final joined = controller.state as PoolJoined;
    expect(joined.pending, isEmpty);
    expect(controller.noticeMessage, '审批已通过');
  });

  test('cancelJoinRequest_usesApiResultToRefreshPendingList', () async {
    final client = _FakePoolApiClient()
      ..joinRequestResults = const <JoinRequestData>[];
    final controller = PoolController(
      apiClient: client,
      initialState: const PoolState.joinPending(
        poolId: 'pool-joined',
        poolName: 'Joined',
        requestId: 'req-1',
        applicantIdentityLabel: 'member@test',
      ),
    );

    await controller.cancelJoinRequest('req-1');

    expect(controller.state, isA<PoolNotJoined>());
    expect(controller.noticeMessage, '加入申请已取消');
  });

  test('reject_marksFirstFailureAndRemovesAfterRetry', () async {
    final client = _FakePoolApiClient()
      ..joinRequestResults = const <JoinRequestData>[]
      ..rejectFailOnceRequestIds.add('req');
    final controller = PoolController(
      apiClient: client,
      initialState: const PoolState.joined(
        pending: <PoolPendingRequest>[
          PoolPendingRequest(id: 'req', displayName: 'req@test'),
        ],
      ),
    );

    await controller.reject('req');
    var joined = controller.state as PoolJoined;
    expect(joined.pending.single.error, contains('拒绝失败'));
    expect(controller.noticeMessage, contains('拒绝失败'));

    await controller.reject('req');
    joined = controller.state as PoolJoined;
    expect(joined.pending, isEmpty);
    expect(controller.noticeMessage, '拒绝已完成');
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

  test(
    'refreshRuntimeView_loadsMembersSummaryAndInvitesFromRuntimeApi',
    () async {
      final client = _FakePoolApiClient();
      final controller = PoolController(
        apiClient: client,
        initialState: const PoolState.joined(poolId: 'pool-joined'),
      );

      await controller.refreshRuntimeView();

      expect(client.runtimeViewCalls, 1);
      expect(controller.runtimeView, isNotNull);
      expect(controller.runtimeView!.summary.memberCountText, '2 nodes');
      expect(controller.runtimeView!.members.map((item) => item.nickname), [
        'Owner Device',
        'Phone',
      ]);
      expect(
        controller.runtimeView!.invites.single.inviteCode,
        'invite://created',
      );
    },
  );

  test('revokeInvite_refreshesRuntimeInviteList', () async {
    final client = _FakePoolApiClient();
    final controller = PoolController(
      apiClient: client,
      initialState: const PoolState.joined(poolId: 'pool-joined'),
    );
    await controller.refreshRuntimeView();

    await controller.revokeInvite('invite-1');

    expect(client.revokedInviteId, 'invite-1');
    expect(controller.runtimeView!.invites, isEmpty);
  });
}
