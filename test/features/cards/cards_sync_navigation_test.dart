// input: 以同步异常状态进入卡片页并触发新增、保存等本地操作。
// output: 卡片页不展示全局同步横幅，且本地编辑保存不被阻断。
// pos: 覆盖主页重设计下卡片域去全局同步反馈后的本地可用性。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/features/cards/cards_page.dart';
import 'package:cardmind/features/sync/sync_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('cards page does not show sync banner in homepage redesign', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CardsPage(syncStatus: SyncStatus.error('REQUEST_TIMEOUT')),
      ),
    );

    expect(find.byType(MaterialBanner), findsNothing);
    expect(find.text('查看'), findsNothing);
  });

  testWidgets('sync error does not block creating/editing note', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CardsPage(syncStatus: SyncStatus.error('REQUEST_TIMEOUT')),
      ),
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('编辑卡片'), findsOneWidget);
  });

  testWidgets('degraded sync remains non-blocking for local save flow', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CardsPage(syncStatus: SyncStatus.degraded('REQUEST_TIMEOUT')),
      ),
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.labelText == '标题',
      ),
      'degraded local save',
    );
    await tester.tap(find.byIcon(Icons.save_outlined));
    await tester.pumpAndSettle();

    expect(find.text('degraded local save'), findsOneWidget);
  });
}
