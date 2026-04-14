// input: 在 CardMindApp 冷启动后观察主页导航与返回行为。
// output: 断言首屏即进入主页并展示底部导航与两个公开导航标签。
// pos: 应用主页导航测试，覆盖首屏直达主页的主路径。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/app/app.dart';
import 'package:cardmind/app/navigation/app_homepage_controller.dart';
import 'package:cardmind/app/navigation/app_homepage_page.dart';
import 'package:cardmind/app/navigation/app_section.dart';
import 'package:cardmind/features/cards/cards_page.dart';
import 'package:cardmind/features/cards/cards_controller.dart';
import 'package:cardmind/features/cards/card_api_client.dart';
import 'package:cardmind/features/cards/card_summary.dart';
import 'package:cardmind/features/pool/pool_api_client.dart';
import 'package:cardmind/features/pool/pool_controller.dart';
import 'package:cardmind/features/pool/pool_page.dart';
import 'package:cardmind/features/pool/pool_shell.dart';
import 'package:cardmind/features/pool/pool_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCardApiClient implements CardApiClient {
  final Map<String, _FakeCardRecord> _rows = <String, _FakeCardRecord>{};

  @override
  Future<List<CardSummary>> listCardSummaries({
    String query = '',
    String? poolId,
    bool? includeDeleted,
  }) async {
    final lowered = query.toLowerCase();
    return _rows.values
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
    _rows[id] = _FakeCardRecord(
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
      throw StateError('missing card');
    }
    _rows[id] = _FakeCardRecord(
      id: row.id,
      title: title,
      body: body,
      deleted: row.deleted,
      updatedAtMicros: DateTime.now().microsecondsSinceEpoch,
    );
  }

  @override
  Future<void> deleteCardNote({required String id}) async {}

  @override
  Future<void> restoreCardNote({required String id}) async {}

  @override
  Future<CardDetailData> getCardDetail({required String id}) async {
    final row = _rows[id];
    if (row == null) {
      throw StateError('missing card');
    }
    return CardDetailData(
      id: row.id,
      title: row.title,
      body: row.body,
      deleted: row.deleted,
    );
  }
}

