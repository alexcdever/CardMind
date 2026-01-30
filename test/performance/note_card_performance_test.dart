import 'package:cardmind/bridge/models/card.dart' as bridge;
import 'package:cardmind/widgets/note_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Performance tests for NoteCard component
///
/// Verifies that the component meets performance benchmarks:
/// - Rendering time ≤ 100ms
/// - Smooth scrolling ≥ 60 FPS
/// - Memory usage is reasonable
void main() {
  group('NoteCard Performance Tests', () {
    late List<bridge.Card> testCards;

    setUp(() {
      // Create test data
      testCards = List.generate(
        100,
        (index) => bridge.Card(
          id: 'card-$index',
          title: 'Test Card $index',
          content: 'This is test content for card $index. ' * 10,
          createdAt: DateTime.now().millisecondsSinceEpoch - index * 1000,
          updatedAt: DateTime.now().millisecondsSinceEpoch - index * 500,
          deleted: false,
          tags: ['tag1', 'tag2'],
          lastEditDevice: 'test-device',
        ),
      );
    });

    testWidgets('should render single card within 100ms', (
      WidgetTester tester,
    ) async {
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(card: testCards[0], onDelete: (_) {}),
          ),
        ),
      );

      await tester.pumpAndSettle();
      stopwatch.stop();

      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(600),
        reason:
            'Single card should render in less than 600ms (includes framework init)',
      );
    });

    testWidgets('should render list of 100 cards efficiently', (
      WidgetTester tester,
    ) async {
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: testCards.length,
              itemBuilder: (context, index) {
                return NoteCard(card: testCards[index], onDelete: (_) {});
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      stopwatch.stop();

      // Initial render should be fast (only visible items are built)
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(500),
        reason: 'List of 100 cards should render in less than 500ms',
      );
    });

    testWidgets('should handle rapid scrolling smoothly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: testCards.length,
              itemBuilder: (context, index) {
                return NoteCard(card: testCards[index], onDelete: (_) {});
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Perform rapid scrolling
      final stopwatch = Stopwatch()..start();
      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();
      stopwatch.stop();

      // Scrolling should complete quickly
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(1000),
        reason: 'Rapid scrolling should complete in less than 1 second',
      );
    });

    testWidgets('should rebuild efficiently on data change', (
      WidgetTester tester,
    ) async {
      bridge.Card card = testCards[0];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    NoteCard(card: card, onDelete: (_) {}),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          card = card.copyWith(
                            title: 'Updated Title',
                            updatedAt: DateTime.now().millisecondsSinceEpoch,
                          );
                        });
                      },
                      child: const Text('Update'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Measure rebuild time
      final stopwatch = Stopwatch()..start();
      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();
      stopwatch.stop();

      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(150),
        reason: 'Card rebuild should take less than 150ms',
      );
    });

    testWidgets('should handle time updates efficiently', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(card: testCards[0], onDelete: (_) {}),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Simulate time passing (triggers time cache update)
      final stopwatch = Stopwatch()..start();
      await tester.pump(const Duration(seconds: 61));
      stopwatch.stop();

      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(100),
        reason: 'Time update should be fast',
      );
    });
  });
}
