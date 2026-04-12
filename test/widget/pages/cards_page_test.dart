// input: 在 CardsPage 执行新增、保存、删除与恢复等用户操作。
// output: 编辑页导航、保存反馈与列表状态按预期变化。
// pos: 覆盖卡片页核心 CRUD 交互路径，防止主流程回归。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/features/cards/cards_page.dart';
import 'package:cardmind/features/cards/cards_controller.dart';
import 'package:cardmind/features/cards/card_api_client.dart';
import 'package:cardmind/features/cards/card_summary.dart';
import 'package:cardmind/bridge_generated/api.dart';
import 'package:cardmind/bridge_generated/models/card.dart' as frb_models;
import 'package:cardmind/bridge_generated/models/api_error.dart';
import 'package:cardmind/bridge_generated/models/error.dart';
import 'package:cardmind/bridge_generated/models/pool.dart';
import 'package:cardmind/bridge_generated/api/recovery_contract.dart';
import 'package:cardmind/bridge_generated/frb_generated.dart';
import 'package:cardmind/bridge_generated/runtime/config.dart';
import 'package:cardmind/bridge_generated/runtime/entry_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

class _FakeCardApiClient implements CardApiClient {
  final Map<String, _FakeCardRecord> _records = <String, _FakeCardRecord>{};
  int createCalls = 0;
  int updateCalls = 0;
  String? lastCreatedId;
  String? lastUpdatedId;

