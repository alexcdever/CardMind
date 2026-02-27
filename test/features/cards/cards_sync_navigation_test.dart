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

    expect(find.text('加入失败: REQUEST_TIMEOUT'), findsOneWidget);
  });
}