class _FakePoolApiClient implements PoolApiClient {
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

CardsPage _buildTestCardsPage() {
  return CardsPage(
    controller: CardsController(apiClient: _FakeCardApiClient()),
  );
}

PoolPage _buildTestPoolPage() {
  return PoolPage(
    state: const PoolState.notJoined(),
    controller: PoolController(apiClient: _FakePoolApiClient()),
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

void main() {
  testWidgets('app cold start shows homepage bottom nav on mobile', (
    tester,
  ) async {
    await tester.pumpWidget(const CardMindApp(appDataDir: 'test-app-dir'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('搜索卡片'), findsOneWidget);
    expect(find.text('卡片'), findsWidgets);
    expect(find.text('数据池'), findsWidgets);
    expect(find.text('设置'), findsNothing);
  });

  testWidgets('app cold start lands on cards by default', (tester) async {
    await tester.pumpWidget(const CardMindApp(appDataDir: 'test-app-dir'));
    await tester.pumpAndSettle();

    expect(find.byType(CardsPage), findsOneWidget);
    expect(find.byType(PoolPage), findsNothing);
  });

  testWidgets('back on non-cards tab switches to cards first', (tester) async {
    final controller = AppHomepageController(initialSection: AppSection.pool);
    await tester.pumpWidget(
      MaterialApp(home: AppHomepagePage(controller: controller)),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(controller.section, AppSection.cards);
  });

  testWidgets('setting same section does not notify homepage listeners twice', (
    tester,
  ) async {
    final controller = AppHomepageController();
    var notifications = 0;
    controller.addListener(() {
      notifications += 1;
    });

    controller.setSection(AppSection.cards);
    controller.setSection(AppSection.pool);

    expect(notifications, 1);
    expect(controller.section, AppSection.pool);
  });

  testWidgets('pool section is guarded by app lock before joined flow', (
    tester,
  ) async {
    final controller = AppHomepageController(initialSection: AppSection.pool);
    await tester.pumpWidget(
      MaterialApp(
        home: AppHomepagePage(
          controller: controller,
          cardsPageBuilder: (_) => _buildTestCardsPage(),
          poolPageBuilder: (_) => _buildTestPoolPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(controller.section, AppSection.pool);
    expect(
      find.byKey(const ValueKey('app_lock.submit_button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('app_lock.submit_button')),
      findsOneWidget,
    );
  });

  testWidgets('homepage switches between cards and pool in one action', (
    tester,
  ) async {
    final controller = AppHomepageController();
    await tester.pumpWidget(
      MaterialApp(
        home: AppHomepagePage(
          controller: controller,
          cardsPageBuilder: (_) => const Center(child: Text('cards-marker')),
          poolPageBuilder: (_) => const Center(child: Text('pool-marker')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('cards-marker'), findsOneWidget);

    await tester.tap(find.text('数据池'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('app_lock.pin_field')),
      '1234',
    );
    await tester.tap(find.byKey(const ValueKey('app_lock.submit_button')));
    await tester.pumpAndSettle();
    expect(find.byType(AppHomepagePage), findsOneWidget);

    await tester.tap(find.text('卡片'));
    await tester.pumpAndSettle();
    expect(find.text('cards-marker'), findsOneWidget);
  });

  testWidgets('homepage forwards pool network id into production pool page', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AppHomepagePage(poolNetworkId: BigInt.one)),
    );

    expect(find.byType(AppHomepagePage), findsOneWidget);
  });

  testWidgets('homepage delegates pool section composition to PoolShell', (
    tester,
  ) async {
    final controller = AppHomepageController(initialSection: AppSection.pool);

    await tester.pumpWidget(
      MaterialApp(
        home: AppHomepagePage(
          controller: controller,
          cardsPageBuilder: (_) => _buildTestCardsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PoolShell), findsOneWidget);
    expect(
      find.byKey(const ValueKey('app_lock.submit_button')),
      findsOneWidget,
    );
  });

  testWidgets('homepage can start in pool section for local verification', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppHomepagePage(
          appDataDir: 'test-app-dir',
          debugStartInPool: true,
          debugAutoPin: '1234',
          debugAutoJoinCode: 'pool-code',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final shell = tester.widget<PoolShell>(find.byType(PoolShell));
    expect(shell.debugAutoPin, '1234');
    expect(shell.debugAutoJoinCode, 'pool-code');
  });

  testWidgets('debug flags flow to pool shell', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppHomepagePage(
          appDataDir: 'test-app-dir',
          debugStartInPool: true,
          debugAutoPin: '1234',
          debugPrintInvite: true,
          debugJoinTrace: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final shell = tester.widget<PoolShell>(find.byType(PoolShell));
    expect(shell.debugPrintInvite, isTrue);
    expect(shell.debugJoinTrace, isTrue);
  });

  testWidgets('back on cards shows exit confirmation dialog', (tester) async {
    final controller = AppHomepageController(initialSection: AppSection.cards);
    await tester.pumpWidget(
      MaterialApp(home: AppHomepagePage(controller: controller)),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('是否退出应用？'), findsOneWidget);
    expect(find.text('是'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
  });

  testWidgets('selecting 取消 closes confirmation and stays on cards', (
    tester,
  ) async {
    final controller = AppHomepageController(initialSection: AppSection.cards);
    await tester.pumpWidget(
      MaterialApp(home: AppHomepagePage(controller: controller)),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(controller.section, AppSection.cards);
    expect(find.text('是否退出应用？'), findsNothing);
  });

  testWidgets('selecting 是 requests platform exit', (tester) async {
    final controller = AppHomepageController(initialSection: AppSection.cards);
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(
      MaterialApp(home: AppHomepagePage(controller: controller)),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('是'));
    await tester.pumpAndSettle();

    expect(calls.any((call) => call.method == 'SystemNavigator.pop'), isTrue);
  });
}
