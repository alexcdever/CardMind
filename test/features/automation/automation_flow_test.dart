// input: 使用稳定 semantics 与 ValueKey 驱动 cards/pool 关键主流程操作。
// output: 验证自动化锚点足以支撑创建卡片、删除恢复、创建池与退出确认等交互回归。
// pos: 覆盖基于自动化锚点的 Flutter 主流程回归测试。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/features/cards/cards_page.dart';
import 'package:cardmind/features/pool/pool_page.dart';
import 'package:cardmind/features/pool/pool_state.dart';
import 'package:cardmind/features/shared/testing/semantic_ids.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'cards automation anchors support create and delete restore flow',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: CardsPage()));
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

      expect(find.text('已删除'), findsOneWidget);

      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      expect(find.text('已删除'), findsNothing);
    },
  );

  testWidgets(
    'pool automation anchors support create and leave confirmation flow',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PoolPage(state: PoolState.notJoined())),
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
}
