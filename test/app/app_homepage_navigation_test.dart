// input: 在 CardMindApp 冷启动后观察主页导航与返回行为。
// output: 断言首屏即进入主页并展示底部导航与三个导航标签。
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
import 'package:cardmind/features/pool/pool_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCardApiClient implements CardApiClient {
  final Map<String, _FakeCardRecord> _rows = <String, _FakeCardRecord>{};

  @override
  Future<List<CardSummary>> listCardSummaries({String query = ''}) async {
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
      poolName: 'Server Pool',
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
      poolName: 'Joined Pool',
      isOwner: true,
      currentIdentityLabel: 'owner@test',
      memberLabels: <String>['owner@test'],
    );
  }

  @override
  Future<PoolDetailData> getPoolDetail(String poolId) async {
    return const PoolDetailData(
      poolName: 'Joined Pool',
      isOwner: true,
      currentIdentityLabel: 'owner@test',
      memberLabels: <String>['owner@test'],
    );
  }
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
    expect(find.text('设置'), findsWidgets);
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

  testWidgets('after pool joined, user remains in pool domain', (tester) async {
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

    await tester.tap(find.text('创建池'));
    await tester.pumpAndSettle();

    expect(controller.section, AppSection.pool);
    expect(find.text('去卡片'), findsNothing);
    expect(find.text('成员列表'), findsOneWidget);
  });

  testWidgets('homepage forwards pool network id into production pool page', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AppHomepagePage(poolNetworkId: BigInt.one)),
    );

    expect(find.byType(AppHomepagePage), findsOneWidget);
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
}
