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
