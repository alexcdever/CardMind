// input: 池控制器接收 fake ApiClient 后执行 create/join 动作。
// output: 断言控制器通过 ApiClient 调后端，并将结果回填到状态。
// pos: 覆盖池控制器改接 ApiClient 主路径，防止回退到本地硬编码流程。修改本文件需同步更新文件头与所属 DIR.md。
import 'dart:io';

import 'package:cardmind/bridge_generated/api.dart' as frb;
import 'package:cardmind/bridge_generated/frb_generated.dart';
import 'package:cardmind/bridge_generated/models/api_error.dart';
import 'package:cardmind/features/cards/card_api_client.dart';
import 'package:cardmind/features/pool/pool_api_client.dart';
import 'package:cardmind/features/pool/pool_controller.dart';
import 'package:cardmind/features/pool/pool_state.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test_utils/rust_library_test_helper.dart';

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

  final dylib = resolveRustLibraryPathForTests();
  await RustLib.init(externalLibrary: ExternalLibrary.open(dylib));
  _rustLibInitialized = true;
}

Future<void> _unlockAppLock() async {
  await frb.setupAppLock(pin: '1234', allowBiometric: true);
  await frb.verifyAppLockWithPin(pin: '1234');
}

Future<void> _switchAppConfig(String appDataDir) async {
  await frb.resetAppConfigForTests();
  await frb.initAppConfig(appDataDir: appDataDir);
  await _unlockAppLock();
}