  @override
  Future<List<CardSummary>> listCardSummaries({
    String query = '',
    String? poolId,
  }) async {
    final lowered = query.toLowerCase();
    final rows =
        _records.values
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
    createCalls += 1;
    lastCreatedId = id;
    _records[id] = _FakeCardRecord(
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
    updateCalls += 1;
    lastUpdatedId = id;
    final existing = _records[id];
    if (existing == null) {
      throw StateError('missing existing card');
    }
    _records[id] = _FakeCardRecord(
      id: id,
      title: title,
      body: body,
      deleted: existing.deleted,
      updatedAtMicros: DateTime.now().microsecondsSinceEpoch,
    );
  }

  @override
  Future<void> deleteCardNote({required String id}) async {
    final row = _records[id]!;
    _records[id] = _FakeCardRecord(
      id: row.id,
      title: row.title,
      body: row.body,
      deleted: true,
      updatedAtMicros: DateTime.now().microsecondsSinceEpoch,
    );
  }

  @override
  Future<void> restoreCardNote({required String id}) async {
    final row = _records[id]!;
    _records[id] = _FakeCardRecord(
      id: row.id,
      title: row.title,
      body: row.body,
      deleted: false,
      updatedAtMicros: DateTime.now().microsecondsSinceEpoch,
    );
  }

  @override
  Future<CardDetailData> getCardDetail({required String id}) async {
    final existing = _records[id];
    if (existing == null) {
      throw StateError('missing existing card');
    }
    return CardDetailData(
      id: existing.id,
      title: existing.title,
      body: existing.body,
      deleted: existing.deleted,
    );
  }
}

CardsController _buildTestCardsController() {
  final apiClient = _FakeCardApiClient();
  return CardsController(apiClient: apiClient);
}

({CardsController controller, _FakeCardApiClient apiClient})
_buildInspectableTestCardsController() {
  final apiClient = _FakeCardApiClient();
  return (
    controller: CardsController(apiClient: apiClient),
    apiClient: apiClient,
  );
}

class _FakeCardRecord {
  const _FakeCardRecord({
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

class _MockRustLibApi extends RustLibApi {
  // ignore: unused_field
  final __uuid = const Uuid();

  @override
  Future<void> crateApiClosePoolNetwork({required BigInt networkId}) async {}

  @override
  Future<CardNoteDto> crateApiCreateCardNote({
    required String title,
    required String content,
  }) async {
    return CardNoteDto(
      id: 'seed-id',
      title: title,
      content: content,
      createdAt: 0,
      updatedAt: 0,
      deleted: false,
    );
  }

  @override
  Future<CardNoteDto> crateApiCreateCardNoteInPool({
    required String poolId,
    required String title,
    required String content,
  }) => throw UnimplementedError();

  @override
  Future<PoolDto> crateApiCreatePool({
    required String endpointId,
    required String nickname,
    required String os,
  }) => throw UnimplementedError();

  @override
  Future<String> crateApiUtilsCurrentMemberRoleForEndpoint({
    required Pool pool,
    required String endpointId,
  }) async => 'admin';

  @override
  Future<CardNoteDto> crateApiGetCardNoteDetail({required String cardId}) =>
      throw UnimplementedError();

  @override
  Future<PoolDetailDto> crateApiGetPoolDetail({
    required String poolId,
    required String endpointId,
  }) => throw UnimplementedError();

  @override
  Future<PoolDetailDto> crateApiGetJoinedPoolView({
    required String endpointId,
  }) => throw UnimplementedError();

  @override
  Future<PoolDto> crateApiLeavePool({
    required String poolId,
    required String endpointId,
  }) => throw UnimplementedError();

  @override
  Future<PoolDto> crateApiDissolvePool({
    required String poolId,
    required String endpointId,
  }) => throw UnimplementedError();

  @override
  Future<List<JoinRequestDto>> crateApiSubmitJoinRequest({
    required String poolId,
    required String endpointId,
    required String nickname,
    required String os,
  }) async => const <JoinRequestDto>[];

  @override
  Future<List<JoinRequestDto>> crateApiApproveJoinRequest({
    required String poolId,
    required String requestId,
    required String approverEndpointId,
  }) async => const <JoinRequestDto>[];

  @override
  Future<List<JoinRequestDto>> crateApiRejectJoinRequest({
    required String poolId,
    required String requestId,
    required String approverEndpointId,
  }) async => const <JoinRequestDto>[];

  @override
  Future<List<JoinRequestDto>> crateApiCancelJoinRequest({
    required String poolId,
    required String requestId,
    required String applicantEndpointId,
  }) async => const <JoinRequestDto>[];

  @override
  Future<void> crateApiInitAppConfig({required String appDataDir}) async {}

  @override
  Future<BigInt> crateApiInitPoolNetwork({required String basePath}) =>
      throw UnimplementedError();

  @override
  Future<PoolDto> crateApiJoinPool({
    required String poolId,
    required String endpointId,
    required String nickname,
    required String os,
  }) => throw UnimplementedError();

  @override
  Future<PoolDto> crateApiJoinByCode({
    required String code,
    required String endpointId,
    required String nickname,
    required String os,
  }) => throw UnimplementedError();

  @override
  Future<List<CardNoteDto>> crateApiListCardNotes() async =>
      const <CardNoteDto>[];

  @override
  Future<List<CardNoteDto>> crateApiQueryCardNotes({
    required String query,
    String? poolId,
    bool? includeDeleted,
  }) async => const <CardNoteDto>[];

  @override
  Future<BackendConfigDto> crateApiGetBackendConfig() async {
    return const BackendConfigDto(
      httpEnabled: false,
      mcpEnabled: false,
      cliEnabled: false,
    );
  }

  @override
  Future<RuntimeEntryStatusDto> crateApiGetRuntimeEntryStatus() async {
    return const RuntimeEntryStatusDto(
      httpActive: false,
      mcpActive: false,
      cliActive: false,
      appLockEnabled: false,
      appLockUnlocked: true,
    );
  }

  @override
  Future<(bool, bool)> crateApiAppLockStatus() async => (false, true);

  @override
  Future<void> crateApiSetupAppLock({
    required String pin,
    required bool allowBiometric,
  }) async {}

  @override
  Future<void> crateApiVerifyAppLockWithPin({required String pin}) async {}

  @override
  Future<void> crateApiMarkBiometricSuccess() async {}

  @override
  Future<void> crateApiResetAppLockForTests() async {}

  @override
  Future<BackendConfigDto> crateApiUpdateBackendConfig({
    required bool httpEnabled,
    required bool mcpEnabled,
    required bool cliEnabled,
  }) async {
    return BackendConfigDto(
      httpEnabled: httpEnabled,
      mcpEnabled: mcpEnabled,
      cliEnabled: cliEnabled,
    );
  }

  @override
  Future<CardNoteDto> crateApiDeleteCardNote({required String cardId}) async {
    return CardNoteDto(
      id: cardId,
      title: 'seed-title',
      content: 'seed-content',
      createdAt: 0,
      updatedAt: 0,
      deleted: true,
    );
  }

  @override
  Future<CardNoteDto> crateApiRestoreCardNote({required String cardId}) async {
    return CardNoteDto(
      id: cardId,
      title: 'seed-title',
      content: 'seed-content',
      createdAt: 0,
      updatedAt: 0,
      deleted: false,
    );
  }

  @override
  Future<List<PoolDto>> crateApiListPools({required String endpointId}) async =>
      const <PoolDto>[];

  @override
  Future<ApiError> crateApiUtilsMapErr({required CardMindError err}) async =>
      const ApiError(code: 'INTERNAL', message: 'mock');

  @override
  Future<String> crateApiUtilsMemberRole({required PoolMember member}) async =>
      member.isAdmin ? 'admin' : 'member';

  @override
  Future<UuidValue> crateApiUtilsParseUuid({
    required String raw,
    required String field,
  }) async => UuidValue.fromString(raw);

  @override
  Future<String> crateApiUtilsPoolName({required Pool pool}) async =>
      pool.poolId.toString();

  @override
  Future<void> crateApiResetAppConfigForTests() async {}

  @override
  Future<void> crateApiSyncConnect({
    required BigInt networkId,
    required String target,
  }) => throw UnimplementedError();

  @override
  Future<void> crateApiSyncDisconnect({required BigInt networkId}) =>
      throw UnimplementedError();

  @override
  Future<void> crateApiSyncJoinPool({
    required BigInt networkId,
    required String poolId,
  }) => throw UnimplementedError();

  @override
  Future<SyncResultDto> crateApiSyncPull({required BigInt networkId}) =>
      throw UnimplementedError();

  @override
  Future<SyncResultDto> crateApiSyncPush({required BigInt networkId}) =>
      throw UnimplementedError();

  @override
  Future<SyncStatusDto> crateApiSyncStatus({required BigInt networkId}) =>
      throw UnimplementedError();

  @override
  Future<void> crateApiRecoveryContractContinuityStateAsStr({
    required ContinuityState that,
  }) async {}

  @override
  Future<RecoveryContract> crateApiRecoveryContractLegacyToPhase2Contract({
    required String syncState,
    required String projectionState,
    required bool hasError,
  }) async {
    return RecoveryContract(
      localContentSafety: LocalContentSafety.safe,
      syncState: SubState.ready,
      queryConvergenceState: SubState.ready,
      instanceContinuityState: SubState.ready,
      recoveryStage: RecoveryStage.stable,
      continuityState: ContinuityState.samePath,
      nextAction: NextAction.none,
      allowedOperations: const ['view', 'continue_edit'],
      forbiddenOperations: const [],
    );
  }

  @override
  Future<void> crateApiRecoveryContractLocalContentSafetyAsStr({
    required LocalContentSafety that,
  }) async {}

  @override
  Future<void> crateApiRecoveryContractNextActionAsStr({
    required NextAction that,
  }) async {}

  @override
  Future<void> crateApiRecoveryContractRecoveryStageAsStr({
    required RecoveryStage that,
  }) async {}

  @override
  Future<void> crateApiRecoveryContractSubStateAsStr({
    required SubState that,
  }) async {}

  @override
  Future<void> crateApiRecoveryContractRecoveryContractValidate({
    required RecoveryContract that,
  }) async {}

  @override
  Future<RecoveryContract>
  crateApiRecoveryContractRecoveryContractFromEvidence({
    required String syncState,
    required String queryConvergenceState,
    required String instanceContinuityState,
    required bool hasLocalContentRisk,
  }) async {
    return RecoveryContract(
      localContentSafety: LocalContentSafety.safe,
      syncState: SubState.ready,
      queryConvergenceState: SubState.ready,
      instanceContinuityState: SubState.ready,
      recoveryStage: RecoveryStage.stable,
      continuityState: ContinuityState.samePath,
      nextAction: NextAction.none,
      allowedOperations: const ['view', 'continue_edit'],
      forbiddenOperations: const [],
    );
  }

  @override
  Future<CardNoteDto> crateApiUtilsToCardNoteDto({
    required frb_models.Card card,
  }) async {
    return CardNoteDto(
      id: card.id.toString(),
      title: card.title,
      content: card.content,
      createdAt: card.createdAt,
      updatedAt: card.updatedAt,
      deleted: card.deleted,
    );
  }

  @override
  Future<PoolDetailDto> crateApiUtilsToPoolDetailDto({
    required Pool pool,
    required String endpointId,
  }) async {
    return PoolDetailDto(
      id: pool.poolId.toString(),
      name: pool.poolId.toString(),
      isDissolved: false,
      currentUserRole: 'admin',
      memberCount: BigInt.from(pool.members.length),
      noteIds: pool.cardIds.map((id) => id.toString()).toList(growable: false),
      members: pool.members
          .map(
            (member) => PoolMemberDto(
              endpointId: member.endpointId,
              nickname: member.nickname,
              os: member.os,
              role: member.isAdmin ? 'admin' : 'member',
            ),
          )
          .toList(growable: false),
      joinRequests: const <JoinRequestDto>[],
    );
  }

  @override
  Future<PoolDto> crateApiUtilsToPoolDto({
    required Pool pool,
    required String endpointId,
  }) async {
    return PoolDto(
      id: pool.poolId.toString(),
      name: pool.poolId.toString(),
      isDissolved: false,
      currentUserRole: 'admin',
      memberCount: BigInt.from(pool.members.length),
    );
  }

  @override
  Future<CardNoteDto> crateApiUpdateCardNote({
    required String cardId,
    required String title,
    required String content,
  }) => throw UnimplementedError();
}

bool _mockRustInitialized = false;

void _ensureMockRustLib() {
  if (_mockRustInitialized) {
    return;
  }
  RustLib.initMock(api: _MockRustLibApi());
  _mockRustInitialized = true;
}

void main() {
  testWidgets(
    'cards page production composition should use handle-free FRB client',
    (tester) async {
      _ensureMockRustLib();
      await tester.pumpWidget(const MaterialApp(home: CardsPage()));

      expect(find.byType(CardsPage), findsOneWidget);
    },
  );

  testWidgets(
    'cards page production composition should not create AppDatabase for product query path',
    (tester) async {
      _ensureMockRustLib();

      await tester.pumpWidget(const MaterialApp(home: CardsPage()));

      expect(find.byType(CardsPage), findsOneWidget);
    },
  );

  testWidgets('renders search, list, and create action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CardsPage(controller: _buildTestCardsController())),
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byType(MaterialBanner), findsNothing);
  });

  testWidgets('navigates to editor when tapping create action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CardsPage(controller: _buildTestCardsController())),
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('编辑卡片'), findsOneWidget);
  });

