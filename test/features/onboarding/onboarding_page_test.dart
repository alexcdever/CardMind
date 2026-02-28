// input: test/features/onboarding/onboarding_page_test.dart 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Flutter 测试模块，验证 UI、交互守卫与文档门禁行为。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 测试模块，验证 UI、交互守卫与文档门禁行为。
import 'package:cardmind/features/onboarding/onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows only two primary actions', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingPage()));

    expect(find.text('先本地使用'), findsOneWidget);
    expect(find.text('创建或加入数据池'), findsOneWidget);
    expect(find.text('稍后再说'), findsNothing);
  });

  testWidgets('tapping local mode enters cards page', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingPage()));

    await tester.tap(find.text('先本地使用'));
    await tester.pumpAndSettle();

    expect(find.text('搜索卡片'), findsOneWidget);
  });

  testWidgets('tapping pool mode enters pool page', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingPage()));

    await tester.tap(find.text('创建或加入数据池'));
    await tester.pumpAndSettle();

    expect(find.text('创建池'), findsOneWidget);
    expect(find.text('扫码加入'), findsOneWidget);
  });
}
