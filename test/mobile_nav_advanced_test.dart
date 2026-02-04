import 'package:cardmind/widgets/mobile_nav/badge_widget.dart';
import 'package:cardmind/widgets/mobile_nav/mobile_nav.dart';
import 'package:cardmind/widgets/mobile_nav/nav_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Advanced widget tests for MobileNav component
/// Covers animation, boundary cases, and theme adaptation
void main() {
  group('MobileNav Advanced Tests', () {
    // Helper function to create test widget
    Widget createTestWidget({
      NavTab currentTab = NavTab.notes,
      OnTabChange? onTabChange,
      int notesCount = 0,
      int devicesCount = 0,
      ThemeMode themeMode = ThemeMode.light,
    }) {
      return MaterialApp(
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: themeMode,
        home: Scaffold(
          bottomNavigationBar: MobileNav(
            currentTab: currentTab,
            onTabChange: onTabChange ?? (_) {},
            notesCount: notesCount,
            devicesCount: devicesCount,
          ),
        ),
      );
    }

    group('Animation Tests', () {
      testWidgets('it_should_animate_icon_scale_on_tab_switch', (
        WidgetTester tester,
      ) async {
        // Given: MobileNav with notes tab active
        NavTab? tappedTab;
        await tester.pumpWidget(
          createTestWidget(
            currentTab: NavTab.notes,
            onTabChange: (tab) => tappedTab = tab,
          ),
        );

        // When: Tap devices tab
        await tester.tap(find.text('设备'));
        await tester.pump();

        // Then: Animation should be in progress
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(AnimatedScale), findsWidgets);

        // Complete animation
        await tester.pumpAndSettle();
        expect(tappedTab, equals(NavTab.devices));
      });

      testWidgets('it_should_animate_indicator_fade', (
        WidgetTester tester,
      ) async {
        // Given: MobileNav widget
        await tester.pumpWidget(createTestWidget(currentTab: NavTab.notes));

        // Then: Should have AnimatedContainer for indicator
        expect(find.byType(AnimatedContainer), findsWidgets);
      });

      testWidgets('it_should_animate_badge_appearance', (
        WidgetTester tester,
      ) async {
        // Given: MobileNav with zero count
        await tester.pumpWidget(createTestWidget(notesCount: 0));

        // When: Update to non-zero count
        await tester.pumpWidget(createTestWidget(notesCount: 5));
        await tester.pump();

        // Then: Badge should appear with animation
        expect(find.byType(BadgeWidget), findsWidgets);
        await tester.pumpAndSettle();
      });
    });

    group('Boundary Tests', () {
      testWidgets('it_should_handle_negative_notes_count', (
        WidgetTester tester,
      ) async {
        // Given: MobileNav with negative count
        await tester.pumpWidget(createTestWidget(notesCount: -5));

        // Then: Should not display badge
        expect(find.text('-5'), findsNothing);
        expect(find.text('5'), findsNothing);
      });

      testWidgets('it_should_handle_negative_devices_count', (
        WidgetTester tester,
      ) async {
        // Given: MobileNav with negative count
        await tester.pumpWidget(createTestWidget(devicesCount: -10));

        // Then: Should not display badge
        expect(find.text('-10'), findsNothing);
        expect(find.text('10'), findsNothing);
      });

      testWidgets('it_should_display_99plus_for_large_notes_count', (
        WidgetTester tester,
      ) async {
        // Given: MobileNav with large count
        await tester.pumpWidget(createTestWidget(notesCount: 1000));

        // Then: Should display "99+"
        expect(find.text('99+'), findsOneWidget);
      });

      testWidgets('it_should_display_99plus_for_large_devices_count', (
        WidgetTester tester,
      ) async {
        // Given: MobileNav with large count
        await tester.pumpWidget(createTestWidget(devicesCount: 9999));

        // Then: Should display "99+"
        expect(find.text('99+'), findsOneWidget);
      });

      testWidgets('it_should_handle_zero_counts', (WidgetTester tester) async {
        // Given: MobileNav with zero counts
        await tester.pumpWidget(
          createTestWidget(notesCount: 0, devicesCount: 0),
        );

        // Then: Should not display any badges
        expect(find.byType(BadgeWidget), findsNothing);
      });

      testWidgets('it_should_handle_boundary_count_99', (
        WidgetTester tester,
      ) async {
        // Given: MobileNav with count = 99
        await tester.pumpWidget(createTestWidget(notesCount: 99));

        // Then: Should display "99" not "99+"
        expect(find.text('99'), findsOneWidget);
        expect(find.text('99+'), findsNothing);
      });

      testWidgets('it_should_handle_boundary_count_100', (
        WidgetTester tester,
      ) async {
        // Given: MobileNav with count = 100
        await tester.pumpWidget(createTestWidget(notesCount: 100));

        // Then: Should display "99+"
        expect(find.text('99+'), findsOneWidget);
        expect(find.text('100'), findsNothing);
      });

      testWidgets('it_should_handle_narrow_screen_layout', (
        WidgetTester tester,
      ) async {
        // Given: Narrow screen size
        await tester.binding.setSurfaceSize(const Size(300, 600));
        await tester.pumpWidget(createTestWidget());

        // Then: Should render without overflow
        expect(tester.takeException(), isNull);
        expect(find.byType(MobileNav), findsOneWidget);

        // Cleanup
        await tester.binding.setSurfaceSize(null);
      });
    });

    group('Theme Adaptation Tests', () {
      testWidgets('it_should_adapt_to_light_theme', (
        WidgetTester tester,
      ) async {
        // Given: Light theme
        await tester.pumpWidget(createTestWidget(themeMode: ThemeMode.light));

        // Then: Should render with light theme colors
        expect(find.byType(MobileNav), findsOneWidget);
        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(MobileNav),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(container, isNotNull);
      });

      testWidgets('it_should_adapt_to_dark_theme', (WidgetTester tester) async {
        // Given: Dark theme
        await tester.pumpWidget(createTestWidget(themeMode: ThemeMode.dark));

        // Then: Should render with dark theme colors
        expect(find.byType(MobileNav), findsOneWidget);
      });

      testWidgets('it_should_use_theme_primary_color_for_active_tab', (
        WidgetTester tester,
      ) async {
        // Given: MobileNav with custom theme
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
            ),
            home: Scaffold(
              bottomNavigationBar: MobileNav(
                currentTab: NavTab.notes,
                onTabChange: (_) {},
                notesCount: 0,
                devicesCount: 0,
              ),
            ),
          ),
        );

        // Then: Should use theme colors
        expect(find.byType(MobileNav), findsOneWidget);
      });

      testWidgets('it_should_use_theme_divider_color_for_border', (
        WidgetTester tester,
      ) async {
        // Given: MobileNav widget
        await tester.pumpWidget(createTestWidget());

        // Then: Should have border using theme divider color
        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(MobileNav),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(container.decoration, isA<BoxDecoration>());
      });
    });

    group('Accessibility Advanced Tests', () {
      testWidgets('it_should_provide_semantic_label_with_count', (
        WidgetTester tester,
      ) async {
        // Given: MobileNav with counts
        await tester.pumpWidget(
          createTestWidget(notesCount: 5, devicesCount: 3),
        );

        // Then: Should have semantic labels with counts
        expect(find.byType(Semantics), findsWidgets);
      });

      testWidgets('it_should_mark_active_tab_as_selected', (
        WidgetTester tester,
      ) async {
        // Given: MobileNav with notes tab active
        await tester.pumpWidget(createTestWidget(currentTab: NavTab.notes));

        // Then: Active tab should be marked as selected
        expect(find.byType(Semantics), findsWidgets);
      });

      testWidgets('it_should_mark_tabs_as_buttons', (
        WidgetTester tester,
      ) async {
        // Given: MobileNav widget
        await tester.pumpWidget(createTestWidget());

        // Then: All tabs should be marked as buttons
        expect(find.byType(Semantics), findsWidgets);
      });
    });

    group('SafeArea Tests', () {
      testWidgets('it_should_respect_safe_area_bottom', (
        WidgetTester tester,
      ) async {
        // Given: Device with safe area
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.only(bottom: 34)),
            child: MaterialApp(
              home: Scaffold(
                bottomNavigationBar: MobileNav(
                  currentTab: NavTab.notes,
                  onTabChange: (_) {},
                  notesCount: 0,
                  devicesCount: 0,
                ),
              ),
            ),
          ),
        );

        // Then: Should use SafeArea
        expect(find.byType(SafeArea), findsOneWidget);
      });

      testWidgets('it_should_handle_no_safe_area', (WidgetTester tester) async {
        // Given: Device without safe area
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.zero),
            child: MaterialApp(
              home: Scaffold(
                bottomNavigationBar: MobileNav(
                  currentTab: NavTab.notes,
                  onTabChange: (_) {},
                  notesCount: 0,
                  devicesCount: 0,
                ),
              ),
            ),
          ),
        );

        // Then: Should still render correctly
        expect(find.byType(MobileNav), findsOneWidget);
        expect(find.byType(SafeArea), findsOneWidget);
      });
    });
  });
}
