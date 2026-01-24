import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:cardmind/screens/home_screen.dart';
import 'package:cardmind/providers/card_provider.dart';
import 'package:cardmind/services/card_service.dart';
import 'package:cardmind/models/sync_status.dart';
import 'package:cardmind/bridge/models/card.dart' as bridge;

/// Mock CardService for testing
class MockCardService extends CardService {
  final List<bridge.Card> _mockCards = [];
  bool _initialized = false;
  bool shouldFailCreate = false;
  bool shouldFailUpdate = false;
  bool shouldFailDelete = false;

  @override
  Future<void> initialize(String storagePath) async {
    _initialized = true;
  }

  @override
  Future<List<bridge.Card>> getActiveCards() async {
    if (!_initialized) {
      throw Exception('CardService not initialized');
    }
    return List.from(_mockCards);
  }

  @override
  Future<bridge.Card> createCard(String title, String content) async {
    if (!_initialized) {
      throw Exception('CardService not initialized');
    }
    if (shouldFailCreate) {
      throw Exception('Failed to create card');
    }
    final card = bridge.Card(
      id: 'test-${_mockCards.length + 1}',
      title: title,
      content: content,
      tags: [],
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      deleted: false,
    );
    _mockCards.add(card);
    return card;
  }

  @override
  Future<void> updateCard(String id, {String? title, String? content}) async {
    if (!_initialized) {
      throw Exception('CardService not initialized');
    }
    if (shouldFailUpdate) {
      throw Exception('Failed to update card');
    }
    final index = _mockCards.indexWhere((c) => c.id == id);
    if (index == -1) {
      throw Exception('Card not found: $id');
    }
    final oldCard = _mockCards[index];
    _mockCards[index] = bridge.Card(
      id: oldCard.id,
      title: title ?? oldCard.title,
      content: content ?? oldCard.content,
      tags: oldCard.tags,
      createdAt: oldCard.createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      deleted: oldCard.deleted,
    );
  }

  @override
  Future<void> deleteCard(String id) async {
    if (!_initialized) {
      throw Exception('CardService not initialized');
    }
    if (shouldFailDelete) {
      throw Exception('Failed to delete card');
    }
    final index = _mockCards.indexWhere((c) => c.id == id);
    if (index == -1) {
      throw Exception('Card not found: $id');
    }
    _mockCards.removeAt(index);
  }
}

void main() {
  group('HomeScreen Integration Tests - Toast Notifications', () {
    late MockCardService mockCardService;
    late CardProvider cardProvider;

    setUp(() {
      mockCardService = MockCardService();
      cardProvider = CardProvider(cardService: mockCardService);
    });

    Widget createTestWidget() {
      return MaterialApp(
        home: ChangeNotifierProvider<CardProvider>.value(
          value: cardProvider,
          child: HomeScreen(
            syncStatusStream: Stream.value(SyncStatus.disconnected()),
          ),
        ),
      );
    }

    testWidgets('should create note successfully', (WidgetTester tester) async {
      await cardProvider.initialize('/test/path');

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap create button (use .first to avoid ambiguity)
      final createButton = find.byIcon(Icons.add).first;
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      // Verify note was created (Toast is shown via ToastUtils.showSuccess)
      expect(cardProvider.cards.length, 1);
      expect(cardProvider.error, isNull);
    });

    testWidgets('should handle create failure', (WidgetTester tester) async {
      await cardProvider.initialize('/test/path');
      mockCardService.shouldFailCreate = true;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap create button (use .first to avoid ambiguity)
      final createButton = find.byIcon(Icons.add).first;
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      // Verify error was handled (Toast is shown via ToastUtils.showError)
      expect(cardProvider.cards.length, 0);
    });

    testWidgets('should update note successfully', (WidgetTester tester) async {
      await cardProvider.initialize('/test/path');
      final card = await cardProvider.createCard('Test Note', 'Content');

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Update the card
      final result = await cardProvider.updateCard(
        card!.id,
        title: 'Updated Title',
      );
      await tester.pumpAndSettle();

      // Verify update was successful (Toast is shown via ToastUtils.showSuccess)
      expect(result, isTrue);
      expect(cardProvider.cards.first.title, 'Updated Title');
      expect(cardProvider.error, isNull);
    });

    testWidgets('should handle update failure', (WidgetTester tester) async {
      await cardProvider.initialize('/test/path');
      final card = await cardProvider.createCard('Test Note', 'Content');
      mockCardService.shouldFailUpdate = true;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Try to update the card
      final result = await cardProvider.updateCard(
        card!.id,
        title: 'Updated Title',
      );
      await tester.pumpAndSettle();

      // Verify error was handled (Toast is shown via ToastUtils.showError)
      expect(result, isFalse);
      expect(cardProvider.cards.first.title, 'Test Note'); // Title unchanged
    });

    testWidgets('should delete note successfully', (WidgetTester tester) async {
      await cardProvider.initialize('/test/path');
      final card = await cardProvider.createCard('Test Note', 'Content');

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Delete the card
      final result = await cardProvider.deleteCard(card!.id);
      await tester.pumpAndSettle();

      // Verify delete was successful (Toast is shown via ToastUtils.showSuccess)
      expect(result, isTrue);
      expect(cardProvider.cards.length, 0);
      expect(cardProvider.error, isNull);
    });

    testWidgets('should handle delete failure', (WidgetTester tester) async {
      await cardProvider.initialize('/test/path');
      final card = await cardProvider.createCard('Test Note', 'Content');
      mockCardService.shouldFailDelete = true;

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Try to delete the card
      final result = await cardProvider.deleteCard(card!.id);
      await tester.pumpAndSettle();

      // Verify error was handled (Toast is shown via ToastUtils.showError)
      expect(result, isFalse);
      expect(cardProvider.cards.length, 1); // Card still exists
    });

    testWidgets('should handle multiple operations in sequence', (
      WidgetTester tester,
    ) async {
      await cardProvider.initialize('/test/path');

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Create a note
      await cardProvider.createCard('Note 1', 'Content 1');
      await tester.pumpAndSettle();
      expect(cardProvider.cards.length, 1);

      // Create another note
      await cardProvider.createCard('Note 2', 'Content 2');
      await tester.pumpAndSettle();
      expect(cardProvider.cards.length, 2);

      // Delete a note
      await cardProvider.deleteCard(cardProvider.cards.first.id);
      await tester.pumpAndSettle();
      expect(cardProvider.cards.length, 1);

      // Verify all operations completed successfully (Toasts shown via ToastUtils)
      expect(cardProvider.error, isNull);
    });

    testWidgets('should complete all operation types successfully', (
      WidgetTester tester,
    ) async {
      await cardProvider.initialize('/test/path');

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Test create
      await cardProvider.createCard('Test', 'Content');
      await tester.pumpAndSettle();
      expect(cardProvider.cards.length, 1);
      expect(cardProvider.error, isNull);

      // Test update
      final updateResult = await cardProvider.updateCard(
        cardProvider.cards.first.id,
        title: 'Updated',
      );
      await tester.pumpAndSettle();
      expect(updateResult, isTrue);
      expect(cardProvider.cards.first.title, 'Updated');
      expect(cardProvider.error, isNull);

      // Test delete
      final deleteResult = await cardProvider.deleteCard(
        cardProvider.cards.first.id,
      );
      await tester.pumpAndSettle();
      expect(deleteResult, isTrue);
      expect(cardProvider.cards.length, 0);
      expect(cardProvider.error, isNull);
    });
  });
}
