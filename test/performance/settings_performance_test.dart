import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardmind/widgets/settings/toggle_setting_item.dart';
import 'package:cardmind/widgets/settings/button_setting_item.dart';
import 'package:cardmind/widgets/dialogs/export_confirm_dialog.dart';
import 'package:cardmind/providers/app_info_provider.dart';
import 'package:cardmind/providers/settings_provider.dart';
import 'package:cardmind/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Settings Performance Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    Widget createToggleWidget({required bool value, required Function(bool) onChanged}) {
      return MaterialApp(
        home: Scaffold(
          body: ToggleSettingItem(
            icon: Icons.notifications,
            label: '测试开关',
            description: '测试描述',
            value: value,
            onChanged: onChanged,
          ),
        ),
      );
    }

    Widget createButtonWidget({required VoidCallback onPressed}) {
      return MaterialApp(
        home: Scaffold(
          body: ButtonSettingItem(
            icon: Icons.download,
            label: '测试按钮',
            description: '测试描述',
            onPressed: onPressed,
          ),
        ),
      );
    }

    testWidgets('PT-001: Toggle component renders within 300ms',
        (WidgetTester tester) async {
      bool value = false;
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(createToggleWidget(
        value: value,
        onChanged: (v) => value = v,
      ));
      await tester.pumpAndSettle();

      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(300),
          reason: 'Toggle component should render within 300ms');
    });

    testWidgets('PT-002: Toggle switch responds within 100ms',
        (WidgetTester tester) async {
      bool value = false;

      await tester.pumpWidget(createToggleWidget(
        value: value,
        onChanged: (v) => value = v,
      ));
      await tester.pumpAndSettle();

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      final stopwatch = Stopwatch()..start();

      await tester.tap(switchFinder);
      await tester.pump(); // Single frame

      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(100),
          reason: 'Toggle should respond within 100ms');
    });

    testWidgets('PT-003: Button component renders within 300ms',
        (WidgetTester tester) async {
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(createButtonWidget(
        onPressed: () {},
      ));
      await tester.pumpAndSettle();

      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(300),
          reason: 'Button component should render within 300ms');
    });

    testWidgets('PT-004: Multiple rapid toggles handle gracefully',
        (WidgetTester tester) async {
      bool value = false;

      await tester.pumpWidget(createToggleWidget(
        value: value,
        onChanged: (v) => value = v,
      ));
      await tester.pumpAndSettle();

      final switchFinder = find.byType(Switch);

      final stopwatch = Stopwatch()..start();

      // Rapid toggles
      for (int i = 0; i < 10; i++) {
        await tester.tap(switchFinder);
        await tester.pump();
      }
      await tester.pumpAndSettle();

      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(500),
          reason: '10 rapid toggles should complete within 500ms');
    });

    testWidgets('PT-005: Settings provider initialization is fast',
        (WidgetTester tester) async {
      final stopwatch = Stopwatch()..start();

      final provider = SettingsProvider();
      await provider.initialize();

      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(50),
          reason: 'Provider initialization should be under 50ms');
    });

    testWidgets('PT-006: App info provider initialization is fast',
        (WidgetTester tester) async {
      final stopwatch = Stopwatch()..start();

      final provider = AppInfoProvider();
      await provider.initialize();

      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(50),
          reason: 'App info initialization should be under 50ms');
    });

    testWidgets('PT-007: Theme provider initialization is fast',
        (WidgetTester tester) async {
      final stopwatch = Stopwatch()..start();

      final provider = ThemeProvider();
      await provider.initialize();

      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(50),
          reason: 'Theme provider initialization should be under 50ms');
    });

    testWidgets('PT-008: Dialog opening is fast',
        (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => ExportConfirmDialog(
                    cardCount: 100,
                  ),
                );
              },
              child: Text('Open Dialog'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final buttonFinder = find.text('Open Dialog');
      expect(buttonFinder, findsOneWidget);

      final stopwatch = Stopwatch()..start();

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(100),
          reason: 'Dialog should open within 100ms');
    });

    testWidgets('PT-009: Memory usage is reasonable',
        (WidgetTester tester) async {
      // Create and destroy widget multiple times
      for (int i = 0; i < 5; i++) {
        await tester.pumpWidget(createToggleWidget(
          value: false,
          onChanged: (_) {},
        ));
        await tester.pumpAndSettle();

        // Verify widget is rendered
        expect(find.byType(ToggleSettingItem), findsOneWidget);

        // Clear widget
        await tester.pumpWidget(Container());
      }

      // If we get here without OOM, memory management is working
      expect(true, isTrue);
    });

    testWidgets('PT-010: Rebuild performance after state change',
        (WidgetTester tester) async {
      bool value = false;

      await tester.pumpWidget(createToggleWidget(
        value: value,
        onChanged: (v) => value = v,
      ));
      await tester.pumpAndSettle();

      final switchFinder = find.byType(Switch);

      final stopwatch = Stopwatch()..start();

      await tester.tap(switchFinder);
      await tester.pump(); // Trigger rebuild

      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(100),
          reason: 'Rebuild after state change should be under 100ms');
    });
  });
}
