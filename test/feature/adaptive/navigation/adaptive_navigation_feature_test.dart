import 'package:cardmind/adaptive/navigation/adaptive_navigation.dart';
import 'package:cardmind/adaptive/platform_detector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdaptiveNavigation', () {
    final destinations = [
      AdaptiveNavigationDestination(
        icon: Icons.home,
        label: 'Home',
        builder: (context) => const Center(child: Text('Home Page')),
      ),
      AdaptiveNavigationDestination(
        icon: Icons.sync,
        label: 'Sync',
        builder: (context) => const Center(child: Text('Sync Page')),
      ),
      AdaptiveNavigationDestination(
        icon: Icons.settings,
        label: 'Settings',
        builder: (context) => const Center(child: Text('Settings Page')),
      ),
    ];

    testWidgets('it_should_display_current_page', (WidgetTester tester) async {
      // Given: Adaptive navigation with 3 destinations
      const int currentIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveNavigation(
            destinations: destinations,
            currentIndex: currentIndex,
            onDestinationSelected: (index) {},
          ),
        ),
      );

      // Then: Should display the current page
      expect(find.text('Home Page'), findsOneWidget);
      expect(find.text('Sync Page'), findsNothing);
      expect(find.text('Settings Page'), findsNothing);
    });

    testWidgets('it_should_show_navigation_items', (WidgetTester tester) async {
      // Given: Adaptive navigation
      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveNavigation(
            destinations: destinations,
            currentIndex: 0,
            onDestinationSelected: (index) {},
          ),
        ),
      );

      // Then: Should show navigation items
      if (PlatformDetector.isMobile) {
        // Mobile: BottomNavigationBar
        expect(find.byType(BottomNavigationBar), findsOneWidget);
        expect(find.byType(NavigationRail), findsNothing);
      } else {
        // Desktop: NavigationRail
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.byType(BottomNavigationBar), findsNothing);
      }
    });

    testWidgets('it_should_call_callback_on_destination_selected', (
      WidgetTester tester,
    ) async {
      // Given: Adaptive navigation with callback
      int? selectedIndex;

      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveNavigation(
            destinations: destinations,
            currentIndex: 0,
            onDestinationSelected: (index) {
              selectedIndex = index;
            },
          ),
        ),
      );

      // When: Tapping on a navigation item
      if (PlatformDetector.isMobile) {
        // Mobile: tap on bottom navigation
        await tester.tap(find.text('Sync'));
      } else {
        // Desktop: tap on navigation rail
        await tester.tap(find.text('Sync'));
      }
      await tester.pump();

      // Then: Callback should be called with correct index
      expect(selectedIndex, equals(1));
    });

    testWidgets('it_should_highlight_selected_destination', (
      WidgetTester tester,
    ) async {
      // Given: Adaptive navigation with second item selected
      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveNavigation(
            destinations: destinations,
            currentIndex: 1,
            onDestinationSelected: (index) {},
          ),
        ),
      );

      // Then: Should display the selected page
      expect(find.text('Sync Page'), findsOneWidget);
      expect(find.text('Home Page'), findsNothing);
    });

    testWidgets('it_should_switch_pages_when_index_changes', (
      WidgetTester tester,
    ) async {
      // Given: Navigation with different index
      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveNavigation(
            destinations: destinations,
            currentIndex: 0,
            onDestinationSelected: (index) {},
          ),
        ),
      );

      // Initially showing home page
      expect(find.text('Home Page'), findsOneWidget);

      // When: Changing to settings page
      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveNavigation(
            destinations: destinations,
            currentIndex: 2,
            onDestinationSelected: (index) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Then: Should show settings page
      expect(find.text('Settings Page'), findsOneWidget);
      expect(find.text('Home Page'), findsNothing);
    });

    testWidgets('it_should_support_3_to_5_destinations', (
      WidgetTester tester,
    ) async {
      // Given: Navigation with 3 destinations
      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveNavigation(
            destinations: destinations,
            currentIndex: 0,
            onDestinationSelected: (index) {},
          ),
        ),
      );

      // Then: Should display all 3 destinations
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Sync'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });
  });

  group('MobileNavigation', () {
    testWidgets('it_should_use_bottom_navigation_bar', (
      WidgetTester tester,
    ) async {
      // Given: Mobile navigation with multiple destinations
      final destinations = [
        AdaptiveNavigationDestination(
          icon: Icons.home,
          label: 'Home',
          builder: (context) => const Text('Home'),
        ),
        AdaptiveNavigationDestination(
          icon: Icons.settings,
          label: 'Settings',
          builder: (context) => const Text('Settings'),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveNavigation(
            destinations: destinations,
            currentIndex: 0,
            onDestinationSelected: (index) {},
          ),
        ),
      );

      // Then: Should have bottom navigation on mobile
      if (PlatformDetector.isMobile) {
        expect(find.byType(BottomNavigationBar), findsOneWidget);
      }
    });
  });

  group('DesktopNavigation', () {
    testWidgets('it_should_use_navigation_rail', (WidgetTester tester) async {
      // Given: Desktop navigation with multiple destinations
      final destinations = [
        AdaptiveNavigationDestination(
          icon: Icons.home,
          label: 'Home',
          builder: (context) => const Text('Home'),
        ),
        AdaptiveNavigationDestination(
          icon: Icons.settings,
          label: 'Settings',
          builder: (context) => const Text('Settings'),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveNavigation(
            destinations: destinations,
            currentIndex: 0,
            onDestinationSelected: (index) {},
          ),
        ),
      );

      // Then: Should have navigation rail on desktop
      if (PlatformDetector.isDesktop) {
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.byType(VerticalDivider), findsOneWidget);
      }
    });
  });
}
