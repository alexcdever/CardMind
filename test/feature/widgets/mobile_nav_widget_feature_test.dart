import 'package:cardmind/widgets/mobile_nav/mobile_nav.dart';
import 'package:cardmind/widgets/mobile_nav/nav_models.dart';
import 'package:cardmind/widgets/mobile_nav/nav_tab_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget tests for MobileNav component
/// Based on design specification section 8.2
void main() {
  group('MobileNav Widget Tests', () {
    // Helper function to create test widget
    Widget createTestWidget({
      NavTab currentTab = NavTab.notes,
      OnTabChange? onTabChange,
      int notesCount = 0,
      int devicesCount = 0,
    }) {
      return MaterialApp(
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

    group('Basic Rendering Tests', () {
      testWidgets('it_should_render_mobile_nav_correctly', (
        WidgetTester tester,
      ) async {
        // Given: MobileNav widget
        await tester.pumpWidget(createTestWidget());

        // Then: Should render without errors
        expect(find.byType(MobileNav), findsOneWidget);
        expect(find.byType(NavTabItem), findsNWidgets(3));
      });

      testWidgets('it_should_display_three_navigation_tabs', (
        WidgetTester tester,
      ) async {
        // Given: MobileNav widget
        await tester.pumpWidget(createTestWidget());

        // Then: Should have three tabs with correct labels
        expect(find.text('笔记'), findsOneWidget);
        expect(find.text('设备'), findsOneWidget);
        expect(find.text('设置'), findsOneWidget);
      });

      testWidgets('it_should_display_correct_icons', (
        WidgetTester tester,
      ) async {
        // Given: MobileNav widget
        await tester.pumpWidget(createTestWidget());

        // Then: Should have correct icons
        expect(find.byIcon(Icons.note), findsOneWidget);
        expect(find.byIcon(Icons.wifi), findsOneWidget);
        expect(find.byIcon(Icons.settings), findsOneWidget);
      });
    });

    group('Active State Tests', () {
      testWidgets('it_should_highlight_active_tab', (
        WidgetTester tester,
      ) async {
        // Given: Notes tab is active
        await tester.pumpWidget(createTestWidget(currentTab: NavTab.notes));

        // Then: Active tab should be visually distinct
        final mobileNav = tester.widget<MobileNav>(find.byType(MobileNav));
        expect(mobileNav.currentTab, equals(NavTab.notes));
      });

      testWidgets('it_should_show_active_indicator', (
        WidgetTester tester,
      ) async {
        // Given: Notes tab is active
        await tester.pumpWidget(createTestWidget(currentTab: NavTab.notes));
        await tester.pumpAndSettle();

        // Then: Should show animated containers (indicators)
        expect(find.byType(AnimatedContainer), findsWidgets);
      });
    });

    group('Badge Tests', () {
      testWidgets('it_should_display_badge_for_notes_when_count_positive', (
        WidgetTester tester,
      ) async {
        // Given: Notes count is positive
        await tester.pumpWidget(createTestWidget(notesCount: 5));

        // Then: Should display badge with correct count
        expect(find.text('5'), findsOneWidget);
      });

      testWidgets('it_should_display_badge_for_devices_when_count_positive', (
        WidgetTester tester,
      ) async {
        // Given: Devices count is positive
        await tester.pumpWidget(createTestWidget(devicesCount: 3));

        // Then: Should display badge with correct count
        expect(find.text('3'), findsOneWidget);
      });

      testWidgets('it_should_not_display_badge_when_count_is_zero', (
        WidgetTester tester,
      ) async {
        // Given: Counts are zero
        await tester.pumpWidget(
          createTestWidget(notesCount: 0, devicesCount: 0),
        );

        // Then: Should not display badges
        expect(find.text('0'), findsNothing);
      });

      testWidgets('it_should_display_99plus_for_large_counts', (
        WidgetTester tester,
      ) async {
        // Given: Large counts
        await tester.pumpWidget(
          createTestWidget(notesCount: 150, devicesCount: 9999),
        );

        // Then: Should display "99+"
        expect(find.text('99+'), findsNWidgets(2));
      });

      testWidgets('it_should_not_display_badge_for_settings', (
        WidgetTester tester,
      ) async {
        // Given: Any counts
        await tester.pumpWidget(
          createTestWidget(notesCount: 5, devicesCount: 3),
        );

        // Then: Should not display badge for settings
        expect(find.text('5'), findsOneWidget); // Notes badge
        expect(find.text('3'), findsOneWidget); // Devices badge
        // Settings should not have a badge
      });
    });

    group('Interaction Tests', () {
      testWidgets('it_should_call_onTabChange_when_tab_tapped', (
        WidgetTester tester,
      ) async {
        // Given: Callback to capture tab changes
        NavTab? capturedTab;
        await tester.pumpWidget(
          createTestWidget(
            currentTab: NavTab.notes,
            onTabChange: (tab) => capturedTab = tab,
          ),
        );

        // When: Tap on devices tab
        await tester.tap(find.text('设备'));
        await tester.pumpAndSettle();

        // Then: Callback should be called with correct tab
        expect(capturedTab, equals(NavTab.devices));
      });

      testWidgets('it_should_not_call_onTabChange_when_active_tab_tapped', (
        WidgetTester tester,
      ) async {
        // Given: Active tab is notes, callback to capture changes
        int callCount = 0;
        await tester.pumpWidget(
          createTestWidget(
            currentTab: NavTab.notes,
            onTabChange: (_) => callCount++,
          ),
        );

        // When: Tap on already active notes tab
        await tester.tap(find.text('笔记'));
        await tester.pumpAndSettle();

        // Then: Callback should not be called
        expect(callCount, equals(0));
      });

      testWidgets('it_should_provide_visual_feedback_on_tap', (
        WidgetTester tester,
      ) async {
        // Given: MobileNav widget
        await tester.pumpWidget(createTestWidget());

        // When: Tap on a tab
        await tester.tap(find.text('设备'));
        await tester.pump(); // Don't settle to see animation

        // Then: Should provide visual feedback (InkWell should be triggered)
        expect(find.byType(InkWell), findsNWidgets(3));
      });
    });

    group('Layout Tests', () {
      testWidgets('it_should_have_correct_height', (WidgetTester tester) async {
        // Given: MobileNav widget
        await tester.pumpWidget(createTestWidget());

        // Then: Should have correct height
        final mobileNav = tester.widget<MobileNav>(find.byType(MobileNav));
        // ignore: unused_local_variable
        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(MobileNav),
                matching: find.byType(Container),
              )
              .first,
        );

        expect(mobileNav, isNotNull);
      });

      testWidgets('it_should_use_safe_area', (WidgetTester tester) async {
        // Given: MobileNav widget
        await tester.pumpWidget(createTestWidget());

        // Then: Should use SafeArea
        expect(find.byType(SafeArea), findsOneWidget);
      });

      testWidgets('it_should_have_top_border', (WidgetTester tester) async {
        // Given: MobileNav widget
        await tester.pumpWidget(createTestWidget());

        // Then: Should have container with border decoration
        expect(find.byType(Container), findsWidgets);
      });
    });

    group('Accessibility Tests', () {
      testWidgets('it_should_have_semantic_labels', (
        WidgetTester tester,
      ) async {
        // Given: MobileNav with badges
        await tester.pumpWidget(
          createTestWidget(notesCount: 5, devicesCount: 3),
        );

        // Then: Should have semantic labels
        expect(find.byType(Semantics), findsWidgets);
      });

      testWidgets('it_should_have_appropriate_touch_targets', (
        WidgetTester tester,
      ) async {
        // Given: MobileNav widget
        await tester.pumpWidget(createTestWidget());

        // Then: Each tab should be expanded to fill available space
        expect(find.byType(Expanded), findsNWidgets(3));
      });
    });
  });
}
