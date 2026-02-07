import 'package:cardmind/widgets/note_editor_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('it_should_render_desktop_card_editor', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NoteEditorDialog(
          currentDevice: 'desktop-device',
          onSave: (_) {},
          onCancel: () {},
        ),
      ),
    );

    expect(find.text('保存'), findsOneWidget);
  });
}
