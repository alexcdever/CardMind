import 'package:cardmind/features/sync/sync_banner.dart';
import 'package:cardmind/features/sync/sync_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows subtle label in healthy status', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SyncBanner(status: SyncStatus.healthy())),
    );

    expect(find.text('本地已保存'), findsOneWidget);
  });

  testWidgets('shows highlighted warning in error status', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SyncBanner(status: SyncStatus.error('REQUEST_TIMEOUT')),
      ),
    );

    expect(find.textContaining('同步异常'), findsOneWidget);
  });
}
