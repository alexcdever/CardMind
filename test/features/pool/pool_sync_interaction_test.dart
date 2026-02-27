// input: 数据池页面同步错误态
// output: retry/reconnect 交互触发控制器动作
// pos: 池页面同步交互测试；修改需同步更新文件头与所属 DIR.md
import 'package:cardmind/features/pool/pool_controller.dart';
import 'package:cardmind/features/pool/pool_page.dart';
import 'package:cardmind/features/pool/pool_state.dart';
import 'package:cardmind/features/sync/sync_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _SpyPoolController extends PoolController {
  _SpyPoolController()
    : super(
        initialState: const PoolState.error('REQUEST_TIMEOUT'),
        initialSyncStatus: const SyncStatus.error('REQUEST_TIMEOUT'),
      );

  int retryCalls = 0;
  int reconnectCalls = 0;

  @override
  Future<void> retrySync() async {
    retryCalls += 1;
  }

  @override
  Future<void> reconnectSync() async {
    reconnectCalls += 1;
  }
}

void main() {
  testWidgets('sync error should show retry and reconnect actions', (
    tester,
  ) async {
    final controller = _SpyPoolController();

    await tester.pumpWidget(
      MaterialApp(
        home: PoolPage(
          state: const PoolState.error('REQUEST_TIMEOUT'),
          controller: controller,
        ),
      ),
    );

    expect(find.text('重试同步'), findsOneWidget);
    expect(find.text('重新连接'), findsOneWidget);

    await tester.tap(find.text('重试同步'));
    await tester.pump();
    await tester.tap(find.text('重新连接'));
    await tester.pump();

    expect(controller.retryCalls, 1);
    expect(controller.reconnectCalls, 1);
  });
}
