import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardmind/main.dart';

void main() {
  testWidgets('desktop renders the three-pane note workspace', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CardMindApp());
    await tester.pumpAndSettle();

    expect(find.text('CardMind'), findsOneWidget);
    expect(find.text('新建笔记'), findsOneWidget);
    expect(find.text('全部笔记'), findsOneWidget);
    expect(find.text('选择一篇笔记'), findsOneWidget);
  });

  testWidgets('mobile renders the simple two-tab shell', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const CardMindApp());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('设备'), findsOneWidget);
    expect(find.byTooltip('新建笔记'), findsOneWidget);

    await tester.tap(find.text('设备'));
    await tester.pumpAndSettle();

    expect(find.text('暂无已连接设备'), findsOneWidget);
    expect(find.byTooltip('新建笔记'), findsNothing);
  });
}
