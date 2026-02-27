import 'package:cardmind/features/editor/editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows unsaved changes dialog when leaving', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: EditorPage()));

    await tester.enterText(find.byType(TextField).first, 'new title');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('保存并离开'), findsOneWidget);
    expect(find.text('放弃更改'), findsOneWidget);
  });
}
