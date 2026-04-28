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

  testWidgets('unselected NoteCard uses vertical padding 0', (tester) async {
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
    expect(container.padding, isNot(const EdgeInsets.all(16)));
  });
}
