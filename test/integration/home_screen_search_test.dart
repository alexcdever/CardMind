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

  void addMockCard(bridge.Card card) {
    _mockCards.add(card);
  }
}

void main() {
  group('HomeScreen Integration Tests - Search Functionality', () {
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

    testWidgets('should display search bar', (WidgetTester tester) async {
      await cardProvider.initialize('/test/path');

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify search bar exists
      expect(find.byType(TextField), findsAtLeastNWidgets(1));
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('should filter notes by title', (WidgetTester tester) async {
      await cardProvider.initialize('/test/path');

      // Create test cards with different titles
      mockCardService.addMockCard(
        bridge.Card(
          id: 'test-1',
          title: 'Flutter Development',
          content: 'Content about Flutter',
          tags: [],
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          deleted: false,
        ),
      );
      mockCardService.addMockCard(
        bridge.Card(
          id: 'test-2',
          title: 'Rust Programming',
          content: 'Content about Rust',
          tags: [],
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          deleted: false,
        ),
      );
      mockCardService.addMockCard(
        bridge.Card(
          id: 'test-3',
          title: 'Flutter UI Design',
          content: 'Content about UI',
          tags: [],
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          deleted: false,
        ),
      );

      await cardProvider.loadCards();
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify all cards are displayed initially
      expect(find.text('Flutter Development'), findsOneWidget);
      expect(find.text('Rust Programming'), findsOneWidget);
      expect(find.text('Flutter UI Design'), findsOneWidget);

      // Enter search query
      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'Flutter');
      await tester.pumpAndSettle();

      // Verify only Flutter cards are displayed
      expect(find.text('Flutter Development'), findsOneWidget);
      expect(find.text('Flutter UI Design'), findsOneWidget);
      expect(find.text('Rust Programming'), findsNothing);
    });

    testWidgets('should filter notes by content', (WidgetTester tester) async {
      await cardProvider.initialize('/test/path');

      // Create test cards with different content
      mockCardService.addMockCard(
        bridge.Card(
          id: 'test-1',
          title: 'Note 1',
          content: 'This is about mobile development',
          tags: [],
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          deleted: false,
        ),
      );
      mockCardService.addMockCard(
        bridge.Card(
          id: 'test-2',
          title: 'Note 2',
          content: 'This is about web development',
          tags: [],
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          deleted: false,
        ),
      );

      await cardProvider.loadCards();
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter search query for content
      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'mobile');
      await tester.pumpAndSettle();

      // Verify only matching card is displayed
      expect(find.text('Note 1'), findsOneWidget);
      expect(find.text('Note 2'), findsNothing);
    });

    testWidgets('should filter notes by tags', (WidgetTester tester) async {
      await cardProvider.initialize('/test/path');

      // Create test cards with different tags
      mockCardService.addMockCard(
        bridge.Card(
          id: 'test-1',
          title: 'Note 1',
          content: 'Content 1',
          tags: ['flutter', 'mobile'],
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          deleted: false,
        ),
      );
      mockCardService.addMockCard(
        bridge.Card(
          id: 'test-2',
          title: 'Note 2',
          content: 'Content 2',
          tags: ['rust', 'backend'],
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          deleted: false,
        ),
      );

      await cardProvider.loadCards();
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter search query for tag
      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'flutter');
      await tester.pumpAndSettle();

      // Verify only matching card is displayed
      expect(find.text('Note 1'), findsOneWidget);
      expect(find.text('Note 2'), findsNothing);
    });

    testWidgets('should be case-insensitive', (WidgetTester tester) async {
      await cardProvider.initialize('/test/path');

      mockCardService.addMockCard(
        bridge.Card(
          id: 'test-1',
          title: 'Flutter Development',
          content: 'Content',
          tags: [],
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          deleted: false,
        ),
      );

      await cardProvider.loadCards();
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Test lowercase search
      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'flutter');
      await tester.pumpAndSettle();
      expect(find.text('Flutter Development'), findsOneWidget);

      // Test uppercase search
      await tester.enterText(searchField, 'FLUTTER');
      await tester.pumpAndSettle();
      expect(find.text('Flutter Development'), findsOneWidget);

      // Test mixed case search
      await tester.enterText(searchField, 'FlUtTeR');
      await tester.pumpAndSettle();
      expect(find.text('Flutter Development'), findsOneWidget);
    });

    testWidgets('should show all notes when search is cleared', (
      WidgetTester tester,
    ) async {
      await cardProvider.initialize('/test/path');

      mockCardService.addMockCard(
        bridge.Card(
          id: 'test-1',
          title: 'Note 1',
          content: 'Content 1',
          tags: [],
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          deleted: false,
        ),
      );
      mockCardService.addMockCard(
        bridge.Card(
          id: 'test-2',
          title: 'Note 2',
          content: 'Content 2',
          tags: [],
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          deleted: false,
        ),
      );

      await cardProvider.loadCards();
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter search query
      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'Note 1');
      await tester.pumpAndSettle();
      // Note 1 appears in both the search field and the card title
      expect(find.text('Note 1'), findsAtLeastNWidgets(1));
      expect(find.text('Note 2'), findsNothing);

      // Clear search
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();

      // Verify all notes are displayed
      // Each note appears in both the search field (if editing) and the card
      expect(find.text('Note 1'), findsAtLeastNWidgets(1));
      expect(find.text('Note 2'), findsAtLeastNWidgets(1));
    });

    testWidgets('should show empty state when no results', (
      WidgetTester tester,
    ) async {
      await cardProvider.initialize('/test/path');

      mockCardService.addMockCard(
        bridge.Card(
          id: 'test-1',
          title: 'Note 1',
          content: 'Content 1',
          tags: [],
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          deleted: false,
        ),
      );

      await cardProvider.loadCards();
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter search query with no matches
      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'nonexistent');
      await tester.pumpAndSettle();

      // Verify no notes are displayed
      expect(find.text('Note 1'), findsNothing);
    });
  });
}
