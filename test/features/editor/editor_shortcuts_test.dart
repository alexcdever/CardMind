import 'package:cardmind/features/editor/editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('saves with cmd/ctrl+s shortcut', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: EditorPage()));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();

    expect(find.text('本地已保存'), findsOneWidget);
  });
}
