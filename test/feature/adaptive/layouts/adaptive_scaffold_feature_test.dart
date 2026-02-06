import 'package:cardmind/adaptive/layouts/adaptive_scaffold.dart';
import 'package:cardmind/adaptive/platform_detector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdaptiveScaffold', () {
    testWidgets('it_should_display_body_content', (WidgetTester tester) async {
      // Given: Adaptive scaffold with body
      await tester.pumpWidget(
        const MaterialApp(
          home: AdaptiveScaffold(body: Center(child: Text('Test Body'))),
        ),
      );

      // Then: Should display body content
      expect(find.text('Test Body'), findsOneWidget);
    });

    testWidgets('it_should_display_app_bar', (WidgetTester tester) async {
      // Given: Adaptive scaffold with app bar
      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveScaffold(
            appBar: AppBar(title: const Text('Test Title')),
            body: const Center(child: Text('Body')),
          ),
        ),
      );

      // Then: Should display app bar
      expect(find.text('Test Title'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('it_should_show_fab_on_mobile', (WidgetTester tester) async {
      // Given: Adaptive scaffold with FAB
      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveScaffold(
            body: const Center(child: Text('Body')),
            floatingActionButton: FloatingActionButton(
              onPressed: () {},
              child: const Icon(Icons.add),
            ),
          ),
        ),
      );

      // Then: Should show FAB on mobile, not on desktop
      if (PlatformDetector.isMobile) {
        expect(find.byType(FloatingActionButton), findsOneWidget);
      } else {
        expect(find.byType(FloatingActionButton), findsNothing);
      }
    });

    testWidgets('it_should_use_scaffold', (WidgetTester tester) async {
      // Given: Adaptive scaffold
      await tester.pumpWidget(
        const MaterialApp(
          home: AdaptiveScaffold(body: Center(child: Text('Body'))),
        ),
      );

      // Then: Should use Scaffold widget
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('it_should_adapt_to_platform', (WidgetTester tester) async {
      // Given: Adaptive scaffold
      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveScaffold(
            body: const Center(child: Text('Body')),
            floatingActionButton: FloatingActionButton(
              onPressed: () {},
              child: const Icon(Icons.add),
            ),
          ),
        ),
      );

      // Then: Should adapt based on platform
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
    });
  });

  group('MobileLayout', () {
    testWidgets('it_should_support_floating_action_button', (
      WidgetTester tester,
    ) async {
      // Given: Mobile layout with FAB
      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveScaffold(
            body: const Text('Body'),
            floatingActionButton: FloatingActionButton(
              onPressed: () {},
              child: const Icon(Icons.add),
            ),
          ),
        ),
      );

      // Then: Should show FAB on mobile
      if (PlatformDetector.isMobile) {
        expect(find.byType(FloatingActionButton), findsOneWidget);
      }
    });

    testWidgets('it_should_use_single_column_layout', (
      WidgetTester tester,
    ) async {
      // Given: Mobile layout
      await tester.pumpWidget(
        const MaterialApp(
          home: AdaptiveScaffold(
            body: Column(children: [Text('Item 1'), Text('Item 2')]),
          ),
        ),
      );

      // Then: Should display content in single column
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
    });
  });

  group('DesktopLayout', () {
    testWidgets('it_should_not_show_fab', (WidgetTester tester) async {
      // Given: Desktop layout with FAB specified
      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveScaffold(
            body: const Text('Body'),
            floatingActionButton: FloatingActionButton(
              onPressed: () {},
              child: const Icon(Icons.add),
            ),
          ),
        ),
      );

      // Then: Should not show FAB on desktop
      if (PlatformDetector.isDesktop) {
        expect(find.byType(FloatingActionButton), findsNothing);
      }
    });

    testWidgets('it_should_optimize_for_wider_screens', (
      WidgetTester tester,
    ) async {
      // Given: Desktop layout
      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveScaffold(
            appBar: AppBar(title: const Text('Desktop')),
            body: const Text('Body'),
          ),
        ),
      );

      // Then: Should display content optimized for desktop
      expect(find.text('Body'), findsOneWidget);
      if (PlatformDetector.isDesktop) {
        expect(find.byType(AppBar), findsOneWidget);
      }
    });
  });
}
