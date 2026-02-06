import 'package:cardmind/adaptive/navigation/adaptive_navigation.dart';
import 'package:cardmind/adaptive/navigation/mobile_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('it_should_render_mobile_navigation', (
    WidgetTester tester,
  ) async {
    final destinations = [
      AdaptiveNavigationDestination(
        icon: Icons.home,
        label: 'Home',
        builder: (_) => const Text('Home'),
      ),
      AdaptiveNavigationDestination(
        icon: Icons.settings,
        label: 'Settings',
        builder: (_) => const Text('Settings'),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: MobileNavigation(
          destinations: destinations,
          currentIndex: 0,
          onDestinationSelected: (_) {},
        ),
      ),
    );

    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
  });
}
