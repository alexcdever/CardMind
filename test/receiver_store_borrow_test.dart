import 'dart:async';
import 'dart:io';

import 'package:cardmind/bridge/debug_log.dart';
import 'package:cardmind/bridge/sync_scheduler.dart';
import 'package:cardmind/src/rust/api.dart' as api;
import 'package:cardmind/src/rust/frb_generated.dart';
import 'package:cardmind/src/rust/store.dart';
import 'package:cardmind/src/rust/sync.dart';
import 'package:flutter_test/flutter_test.dart';

/// 任务 P：start_receiver 不得消费 Store RustArc。
///
/// 缺陷：`start_receiver(svc: &SyncService, store: NoteStore)` 按值跨 FRB 边界，
/// 生成绑定把 Dart `_store` 视为 move/消费（`Auto_Owned` 编码），调用返回后
/// `_store` 已 disposed，下一次 `runSyncCycle(svc, store)` 抛
/// `DroppableDisposedException`（Windows + Android 双端复现）。
///
/// 全部用例使用真实生成绑定（RustLib.init + cardmind_backend dylib）与真实
/// RustArc；禁止用 fake SyncApi 代替缺陷回归（验收 3）。
///
/// 测试用网络监视器：恒允许同步（fake 仅用于注入网络状态，不替代 Rust API）。
class _FakeNetworkMonitor implements NetworkTypeMonitor {
  final _controller = StreamController<bool>.broadcast();

  @override
  Stream<bool> get allowedChanges => _controller.stream;

  @override
  Future<bool> currentAllowed() async => true;

  @override
  void dispose() {
    if (!_controller.isClosed) _controller.close();
  }
}

/// 捕获 DebugLogger 事件（断言周期同步真实结果，不依赖控制台文本）。
class _CaptureSink implements DebugSink {
  final List<DebugEvent> events = [];

  @override
  void emit(DebugEvent event) => events.add(event);
}

