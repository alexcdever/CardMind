// input: 在不同池状态下执行创建、加入、审批、退出与重试操作。
// output: 页面状态、提示文案与待审批列表按流程更新。
// pos: 覆盖池管理全流程交互与异常分支，防止成员协作链路回归。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/features/pool/pool_page.dart';
import 'package:cardmind/features/pool/pool_api_client.dart';
import 'package:cardmind/features/pool/pool_controller.dart';
import 'package:cardmind/features/pool/pool_state.dart';
import 'package:cardmind/features/pool/join_error_mapper.dart';
import 'package:cardmind/bridge_generated/api.dart' as frb;
import 'package:cardmind/bridge_generated/models/api_error.dart';
import 'package:cardmind/features/sync/sync_service.dart';
import 'package:cardmind/features/sync/sync_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'dart:io';

class _FakePoolApiClient implements PoolApiClient {
  Object? leaveError;
  Object? leavePartialCleanupError;
  String? leftPoolId;
  bool dissolveCalled = false;
  int createCalls = 0;
  List<JoinRequestData> joinRequestResults = const <JoinRequestData>[];
  final Set<String> rejectFailOnceRequestIds = <String>{};

  @override
  Future<PoolCreateResult> createPool() async {
    createCalls += 1;
    return const PoolCreateResult(
      poolId: 'server-pool',
      poolName: 'Server Pool',
      isDissolved: false,
      isOwner: true,
      currentIdentityLabel: 'owner@test',
      memberLabels: <String>['owner@test'],
      inviteCode: 'invite://server-pool',
    );
  }

  @override
  Future<PoolJoinResult> joinByCode(String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (code == 'joined-pool-code') {
      return const PoolJoinResult.joined(poolName: 'Joined Pool');
    }
    return const PoolJoinResult.error('ADMIN_OFFLINE');
  }

  @override
  Future<PoolViewData?> getJoinedPoolView() async {
    return const PoolViewData(
      poolId: 'joined-pool',
      poolName: 'Joined Pool',
      isDissolved: false,
      isOwner: true,
      currentIdentityLabel: 'joiner@test',
      memberLabels: <String>['owner@test', 'joiner@test'],
      joinRequests: <JoinRequestData>[],
    );
  }

  @override
  Future<PoolDetailData> getPoolDetail(String poolId) async {
    return const PoolDetailData(
      poolId: 'joined-pool',
      poolName: 'Joined Pool',
      isDissolved: false,
      isOwner: true,
      currentIdentityLabel: 'owner@test',
      memberLabels: <String>['owner@test'],
      joinRequests: <JoinRequestData>[],
    );
  }

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
      poolId: 'joined-pool',
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
}

PoolController _buildTestPoolController({
  PoolState state = const PoolState.notJoined(),
}) {
  return PoolController(initialState: state, apiClient: _FakePoolApiClient());
}

class _FakeSyncGateway implements SyncGateway {
  int statusCalls = 0;
  int pullCalls = 0;
  int connectCalls = 0;
  int disconnectCalls = 0;

  @override
  Future<void> syncConnect({
    required BigInt networkId,
    required String target,
  }) async {
    connectCalls += 1;
  }

  @override
  Future<void> syncDisconnect({required BigInt networkId}) async {
    disconnectCalls += 1;
  }

  @override
  Future<void> syncJoinPool({
    required BigInt networkId,
    required String poolId,
  }) async {}

  @override
  Future<frb.SyncResultDto> syncPull({required BigInt networkId}) async {
    pullCalls += 1;
    return const frb.SyncResultDto(
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
  }

  @override
  Future<frb.SyncResultDto> syncPush({required BigInt networkId}) =>
      throw UnimplementedError();

  @override
  Future<frb.SyncStatusDto> syncStatus({required BigInt networkId}) async {
    statusCalls += 1;
    return const frb.SyncStatusDto(
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
}

void main() {
  testWidgets(
    'pool page production composition should use handle-free FRB client',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PoolPage(state: PoolState.notJoined())),
      );

      expect(find.byType(PoolPage), findsOneWidget);
    },
  );

