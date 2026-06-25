import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v2/main.dart';

void main() {
  testWidgets('App renders note list page', (WidgetTester tester) async {
    await tester.pumpWidget(const CardMindApp());

    // Verify the app bar title is shown
    expect(find.text('CardMind'), findsOneWidget);

    // Verify the placeholder text is shown
    expect(find.text('暂无笔记'), findsOneWidget);

    // Verify the FAB is present
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
