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

  testWidgets('create note opens editor and save feedback is visible', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CardsPage()));

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'new note');
    await tester.tap(find.byIcon(Icons.save_outlined));
    await tester.pump();

    expect(find.text('本地已保存'), findsOneWidget);
  });

  testWidgets('delete or restore action changes list state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CardsPage()));

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
