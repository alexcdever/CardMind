import 'package:cardmind/features/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('exposes pool entry from settings', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));

    expect(find.text('创建或加入数据池'), findsOneWidget);
  });
}
