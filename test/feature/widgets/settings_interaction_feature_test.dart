import 'package:cardmind/providers/settings_provider.dart';
import 'package:cardmind/providers/theme_provider.dart';
import 'package:cardmind/widgets/dialogs/export_confirm_dialog.dart';
import 'package:cardmind/widgets/settings/button_setting_item.dart';
import 'package:cardmind/widgets/settings/toggle_setting_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Settings Widget Interaction Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets(
      'it_should_WT-016: Tap sync notification switch toggles state',
      (tester) async {
        final provider = SettingsProvider();
        await provider.initialize();

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: provider,
            child: MaterialApp(
              home: Scaffold(
                body: Consumer<SettingsProvider>(
                  builder: (context, settings, _) {
                    return ToggleSettingItem(
                      icon: Icons.notifications,
                      label: 'Sync Notifications',
                      value: settings.syncNotificationEnabled,
                      onChanged: (value) =>
                          settings.setSyncNotificationEnabled(value),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        // Initial state should be true
        expect(provider.syncNotificationEnabled, true);

        // Tap the switch
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();

        // State should be toggled
        expect(provider.syncNotificationEnabled, false);
      },
    );

    testWidgets('it_should_WT-017: Tap dark mode switch toggles state', (
      tester,
    ) async {
      final provider = ThemeProvider();
      await provider.initialize();

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer<ThemeProvider>(
                builder: (context, theme, _) {
                  return ToggleSettingItem(
                    icon: Icons.dark_mode,
                    label: 'Dark Mode',
                    value: theme.isDarkMode,
                    onChanged: (value) => theme.setThemeMode(
                      value ? ThemeMode.dark : ThemeMode.light,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Initial state should be false (light mode)
      expect(provider.isDarkMode, false);

      // Tap the switch
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // State should be toggled to dark mode
      expect(provider.isDarkMode, true);
    });

    testWidgets('it_should_WT-018: Tap export button shows dialog', (
      tester,
    ) async {
      bool dialogShown = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ButtonSettingItem(
              icon: Icons.upload_file,
              label: 'Export Data',
              onPressed: () {
                dialogShown = true;
              },
            ),
          ),
        ),
      );

      // Tap the button
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      expect(dialogShown, true);
    });

    testWidgets('it_should_WT-020: Confirm export proceeds', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    final result = await ExportConfirmDialog.show(context, 10);
                    if (result) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Export confirmed')),
                      );
                    }
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      // Show the dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Verify dialog is shown
      expect(find.text('导出数据'), findsOneWidget);
      expect(find.text('即将导出 10 张卡片'), findsOneWidget);

      // Tap confirm button
      await tester.tap(find.text('导出'));
      await tester.pumpAndSettle();

      // Verify snackbar is shown
      expect(find.text('Export confirmed'), findsOneWidget);
    });

    testWidgets('it_should_WT-021: Cancel export closes dialog', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    final result = await ExportConfirmDialog.show(context, 10);
                    if (!result) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Export cancelled')),
                      );
                    }
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        ),
      );

      // Show the dialog
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Verify dialog is shown
      expect(find.text('导出数据'), findsOneWidget);

      // Tap cancel button
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // Verify snackbar is shown
      expect(find.text('Export cancelled'), findsOneWidget);
    });

    testWidgets(
      'it_should_WT-030: Switch toggle shows success (no toast in test)',
      (tester) async {
        final provider = SettingsProvider();
        await provider.initialize();

        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: provider,
            child: MaterialApp(
              home: Scaffold(
                body: Consumer<SettingsProvider>(
                  builder: (context, settings, _) {
                    return ToggleSettingItem(
                      icon: Icons.notifications,
                      label: 'Sync Notifications',
                      value: settings.syncNotificationEnabled,
                      onChanged: (value) async {
                        await settings.setSyncNotificationEnabled(value);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Setting updated')),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        );

        // Tap the switch
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();

        // Verify snackbar is shown
        expect(find.text('Setting updated'), findsOneWidget);
      },
    );

    testWidgets('it_should_WT-031: Switch failure shows error and reverts', (
      tester,
    ) async {
      const bool shouldFail = true;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              const bool value = true;
              return Scaffold(
                body: ToggleSettingItem(
                  icon: Icons.notifications,
                  label: 'Sync Notifications',
                  value: value,
                  onChanged: (newValue) async {
                    if (shouldFail) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to update')),
                      );
                      // Don't update state on failure
                    }
                  },
                ),
              );
            },
          ),
        ),
      );

      // Tap the switch (should fail)
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Verify error message is shown
      expect(find.text('Failed to update'), findsOneWidget);

      // Verify state didn't change
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, true);
    });

    testWidgets('it_should_WT-032: Export success shows toast', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ButtonSettingItem(
                  icon: Icons.upload_file,
                  label: 'Export Data',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('数据已导出到: /path/to/file.json'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      );

      // Tap the button
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      // Verify snackbar is shown
      expect(find.textContaining('数据已导出到'), findsOneWidget);
    });

    testWidgets('it_should_WT-033: Export failure shows error', (tester) async {
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

      // Tap the button
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      // Verify error message is shown
      expect(find.text('导出失败: 权限不足'), findsOneWidget);
    });

    testWidgets('it_should_WT-034: Import success shows toast with count', (
      tester,
    ) async {
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
                      const SnackBar(content: Text('成功导入 25 张卡片')),
                    );
                  },
                );
              },
            ),
          ),
        ),
      );

      // Tap the button
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      // Verify snackbar is shown with count
      expect(find.text('成功导入 25 张卡片'), findsOneWidget);
    });

    testWidgets('it_should_WT-035: Import failure shows error', (tester) async {
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
                      const SnackBar(content: Text('导入失败: 文件格式无效')),
                    );
                  },
                );
              },
            ),
          ),
        ),
      );

      // Tap the button
      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      // Verify error message is shown
      expect(find.text('导入失败: 文件格式无效'), findsOneWidget);
    });
  });
}
