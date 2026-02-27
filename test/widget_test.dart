import 'package:flutter_test/flutter_test.dart';

import 'package:cardmind/app/app.dart';

void main() {
  testWidgets('app boots into onboarding or cards flow', (tester) async {
    await tester.pumpWidget(const CardMindApp());

    final onboarding = find.text('先本地使用').evaluate().isNotEmpty;
    final cards = find.text('搜索卡片').evaluate().isNotEmpty;

    expect(onboarding || cards, true);
  });
}
