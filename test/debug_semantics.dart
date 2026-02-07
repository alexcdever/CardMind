// ignore_for_file: avoid_print

import 'package:cardmind/bridge/models/card.dart' as bridge;
import 'package:cardmind/widgets/note_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Debug semantics', (WidgetTester tester) async {
    final testCard = bridge.Card(
      id: 'test-id',
      title: 'Test Title',
      content: 'Test Content',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      deleted: false,
      tags: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteCard(card: testCard, onTap: () {}, onDelete: (_) {}),
        ),
      ),
    );

    // Print all semantics labels
    // Note: debugDescribeSemanticsTree is no longer available in newer Flutter versions
    // Use SemanticsDebugger widget or flutter inspector instead
    print('Semantics tree: Use SemanticsDebugger widget for debugging');

    // Find all semantics widgets
    final semanticsWidgets = find.byType(Semantics).evaluate();
    for (final widget in semanticsWidgets) {
      // Note: debugLabel is no longer available on Element
      print('Semantics widget: ${widget.widget.runtimeType}');
    }
  });
}
