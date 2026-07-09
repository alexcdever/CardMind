import 'package:flutter_test/flutter_test.dart';
import 'package:v2/main.dart';

void main() {
  testWidgets('App renders note list page', (tester) async {
    // 先初始化
    await tester.pumpWidget(const CardMindApp());
    await tester.pumpAndSettle();

    // 验证标题出现
    expect(find.text('CardMind'), findsOneWidget);
  });
}
