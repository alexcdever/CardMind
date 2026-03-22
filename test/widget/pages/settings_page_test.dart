// input: 独立挂载内部 SettingsPage 页面。
// output: 保留最小内部页面契约，暴露稳定语义锚点且可正常渲染。
// pos: 覆盖设置页内部占位契约，避免其继续承担公开主导航职责。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/features/settings/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('settings page exposes minimal internal page anchor', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
    await tester.pumpAndSettle();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.bySemanticsLabel('设置页'), findsWidgets);
    expect(find.byKey(const ValueKey('settings.page')), findsOneWidget);
  });
}
