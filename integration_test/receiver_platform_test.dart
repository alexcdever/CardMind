import 'dart:io';

import 'package:cardmind/bridge/debug_log.dart';
import 'package:cardmind/bridge/sync_scheduler.dart';
import 'package:cardmind/src/rust/api.dart' as api;
import 'package:cardmind/src/rust/frb_generated.dart';
import 'package:cardmind/src/rust/store.dart';
import 'package:cardmind/src/rust/sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// 任务 P 验收 16/17：真实平台（Windows 桌面 / Android 模拟器）回归。
///
/// 复现缺陷现场：应用真实接线（FrbSyncApi + 真实 ConnectivityPlusMonitor +
/// SyncScheduler）启动 → `receiver.start` 成功 → 等待真实 60s 周期 Timer 至少
/// 触发两次 `sync.cycle`。缺陷修复前：startReceiver 按值消费 `_store` RustArc，
/// 下一周期 `runSyncCycle` 抛 DroppableDisposedException（日志
/// `sync.cycle ok=false error=DroppableDisposedException`）。
/// 修复后：`receiver.start action=success` + ≥2 次 `sync.cycle ok=true`，无 disposed。
///
/// 运行：`flutter test integration_test/receiver_platform_test.dart -d windows`
/// 或 `-d emulator-5554`（Android 需先清除 HTTP_PROXY/HTTPS_PROXY/ALL_PROXY）。

class _CaptureSink implements DebugSink {
  final List<DebugEvent> events = [];

  @override
  void emit(DebugEvent event) => events.add(event);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'real platform: receiver.start success + at least two periodic sync.cycle without disposed',
    (tester) async {
      await RustLib.init();
      final capture = _CaptureSink();
      DebugLogger.instance.setSink(capture);
      DebugLogger.instance.setPlatform(Platform.operatingSystem);

      final dir = Directory.systemTemp.createTempSync('cardmind_platform_');
      late SyncService svc;
      late NoteStore store;
      try {
        svc = await api.createPersistentSyncService(path: dir.path);
        store = await api.createNoteStore(path: '${dir.path}/cardmind.db');
      } catch (e) {
        fail('平台初始化失败（真实 Rust DLL 未加载？）：$e');
      }

      final scheduler = SyncScheduler(
        monitor: ConnectivityPlusMonitor(),
        api: FrbSyncApi(svc, store),
      );
      await scheduler.start();

      // 等待 receiver.start 事件出现（调度器 fire-and-forget 启动接收器）
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        final started = capture.events
            .where((e) => e.event == 'receiver.start')
            .toList();
        if (started.isNotEmpty) break;
      }
      final receiverStartEvents = capture.events
          .where((e) => e.event == 'receiver.start')
          .toList();
      expect(
        receiverStartEvents,
        isNotEmpty,
        reason: '真实平台启动后应产生 receiver.start 事件',
      );
      expect(
        receiverStartEvents.last.fields['action'],
        'success',
        reason: 'receiver.start 必须 success（不得在接收器启动路径消费 store）',
      );

      // 等待真实 60s 周期 Timer 触发至少两次 sync.cycle（缺陷现场：第二周期抛 disposed）
      final cycleDeadline = DateTime.now().add(const Duration(seconds: 170));
      while (DateTime.now().isBefore(cycleDeadline)) {
        await Future<void>.delayed(const Duration(seconds: 1));
        final cycles = capture.events
            .where((e) => e.event == 'sync.cycle')
            .toList();
        if (cycles.length >= 2) break;
      }
      final cycleEvents = capture.events
          .where((e) => e.event == 'sync.cycle')
          .toList();
      expect(
        cycleEvents.length,
        greaterThanOrEqualTo(2),
        reason: '真实周期 Timer 应至少触发两次 sync.cycle',
      );

      for (final e in cycleEvents) {
        expect(
          e.fields['ok'],
          'true',
          reason: '周期 sync.cycle 不得失败（缺陷现场为 DroppableDisposedException）',
        );
        expect(e.error, isNull, reason: '周期 sync.cycle 不得携带错误');
        expect(
          '${e.error} ${e.errorChain}',
          isNot(contains('DroppableDisposedException')),
          reason: '任何周期都不得出现 DroppableDisposedException',
        );
      }
      expect(
        store.isDisposed,
        isFalse,
        reason: '真实平台周期同步后 Store RustArc 必须仍可用',
      );

      // 清理：停止调度器（fire-and-forget 内部 stopReceiver），等待接收任务退出
      // （释放 store clone）后再释放 Rust 对象，避免 dispose 顺序竞争产生噪声。
      scheduler.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 800));
      try {
        await api.stopReceiver(svc: svc);
      } catch (_) {}
      for (var i = 0; i < 20 && await api.receiverRunning(svc: svc); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      if (!store.isDisposed) store.dispose();
      if (!svc.isDisposed) svc.dispose();
      try {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      } catch (_) {}
      DebugLogger.instance.resetSink();
      DebugLogger.instance.resetPlatform();
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
