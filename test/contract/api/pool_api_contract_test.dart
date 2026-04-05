// input: 池控制器接收 fake ApiClient 后执行 create/join 动作。
// output: 断言控制器通过 ApiClient 调后端，并将结果回填到状态。
// pos: 覆盖池控制器改接 ApiClient 主路径，防止回退到本地硬编码流程。修改本文件需同步更新文件头与所属 DIR.md。
import 'dart:io';

import 'package:cardmind/bridge_generated/api.dart' as frb;
import 'package:cardmind/bridge_generated/frb_generated.dart';
import 'package:cardmind/bridge_generated/models/api_error.dart';
import 'package:cardmind/features/pool/pool_api_client.dart';
import 'package:cardmind/features/pool/pool_controller.dart';
import 'package:cardmind/features/pool/pool_state.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePoolApiClient implements PoolApiClient {
  int createCalls = 0;
  int joinCalls = 0;

  @override
  Future<PoolCreateResult> createPool() async {
    createCalls += 1;
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
    joinCalls += 1;
    if (code == 'ok') {
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

Future<void> _unlockAppLock() async {
  await frb.setupAppLock(pin: '1234', allowBiometric: true);
  await frb.verifyAppLockWithPin(pin: '1234');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('frb pool api client should not require storeId constructor state', () {
    final client = FrbPoolApiClient(
      endpointId: 'endpoint-a',
      nickname: 'nick-a',
      os: 'macos',
    );

    expect(client, isA<PoolApiClient>());
  });

  test(
    'frb pool api client createPool returns owner scoped detail data',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'cardmind-pool-create-',
      );
      await _ensureRustLibInitialized();
      await frb.resetAppConfigForTests();
      await frb.initAppConfig(appDataDir: root.path);
      await _unlockAppLock();

      try {
        final client = FrbPoolApiClient(
          endpointId: 'endpoint-a',
          nickname: 'nick-a',
          os: 'macos',
        );

        final created = await client.createPool();

        expect(created.poolName, contains('nick-a'));
        expect(created.isOwner, isTrue);
        expect(created.currentIdentityLabel, 'endpoint-a');
        expect(created.memberLabels, contains('endpoint-a'));
      } finally {
        await frb.resetAppConfigForTests();
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'frb pool api client maps joinByCode to backend result without handle state',
    () async {
      final root = await Directory.systemTemp.createTemp('cardmind-pool-api-');
      await _ensureRustLibInitialized();
      await frb.resetAppConfigForTests();
      await frb.initAppConfig(appDataDir: root.path);
      await _unlockAppLock();

      try {
        await frb.createCardNote(title: 'attached', content: 'body');
        final pool = await frb.createPool(
          endpointId: 'endpoint-a',
          nickname: 'nick-a',
          os: 'macos',
        );
        final client = FrbPoolApiClient(
          endpointId: 'endpoint-b',
          nickname: 'nick-b',
          os: 'ios',
        );

        final joined = await client.joinByCode(pool.id);
        final detail = await frb.getPoolDetail(
          poolId: pool.id,
          endpointId: 'endpoint-b',
        );
        final timeout = await client.joinByCode('timeout');

        expect(joined.isSuccess, isTrue);
        expect(joined.poolName, contains("nick-a"));
        expect(detail.noteIds, isNotEmpty);
        expect(timeout.isSuccess, isFalse);
        expect(timeout.errorCode, 'REQUEST_TIMEOUT');
      } finally {
        await frb.resetAppConfigForTests();
        await root.delete(recursive: true);
      }
    },
  );

  test('pool controller should create through api client', () async {
    final apiClient = _FakePoolApiClient();
    final controller = PoolController(apiClient: apiClient);

    await controller.createPool();

    expect(apiClient.createCalls, 1);
    final state = controller.state as PoolJoined;
    expect(state.poolName, 'Server Pool');
    expect(state.isOwner, isTrue);
  });

  test(
    'pool controller should join through api client and map result',
    () async {
      final apiClient = _FakePoolApiClient();
      final controller = PoolController(apiClient: apiClient);

      await controller.joinByCode('ok');

      expect(apiClient.joinCalls, 1);
      final state = controller.state as PoolJoined;
      expect(state.poolName, 'Joined Pool');
    },
  );

  test(
    'joined pool view should use backend current-user role instead of first member',
    () async {
      final root = await Directory.systemTemp.createTemp('cardmind-pool-view-');
      await _ensureRustLibInitialized();
      await frb.resetAppConfigForTests();
      await frb.initAppConfig(appDataDir: root.path);
      await _unlockAppLock();

      try {
        final pool = await frb.createPool(
          endpointId: 'owner-endpoint',
          nickname: 'owner',
          os: 'macos',
        );
        await frb.joinByCode(
          code: pool.id,
          endpointId: 'joiner-endpoint',
          nickname: 'joiner',
          os: 'ios',
        );
        final client = FrbPoolApiClient(
          endpointId: 'joiner-endpoint',
          nickname: 'joiner',
          os: 'ios',
        );
        final controller = PoolController(apiClient: client);

        final view = await client.getJoinedPoolView();
        await controller.joinByCode(pool.id);

        expect(view, isNotNull);
        expect(view!.isOwner, isFalse);
        final state = controller.state as PoolJoined;
        expect(state.isOwner, isFalse);
      } finally {
        await frb.resetAppConfigForTests();
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'frb pool api client should surface explicit not-member error for unknown caller',
    () async {
      final root = await Directory.systemTemp.createTemp('cardmind-pool-miss-');
      await _ensureRustLibInitialized();
      await frb.resetAppConfigForTests();
      await frb.initAppConfig(appDataDir: root.path);
      await _unlockAppLock();

      try {
        await frb.createPool(
          endpointId: 'owner-endpoint',
          nickname: 'owner',
          os: 'macos',
        );
        final client = FrbPoolApiClient(
          endpointId: 'unknown-endpoint',
          nickname: 'outsider',
          os: 'ios',
        );

        await expectLater(client.getJoinedPoolView(), throwsA(isA<ApiError>()));
      } finally {
        await frb.resetAppConfigForTests();
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'pool detail api should pass endpoint identity for current_user_role semantics',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'cardmind-pool-detail-',
      );
      await _ensureRustLibInitialized();
      await frb.resetAppConfigForTests();
      await frb.initAppConfig(appDataDir: root.path);
      await _unlockAppLock();

      try {
        final pool = await frb.createPool(
          endpointId: 'owner-endpoint',
          nickname: 'owner',
          os: 'macos',
        );
        await frb.joinByCode(
          code: pool.id,
          endpointId: 'joiner-endpoint',
          nickname: 'joiner',
          os: 'ios',
        );

        final detail = await frb.getPoolDetail(
          poolId: pool.id,
          endpointId: 'joiner-endpoint',
        );

        expect(detail.currentUserRole, 'member');
      } finally {
        await frb.resetAppConfigForTests();
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'frb pool api client getPoolDetail maps backend member labels',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'cardmind-pool-detail-client-',
      );
      await _ensureRustLibInitialized();
      await frb.resetAppConfigForTests();
      await frb.initAppConfig(appDataDir: root.path);
      await _unlockAppLock();

      try {
        final pool = await frb.createPool(
          endpointId: 'owner-endpoint',
          nickname: 'owner',
          os: 'macos',
        );
        await frb.joinByCode(
          code: pool.id,
          endpointId: 'joiner-endpoint',
          nickname: 'joiner',
          os: 'ios',
        );
        final client = FrbPoolApiClient(
          endpointId: 'joiner-endpoint',
          nickname: 'joiner',
          os: 'ios',
        );

        final detail = await client.getPoolDetail(pool.id);

        expect(detail.poolName, isNotEmpty);
        expect(detail.isOwner, isFalse);
        expect(detail.currentIdentityLabel, 'joiner-endpoint');
        expect(
          detail.memberLabels,
          containsAll(<String>['owner-endpoint', 'joiner-endpoint']),
        );
      } finally {
        await frb.resetAppConfigForTests();
        await root.delete(recursive: true);
      }
    },
  );
}
