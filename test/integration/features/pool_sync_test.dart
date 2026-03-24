// input: 在池页同步错误态点击“重试同步”和“重新连接”操作。
// output: 控制器 retrySync 与 reconnectSync 调用计数递增。
// pos: 覆盖池页与同步控制器动作连线，防止错误恢复按钮失灵。修改本文件需同步更新文件头与所属 DIR.md。
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
    expect(find.byType(MaterialBanner), findsNothing);

    await tester.tap(find.text('重试同步'));
    await tester.pump();
    await tester.tap(find.text('重新连接'));
    await tester.pump();

    expect(controller.retryCalls, 1);
    expect(controller.reconnectCalls, 1);
  });

  testWidgets('pool degraded feedback stays local without material banner', (
    tester,
  ) async {
    final controller = PoolController(
      initialState: const PoolState.joined(),
      initialSyncStatus: const SyncStatus.degraded(
        'REQUEST_TIMEOUT',
        isWriteSaved: true,
        continuityState: ContinuityState.samePath,
        contentState: 'content_safe_local_only',
        nextAction: 'reconnect',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PoolPage(state: controller.state, controller: controller),
      ),
    );

    expect(find.text('同步状态降级：仍在同一条延续路径'), findsOneWidget);
    expect(find.text('当前内容安全，可继续本地操作。'), findsOneWidget);
    expect(find.text('建议下一步：重新连接'), findsOneWidget);
    expect(find.text('重试同步'), findsOneWidget);
    expect(find.text('重新连接'), findsOneWidget);
    expect(find.byType(MaterialBanner), findsNothing);
  });

  testWidgets('retry action in partial cleanup keeps recovery visible', (
    tester,
  ) async {
    final controller = PoolController(
      initialState: const PoolState.joined(exitShouldFail: true),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PoolPage(state: controller.state, controller: controller),
      ),
    );

    await tester.tap(find.text('退出池'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认退出'));
    await tester.pumpAndSettle();

    expect(find.text('部分清理失败'), findsOneWidget);
    expect(find.text('重试清理'), findsOneWidget);

    await tester.tap(find.text('重试清理'));
    await tester.pumpAndSettle();

    expect(find.text('创建池'), findsOneWidget);
    expect(find.text('扫码加入'), findsOneWidget);
  });
}
