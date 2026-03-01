// input: 在引导页点击“先本地使用”或“创建或加入数据池”按钮。
// output: 仅展示双主行动作并分别进入卡片页或池页。
// pos: 覆盖引导分流入口与去向正确性，防止首次路径偏航。修改本文件需同步更新文件头与所属 DIR.md。
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

  testWidgets('pool path can return to onboarding via system back', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingPage()));

    await tester.tap(find.text('创建或加入数据池'));
    await tester.pumpAndSettle();
    expect(find.text('创建池'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('创建或加入数据池'), findsOneWidget);
  });
}
