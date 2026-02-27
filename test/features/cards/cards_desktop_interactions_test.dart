// input: 桌面指针场景下的卡片页组件
// output: 断言右键交互可打开上下文菜单项
// pos: 卡片桌面交互回归测试；修改本文件需同步更新文件头与所属 DIR.md
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