void main() {
  late Directory tempDir;
  late List<NoteStore> openedStores;
  late List<SyncService> openedServices;
  late _CaptureSink capture;

  setUpAll(() async {
    await RustLib.init();
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('cardmind_borrow_');
    openedStores = <NoteStore>[];
    openedServices = <SyncService>[];
    capture = _CaptureSink();
    DebugLogger.instance.setSink(capture);
    DebugLogger.instance.setPlatform('test');
    DebugLogger.instance.verbose = false;
  });

  tearDown(() async {
    DebugLogger.instance.resetSink();
    DebugLogger.instance.resetPlatform();
    // 先停接收器（有界 3s），再释放 RustArc，避免残留后台 task
    for (final svc in openedServices.reversed) {
      if (!svc.isDisposed) {
        try {
          await api.stopReceiver(svc: svc);
        } catch (_) {}
        // 等待接收器任务完全退出（释放其 store clone 后 SQLite 连接才关闭）。
        // 调度器 stop() 是 fire-and-forget，这里必须轮询到 receiver_running=false。
        try {
          for (var i = 0;
              i < 40 && await api.receiverRunning(svc: svc);
              i++) {
            await Future<void>.delayed(const Duration(milliseconds: 50));
          }
        } catch (_) {}
        svc.dispose();
      }
    }
    for (final store in openedStores.reversed) {
      if (!store.isDisposed) store.dispose();
    }
    for (final entity in tempDir.listSync(recursive: true)) {
      if (entity is File) entity.deleteSync();
    }
    tempDir.deleteSync(recursive: true);
  });

  Future<SyncService> newService() async {
    final svc = await api.createSyncService();
    openedServices.add(svc);
    return svc;
  }

  Future<NoteStore> newStore(String name) async {
    final store = await api.createNoteStore(path: '${tempDir.path}/$name');
    openedStores.add(store);
    return store;
  }

  /// 等待事件循环推进（让 fire-and-forget 的接收器启动完成）。
  Future<void> pump() async {
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  // ━━ 验收 1/6：start_receiver 不消费 Store RustArc ━━

  test('start_receiver does not consume store RustArc', () async {
    final svc = await newService();
    final store = await newStore('a.db');

    await api.startReceiver(svc: svc, store: store);
    expect(store.isDisposed, isFalse, reason: 'startReceiver 不得消费 Store RustArc');

    // start 后至少连续调用 3 个使用同一 Store 的 API，均不得抛 disposed
    final paired = await api.listPairedDevices(store: store);
    expect(paired, isEmpty);
    final rows = await api.storeList(store: store);
    expect(rows, isEmpty);
    final result = await api.runSyncCycle(svc: svc, store: store);
    expect(result, isNotNull);
    expect(store.isDisposed, isFalse, reason: '周期同步后 Store 仍不得被消费');

    await api.stopReceiver(svc: svc);
    expect(store.isDisposed, isFalse);
  });

  // ━━ 验收 2/7：start 后周期 cycle 不抛 disposed（SyncScheduler 真实 FRB API）━━

  test('start_receiver then periodic cycle does not dispose store', () async {
    final svc = await newService();
    final store = await newStore('b.db');
    final frbApi = FrbSyncApi(svc, store);
    final monitor = _FakeNetworkMonitor();
    final scheduler = SyncScheduler(monitor: monitor, api: frbApi);

    await scheduler.start();
    await pump(); // 让 _startReceiverQuietly → api.startReceiver() 完成
    expect(store.isDisposed, isFalse, reason: '调度器启动接收器后 Store 不得被消费');

    // 运行一个完整同步周期（SyncScheduler.syncNow 内部 runSyncCycle(store)）
    await scheduler.syncNow();
    expect(store.isDisposed, isFalse, reason: 'start 后首个周期不得抛 disposed');

    // 第二个周期（真实缺陷在"下一周期"暴露）
    await scheduler.syncNow();
    expect(store.isDisposed, isFalse, reason: '第二个周期 Store 仍可用');

    // 周期同步日志必须成功（ok=true），不得出现 DroppableDisposedException
    final cycleEvents =
        capture.events.where((e) => e.event == 'sync.cycle').toList();
    expect(cycleEvents, isNotEmpty, reason: '应记录至少一个周期同步事件');
    for (final e in cycleEvents) {
      expect(e.fields['ok'], 'true', reason: '周期同步不得失败为 disposed');
      expect(e.error, isNull, reason: '周期同步不得携带 disposed 错误');
      expect('${e.error} ${e.errorChain}', isNot(contains('DroppableDisposedException')));
    }

    scheduler.stop();
    // scheduler.stop() 的 _stopReceiverQuietly 是 fire-and-forget；接收器任务
    // 在 ≤300ms accept 窗口结束后退出并释放 store clone。等待其完全退出，
    // 否则 tearDown 时 SQLite 连接仍被接收任务持有、临时文件无法删除。
    await Future<void>.delayed(const Duration(milliseconds: 800));
    monitor.dispose();
  });

  // ━━ 验收 8：stop 后同一 Store 仍可查询/写入 ━━

  test('receiver stop then store reuse', () async {
    final svc = await newService();
    final store = await newStore('c.db');

    await api.startReceiver(svc: svc, store: store);
    expect(store.isDisposed, isFalse);

    await api.stopReceiver(svc: svc);
    expect(store.isDisposed, isFalse, reason: 'stopReceiver 不得释放 Store');

    // 查询
    expect(await api.storeList(store: store), isEmpty);
    // 写入：create → 投影 → 读回
    await api.noteCreate(svc: svc, id: 'reuse-1', content: '# Reuse\n\nbody');
    await api.syncNotesToStore(svc: svc, store: store);
    final rows = await api.storeList(store: store);
    expect(rows.length, 1);
    expect(rows.first.id, 'reuse-1');
    expect(store.isDisposed, isFalse);
  });

  // ━━ 验收 9：重复 start 幂等且 Store 可复用 ━━

  test('receiver repeated start is idempotent and store reusable', () async {
    final svc = await newService();
    final store = await newStore('d.db');

    await api.startReceiver(svc: svc, store: store);
    expect(store.isDisposed, isFalse);
    expect(await api.receiverRunning(svc: svc), isTrue);

    // 第二次 start：幂等成功，不得消费/释放 Store
    await api.startReceiver(svc: svc, store: store);
    expect(store.isDisposed, isFalse, reason: '重复 start 不得消费 Store');
    expect(await api.receiverRunning(svc: svc), isTrue);

    // 第三次 start 后再用同一 Store
    await api.startReceiver(svc: svc, store: store);
    expect(await api.storeList(store: store), isEmpty);
    expect(await api.listPairedDevices(store: store), isEmpty);
    expect(store.isDisposed, isFalse);

    await api.stopReceiver(svc: svc);
    expect(await api.receiverRunning(svc: svc), isFalse);
    expect(store.isDisposed, isFalse, reason: '停止后 Store 仍未被释放');
    expect(await api.storeList(store: store), isEmpty);
  });

  // ━━ 验收 10：receiver 失败/生命周期错误不 dispose Store ━━
  //
  // 说明：`start_receiver`（Rust 侧）对合法输入无可达的 Err 路径——接收任务
  // 启动只 clone store + spawn，不触碰 SQLite。故验收 10 的回归点是：无论
  // start/stop/周期同步成功或失败，Store RustArc 都不得被消费（借用语义）。
  // 本用例覆盖完整生命周期：start → stop → cycle → 查询 → 写入。

  test('receiver failure does not dispose store', () async {
    final svc = await newService();
    final store = await newStore('e.db');

    await api.startReceiver(svc: svc, store: store);
    expect(store.isDisposed, isFalse, reason: 'start 成功路径不得消费 Store');

    // 接收器生命周期错误场景：停止接收器（有界等待），Store 必须保持可用
    await api.stopReceiver(svc: svc);
    expect(store.isDisposed, isFalse, reason: 'stop 路径不得消费 Store');

    // 周期同步（无对端时正常返回结果；任何错误也不得吞掉 Store）
    final result = await api.runSyncCycle(svc: svc, store: store);
    expect(result, isNotNull);
    expect(store.isDisposed, isFalse, reason: 'cycle 返回/出错路径不得消费 Store');

    // Store 仍可查询与写入
    expect(await api.storeList(store: store), isEmpty);
    await api.noteCreate(svc: svc, id: 'after-fail', content: 'keep');
    await api.syncNotesToStore(svc: svc, store: store);
    final rows = await api.storeList(store: store);
    expect(rows.length, 1);
    expect(rows.first.id, 'after-fail');
    expect(store.isDisposed, isFalse);
  });
}
