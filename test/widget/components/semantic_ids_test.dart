// input: 渲染 cards/editor 首批关键交互界面。
// output: 断言关键控件暴露稳定语义标识，供系统自动化与 widget test 共同使用。
// pos: 覆盖 UI 自动化语义标识契约，防止关键控件丢失可访问性锚点。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/features/cards/cards_page.dart';
import 'package:cardmind/features/editor/editor_page.dart';
import 'package:cardmind/features/pool/pool_page.dart';
import 'package:cardmind/features/pool/pool_state.dart';
import 'package:cardmind/features/settings/settings_page.dart';
import 'package:cardmind/app/layout/adaptive_homepage_scaffold.dart';
import 'package:cardmind/app/navigation/app_section.dart';
import '../../support/test_page_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('cards page exposes stable semantics for core actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: CardsPage(controller: buildTestCardsController())),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('搜索卡片'), findsWidgets);
    expect(find.bySemanticsLabel('新建卡片'), findsWidgets);
    expect(find.bySemanticsLabel('卡片列表'), findsWidgets);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets(
    'editor page exposes stable semantics for core fields and actions',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: EditorPage()));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('标题输入框'), findsWidgets);
      expect(find.bySemanticsLabel('内容输入框'), findsWidgets);
      expect(find.bySemanticsLabel('保存卡片'), findsWidgets);
    },
  );

  testWidgets('pool page exposes stable semantics for primary actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PoolPage(
          state: const PoolState.notJoined(),
          controller: buildTestPoolController(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('创建池'), findsWidgets);
    expect(find.bySemanticsLabel('扫码加入'), findsWidgets);
    expect(find.byKey(const ValueKey('pool.create_button')), findsOneWidget);
    expect(find.byKey(const ValueKey('pool.join_scan_button')), findsOneWidget);
  });

  testWidgets(
    'joined pool page exposes stable semantics for management actions',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PoolPage(
            state: PoolState.joinedWithPending(),
            controller: buildTestPoolController(
              initialState: PoolState.joinedWithPending(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('编辑池信息'), findsWidgets);
      expect(find.bySemanticsLabel('解散池'), findsWidgets);
      expect(find.bySemanticsLabel('退出池'), findsWidgets);
      expect(find.bySemanticsLabel('通过审批'), findsWidgets);
      expect(find.bySemanticsLabel('拒绝审批'), findsWidgets);
      expect(find.byKey(const ValueKey('pool.edit_button')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('pool.dissolve_button')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('pool.leave_button')), findsOneWidget);
    },
  );

  testWidgets('pool leave dialog exposes stable semantics and keys', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PoolPage(
          state: const PoolState.joined(),
          controller: buildTestPoolController(
            initialState: const PoolState.joined(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('pool.leave_button')));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('确认退出数据池'), findsWidgets);
    expect(
      find.byKey(const ValueKey('pool.leave_dialog.confirm')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('pool.leave_dialog.cancel')));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'pool dialogs and sync actions expose stable identifiers and keys',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PoolPage(
            state: const PoolState.notJoined(),
            controller: buildTestPoolController(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('pool.join_scan_button')));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('加入码输入框'), findsWidgets);
      expect(find.bySemanticsLabel('确认加入数据池'), findsWidgets);
      expect(find.bySemanticsLabel('取消加入数据池'), findsWidgets);
      expect(
        find.byKey(const ValueKey('pool.join_dialog.code_input')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('pool.join_dialog.confirm')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('pool.join_dialog.cancel')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('pool.join_dialog.code_input')),
        'test-pool-code',
      );
      await tester.tap(find.byKey(const ValueKey('pool.join_dialog.confirm')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('pool.edit_button')));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('池名称输入框'), findsWidgets);
      expect(
        find.byKey(const ValueKey('pool.edit_dialog.name_input')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('pool.edit_dialog.save')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('pool.edit_dialog.cancel')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('pool.edit_dialog.cancel')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('pool.dissolve_button')));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('确认解散数据池'), findsWidgets);
      expect(
        find.byKey(const ValueKey('pool.dissolve_dialog.confirm')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('pool.dissolve_dialog.cancel')),
        findsOneWidget,
      );
    },
  );

  testWidgets('editor leave dialog exposes stable identifiers and keys', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: EditorPage()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('editor.title_input')),
      'draft',
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('保存并离开'), findsWidgets);
    expect(find.bySemanticsLabel('放弃更改'), findsWidgets);
    expect(find.bySemanticsLabel('取消'), findsWidgets);
    expect(
      find.byKey(const ValueKey('editor.leave_dialog.save')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('editor.leave_dialog.discard')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('editor.leave_dialog.cancel')),
      findsOneWidget,
    );
  });

  testWidgets('desktop cards page exposes stable semantics for editor fields', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.macOS),
        home: MediaQuery(
          data: MediaQueryData(size: Size(1200, 900)),
          child: CardsPage(controller: buildTestCardsController()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('cards.create_fab')));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('桌面编辑标题输入框'), findsWidgets);
    expect(find.bySemanticsLabel('桌面编辑内容输入框'), findsWidgets);
    expect(find.bySemanticsLabel('保存桌面编辑卡片'), findsWidgets);
    expect(
      find.byKey(const ValueKey('cards.desktop_editor.title_input')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('cards.desktop_editor.body_input')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('cards.desktop_editor.save_button')),
      findsOneWidget,
    );
  });

  testWidgets(
    'settings page and public navigation expose stable identifiers and keys',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(390, 844)),
            child: AdaptiveHomepageScaffold(
              section: AppSection.cards,
              onSectionChanged: (_) {},
              child: const SettingsPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('设置页'), findsWidgets);
      expect(find.byKey(const ValueKey('settings.page')), findsOneWidget);
      expect(find.bySemanticsLabel('卡片导航'), findsWidgets);
      expect(find.bySemanticsLabel('数据池导航'), findsWidgets);
      expect(find.bySemanticsLabel('设置导航'), findsNothing);
      expect(find.byKey(const ValueKey('nav.cards')), findsOneWidget);
      expect(find.byKey(const ValueKey('nav.pool')), findsOneWidget);
      expect(find.byKey(const ValueKey('nav.settings')), findsNothing);
    },
  );
}
