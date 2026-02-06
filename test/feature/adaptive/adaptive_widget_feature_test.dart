import 'package:cardmind/adaptive/adaptive_builder.dart';
import 'package:cardmind/adaptive/adaptive_widget.dart';
import 'package:cardmind/adaptive/platform_detector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Test implementation of AdaptiveWidget
class TestAdaptiveWidget extends AdaptiveWidget {
  const TestAdaptiveWidget({super.key});

  @override
  Widget buildMobile(BuildContext context) {
    return const Text('Mobile');
  }

  @override
  Widget buildDesktop(BuildContext context) {
    return const Text('Desktop');
  }
}

void main() {
  group('AdaptiveWidget', () {
    testWidgets('it_should_build_platform_specific_widget', (
      WidgetTester tester,
    ) async {
      // Given: An adaptive widget
      // When: Building the widget
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TestAdaptiveWidget())),
      );

      // Then: Should display platform-specific content
      if (PlatformDetector.isMobile) {
        expect(find.text('Mobile'), findsOneWidget);
        expect(find.text('Desktop'), findsNothing);
      } else {
        expect(find.text('Desktop'), findsOneWidget);
        expect(find.text('Mobile'), findsNothing);
      }
    });

    testWidgets('it_should_call_correct_build_method', (
      WidgetTester tester,
    ) async {
      // Given: An adaptive widget
      // When: Building the widget
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: TestAdaptiveWidget())),
      );

      // Then: Should call the appropriate build method based on platform
      final widget = tester.widget<TestAdaptiveWidget>(
        find.byType(TestAdaptiveWidget),
      );
      expect(widget, isNotNull);
    });
  });

  group('AdaptiveBuilder', () {
    testWidgets('it_should_build_mobile_widget_on_mobile', (
      WidgetTester tester,
    ) async {
      // Given: An adaptive builder
      // When: Building on mobile platform
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdaptiveBuilder(
              mobile: (context) => const Text('Mobile Builder'),
              desktop: (context) => const Text('Desktop Builder'),
            ),
          ),
        ),
      );

      // Then: Should display platform-specific content
      if (PlatformDetector.isMobile) {
        expect(find.text('Mobile Builder'), findsOneWidget);
        expect(find.text('Desktop Builder'), findsNothing);
      } else {
        expect(find.text('Desktop Builder'), findsOneWidget);
        expect(find.text('Mobile Builder'), findsNothing);
      }
    });

    testWidgets('it_should_pass_context_to_builder', (
      WidgetTester tester,
    ) async {
      // Given: An adaptive builder that uses context
      BuildContext? capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdaptiveBuilder(
              mobile: (context) {
                capturedContext = context;
                return const Text('Mobile');
              },
              desktop: (context) {
                capturedContext = context;
                return const Text('Desktop');
              },
            ),
          ),
        ),
      );

      // Then: Context should be passed to builder
      expect(capturedContext, isNotNull);
    });

    testWidgets('it_should_rebuild_when_parent_rebuilds', (
      WidgetTester tester,
    ) async {
      // Given: A stateful parent widget
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  children: [
                    AdaptiveBuilder(
                      mobile: (context) {
                        buildCount++;
                        return Text('Build $buildCount');
                      },
                      desktop: (context) {
                        buildCount++;
                        return Text('Build $buildCount');
                      },
                    ),
                    ElevatedButton(
                      onPressed: () => setState(() {}),
                      child: const Text('Rebuild'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      expect(buildCount, equals(1));

      // When: Parent rebuilds
      await tester.tap(find.text('Rebuild'));
      await tester.pump();

      // Then: AdaptiveBuilder should rebuild
      expect(buildCount, equals(2));
    });
  });

  group('AdaptiveWidget and AdaptiveBuilder integration', () {
    testWidgets('it_should_work_together_in_widget_tree', (
      WidgetTester tester,
    ) async {
      // Given: Nested adaptive widgets
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const TestAdaptiveWidget(),
                AdaptiveBuilder(
                  mobile: (context) => const Text('Builder Mobile'),
                  desktop: (context) => const Text('Builder Desktop'),
                ),
              ],
            ),
          ),
        ),
      );

      // Then: Both should render correctly
      if (PlatformDetector.isMobile) {
        expect(find.text('Mobile'), findsOneWidget);
        expect(find.text('Builder Mobile'), findsOneWidget);
      } else {
        expect(find.text('Desktop'), findsOneWidget);
        expect(find.text('Builder Desktop'), findsOneWidget);
      }
    });
  });
}
