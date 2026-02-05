import 'package:cardmind/widgets/settings_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('it_should_render_settings_panel', (
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
}
