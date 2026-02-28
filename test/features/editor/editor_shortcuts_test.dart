// input: test/features/editor/editor_shortcuts_test.dart 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Flutter 测试模块，验证 UI、交互守卫与文档门禁行为。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 测试模块，验证 UI、交互守卫与文档门禁行为。
import 'package:cardmind/features/editor/editor_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('saves with cmd/ctrl+s shortcut', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: EditorPage()));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pump();

    expect(find.text('本地已保存'), findsOneWidget);
  });
}
