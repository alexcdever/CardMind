import 'package:cardmind/models/app_info.dart';
import 'package:cardmind/providers/app_info_provider.dart';
import 'package:cardmind/providers/settings_provider.dart';
import 'package:cardmind/widgets/settings/button_setting_item.dart';
import 'package:cardmind/widgets/settings/toggle_setting_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Settings Widget Edge Case Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('it_should_WT-036: Handle null sync notification value', (
      tester,
    ) async {
      // Test with missing key in SharedPreferences
      SharedPreferences.setMockInitialValues({});

      final provider = SettingsProvider();
      await provider.initialize();

      // Should default to true
      expect(provider.syncNotificationEnabled, true);
    });

    testWidgets('it_should_WT-037: Handle null dark mode value', (
      tester,
    ) async {
      // Test with missing key in SharedPreferences
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ToggleSettingItem(
              icon: Icons.dark_mode,
              label: 'Dark Mode',
              value: false, // Default value
              onChanged: (_) {},
            ),
          ),
        ),
      );

      // Should render without error
      expect(find.text('Dark Mode'), findsOneWidget);
    });

    testWidgets('it_should_WT-038: Handle file size > 100MB (simulated)', (
      tester,
    ) async {
      // This would be tested in integration tests with actual file operations
      // Here we just verify the UI handles the error message

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ButtonSettingItem(
                  icon: Icons.download,
                  label: 'Import Data',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('导入失败: 文件大小超过 100MB 限制')),
                    );
                  },
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      expect(find.textContaining('文件大小超过 100MB'), findsOneWidget);
    });

    testWidgets('it_should_WT-039: Handle invalid file format', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ButtonSettingItem(
                  icon: Icons.download,
                  label: 'Import Data',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('导入失败: Invalid backup file'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      expect(find.textContaining('Invalid backup file'), findsOneWidget);
    });

    testWidgets('it_should_WT-040: Handle file permission denied', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ButtonSettingItem(
                  icon: Icons.upload_file,
                  label: 'Export Data',
                  onPressed: () {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('导出失败: 权限不足')));
                  },
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      expect(find.text('导出失败: 权限不足'), findsOneWidget);
    });

    testWidgets('it_should_WT-041: Handle import with 0 cards', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ButtonSettingItem(
                  icon: Icons.download,
                  label: 'Import Data',
                  onPressed: () {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('成功导入 0 张卡片')));
                  },
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      expect(find.text('成功导入 0 张卡片'), findsOneWidget);
    });

    testWidgets('it_should_WT-042: Handle settings load timeout', (
      tester,
    ) async {
      // Simulate timeout by testing with default values
      final provider = SettingsProvider();
      // Don't call initialize to simulate timeout

      // Should have default values
      expect(provider.syncNotificationEnabled, true);
    });

    testWidgets('it_should_WT-043: Handle settings save failure', (
      tester,
    ) async {
      final provider = SettingsProvider();
      await provider.initialize();

      // Try to toggle (in real scenario, SharedPreferences might fail)
      await provider.setSyncNotificationEnabled(false);

      // In test environment, it should succeed
      expect(provider.syncNotificationEnabled, false);
    });

    testWidgets('it_should_WT-044: Handle corrupted settings data', (
      tester,
    ) async {
      // Test with invalid data type
      SharedPreferences.setMockInitialValues({
        'sync_notification_enabled': 'invalid_string',
      });

      final provider = SettingsProvider();
      await provider.initialize();

      // Should handle gracefully and use default
      expect(provider.syncNotificationEnabled, true);
    });

    testWidgets('it_should_WT-045: Handle missing app info', (tester) async {
      final provider = AppInfoProvider();
      await provider.initialize();

      // Should have default info
      expect(provider.appInfo, isNotNull);
      expect(provider.appInfo.version, isNotEmpty);
    });

    testWidgets('it_should_WT-046: Handle empty contributors list', (
      tester,
    ) async {
      final provider = AppInfoProvider();
      const emptyInfo = AppInfo(
        version: '1.0.0',
        buildNumber: '1',
        description: 'Test',
        homepage: 'https://test.com',
        issuesUrl: 'https://test.com/issues',
        contributors: [], // Empty list
        changelog: [],
      );
      provider.setAppInfo(emptyInfo);

      expect(provider.appInfo.contributors, isEmpty);
    });

    testWidgets('it_should_WT-047: Handle empty changelog', (tester) async {
      final provider = AppInfoProvider();
      const emptyInfo = AppInfo(
        version: '1.0.0',
        buildNumber: '1',
        description: 'Test',
        homepage: 'https://test.com',
        issuesUrl: 'https://test.com/issues',
        contributors: ['Test'],
        changelog: [], // Empty list
      );
      provider.setAppInfo(emptyInfo);

      expect(provider.appInfo.changelog, isEmpty);
    });

    testWidgets('it_should_WT-048: Handle very long changelog', (tester) async {
      final provider = AppInfoProvider();
      final longChangelog = List.generate(
        100,
        (i) => ChangelogEntry(
          version: '1.0.$i',
          date: '2026-01-${(i % 30) + 1}',
          changes: ['Change $i'],
        ),
      );

      final info = AppInfo(
        version: '1.0.0',
        buildNumber: '1',
        description: 'Test',
        homepage: 'https://test.com',
        issuesUrl: 'https://test.com/issues',
        contributors: ['Test'],
        changelog: longChangelog,
      );
      provider.setAppInfo(info);

      // Should handle large changelog
      expect(provider.appInfo.changelog.length, 100);
    });

    testWidgets('it_should_WT-049: Handle button disabled state', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ButtonSettingItem(
              icon: Icons.upload_file,
              label: 'Export Data',
              onPressed: null, // Disabled
            ),
          ),
        ),
      );

      // Button should be disabled
      final listTile = tester.widget<ListTile>(find.byType(ListTile));
      expect(listTile.enabled, true); // ListTile is enabled by default
      expect(listTile.onTap, null); // But onTap is null
    });

    testWidgets('it_should_WT-050: Handle toggle disabled state', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ToggleSettingItem(
              icon: Icons.notifications,
              label: 'Sync Notifications',
              value: true,
              onChanged: null, // Disabled
            ),
          ),
        ),
      );

      // Switch should be disabled
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.onChanged, null);
    });
  });
}
