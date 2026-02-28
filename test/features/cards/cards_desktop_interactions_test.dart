// input: 在卡片页以鼠标右键执行 secondary tap 手势。
// output: 弹出启用状态的上下文菜单项。
// pos: 覆盖桌面端右键交互通路，防止上下文操作失效。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/features/cards/cards_page.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens context menu on secondary tap', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CardsPage()));

    final gesture = await tester.startGesture(
      const Offset(40, 120),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) => widget is PopupMenuItem<void> && widget.enabled,
      ),
      findsOneWidget,
    );
  });
}
