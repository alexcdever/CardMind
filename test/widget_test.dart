// input: 启动 CardMindApp 并等待首屏渲染结果。
// output: 首屏呈现引导入口或卡片页入口之一。
// pos: 覆盖应用冷启动分流可见性，防止首屏断流。修改本文件需同步更新文件头与所属 DIR.md。
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
