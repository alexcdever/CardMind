// input: 以同步错误状态进入卡片页并触发“查看”与“新增”操作。
// output: 可跳转到池错误处理页且不阻断进入编辑页。
// pos: 覆盖同步异常下的导航与可编辑性保障，防止降级阻塞。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/features/cards/cards_page.dart';
import 'package:cardmind/features/sync/sync_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('error banner view action routes to pool error page', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CardsPage(syncStatus: SyncStatus.error('REQUEST_TIMEOUT')),
      ),
    );

    await tester.tap(find.text('查看'));
    await tester.pumpAndSettle();

    expect(find.textContaining('加入失败:'), findsOneWidget);
    expect(find.text('立即重试'), findsOneWidget);
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
}
