// input: 健康态与异常态下的同步横幅组件
// output: 验证反馈展示与查看动作行为
// pos: 同步横幅组件测试；修改本文件需同步更新文件头与所属 DIR.md
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

    expect(find.textContaining('同步'), findsOneWidget);
  });

  testWidgets('invokes view callback when tapping error action', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: SyncBanner(
          status: const SyncStatus.error('REQUEST_TIMEOUT'),
          onView: () {
            tapped = true;
          },
        ),
      ),
    );

    await tester.tap(find.text('查看'));
    await tester.pump();

    expect(tapped, true);
  });

  testWidgets(
    'sync error banner has view action that navigates to handling page',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return SyncBanner(
                status: const SyncStatus.error('REQUEST_TIMEOUT'),
                onView: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(
                        body: Center(child: Text('pool-error-page')),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('查看'));
      await tester.pumpAndSettle();

      expect(find.text('pool-error-page'), findsOneWidget);
    },
  );
}
