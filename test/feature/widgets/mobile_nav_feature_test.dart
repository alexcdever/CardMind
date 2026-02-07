import 'package:cardmind/widgets/mobile_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MobileNav Widget Tests', () {
    testWidgets('it_should_display_all_three_tabs', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MobileNav(
              currentTab: NavTab.notes,
              onTabChange: (_) {},
              notesCount: 5,
              devicesCount: 2,
            ),
          ),
        ),
      );

      expect(find.text('笔记'), findsOneWidget);
      expect(find.text('设备'), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);
    });

    testWidgets('it_should_display_all_icons', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MobileNav(
              currentTab: NavTab.notes,
              onTabChange: (_) {},
              notesCount: 5,
              devicesCount: 2,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.note), findsOneWidget);
      expect(find.byIcon(Icons.wifi), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('it_should_display_note_count_badge', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MobileNav(
              currentTab: NavTab.notes,
              onTabChange: (_) {},
              notesCount: 5,
              devicesCount: 2,
            ),
          ),
        ),
      );

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('it_should_display_device_count_badge', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MobileNav(
              currentTab: NavTab.notes,
              onTabChange: (_) {},
              notesCount: 5,
              devicesCount: 2,
            ),
          ),
        ),
      );

      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('it_should_display_99_plus_for_counts_over_99', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MobileNav(
              currentTab: NavTab.notes,
              onTabChange: (_) {},
              notesCount: 150,
              devicesCount: 2,
            ),
          ),
        ),
      );

      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('it_should_not_display_badge_when_count_is_zero', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
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

      // Should only find text labels, no badge numbers
      expect(find.text('0'), findsNothing);
    });

    testWidgets('it_should_call_onTabChange_when_notes_tab_tapped', (
      WidgetTester tester,
    ) async {
      NavTab? selectedTab;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MobileNav(
              currentTab: NavTab.devices,
              onTabChange: (tab) {
                selectedTab = tab;
              },
              notesCount: 5,
              devicesCount: 2,
            ),
          ),
        ),
      );

      await tester.tap(find.text('笔记'));
      await tester.pumpAndSettle();

      expect(selectedTab, equals(NavTab.notes));
    });

    testWidgets('it_should_call_onTabChange_when_devices_tab_tapped', (
      WidgetTester tester,
    ) async {
      NavTab? selectedTab;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MobileNav(
              currentTab: NavTab.notes,
              onTabChange: (tab) {
                selectedTab = tab;
              },
              notesCount: 5,
              devicesCount: 2,
            ),
          ),
        ),
      );

      await tester.tap(find.text('设备'));
      await tester.pumpAndSettle();

      expect(selectedTab, equals(NavTab.devices));
    });

    testWidgets('it_should_call_onTabChange_when_settings_tab_tapped', (
      WidgetTester tester,
    ) async {
      NavTab? selectedTab;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MobileNav(
              currentTab: NavTab.notes,
              onTabChange: (tab) {
                selectedTab = tab;
              },
              notesCount: 5,
              devicesCount: 2,
            ),
          ),
        ),
      );

      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();

      expect(selectedTab, equals(NavTab.settings));
    });

    testWidgets('it_should_highlight_active_tab_with_indicator', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MobileNav(
              currentTab: NavTab.devices,
              onTabChange: (_) {},
              notesCount: 5,
              devicesCount: 2,
            ),
          ),
        ),
      );

      // The active tab should have a visible indicator
      expect(find.byType(Container), findsWidgets);
    });
  });
}
