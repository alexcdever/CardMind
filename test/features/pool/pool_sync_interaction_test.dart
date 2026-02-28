// input: test/features/pool/pool_sync_interaction_test.dart 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Flutter 测试模块，验证 UI、交互守卫与文档门禁行为。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 测试模块，验证 UI、交互守卫与文档门禁行为。
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
