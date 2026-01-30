import 'package:cardmind/widgets/settings/button_setting_item.dart';
import 'package:cardmind/widgets/settings/info_setting_item.dart';
import 'package:cardmind/widgets/settings/toggle_setting_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Settings Components Rendering Tests', () {
    testWidgets('WT-001: ToggleSettingItem renders correctly', (tester) async {
      bool value = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ToggleSettingItem(
              icon: Icons.notifications,
              label: 'Test Setting',
              description: 'Test description',
              value: value,
              onChanged: (newValue) {
                value = newValue;
              },
            ),
          ),
        ),
      );

      expect(find.text('Test Setting'), findsOneWidget);
      expect(find.text('Test description'), findsOneWidget);
      expect(find.byIcon(Icons.notifications), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('WT-002: ButtonSettingItem renders correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ButtonSettingItem(
              icon: Icons.upload_file,
              label: 'Export Data',
              description: 'Export all notes',
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Export Data'), findsOneWidget);
      expect(find.text('Export all notes'), findsOneWidget);
      expect(find.byIcon(Icons.upload_file), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('WT-003: ButtonSettingItem shows loading state', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ButtonSettingItem(
              icon: Icons.upload_file,
              label: 'Export Data',
              description: 'Export all notes',
              onPressed: () {},
              isLoading: true,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('WT-004: InfoSettingItem renders correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InfoSettingItem(
              icon: Icons.info,
              label: 'Version',
              value: '1.0.0',
            ),
          ),
        ),
      );

      expect(find.text('Version'), findsOneWidget);
      expect(find.text('1.0.0'), findsOneWidget);
      expect(find.byIcon(Icons.info), findsOneWidget);
    });

    testWidgets('WT-005: ToggleSettingItem can be toggled', (tester) async {
      bool value = false;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: ToggleSettingItem(
                  icon: Icons.notifications,
                  label: 'Test Setting',
                  value: value,
                  onChanged: (newValue) {
                    setState(() {
                      value = newValue;
                    });
                  },
                ),
              ),
            );
          },
        ),
      );

      // Initial state
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, false);

      // Toggle switch
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Verify state changed
      final updatedSwitch = tester.widget<Switch>(find.byType(Switch));
      expect(updatedSwitch.value, true);
    });

    testWidgets('WT-006: ButtonSettingItem can be tapped', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ButtonSettingItem(
              icon: Icons.upload_file,
              label: 'Export Data',
              onPressed: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      expect(tapped, true);
    });

    testWidgets('WT-007: ButtonSettingItem disabled when loading', (
      tester,
    ) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ButtonSettingItem(
              icon: Icons.upload_file,
              label: 'Export Data',
              onPressed: () {
                tapped = true;
              },
              isLoading: true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ListTile));
      await tester.pump();

      expect(tapped, false);
    });
  });
}
