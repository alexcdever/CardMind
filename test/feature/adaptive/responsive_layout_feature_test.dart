import 'package:cardmind/adaptive/adaptive_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Responsive Layout Tests - Breakpoint Switching', () {
    testWidgets('it_should_should detect mobile layout below 1024px', (
      WidgetTester tester,
    ) async {
      // Set window size to mobile (800x600)
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final isMobile = MediaQuery.of(context).size.width < 1024;
                return Center(child: Text(isMobile ? 'Mobile' : 'Desktop'));
              },
            ),
          ),
        ),
      );

      expect(find.text('Mobile'), findsOneWidget);
      expect(find.text('Desktop'), findsNothing);
    });

    testWidgets('it_should_should detect desktop layout at 1024px and above', (
      WidgetTester tester,
    ) async {
      // Set window size to desktop (1280x720)
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final isMobile = MediaQuery.of(context).size.width < 1024;
                return Center(child: Text(isMobile ? 'Mobile' : 'Desktop'));
              },
            ),
          ),
        ),
      );

      expect(find.text('Desktop'), findsOneWidget);
      expect(find.text('Mobile'), findsNothing);
    });

    testWidgets('it_should_should switch from mobile to desktop at breakpoint', (
      WidgetTester tester,
    ) async {
      // Start with mobile size
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final isMobile = MediaQuery.of(context).size.width < 1024;
                return Center(child: Text(isMobile ? 'Mobile' : 'Desktop'));
              },
            ),
          ),
        ),
      );

      expect(find.text('Mobile'), findsOneWidget);

      // Resize to desktop
      tester.view.physicalSize = const Size(1280, 720);
      await tester.pumpAndSettle();

      expect(find.text('Desktop'), findsOneWidget);
      expect(find.text('Mobile'), findsNothing);
    });

    testWidgets('it_should_should switch from desktop to mobile at breakpoint', (
      WidgetTester tester,
    ) async {
      // Start with desktop size
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final isMobile = MediaQuery.of(context).size.width < 1024;
                return Center(child: Text(isMobile ? 'Mobile' : 'Desktop'));
              },
            ),
          ),
        ),
      );

      expect(find.text('Desktop'), findsOneWidget);

      // Resize to mobile
      tester.view.physicalSize = const Size(800, 600);
      await tester.pumpAndSettle();

      expect(find.text('Mobile'), findsOneWidget);
      expect(find.text('Desktop'), findsNothing);
    });

    testWidgets('it_should_should handle exact breakpoint (1024px)', (
      WidgetTester tester,
    ) async {
      // Set window size to exactly 1024px
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final isMobile = MediaQuery.of(context).size.width < 1024;
                return Center(child: Text(isMobile ? 'Mobile' : 'Desktop'));
              },
            ),
          ),
        ),
      );

      // At exactly 1024px, should be desktop (not less than 1024)
      expect(find.text('Desktop'), findsOneWidget);
      expect(find.text('Mobile'), findsNothing);
    });

    testWidgets('it_should_should use AdaptiveBuilder correctly', (
      WidgetTester tester,
    ) async {
      // Mobile size
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdaptiveBuilder(
              mobile: (context) => const Text('Mobile Layout'),
              desktop: (context) => const Text('Desktop Layout'),
            ),
          ),
        ),
      );

      expect(find.text('Mobile Layout'), findsOneWidget);
      expect(find.text('Desktop Layout'), findsNothing);

      // Note: AdaptiveBuilder uses PlatformDetector which checks compile-time platform
      // not runtime window size, so resizing won't change the layout in tests
      // This test verifies that AdaptiveBuilder works with the current platform
    });

    testWidgets('it_should_should handle multiple breakpoint switches', (
      WidgetTester tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final isMobile = MediaQuery.of(context).size.width < 1024;
                return Center(child: Text(isMobile ? 'Mobile' : 'Desktop'));
              },
            ),
          ),
        ),
      );

      // Mobile -> Desktop -> Mobile -> Desktop
      final sizes = [
        const Size(800, 600), // Mobile
        const Size(1280, 720), // Desktop
        const Size(600, 800), // Mobile
        const Size(1920, 1080), // Desktop
      ];

      final expected = ['Mobile', 'Desktop', 'Mobile', 'Desktop'];

      for (var i = 0; i < sizes.length; i++) {
        tester.view.physicalSize = sizes[i];
        await tester.pumpAndSettle();
        expect(find.text(expected[i]), findsOneWidget);
      }
    });

    testWidgets('it_should_should handle edge cases near breakpoint', (
      WidgetTester tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                final isMobile = MediaQuery.of(context).size.width < 1024;
                return Center(child: Text(isMobile ? 'Mobile' : 'Desktop'));
              },
            ),
          ),
        ),
      );

      // Test 1023px (just below breakpoint)
      tester.view.physicalSize = const Size(1023, 768);
      await tester.pumpAndSettle();
      expect(find.text('Mobile'), findsOneWidget);

      // Test 1024px (at breakpoint)
      tester.view.physicalSize = const Size(1024, 768);
      await tester.pumpAndSettle();
      expect(find.text('Desktop'), findsOneWidget);

      // Test 1025px (just above breakpoint)
      tester.view.physicalSize = const Size(1025, 768);
      await tester.pumpAndSettle();
      expect(find.text('Desktop'), findsOneWidget);
    });

    testWidgets('it_should_should maintain state across breakpoint switches', (
      WidgetTester tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      int counter = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                final isMobile = MediaQuery.of(context).size.width < 1024;
                return Column(
                  children: [
                    Text(isMobile ? 'Mobile' : 'Desktop'),
                    Text('Counter: $counter'),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          counter++;
                        });
                      },
                      child: const Text('Increment'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Start mobile
      tester.view.physicalSize = const Size(800, 600);
      await tester.pumpAndSettle();
      expect(find.text('Mobile'), findsOneWidget);
      expect(find.text('Counter: 0'), findsOneWidget);

      // Increment counter
      await tester.tap(find.text('Increment'));
      await tester.pumpAndSettle();
      expect(find.text('Counter: 1'), findsOneWidget);

      // Switch to desktop - counter should persist
      tester.view.physicalSize = const Size(1280, 720);
      await tester.pumpAndSettle();
      expect(find.text('Desktop'), findsOneWidget);
      expect(find.text('Counter: 1'), findsOneWidget);

      // Increment again
      await tester.tap(find.text('Increment'));
      await tester.pumpAndSettle();
      expect(find.text('Counter: 2'), findsOneWidget);

      // Switch back to mobile - counter should still persist
      tester.view.physicalSize = const Size(800, 600);
      await tester.pumpAndSettle();
      expect(find.text('Mobile'), findsOneWidget);
      expect(find.text('Counter: 2'), findsOneWidget);
    });
  });
}