  testWidgets('create-edit-save appears in cards list through read model', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: CardsPage(controller: _buildTestCardsController())),
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(_editorTitleField(), 'Title 1');
    await tester.tap(find.byIcon(Icons.save_outlined));
    await tester.pumpAndSettle();
    await _pumpUntilFound(tester, find.text('Title 1'));

    expect(find.text('编辑卡片'), findsNothing);
    expect(find.text('Title 1'), findsOneWidget);
    expect(find.byType(MaterialBanner), findsNothing);
  });

  testWidgets('delete or restore action changes list state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CardsPage(controller: _buildTestCardsController())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(_editorTitleField(), '待删除卡片');
    await tester.tap(find.byIcon(Icons.save_outlined));
    await tester.pumpAndSettle();
    await _pumpUntilFound(tester, find.text('待删除卡片'));

    expect(find.text('待删除卡片'), findsOneWidget);
    expect(find.text('已删除'), findsNothing);

    await tester.tap(_actionTextForTitle('待删除卡片', '删除'));
    await tester.pumpAndSettle();

    expect(find.text('待删除卡片'), findsNothing);
    expect(find.text('已删除'), findsNothing);
  });

  testWidgets('primary actions remain reachable with long labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: CardsPage(controller: _buildTestCardsController())),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets(
    'search is case-insensitive across title and body for active notes',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CardsPage(controller: _buildTestCardsController())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(_editorTitleField(), 'Alpha KEYWORD');
      await tester.tap(find.byIcon(Icons.save_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(_editorTitleField(), 'Body host');
      await tester.enterText(_editorBodyField(), 'contains KeyWord in body');
      await tester.tap(find.byIcon(Icons.save_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(_editorTitleField(), 'keyword deleted');
      await tester.tap(find.byIcon(Icons.save_outlined));
      await tester.pumpAndSettle();
      await tester.tap(_actionTextForTitle('keyword deleted', '删除'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'keyword');
      await tester.pumpAndSettle();

      expect(find.text('Alpha KEYWORD'), findsOneWidget);
      expect(find.text('Body host'), findsOneWidget);
      expect(find.text('keyword deleted'), findsNothing);
    },
  );

  testWidgets('desktop cards page shows list and editor panes together', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.macOS),
        home: MediaQuery(
          data: MediaQueryData(size: Size(1200, 900)),
          child: CardsPage(controller: _buildTestCardsController()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('搜索卡片'), findsOneWidget);
    expect(find.text('选择卡片或新建卡片'), findsOneWidget);
  });

  testWidgets('macOS uses desktop cards layout even in narrow window', (
    tester,
  ) async {
    final harness = _buildInspectableTestCardsController();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.macOS),
        home: MediaQuery(
          data: const MediaQueryData(size: Size(800, 900)),
          child: CardsPage(controller: harness.controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(_editorTitleField(), 'mac note');
    await tester.enterText(_editorBodyField(), 'mac body');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    await _pumpUntilFound(tester, find.text('mac note'));

    expect(find.text('编辑卡片'), findsOneWidget);

    await tester.tap(find.text('mac note').last);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'mac body'), findsOneWidget);
  });

  testWidgets(
    'desktop dirty editor blocks selecting another card until resolved',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.macOS),
          home: MediaQuery(
            data: MediaQueryData(size: Size(1200, 900)),
            child: CardsPage(controller: _buildTestCardsController()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(_editorTitleField(), 'Desktop Draft');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      await _pumpUntilFound(tester, find.text('Desktop Draft'));

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(_editorTitleField(), 'Unsaved Draft');

      await tester.tap(find.text('Desktop Draft').last);
      await tester.pumpAndSettle();

      expect(find.text('离开编辑？'), findsOneWidget);
      expect(find.text('保存并离开'), findsOneWidget);
      expect(find.text('放弃更改'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);

      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(find.text('Unsaved Draft'), findsOneWidget);
      expect(find.text('离开编辑？'), findsNothing);
    },
  );

  testWidgets(
    'desktop leave guard save branch persists draft before switching note',
    (tester) async {
      final harness = _buildInspectableTestCardsController();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.macOS),
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1200, 900)),
            child: CardsPage(controller: harness.controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(_editorTitleField(), 'Saved First');
      await tester.enterText(_editorBodyField(), 'Saved Body');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      await _pumpUntilFound(tester, find.text('Saved First'));

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(_editorTitleField(), 'Unsaved Draft');
      await tester.enterText(_editorBodyField(), 'Unsaved Body');

      await tester.tap(find.text('Saved First').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存并离开'));
      await tester.pumpAndSettle();

      expect(find.text('离开编辑？'), findsNothing);
      expect(_tileForTitle('Unsaved Draft'), findsOneWidget);
      expect(harness.apiClient.createCalls, greaterThanOrEqualTo(2));
    },
  );

  testWidgets(
    'desktop leave guard discard branch switches selection without saving draft',
    (tester) async {
      final harness = _buildInspectableTestCardsController();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.macOS),
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1200, 900)),
            child: CardsPage(controller: harness.controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(_editorTitleField(), 'Stable Note');
      await tester.enterText(_editorBodyField(), 'Stable Body');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      await _pumpUntilFound(tester, find.text('Stable Note'));

      final createCallsBeforeDraft = harness.apiClient.createCalls;

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(_editorTitleField(), 'Draft To Drop');

      await tester.tap(find.text('Stable Note').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('放弃更改'));
      await tester.pumpAndSettle();

      expect(find.text('离开编辑？'), findsNothing);
      expect(find.widgetWithText(TextField, 'Stable Note'), findsOneWidget);
      expect(harness.apiClient.createCalls, createCallsBeforeDraft);
      expect(_tileForTitle('Draft To Drop'), findsNothing);
    },
  );

  testWidgets(
    'saving an existing selected card should call update not create',
    (tester) async {
      final harness = _buildInspectableTestCardsController();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.macOS),
          home: MediaQuery(
            data: MediaQueryData(size: Size(1200, 900)),
            child: CardsPage(controller: harness.controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(_editorTitleField(), 'Existing Title');
      await tester.enterText(_editorBodyField(), 'Initial Body');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      await _pumpUntilFound(tester, find.text('Existing Title'));

      final createdId = harness.apiClient.lastCreatedId;
      expect(createdId, isNotNull);
      final createCallsAfterFirstSave = harness.apiClient.createCalls;

      await tester.tap(find.text('Existing Title').last);
      await tester.pumpAndSettle();
      await tester.enterText(_editorTitleField(), 'Existing Title Updated');
      await tester.enterText(_editorBodyField(), 'Updated Body');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(harness.apiClient.updateCalls, 1);
      expect(harness.apiClient.lastUpdatedId, createdId);
      expect(harness.apiClient.createCalls, createCallsAfterFirstSave);
      expect(find.byKey(ValueKey('cards.item.$createdId')), findsOneWidget);
      expect(_tileForTitle('Existing Title Updated'), findsOneWidget);
    },
  );

  testWidgets(
    'selecting existing card hydrates body before save and does not wipe content',
    (tester) async {
      final harness = _buildInspectableTestCardsController();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.macOS),
          home: MediaQuery(
            data: MediaQueryData(size: Size(1200, 900)),
            child: CardsPage(controller: harness.controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(_editorTitleField(), 'Body Keep');
      await tester.enterText(_editorBodyField(), 'Original Body');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      await _pumpUntilFound(tester, find.text('Body Keep'));

      await tester.tap(find.text('Body Keep').last);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Original Body'), findsOneWidget);

      await tester.enterText(_editorTitleField(), 'Body Keep Updated');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      final createdId = harness.apiClient.lastCreatedId!;
      final detail = await harness.apiClient.getCardDetail(id: createdId);
      expect(detail.body, 'Original Body');
      expect(detail.title, 'Body Keep Updated');
    },
  );
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxTurns = 250,
}) async {
  for (var i = 0; i < maxTurns; i++) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Finder _editorTitleField() {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == '标题',
  );
}

Finder _editorBodyField() {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == '内容',
  );
}

Finder _tileForTitle(String title) {
  return find.ancestor(of: find.text(title), matching: find.byType(ListTile));
}

Finder _actionTextForTitle(String title, String action) {
  return find.descendant(of: _tileForTitle(title), matching: find.text(action));
}
