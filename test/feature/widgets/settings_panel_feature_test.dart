import 'package:cardmind/widgets/settings_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SettingsPanel Widget Tests', () {
    testWidgets('it_should_display_settings_title', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPanel(isDarkMode: false, onThemeChanged: (_) {}),
          ),
        ),
      );

      expect(find.text('设置'), findsOneWidget);
    });

    testWidgets('it_should_display_theme_toggle', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPanel(isDarkMode: false, onThemeChanged: (_) {}),
          ),
        ),
      );

      expect(find.text('暗色模式'), findsOneWidget);
      expect(find.text('切换应用主题'), findsOneWidget);
    });

    testWidgets('it_should_display_sync_settings', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPanel(isDarkMode: false, onThemeChanged: (_) {}),
          ),
        ),
      );

      expect(find.text('同步'), findsOneWidget);
      expect(find.text('自动同步'), findsOneWidget);
      expect(find.text('仅 WiFi 同步'), findsOneWidget);
    });

    testWidgets('it_should_display_storage_settings', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPanel(isDarkMode: false, onThemeChanged: (_) {}),
          ),
        ),
      );

      expect(find.text('存储'), findsOneWidget);
      expect(find.text('清除缓存'), findsOneWidget);
    });

    testWidgets('it_should_display_about_section', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPanel(isDarkMode: false, onThemeChanged: (_) {}),
          ),
        ),
      );

      expect(find.text('关于'), findsOneWidget);
      expect(find.text('版本信息'), findsOneWidget);
      expect(find.text('开源许可'), findsOneWidget);
    });

    testWidgets('it_should_call_onThemeChanged_when_theme_toggle_switched', (
      WidgetTester tester,
    ) async {
      bool? newTheme;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPanel(
              isDarkMode: false,
              onThemeChanged: (value) {
                newTheme = value;
              },
            ),
          ),
        ),
      );

      final switchFinder = find.byType(SwitchListTile).first;
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(newTheme, isTrue);
    });

    testWidgets('it_should_show_clear_cache_dialog_when_tapped', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPanel(isDarkMode: false, onThemeChanged: (_) {}),
          ),
        ),
      );

      await tester.tap(find.text('清除缓存'));
      await tester.pumpAndSettle();

      expect(find.text('确定要清除所有缓存数据吗？此操作不会删除您的笔记。'), findsOneWidget);
      expect(find.text('取消'), findsWidgets);
      expect(find.text('确定'), findsOneWidget);
    });

    testWidgets('it_should_display_light_mode_icon_when_not_dark', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPanel(isDarkMode: false, onThemeChanged: (_) {}),
          ),
        ),
      );

      expect(find.byIcon(Icons.light_mode), findsOneWidget);
    });

    testWidgets('it_should_display_dark_mode_icon_when_dark', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPanel(isDarkMode: true, onThemeChanged: (_) {}),
          ),
        ),
      );

      expect(find.byIcon(Icons.dark_mode), findsOneWidget);
    });

    testWidgets('it_should_close_clear_cache_dialog_when_cancel_pressed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPanel(isDarkMode: false, onThemeChanged: (_) {}),
          ),
        ),
      );

      await tester.tap(find.text('清除缓存'));
      await tester.pumpAndSettle();

      expect(find.text('清除缓存'), findsWidgets);

      await tester.tap(find.text('取消').last);
      await tester.pumpAndSettle();

      expect(find.text('确定要清除所有缓存数据吗？此操作不会删除您的笔记。'), findsNothing);
    });

    testWidgets('it_should_display_all_section_icons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SettingsPanel(isDarkMode: false, onThemeChanged: (_) {}),
          ),
        ),
      );

      expect(find.byIcon(Icons.settings), findsOneWidget);
      expect(find.byIcon(Icons.sync), findsOneWidget);
      expect(find.byIcon(Icons.wifi), findsOneWidget);
      expect(find.byIcon(Icons.storage), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    });
  });
}
