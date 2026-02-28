// input: 在 CardsPage 执行新增、保存、删除与恢复等用户操作。
// output: 编辑页导航、保存反馈与列表状态按预期变化。
// pos: 覆盖卡片页核心 CRUD 交互路径，防止主流程回归。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/features/cards/cards_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders search, list, and create action', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CardsPage()));

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('navigates to editor when tapping create action', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CardsPage()));

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('编辑卡片'), findsOneWidget);
  });

  testWidgets('create-edit-save appears in cards list through read model', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CardsPage()));

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Title 1');
    await tester.tap(find.byIcon(Icons.save_outlined));
    await tester.pumpAndSettle();

    expect(find.text('编辑卡片'), findsNothing);
    expect(find.text('Title 1'), findsOneWidget);
  });

  testWidgets('delete or restore action changes list state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CardsPage()));
    await tester.pumpAndSettle();

    expect(find.text('示例卡片A'), findsOneWidget);
    expect(find.text('已删除'), findsNothing);

    await tester.tap(find.text('删除'));
    await tester.pump();

    expect(find.text('已删除'), findsOneWidget);
    expect(find.text('恢复'), findsOneWidget);

    await tester.tap(find.text('恢复'));
    await tester.pump();

    expect(find.text('已删除'), findsNothing);
    expect(find.text('删除'), findsOneWidget);
  });
}
