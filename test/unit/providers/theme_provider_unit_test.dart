import 'package:cardmind/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('it_should_initialize_theme_from_preferences', () async {
    SharedPreferences.setMockInitialValues({
      'theme_mode': ThemeMode.dark.toString(),
    });

    final provider = ThemeProvider();
    await provider.initialize();

    expect(provider.themeMode, ThemeMode.dark);
  });

  test('it_should_toggle_theme_mode', () async {
    SharedPreferences.setMockInitialValues({});

    final provider = ThemeProvider();
    await provider.setThemeMode(ThemeMode.light);
    await provider.toggleTheme();

    expect(provider.themeMode, ThemeMode.dark);
  });

  test('it_should_report_is_dark_mode', () async {
    SharedPreferences.setMockInitialValues({});

    final provider = ThemeProvider();
    await provider.setThemeMode(ThemeMode.dark);

    expect(provider.isDarkMode, isTrue);
  });

  test('it_should_is_dark_mode_false_for_system', () async {
    SharedPreferences.setMockInitialValues({});

    final provider = ThemeProvider();
    await provider.initialize();

    expect(provider.isDarkMode, isFalse);
  });

  test('it_should_persist_theme_mode_to_preferences', () async {
    SharedPreferences.setMockInitialValues({});

    final provider = ThemeProvider();
    await provider.setThemeMode(ThemeMode.light);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), ThemeMode.light.toString());
  });

  test('it_should_toggle_theme_twice_returns_to_light', () async {
    SharedPreferences.setMockInitialValues({});

    final provider = ThemeProvider();
    await provider.setThemeMode(ThemeMode.light);
    await provider.toggleTheme();
    await provider.toggleTheme();

    expect(provider.themeMode, ThemeMode.light);
  });
}
