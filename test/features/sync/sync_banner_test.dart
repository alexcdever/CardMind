// input: test/features/sync/sync_banner_test.dart 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Flutter 测试模块，验证 UI、交互守卫与文档门禁行为。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 测试模块，验证 UI、交互守卫与文档门禁行为。
import 'package:cardmind/features/sync/sync_banner.dart';
import 'package:cardmind/features/sync/sync_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sync error should show retry and reconnect actions', (
    tester,
  ) async {
    var retryTapped = false;
    var reconnectTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: SyncBanner(
          status: const SyncStatus.error('REQUEST_TIMEOUT'),
          onRetry: () {
            retryTapped = true;
          },
          onReconnect: () {
            reconnectTapped = true;
          },
        ),
      ),
    );

    expect(find.text('重试同步'), findsOneWidget);
    expect(find.text('重新连接'), findsOneWidget);

    await tester.tap(find.text('重试同步'));
    await tester.pump();
    await tester.tap(find.text('重新连接'));
    await tester.pump();

    expect(retryTapped, isTrue);
    expect(reconnectTapped, isTrue);
  });

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

    expect(find.text('同步请求超时，请查看并处理'), findsOneWidget);
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
