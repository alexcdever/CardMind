import 'package:cardmind/features/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('exposes pool entry from settings', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));

    expect(find.text('创建或加入数据池'), findsOneWidget);
  });

  testWidgets('navigates to pool page from settings entry', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));

    await tester.tap(find.text('创建或加入数据池'));
    await tester.pumpAndSettle();

    expect(find.text('创建池'), findsOneWidget);
    expect(find.text('扫码加入'), findsOneWidget);
  });
}
