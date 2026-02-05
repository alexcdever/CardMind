import 'package:cardmind/screens/card_editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('it_should_render_card_editor_screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: CardEditorScreen()),
    );

    expect(find.byKey(const Key('title_field')), findsOneWidget);
  });
}
