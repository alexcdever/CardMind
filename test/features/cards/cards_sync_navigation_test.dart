// input: 带同步异常状态的卡片页
// output: 验证异常处理跳转与编辑流程不阻断
// pos: 卡片同步交互测试；修改本文件需同步更新文件头与所属 DIR.md
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
