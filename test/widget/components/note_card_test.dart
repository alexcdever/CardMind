import 'package:cardmind/app/theme/cardmind_colors.dart';
import 'package:cardmind/features/shared/widgets/note_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selected NoteCard uses padding 16', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NoteCard(
          tag: '已同步',
          title: 'Test Title',
          body: 'Test Body',
          selected: true,
        ),
      ),
    );

    final container = tester.widget<Container>(
      find.byKey(const ValueKey('note_card.container')),
    );
    expect(container.padding, const EdgeInsets.all(16));
  });

  testWidgets(
    'unselected NoteCard uses canvas background without selection border',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: NoteCard(
            tag: '本地优先',
            title: 'Test Title',
            body: 'Test Body',
            selected: false,
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.byKey(const ValueKey('note_card.container')),
      );
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, CardMindColors.bgCanvas);
      expect(decoration.border, isNull);
    },
  );
}
