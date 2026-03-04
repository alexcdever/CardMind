// input: 在 CardMindApp 冷启动后观察主壳导航与返回行为。
// output: 断言首屏即进入主工作台并展示底部导航与三个导航标签。
// pos: 应用壳层导航测试，覆盖首屏直达 shell 的主路径。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/app/app.dart';
import 'package:cardmind/app/navigation/app_section.dart';
import 'package:cardmind/app/navigation/app_shell_controller.dart';
import 'package:cardmind/app/navigation/app_shell_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app cold start shows shell bottom nav on mobile', (
    tester,
  ) async {
    await tester.pumpWidget(const CardMindApp());
    await tester.pumpAndSettle();

    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('搜索卡片'), findsOneWidget);
    expect(find.text('卡片'), findsWidgets);
    expect(find.text('数据池'), findsWidgets);
    expect(find.text('设置'), findsWidgets);
  });

  testWidgets('back on non-cards tab switches to cards first', (tester) async {
    final controller = AppShellController(initialSection: AppSection.pool);
    await tester.pumpWidget(
      MaterialApp(home: AppShellPage(controller: controller)),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(controller.section, AppSection.cards);
  });

  testWidgets(
    'after pool joined, go-to-cards action switches shell section to cards',
    (tester) async {
      final controller = AppShellController(initialSection: AppSection.pool);
      await tester.pumpWidget(
        MaterialApp(home: AppShellPage(controller: controller)),
      );

      await tester.tap(find.text('创建池'));
      await tester.pumpAndSettle();
      expect(find.text('去卡片'), findsOneWidget);

      await tester.tap(find.text('去卡片'));
      await tester.pumpAndSettle();

      expect(controller.section, AppSection.cards);
      expect(find.text('搜索卡片'), findsOneWidget);
    },
  );

  testWidgets('back on cards shows exit confirmation dialog', (tester) async {
    final controller = AppShellController(initialSection: AppSection.cards);
    await tester.pumpWidget(
      MaterialApp(home: AppShellPage(controller: controller)),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('是否退出应用？'), findsOneWidget);
    expect(find.text('是'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
  });

  testWidgets('selecting 取消 closes confirmation and stays on cards', (
    tester,
  ) async {
    final controller = AppShellController(initialSection: AppSection.cards);
    await tester.pumpWidget(
      MaterialApp(home: AppShellPage(controller: controller)),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(controller.section, AppSection.cards);
    expect(find.text('是否退出应用？'), findsNothing);
  });
}
