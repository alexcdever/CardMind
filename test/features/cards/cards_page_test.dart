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
}
