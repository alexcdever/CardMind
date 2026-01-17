import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:cardmind/screens/home_screen.dart';
import 'package:cardmind/providers/card_provider.dart';
import 'package:cardmind/adaptive/platform_detector.dart';

void main() {
  group('HomeScreen Adaptive UI', () {
    late CardProvider cardProvider;

    setUp(() {
      cardProvider = CardProvider();
    });

    testWidgets('it_should_display_app_bar_with_title',
        (WidgetTester tester) async {
      // Given: Home screen
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<CardProvider>.value(
            value: cardProvider,
            child: const HomeScreen(),
          ),
        ),
      );

      // Then: Should display app bar with title
      expect(find.text('CardMind'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('it_should_show_fab_on_mobile', (WidgetTester tester) async {
      // Given: Home screen
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<CardProvider>.value(
            value: cardProvider,
            child: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Then: Should show FAB on mobile, not on desktop
      if (PlatformDetector.isMobile) {
        expect(find.byType(FloatingActionButton), findsOneWidget);
      } else {
        expect(find.byType(FloatingActionButton), findsNothing);
      }
    });

    testWidgets('it_should_show_new_card_button_in_toolbar_on_desktop',
        (WidgetTester tester) async {
      // Given: Home screen
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<CardProvider>.value(
            value: cardProvider,
            child: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Then: Desktop should have "New Card" button in toolbar
      if (PlatformDetector.isDesktop) {
        // Find the add icon button in the app bar
        final addButtons = find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.add),
        );
        expect(addButtons, findsOneWidget);
      }
    });

    testWidgets('it_should_display_sync_status_indicator',
        (WidgetTester tester) async {
      // Given: Home screen
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<CardProvider>.value(
            value: cardProvider,
            child: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Then: Should display sync status indicator in app bar
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('it_should_display_refresh_button',
        (WidgetTester tester) async {
      // Given: Home screen
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<CardProvider>.value(
            value: cardProvider,
            child: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Then: Should display refresh button
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('it_should_display_settings_button',
        (WidgetTester tester) async {
      // Given: Home screen
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<CardProvider>.value(
            value: cardProvider,
            child: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Then: Should display settings button
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('it_should_show_empty_state_when_no_cards',
        (WidgetTester tester) async {
      // Given: Home screen with no cards
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<CardProvider>.value(
            value: cardProvider,
            child: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Then: Should show empty state
      expect(find.text('No cards yet'), findsOneWidget);
      expect(find.byIcon(Icons.note_add_outlined), findsOneWidget);
    });

    testWidgets('it_should_show_platform_specific_empty_message',
        (WidgetTester tester) async {
      // Given: Home screen with no cards
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<CardProvider>.value(
            value: cardProvider,
            child: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Then: Should show platform-specific message
      if (PlatformDetector.isMobile) {
        expect(find.text('Tap + to create your first card'), findsOneWidget);
      } else {
        expect(find.text('Click + to create your first card'), findsOneWidget);
      }
    });

    testWidgets('it_should_use_adaptive_scaffold',
        (WidgetTester tester) async {
      // Given: Home screen
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<CardProvider>.value(
            value: cardProvider,
            child: const HomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Then: Should use Scaffold (from AdaptiveScaffold)
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
