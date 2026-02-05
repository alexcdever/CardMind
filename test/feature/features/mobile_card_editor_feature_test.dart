import 'package:cardmind/widgets/note_editor_fullscreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('it_should_render_mobile_card_editor', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NoteEditorFullscreen(
          currentDevice: 'mobile-device',
          isOpen: true,
          onClose: () {},
          onSave: (_) {},
        ),
      ),
    );

    expect(find.text('完成'), findsOneWidget);
  });
}
