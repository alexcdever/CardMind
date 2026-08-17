import 'dart:async';
import 'dart:io';

import 'package:cardmind/bridge/frb_note_repository.dart';
import 'package:cardmind/bridge/sync_scheduler.dart';
import 'package:cardmind/src/rust/frb_generated.dart';
import 'package:flutter_test/flutter_test.dart';

/// 任务 H 验收 7/8：
/// 7. scheduler responds to connectivity — sync_scheduler 在 connectivity 变化时
///    正确调用 setSyncAllowed（fake connectivity 注入）
/// 8. repository save triggers background push — repository 保存后调度器被触发
///   （fake 调度器记录调用）

// ━━ fakes ━━

class FakeNetworkMonitor implements NetworkTypeMonitor {
  final _controller = StreamController<bool>.broadcast();

  @override
  Stream<bool> get allowedChanges => _controller.stream;

  @override
  Future<bool> currentAllowed() async => true;

  @override
  void dispose() {
    if (!_controller.isClosed) _controller.close();
  }

  void emit(bool allowed) => _controller.add(allowed);
}

class FakeSyncApi implements SyncApi {
  final List<bool> setSyncAllowedCalls = [];
  int pushPendingCalls = 0;
  int runSyncCycleCalls = 0;
  int startReceiverCalls = 0;
  int stopReceiverCalls = 0;

  @override
  Future<int> get pollIntervalSecs async => 60;

  @override
  Future<int> pendingCount() async => 0;

  @override
  Future<void> setSyncAllowed(bool allowed) async {
    setSyncAllowedCalls.add(allowed);
  }

  @override
  Future<void> pushPending() async {
    pushPendingCalls++;
  }

  @override
  Future<void> runSyncCycle() async {
    runSyncCycleCalls++;
  }

  @override
  Future<void> startReceiver() async {
    startReceiverCalls++;
  }

  @override
  Future<void> stopReceiver() async {
    stopReceiverCalls++;
  }
}

class FakeSyncScheduler {
  int noteEditedCalls = 0;
  void noteEdited() => noteEditedCalls++;
}

void main() {
  setUpAll(RustLib.init);

  // ━━ 验收 7：scheduler responds to connectivity ━━

  test('scheduler calls setSyncAllowed when connectivity changes', () async {
    final monitor = FakeNetworkMonitor();
    final api = FakeSyncApi();
    final scheduler = SyncScheduler(monitor: monitor, api: api);
    await scheduler.start();
    addTearDown(() {
      scheduler.stop();
      monitor.dispose();
    });

    // 初始：currentAllowed()=true → 启动即允许
    await Future<void>.delayed(Duration.zero);
    expect(api.setSyncAllowedCalls, isNotEmpty, reason: '启动时应同步一次当前网络状态');
    expect(api.setSyncAllowedCalls.last, isTrue);

    // 蜂窝（false）→ 调用 setSyncAllowed(false)
    monitor.emit(false);
    await Future<void>.delayed(Duration.zero);
    expect(api.setSyncAllowedCalls.last, isFalse, reason: '蜂窝应暂停同步');

    // WiFi（true）→ 调用 setSyncAllowed(true)
    monitor.emit(true);
    await Future<void>.delayed(Duration.zero);
    expect(api.setSyncAllowedCalls.last, isTrue, reason: 'WiFi 应恢复同步');
  });

  // ━━ 验收 8：repository save triggers background push ━━

  test('repository save triggers scheduler noteEdited', () async {
    final dir = await Directory.systemTemp.createTemp('cardmind_sync_');
    final scheduler = FakeSyncScheduler();
    final repository = await FrbNoteRepository.open(
      dataDirectory: dir.path,
      onLocalChange: scheduler.noteEdited,
    );
    addTearDown(() {
      repository.close();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    await repository.createNote('a', '# A\n\nbody');
    expect(scheduler.noteEditedCalls, 1, reason: 'createNote 后应触发调度器');

    await repository.updateMetadata('a', ['work']);
    expect(scheduler.noteEditedCalls, 2, reason: 'updateMetadata 后应触发调度器');

    await repository.softDelete('a');
    expect(scheduler.noteEditedCalls, 3, reason: 'softDelete 后应触发调度器');

    await repository.restore('a');
    expect(scheduler.noteEditedCalls, 4, reason: 'restore 后应触发调度器');

    await repository.purge('a');
    expect(scheduler.noteEditedCalls, 5, reason: 'purge 后应触发调度器');
  });

  // ━━ 任务 O：调度器启动/停止时启动/停止持续接收器 ━━

  test('scheduler starts receiver on start and stops on stop', () async {
    final monitor = FakeNetworkMonitor();
    final api = FakeSyncApi();
    final scheduler = SyncScheduler(monitor: monitor, api: api);
    await scheduler.start();
    // start() 异步 fire-and-forget 启动接收器（_startReceiverQuietly）
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(api.startReceiverCalls, 1, reason: '调度器启动应启动持续接收器');
    expect(api.stopReceiverCalls, 0, reason: '启动阶段不应停止接收器');

    scheduler.stop();
    // stop() 异步 fire-and-forget 停止接收器（_stopReceiverQuietly）
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(api.stopReceiverCalls, 1, reason: '调度器停止应停止持续接收器');

    monitor.dispose();
  });

  test('scheduler start is idempotent for receiver', () async {
    final monitor = FakeNetworkMonitor();
    final api = FakeSyncApi();
    final scheduler = SyncScheduler(monitor: monitor, api: api);
    await scheduler.start();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    final first = api.startReceiverCalls;
    // 重复 start：Rust 侧幂等（Dart 侧也只会再次调用 startReceiver，
    // Rust 端已运行的接收器不重复创建）
    await scheduler.start();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(
      api.startReceiverCalls,
      first + 1,
      reason: '重复 start 仍调用 startReceiver（Rust 幂等）',
    );
    scheduler.stop();
    monitor.dispose();
  });
}