  testWidgets('shows join actions when not joined', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PoolPage(
          state: const PoolState.notJoined(),
          controller: _buildTestPoolController(),
        ),
      ),
    );

    expect(find.text('在这里创建或加入数据池'), findsOneWidget);
    expect(find.text('扫码加入'), findsOneWidget);
  });

  testWidgets('pool unjoined state shows create/join guidance copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PoolPage(
          state: const PoolState.notJoined(),
          controller: _buildTestPoolController(),
        ),
      ),
    );

    expect(find.textContaining('在这里创建或加入数据池'), findsOneWidget);
  });

  testWidgets('create pool enters joined state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PoolPage(
          state: const PoolState.notJoined(),
          controller: _buildTestPoolController(),
        ),
      ),
    );

    await tester.tap(find.text('创建池'));
    await tester.pumpAndSettle();

    expect(find.text('成员列表'), findsOneWidget);
    expect(find.text('我的身份: owner@test'), findsOneWidget);
    expect(find.text('1. owner@test'), findsOneWidget);
    expect(find.text('邀请字符串'), findsOneWidget);
    expect(find.text('invite://server-pool'), findsOneWidget);
  });

  testWidgets('joined pool state does not expose one-step go-to-cards action', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PoolPage(state: PoolState.joined())),
    );

    expect(find.text('去卡片'), findsNothing);
  });

  testWidgets('joined page can return to pool tab route', (tester) async {
    var returnedToPoolTab = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PoolPage(
                          state: PoolState.joined(),
                          onReturnToPoolTab: () {
                            returnedToPoolTab = true;
                          },
                        ),
                      ),
                    );
                  },
                  child: const Text('open-pool-route'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open-pool-route'));
    await tester.pumpAndSettle();

    expect(find.text('返回数据池Tab'), findsOneWidget);
    await tester.tap(find.text('返回数据池Tab'));
    await tester.pumpAndSettle();

    expect(returnedToPoolTab, isTrue);
    expect(find.text('open-pool-route'), findsOneWidget);
  });

  testWidgets('scan join can lead to error state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PoolPage(
          state: const PoolState.notJoined(),
          controller: _buildTestPoolController(),
        ),
      ),
    );

    await tester.tap(find.text('扫码加入'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('pool.join_dialog.code_input')),
      'bad-pool-code',
    );
    await tester.tap(find.byKey(const ValueKey('pool.join_dialog.confirm')));
    await tester.pumpAndSettle();

    expect(find.textContaining('加入失败:'), findsOneWidget);
    expect(find.text('稍后重试'), findsOneWidget);
  });

  testWidgets('closing scan dialog without code keeps unjoined state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PoolPage(
          state: const PoolState.notJoined(),
          controller: _buildTestPoolController(),
        ),
      ),
    );

    await tester.tap(find.text('扫码加入'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.text('在这里创建或加入数据池'), findsOneWidget);
    expect(find.text('扫码加入'), findsOneWidget);
  });

  testWidgets('join flow shows visible pending feedback before result', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PoolPage(
          state: const PoolState.notJoined(),
          controller: _buildTestPoolController(),
        ),
      ),
    );

    await tester.tap(find.text('扫码加入'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('pool.join_dialog.code_input')),
      'joined-pool-code',
    );
    await tester.tap(find.byKey(const ValueKey('pool.join_dialog.confirm')));
    await tester.pump();

    expect(find.text('请求处理中...'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('成员列表'), findsOneWidget);
    expect(find.text('我的身份: joiner@test'), findsOneWidget);
    expect(find.text('1. owner@test'), findsOneWidget);
    expect(find.text('2. joiner@test'), findsOneWidget);
  });

  testWidgets('auto join code should join once on first render', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PoolPage(
          state: const PoolState.notJoined(),
          controller: _buildTestPoolController(),
          autoJoinCode: 'joined-pool-code',
        ),
      ),
    );

    await tester.pump();
    expect(find.text('请求处理中...'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('成员列表'), findsOneWidget);
    expect(find.text('我的身份: joiner@test'), findsOneWidget);
  });

  testWidgets('auto create pool should create once on first render', (
    tester,
  ) async {
    final client = _FakePoolApiClient();
    final controller = PoolController(
      initialState: const PoolState.notJoined(),
      apiClient: client,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PoolPage(
          state: const PoolState.notJoined(),
          controller: controller,
          autoCreatePool: true,
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(client.createCalls, 1);
    expect(find.text('成员列表'), findsOneWidget);
    expect(find.byKey(const ValueKey('pool.invite_code')), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: PoolPage(
          state: controller.state,
          controller: controller,
          autoCreatePool: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(client.createCalls, 1);
  });

  testWidgets('auto create pool can export invite code to file', (
    tester,
  ) async {
    final client = _FakePoolApiClient();
    final controller = PoolController(
      initialState: const PoolState.notJoined(),
      apiClient: client,
    );
    final tempDir = await Directory.systemTemp.createTemp(
      'cardmind-pool-page-invite-',
    );
    final invitePath = p.join(tempDir.path, 'invite.txt');

    try {
      await tester.pumpWidget(
        MaterialApp(
          home: PoolPage(
            state: const PoolState.notJoined(),
            controller: controller,
            autoCreatePool: true,
            debugExportInvitePath: invitePath,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      final exported = await File(invitePath).readAsString();
      expect(exported, 'invite://server-pool');
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('auto create pool prints invite in debug mode', (tester) async {
    final client = _FakePoolApiClient();
    final controller = PoolController(
      initialState: const PoolState.notJoined(),
      apiClient: client,
    );
    final logs = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: PoolPage(
          state: const PoolState.notJoined(),
          controller: controller,
          autoCreatePool: true,
          debugPrintInvite: true,
          debugLogSink: logs.add,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(logs, contains('pool_debug.invite:invite://server-pool'));
  });

  testWidgets('leave pool confirmation returns to not joined', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PoolPage(
          state: const PoolState.joined(poolId: 'joined-pool'),
          controller: _buildTestPoolController(
            state: const PoolState.joined(poolId: 'joined-pool'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('退出池'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认退出'));
    await tester.pumpAndSettle();

    expect(find.text('在这里创建或加入数据池'), findsOneWidget);
    expect(find.text('扫码加入'), findsOneWidget);
  });

  testWidgets('approve/reject updates pending list with observable result', (
    tester,
  ) async {
    final client = _FakePoolApiClient()
      ..joinRequestResults = const <JoinRequestData>[]
      ..rejectFailOnceRequestIds.add('bob');
    final controller = PoolController(
      apiClient: client,
      initialState: const PoolState.joined(
        poolId: 'joined-pool',
        pending: <PoolPendingRequest>[
          PoolPendingRequest(id: 'alice', displayName: 'alice@pending'),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PoolPage(
          state: const PoolState.joined(
            poolId: 'joined-pool',
            pending: <PoolPendingRequest>[
              PoolPendingRequest(id: 'alice', displayName: 'alice@pending'),
            ],
          ),
          controller: controller,
        ),
      ),
    );

    expect(find.text('待审批请求'), findsOneWidget);
    expect(find.text('alice@pending'), findsOneWidget);

    await tester.tap(find.text('通过'));
    await tester.pumpAndSettle();

    expect(find.text('alice@pending'), findsNothing);
    expect(find.text('审批已通过'), findsOneWidget);

    controller.setState(
      const PoolState.joined(
        poolId: 'joined-pool',
        pending: <PoolPendingRequest>[
          PoolPendingRequest(id: 'bob', displayName: 'bob@pending-fail'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('拒绝'));
    await tester.pumpAndSettle();

    expect(find.text('bob@pending-fail'), findsOneWidget);
    expect(find.text('拒绝失败：网络异常'), findsOneWidget);
    expect(find.text('拒绝失败，请稍后重试'), findsOneWidget);
    expect(find.text('重试拒绝'), findsOneWidget);

    await tester.tap(find.text('重试拒绝'));
    await tester.pumpAndSettle();

    expect(find.text('bob@pending-fail'), findsNothing);
    expect(find.text('拒绝已完成'), findsOneWidget);
  });

  testWidgets('approve pending request uses API result to refresh list', (
    tester,
  ) async {
    final client = _FakePoolApiClient()
      ..joinRequestResults = const <JoinRequestData>[];
    final controller = PoolController(
      apiClient: client,
      initialState: const PoolState.joined(
        poolId: 'joined-pool',
        pending: <PoolPendingRequest>[
          PoolPendingRequest(id: 'req-1', displayName: 'alice@pending'),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PoolPage(
          state: const PoolState.joined(
            poolId: 'joined-pool',
            pending: <PoolPendingRequest>[
              PoolPendingRequest(id: 'req-1', displayName: 'alice@pending'),
            ],
          ),
          controller: controller,
        ),
      ),
    );

    await tester.tap(find.text('通过'));
    await tester.pumpAndSettle();

    expect(find.text('alice@pending'), findsNothing);
    expect(find.text('审批已通过'), findsOneWidget);
  });

  testWidgets('cancel join request uses API result to refresh list', (
    tester,
  ) async {
    final client = _FakePoolApiClient()
      ..joinRequestResults = const <JoinRequestData>[];
    final controller = PoolController(
      apiClient: client,
      initialState: const PoolState.joined(
        poolId: 'joined-pool',
        pending: <PoolPendingRequest>[
          PoolPendingRequest(id: 'req-1', displayName: 'alice@pending'),
        ],
      ),
    );

    await controller.cancelJoinRequest('req-1');
    await tester.pumpWidget(
      MaterialApp(
        home: PoolPage(state: controller.state, controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('alice@pending'), findsNothing);
    expect(find.text('加入申请已取消'), findsOneWidget);
  });

  testWidgets('applicant can submit join request from not joined state', (
    tester,
  ) async {
    final client = _FakePoolApiClient()
      ..joinRequestResults = const <JoinRequestData>[
        JoinRequestData(
          requestId: 'req-1',
          displayName: 'applicant@test',
          status: 'pending',
        ),
      ];
    final controller = PoolController(
      apiClient: client,
      initialState: const PoolState.notJoined(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PoolPage(
          state: const PoolState.notJoined(),
          controller: controller,
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey('pool.submit_join_request_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('待审批请求'), findsOneWidget);
    expect(find.text('applicant@test'), findsOneWidget);
    expect(find.text('取消申请'), findsOneWidget);
    expect(find.textContaining('等待管理员审批'), findsOneWidget);
  });

  testWidgets('exit pool partial cleanup shows retry action', (tester) async {
    final client = _FakePoolApiClient()
      ..leavePartialCleanupError = ApiError(
        code: 'PARTIAL_CLEANUP',
        message: 'partial cleanup required',
      );
    await tester.pumpWidget(
      MaterialApp(
        home: PoolPage(
          state: const PoolState.joined(),
          controller: PoolController(
            apiClient: client,
            initialState: const PoolState.joined(),
          ),
        ),
      ),
    );

    await tester.tap(find.text('退出池'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认退出'));
    await tester.pumpAndSettle();

    expect(find.text('部分清理失败'), findsOneWidget);
    expect(find.text('重试清理'), findsOneWidget);

    await tester.tap(find.text('重试清理'));
    await tester.pumpAndSettle();

    expect(find.text('创建池'), findsOneWidget);
    expect(find.text('扫码加入'), findsOneWidget);
  });

  testWidgets('join error state shows mapped primary action label', (
    tester,
  ) async {
    final mapped = mapJoinError('REQUEST_TIMEOUT');

    await tester.pumpWidget(
      const MaterialApp(
        home: PoolPage(state: PoolState.error('REQUEST_TIMEOUT')),
      ),
    );

    expect(find.text(mapped.primaryActionLabel), findsOneWidget);
    expect(find.textContaining('发生了什么'), findsOneWidget);
    expect(find.textContaining('可以做什么'), findsOneWidget);
  });

  testWidgets('POOL_NOT_FOUND shows stable primary and follow-up actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PoolPage(state: PoolState.error('POOL_NOT_FOUND')),
      ),
    );

    expect(find.text('重新获取池信息'), findsOneWidget);
    expect(find.text('查看排查建议'), findsOneWidget);
    expect(find.text('重试同步'), findsOneWidget);
    expect(find.text('重新连接'), findsOneWidget);
  });

  testWidgets('owner can edit pool info and dissolve pool', (tester) async {
    final controller = PoolController(
      apiClient: _FakePoolApiClient(),
      initialState: const PoolState.joined(
        poolId: 'joined-pool',
        poolName: '默认数据池',
        isOwner: true,
        isDissolved: false,
        currentIdentityLabel: '未知身份',
        memberLabels: <String>[],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PoolPage(
          state: const PoolState.joined(
            poolId: 'joined-pool',
            poolName: '默认数据池',
            isOwner: true,
            isDissolved: false,
            currentIdentityLabel: '未知身份',
            memberLabels: <String>[],
          ),
          controller: controller,
        ),
      ),
    );

    await tester.tap(find.text('编辑池信息'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'New Pool Name');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('New Pool Name'), findsOneWidget);

    await tester.tap(find.text('解散池'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认解散'));
    await tester.pumpAndSettle();

    expect(find.textContaining('已解散'), findsWidgets);
    expect(find.textContaining('只读状态'), findsWidgets);
    expect(find.text('编辑池信息'), findsNothing);
  });

  testWidgets('dissolved pool enters read-only state', (tester) async {
    final client = _FakePoolApiClient();
    final controller = PoolController(
      apiClient: client,
      initialState: const PoolState.joined(
        poolId: 'joined-pool',
        poolName: 'Joined Pool',
        isOwner: true,
        isDissolved: false,
        currentIdentityLabel: 'owner@test',
        memberLabels: <String>['owner@test'],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PoolPage(
          state: const PoolState.joined(
            poolId: 'joined-pool',
            poolName: 'Joined Pool',
            isOwner: true,
            isDissolved: false,
            currentIdentityLabel: 'owner@test',
            memberLabels: <String>['owner@test'],
          ),
          controller: controller,
        ),
      ),
    );

    await tester.tap(find.text('解散池'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认解散'));
    await tester.pumpAndSettle();

    expect(client.dissolveCalled, isTrue);
    expect(find.textContaining('已解散'), findsWidgets);
    expect(find.textContaining('只读状态'), findsWidgets);
    expect(find.text('编辑池信息'), findsNothing);
  });

  testWidgets('last admin leave failure shows blocking message', (
    tester,
  ) async {
    final client = _FakePoolApiClient()
      ..leaveError = ApiError(
        code: 'INVALID_ARGUMENT',
        message: 'last admin cannot leave pool',
      );
    final controller = PoolController(
      apiClient: client,
      initialState: const PoolState.joined(
        poolId: 'joined-pool',
        poolName: 'Joined Pool',
        isOwner: true,
        currentIdentityLabel: 'owner@test',
        memberLabels: <String>['owner@test', 'member@test'],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PoolPage(
          state: const PoolState.joined(
            poolId: 'joined-pool',
            poolName: 'Joined Pool',
            isOwner: true,
            currentIdentityLabel: 'owner@test',
            memberLabels: <String>['owner@test', 'member@test'],
          ),
          controller: controller,
        ),
      ),
    );

    await tester.tap(find.text('退出池'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认退出'));
    await tester.pumpAndSettle();

    expect(find.textContaining('唯一的管理员'), findsOneWidget);
    expect(client.leftPoolId, 'joined-pool');
    expect(find.text('成员列表'), findsOneWidget);
  });

  testWidgets('editing pool info with blank name keeps original value', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PoolPage(state: PoolState.joined())),
    );

    await tester.tap(find.text('编辑池信息'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '   ');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('默认数据池'), findsOneWidget);
  });

  testWidgets('dismissing edit dialog keeps existing pool name', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: PoolPage(state: PoolState.joined())),
    );

    await tester.tap(find.text('编辑池信息'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('默认数据池'), findsOneWidget);
  });

  testWidgets('degraded sync feedback hides when status becomes healthy', (
    tester,
  ) async {
    final controller = PoolController(
      initialState: const PoolState.joined(),
      initialSyncStatus: const SyncStatus.degraded('REQUEST_TIMEOUT'),
      apiClient: _FakePoolApiClient(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PoolPage(state: controller.state, controller: controller),
      ),
    );
    // Phase 2: SyncStatus.degraded 默认使用 pathAtRisk，显示 "延续路径有风险"
    expect(find.text('同步状态降级：延续路径有风险'), findsOneWidget);

    controller.setSyncStatus(const SyncStatus.connected());
    await tester.pumpAndSettle();

    expect(find.text('同步状态降级：延续路径有风险'), findsNothing);
  });

  testWidgets(
    'retry sync should invoke backend retry action and refresh status',
    (tester) async {
      final gateway = _FakeSyncGateway();
      final controller = PoolController(
        initialState: const PoolState.error('REQUEST_TIMEOUT'),
        initialSyncStatus: const SyncStatus.error('REQUEST_TIMEOUT'),
        apiClient: _FakePoolApiClient(),
        syncService: SyncService(gateway: gateway, networkId: BigInt.one),
        reconnectTarget: 'peer-1',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PoolPage(
            state: const PoolState.error('REQUEST_TIMEOUT'),
            controller: controller,
          ),
        ),
      );

      await tester.tap(find.text('重试同步'));
      await tester.pumpAndSettle();

      expect(gateway.pullCalls, 1);
      expect(gateway.statusCalls, 1);
      expect(controller.syncStatus.kind, SyncStatusKind.connected);
    },
  );

  testWidgets(
    'reconnect sync should invoke backend reconnect action and refresh status',
    (tester) async {
      final gateway = _FakeSyncGateway();
      final controller = PoolController(
        initialState: const PoolState.error('REQUEST_TIMEOUT'),
        initialSyncStatus: const SyncStatus.error('REQUEST_TIMEOUT'),
        apiClient: _FakePoolApiClient(),
        syncService: SyncService(gateway: gateway, networkId: BigInt.two),
        reconnectTarget: 'peer-1',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PoolPage(
            state: const PoolState.error('REQUEST_TIMEOUT'),
            controller: controller,
          ),
        ),
      );

      await tester.tap(find.text('重新连接'));
      await tester.pumpAndSettle();

      expect(gateway.disconnectCalls, 1);
      expect(gateway.connectCalls, 1);
      expect(gateway.statusCalls, 1);
      expect(controller.syncStatus.kind, SyncStatusKind.connected);
    },
  );
}
