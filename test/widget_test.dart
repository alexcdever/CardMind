// input: test/widget_test.dart 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Flutter 测试模块，验证 UI、交互守卫与文档门禁行为。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 测试模块，验证 UI、交互守卫与文档门禁行为。
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
