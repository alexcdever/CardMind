// input: 在 CardMindApp 中完成 onboarding 本地入口点击流程。
// output: 断言进入主工作台后展示底部导航与三个导航标签。
// pos: 应用壳层导航测试，覆盖 onboarding 到 shell 的主路径。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/app/app.dart';
import 'package:cardmind/app/navigation/app_section.dart';
import 'package:cardmind/app/navigation/app_shell_controller.dart';
import 'package:cardmind/app/navigation/app_shell_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'after onboarding local entry, app shows shell bottom nav on mobile',
    (tester) async {
      await tester.pumpWidget(const CardMindApp());
      await tester.tap(find.text('先本地使用'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.text('卡片'), findsWidgets);
      expect(find.text('数据池'), findsWidgets);
      expect(find.text('设置'), findsWidgets);
    },
  );

  testWidgets('back on non-cards tab switches to cards first', (tester) async {
    final controller = AppShellController(initialSection: AppSection.pool);
    await tester.pumpWidget(
      MaterialApp(home: AppShellPage(controller: controller)),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(controller.section, AppSection.cards);
  });

  testWidgets('back on cards shows exit confirmation dialog', (tester) async {
    final controller = AppShellController(initialSection: AppSection.cards);
    await tester.pumpWidget(
      MaterialApp(home: AppShellPage(controller: controller)),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('是否退出应用？'), findsOneWidget);
    expect(find.text('是'), findsOneWidget);
    expect(find.text('否'), findsOneWidget);
  });

  testWidgets('selecting 否 closes confirmation and stays on cards', (
    tester,
  ) async {
    final controller = AppShellController(initialSection: AppSection.cards);
    await tester.pumpWidget(
      MaterialApp(home: AppShellPage(controller: controller)),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('否'));
    await tester.pumpAndSettle();

    expect(controller.section, AppSection.cards);
    expect(find.text('是否退出应用？'), findsNothing);
  });
}
