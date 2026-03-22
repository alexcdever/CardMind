// input: 使用稳定 semantics 与 ValueKey 驱动 cards/pool 关键主流程操作。
// output: 验证自动化锚点足以支撑创建卡片、删除恢复、创建池与退出确认等交互回归。
// pos: 覆盖基于自动化锚点的 Flutter 主流程回归测试。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/features/cards/cards_page.dart';
import 'package:cardmind/features/pool/pool_page.dart';
import 'package:cardmind/features/pool/pool_state.dart';
import 'package:cardmind/app/layout/adaptive_homepage_scaffold.dart';
import 'package:cardmind/app/navigation/app_section.dart';
import '../../support/test_page_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'cards automation anchors support create and delete restore flow',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: CardsPage(controller: buildTestCardsController())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('cards.create_fab')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('editor.title_input')),
        'Automation Card',
      );
      await tester.tap(find.byKey(const ValueKey('editor.save_button')));
      await tester.pumpAndSettle();

      expect(find.text('Automation Card'), findsOneWidget);

      final tile = find.ancestor(
        of: find.text('Automation Card'),
        matching: find.byType(ListTile),
      );
      final deleteButton = find.descendant(
        of: tile,
        matching: find.byType(TextButton),
      );
      expect(deleteButton, findsOneWidget);
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      expect(find.text('Automation Card'), findsNothing);
      expect(find.text('已删除'), findsNothing);
    },
  );

  testWidgets(
    'pool automation anchors support create and leave confirmation flow',
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

      await tester.tap(find.byKey(const ValueKey('pool.create_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('pool.leave_button')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('pool.leave_button')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('pool.leave_dialog.confirm')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('pool.leave_dialog.cancel')));
      await tester.pumpAndSettle();

      expect(find.text('成员列表'), findsOneWidget);
    },
  );

  testWidgets('pool automation anchors support scan and edit dialog flow', (
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

    await tester.tap(find.byKey(const ValueKey('pool.join_scan_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pool.scan_dialog.success')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('pool.edit_button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('pool.edit_dialog.name_input')),
      'Edited Pool Name',
    );
    await tester.tap(find.byKey(const ValueKey('pool.edit_dialog.save')));
    await tester.pumpAndSettle();

    expect(find.text('Edited Pool Name'), findsOneWidget);
  });

  testWidgets('editor automation anchors support leave dialog flow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: CardsPage(controller: buildTestCardsController())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('cards.create_fab')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('editor.title_input')),
      'Unsaved automation draft',
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

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

  testWidgets(
    'navigation automation anchors support cards and pool switching',
    (tester) async {
      AppSection current = AppSection.cards;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return MediaQuery(
                data: const MediaQueryData(size: Size(390, 844)),
                child: AdaptiveHomepageScaffold(
                  section: current,
                  onSectionChanged: (section) {
                    setState(() {
                      current = section;
                    });
                  },
                  child: switch (current) {
                    AppSection.cards => const Center(
                      child: Text('cards-marker'),
                    ),
                    AppSection.pool => const Center(child: Text('pool-marker')),
                  },
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('nav.pool')));
      await tester.pumpAndSettle();
      expect(find.text('pool-marker'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('nav.cards')));
      await tester.pumpAndSettle();
      expect(find.text('cards-marker'), findsOneWidget);
    },
  );
}
