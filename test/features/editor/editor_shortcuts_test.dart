// input: 在编辑页发送 Ctrl+S 键盘快捷键事件。
// output: 触发保存并显示“本地已保存”反馈文案。
// pos: 覆盖编辑器快捷键保存链路，防止桌面效率入口失效。修改本文件需同步更新文件头与所属 DIR.md。
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
