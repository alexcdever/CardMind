// input: 启动 CardMindApp 并等待首屏渲染结果。
// output: 首屏直接呈现卡片页并且不再显示引导入口。
// pos: 覆盖应用冷启动首屏直达卡片契约，防止回退到引导分流。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:flutter_test/flutter_test.dart';

import 'package:cardmind/app/app.dart';

void main() {
  testWidgets('app boots directly into shell cards section', (tester) async {
    await tester.pumpWidget(const CardMindApp());

    expect(find.text('搜索卡片'), findsOneWidget);
    expect(find.text('先本地使用'), findsNothing);
  });
}
