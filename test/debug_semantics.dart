import 'package:cardmind/widgets/note_card.dart';
import 'package:cardmind/bridge/models/card.dart' as bridge;
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
    final renderObject = tester.binding.pipelineOwner!.semanticsOwner!;
    final semantics = renderObject.debugDescribeSemanticsTree(
      includeChildIds: true,
    );
    print('Semantics tree:');
    print(semantics);

    // Find all semantics widgets
    final semanticsWidgets = find.byType(Semantics).evaluate();
    for (final widget in semanticsWidgets) {
      print('Semantics widget: ${widget.debugLabel}');
    }
  });
}
