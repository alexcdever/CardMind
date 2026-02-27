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
}