Future<CardDetailData> _waitForCardDetail({
  required String appDataDir,
  required String cardId,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  Object? lastError;
  while (DateTime.now().isBefore(deadline)) {
    await _switchAppConfig(appDataDir);
    try {
      return await FrbCardApiClient().getCardDetail(id: cardId);
    } catch (error) {
      lastError = error;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }
  throw StateError('timed out waiting for card $cardId: $lastError');
}

Future<frb.CardNoteDto> _waitForRawCard({
  required String appDataDir,
  required String cardId,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  String? lastError;
  while (DateTime.now().isBefore(deadline)) {
    await _switchAppConfig(appDataDir);
    try {
      return await frb.getCardNoteDetail(cardId: cardId);
    } on ApiError catch (error) {
      lastError = '${error.code} ${error.message}';
      await Future<void>.delayed(const Duration(milliseconds: 200));
    } catch (error) {
      lastError = error.toString();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }
  throw StateError('timed out waiting for raw card $cardId: $lastError');
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
    'frb pool api client createPool can surface invite without explicit runtime handles',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'cardmind-pool-create-invite-',
      );
      await _ensureRustLibInitialized();
      await frb.resetAppConfigForTests();
      await frb.initAppConfig(appDataDir: root.path);
      await _unlockAppLock();

      try {
        final client = FrbPoolApiClient(
          nickname: 'nick-a',
          os: 'macos',
          appDataDir: root.path,
        );

        final created = await client.createPool();

        expect(created.poolName, contains('nick-a'));
        expect(created.isOwner, isTrue);
        expect(created.currentIdentityLabel, isNotEmpty);
        expect(created.memberLabels, contains(created.currentIdentityLabel));
        expect(created.inviteCode, isNotNull);
        expect(created.inviteCode, isNotEmpty);
      } finally {
        await frb.resetAppConfigForTests();
        await root.delete(recursive: true);
      }
    },
  );

  test(
    'frb pool api client should reuse injected networkId for invite join flow',
    () async {
      final ownerRoot = await Directory.systemTemp.createTemp(
        'cardmind-pool-client-owner-',
      );
      final joinerRoot = await Directory.systemTemp.createTemp(
        'cardmind-pool-client-joiner-',
      );
      await _ensureRustLibInitialized();

      BigInt? ownerNetworkId;
      BigInt? joinerNetworkId;

      try {
        await _switchAppConfig(ownerRoot.path);
        ownerNetworkId = await frb.initPoolNetwork(basePath: ownerRoot.path);
        final ownerEndpointId = await frb.getPoolNetworkEndpointId(
          networkId: ownerNetworkId,
        );
        final ownerClient = FrbPoolApiClient(
          nickname: 'owner',
          os: 'macos',
          appDataDir: ownerRoot.path,
          networkId: ownerNetworkId,
        );
        final ownerTarget = await frb.getPoolNetworkSyncTarget(
          networkId: ownerNetworkId,
        );
        final created = await ownerClient.createPool();

        await _switchAppConfig(joinerRoot.path);
        joinerNetworkId = await frb.initPoolNetwork(basePath: joinerRoot.path);
        final joinerClient = FrbPoolApiClient(
          nickname: 'joiner',
          os: 'android',
          appDataDir: joinerRoot.path,
          networkId: joinerNetworkId,
        );
        final joinerTarget = await frb.getPoolNetworkSyncTarget(
          networkId: joinerNetworkId,
        );
        final joined = await joinerClient.joinByCode(created.inviteCode!);

        expect(
          joined.isSuccess,
          isTrue,
          reason: 'join error: ${joined.errorCode}',
        );
        expect(joined.isPending, isTrue);
        await _switchAppConfig(ownerRoot.path);
        await frb.approveJoinRequest(
          poolId: created.poolId,
          requestId: joined.requestId!,
          approverEndpointId: ownerEndpointId,
        );

        await frb.syncConnect(networkId: ownerNetworkId, target: joinerTarget);
        await frb.syncJoinPool(
          networkId: ownerNetworkId,
          poolId: created.poolId,
        );
        final createdCard = await frb.createCardNoteInPool(
          poolId: created.poolId,
          title: 'shared-title',
          content: 'shared-body',
        );
        await frb.syncPush(networkId: ownerNetworkId);

        await _switchAppConfig(joinerRoot.path);
        await frb.syncConnect(networkId: joinerNetworkId, target: ownerTarget);
        await frb.syncJoinPool(
          networkId: joinerNetworkId,
          poolId: created.poolId,
        );
        final synced = await _waitForRawCard(
          appDataDir: joinerRoot.path,
          cardId: createdCard.id,
        );

        expect(synced.id, createdCard.id);
      } finally {
        if (ownerNetworkId != null) {
          await frb.closePoolNetwork(networkId: ownerNetworkId);
        }
        if (joinerNetworkId != null) {
          await frb.closePoolNetwork(networkId: joinerNetworkId);
        }
        await frb.resetAppConfigForTests();
        await ownerRoot.delete(recursive: true);
        await joinerRoot.delete(recursive: true);
      }
    },
  );

  test(
    'frb pool api client using same appDataDir for owner and joiner still reads joined view in single process',
    () async {
      final sharedRoot = await Directory.systemTemp.createTemp(
        'cardmind-pool-client-shared-',
      );
      await _ensureRustLibInitialized();

      BigInt? ownerNetworkId;
      BigInt? joinerNetworkId;

      try {
        await _switchAppConfig(sharedRoot.path);
        ownerNetworkId = await frb.initPoolNetwork(basePath: sharedRoot.path);
        final ownerClient = FrbPoolApiClient(
          nickname: 'owner',
          os: 'macos',
          appDataDir: sharedRoot.path,
          networkId: ownerNetworkId,
        );
        final created = await ownerClient.createPool();

        joinerNetworkId = await frb.initPoolNetwork(basePath: sharedRoot.path);
        final joinerClient = FrbPoolApiClient(
          nickname: 'joiner',
          os: 'android',
          appDataDir: sharedRoot.path,
          networkId: joinerNetworkId,
        );
        final joined = await joinerClient.joinByCode(created.inviteCode!);

        expect(joined.isSuccess, isTrue, reason: 'join should succeed first');
        expect(joined.isPending, isTrue);
        final ownerEndpointId = await frb.getPoolNetworkEndpointId(
          networkId: ownerNetworkId,
        );
        await frb.approveJoinRequest(
          poolId: created.poolId,
          requestId: joined.requestId!,
          approverEndpointId: ownerEndpointId,
        );

        final joinedView = await joinerClient.getJoinedPoolView();
        expect(joinedView, isNotNull);
        expect(joinedView!.poolId, created.poolId);
      } finally {
        if (ownerNetworkId != null) {
          await frb.closePoolNetwork(networkId: ownerNetworkId);
        }
        if (joinerNetworkId != null) {
          await frb.closePoolNetwork(networkId: joinerNetworkId);
        }
        await frb.resetAppConfigForTests();
        await sharedRoot.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'frb pool api client prints join trace when debug enabled',
    () async {
      final ownerRoot = await Directory.systemTemp.createTemp(
        'cardmind-pool-trace-owner-',
      );
      final joinerRoot = await Directory.systemTemp.createTemp(
        'cardmind-pool-trace-joiner-',
      );
      await _ensureRustLibInitialized();

      BigInt? ownerNetworkId;
      BigInt? joinerNetworkId;

      try {
        await _switchAppConfig(ownerRoot.path);
        ownerNetworkId = await frb.initPoolNetwork(basePath: ownerRoot.path);
        final ownerClient = FrbPoolApiClient(
          nickname: 'owner',
          os: 'macos',
          appDataDir: ownerRoot.path,
          networkId: ownerNetworkId,
        );
        final created = await ownerClient.createPool();
        await frb.closePoolNetwork(networkId: ownerNetworkId);
        ownerNetworkId = null;

        final logs = <String>[];
        await _switchAppConfig(joinerRoot.path);
        joinerNetworkId = await frb.initPoolNetwork(basePath: joinerRoot.path);
        final joinerClient = FrbPoolApiClient(
          nickname: 'joiner',
          os: 'android',
          appDataDir: joinerRoot.path,
          networkId: joinerNetworkId,
          debugJoinTrace: true,
          debugLogSink: logs.add,
        );

        final joined = await joinerClient.joinByCode(created.inviteCode!);

        expect(joined.isSuccess, isFalse);
        expect(
          logs.any((line) => line.startsWith('pool_debug.join.invite_parsed:')),
          isTrue,
        );
        expect(
          logs.any((line) => line.startsWith('pool_debug.join.target_addrs:')),
          isTrue,
        );
        expect(
          logs.any((line) => line.startsWith('pool_debug.join.attempt_start:')),
          isTrue,
        );
        expect(
          logs.any((line) => line.startsWith('pool_debug.join.attempt_end:')),
          isTrue,
        );
        expect(
          logs.any((line) => line.startsWith('pool_debug.join.final:')),
          isTrue,
        );
      } finally {
        if (ownerNetworkId != null) {
          await frb.closePoolNetwork(networkId: ownerNetworkId);
        }
        if (joinerNetworkId != null) {
          await frb.closePoolNetwork(networkId: joinerNetworkId);
        }
        await frb.resetAppConfigForTests();
        await ownerRoot.delete(recursive: true);
        await joinerRoot.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
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

  test(
    'frb pool api client can join by invite without explicit runtime handles',
    () async {
      final ownerRoot = await Directory.systemTemp.createTemp(
        'cardmind-pool-owner-',
      );
      final joinerRoot = await Directory.systemTemp.createTemp(
        'cardmind-pool-joiner-',
      );
      await _ensureRustLibInitialized();
      await frb.resetAppConfigForTests();
      await frb.initAppConfig(appDataDir: ownerRoot.path);
      await _unlockAppLock();

      try {
        final ownerNetworkId = await frb.initPoolNetwork(
          basePath: ownerRoot.path,
        );
        final ownerEndpointId = await frb.getPoolNetworkEndpointId(
          networkId: ownerNetworkId,
        );
        final pool = await frb.createPool(
          endpointId: ownerEndpointId,
          nickname: 'owner',
          os: 'macos',
        );
        final invite = await frb.createPoolInvite(
          networkId: ownerNetworkId,
          poolId: pool.id,
        );

        final client = FrbPoolApiClient(
          nickname: 'joiner',
          os: 'ios',
          appDataDir: joinerRoot.path,
        );

        final joined = await client.joinByCode(invite);
        expect(
          joined.isSuccess,
          isTrue,
          reason: 'join error: ${joined.errorCode}',
        );
        expect(joined.isPending, isTrue);
        await frb.approveJoinRequest(
          poolId: pool.id,
          requestId: joined.requestId!,
          approverEndpointId: ownerEndpointId,
        );

        await frb.resetAppConfigForTests();
        await frb.initAppConfig(appDataDir: joinerRoot.path);
        await _unlockAppLock();
        await expectLater(client.getJoinedPoolView(), throwsA(isA<ApiError>()));
      } finally {
        await frb.resetAppConfigForTests();
        await ownerRoot.delete(recursive: true);
        await joinerRoot.delete(recursive: true);
      }
    },
  );

  test(
    'invite-linked dual app instances should sync pool note CRUD across app data dirs',
    () async {
      final ownerRoot = await Directory.systemTemp.createTemp(
        'cardmind-pool-sync-owner-',
      );
      final joinerRoot = await Directory.systemTemp.createTemp(
        'cardmind-pool-sync-joiner-',
      );
      await _ensureRustLibInitialized();
      await _switchAppConfig(ownerRoot.path);

      BigInt? ownerNetworkId;
      BigInt? joinerNetworkId;

      try {
        ownerNetworkId = await frb.initPoolNetwork(basePath: ownerRoot.path);
        final ownerSyncTarget = await frb.getPoolNetworkSyncTarget(
          networkId: ownerNetworkId,
        );
        final ownerClient = FrbPoolApiClient(
          nickname: 'owner',
          os: 'macos',
          appDataDir: ownerRoot.path,
          networkId: ownerNetworkId,
        );
        final created = await ownerClient.createPool();

        await _switchAppConfig(joinerRoot.path);
        joinerNetworkId = await frb.initPoolNetwork(basePath: joinerRoot.path);
        final joinerSyncTarget = await frb.getPoolNetworkSyncTarget(
          networkId: joinerNetworkId,
        );
        final joinerClient = FrbPoolApiClient(
          nickname: 'joiner',
          os: 'android',
          appDataDir: joinerRoot.path,
          networkId: joinerNetworkId,
        );
        final joined = await joinerClient.joinByCode(created.inviteCode!);

        expect(
          joined.isSuccess,
          isTrue,
          reason: 'join error: ${joined.errorCode}',
        );
        expect(joined.isPending, isTrue);
        final ownerEndpointId = await frb.getPoolNetworkEndpointId(
          networkId: ownerNetworkId,
        );
        await _switchAppConfig(ownerRoot.path);
        await frb.approveJoinRequest(
          poolId: created.poolId,
          requestId: joined.requestId!,
          approverEndpointId: ownerEndpointId,
        );
        await _switchAppConfig(joinerRoot.path);

        await _switchAppConfig(ownerRoot.path);
        await frb.syncConnect(
          networkId: ownerNetworkId,
          target: joinerSyncTarget,
        );
        await frb.syncJoinPool(
          networkId: ownerNetworkId,
          poolId: created.poolId,
        );

        await _switchAppConfig(joinerRoot.path);
        await frb.syncConnect(
          networkId: joinerNetworkId,
          target: ownerSyncTarget,
        );
        await frb.syncJoinPool(
          networkId: joinerNetworkId,
          poolId: created.poolId,
        );

        await _switchAppConfig(ownerRoot.path);
        final createdCard = await frb.createCardNoteInPool(
          poolId: created.poolId,
          title: 'owner-title',
          content: 'owner-body',
        );
        final ownerPush = await frb.syncPush(networkId: ownerNetworkId);

        await _switchAppConfig(joinerRoot.path);
        final joinerSyncStatus = await frb.syncStatus(
          networkId: joinerNetworkId,
        );
        final joinerDetail = await joinerClient.getPoolDetail(created.poolId);
        final joinerRawCard = await _waitForRawCard(
          appDataDir: joinerRoot.path,
          cardId: createdCard.id,
        );
        final joinerCardDetail = await _waitForCardDetail(
          appDataDir: joinerRoot.path,
          cardId: createdCard.id,
        );
        await _switchAppConfig(joinerRoot.path);
        final joinerCards = await frb.listCardNotes();
        final joinerPoolCards = await frb.queryCardNotes(
          query: '',
          poolId: created.poolId,
          includeDeleted: false,
        );

        expect(ownerPush.state, 'ok');
        expect(joinerSyncStatus.state, anyOf('connected', 'idle'));
        expect(joinerDetail.poolId, created.poolId);
        expect(joinerRawCard.id, createdCard.id);
        expect(joinerCardDetail.id, createdCard.id);
        expect(joinerCards.map((card) => card.id), contains(createdCard.id));
        expect(
          joinerPoolCards.map((card) => card.id),
          contains(createdCard.id),
        );
      } finally {
        if (ownerNetworkId != null) {
          await frb.closePoolNetwork(networkId: ownerNetworkId);
        }
        if (joinerNetworkId != null) {
          await frb.closePoolNetwork(networkId: joinerNetworkId);
        }
        await frb.resetAppConfigForTests();
        await ownerRoot.delete(recursive: true);
        await joinerRoot.delete(recursive: true);
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
    'frb pool api client joinByCode preserves backend error message',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'cardmind-pool-join-error-',
      );
      await _ensureRustLibInitialized();
      await frb.resetAppConfigForTests();
      await frb.initAppConfig(appDataDir: root.path);
      await _unlockAppLock();

      try {
        final client = FrbPoolApiClient(
          endpointId: 'joiner-endpoint',
          nickname: 'joiner',
          os: 'ios',
        );

        final result = await client.joinByCode('missing-pool-id');

        expect(result.isSuccess, isFalse);
        expect(result.errorCode, 'INVALID_POOL_HASH');
        expect(result.errorMessage, isNotEmpty);
      } finally {
        await frb.resetAppConfigForTests();
        await root.delete(recursive: true);
      }
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
