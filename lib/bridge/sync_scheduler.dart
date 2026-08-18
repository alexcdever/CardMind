import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../src/rust/api.dart' as api;
import '../src/rust/store.dart';
import '../src/rust/sync.dart';
import 'debug_log.dart';

/// 网络类型监听抽象（测试注入 fake）。
///
/// `allowedChanges` 每 500ms 以上粒度推送当前"是否允许同步"：
/// true = WiFi / 以太网（允许），false = 蜂窝（暂停，决策 6）。
abstract interface class NetworkTypeMonitor {
  /// 同步允许状态变化流
  Stream<bool> get allowedChanges;

  /// 当前是否允许同步
  Future<bool> currentAllowed();

  void dispose();
}

/// Rust 同步能力抽象（测试注入 fake）。
abstract interface class SyncApi {
  /// 周期拉取间隔（秒），来自 Rust 侧 `SYNC_POLL_INTERVAL_SECS`。
  Future<int> get pollIntervalSecs;

  /// 设置同步开关（决策 6 能力）。
  Future<void> setSyncAllowed(bool allowed);

  /// 推送待办（编辑保存即推送；失败静默，不抛错）。
  Future<void> pushPending();

  /// 周期同步任务体：push 给所有对端 + 短窗口 accept 对端 push。
  Future<void> runSyncCycle();

  /// 启动被动接收器（任务 O）：持续 accept 对端 push，收到即 import/投影/last_seen。
  /// 幂等：重复调用不产生第二个接收器。
  Future<void> startReceiver();

  /// 停止被动接收器（幂等；3 秒内返回，不留下永久 task）。
  Future<void> stopReceiver();

  /// 当前待同步笔记数（模块 5 状态指示器数据源）。
  Future<int> pendingCount();

  Future<int> receiverContentRevision();
}

/// connectivity_plus 实现：WiFi/以太网 → true（允许），蜂窝 → false（暂停）。
///
/// 桌面端（Windows）connectivity 通常报 wifi/ethernet/other → 恒 true（不限制）；
/// 平台不支持时保守允许（default true）。
class ConnectivityPlusMonitor implements NetworkTypeMonitor {
  final _connectivity = Connectivity();

  @override
  Stream<bool> get allowedChanges =>
      _connectivity.onConnectivityChanged.map(_allowedForType);

  @override
  Future<bool> currentAllowed() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return _allowedForType(result);
    } catch (_) {
      // 平台不支持 connectivity 时保守允许（桌面端不限制）
      return true;
    }
  }

  /// connectivity_plus 6.x：`checkConnectivity`/`onConnectivityChanged` 均为
  /// `List<ConnectivityResult>`。蜂窝（mobile）出现在列表 → 暂停；其余允许。
  static bool _allowedForType(List<ConnectivityResult> types) {
    if (types.contains(ConnectivityResult.mobile)) return false;
    return true;
  }

  @override
  void dispose() {}
}

/// FRB 实现：包装 Rust API。
class FrbSyncApi implements SyncApi {
  FrbSyncApi(this._sync, this._store);

  final SyncService _sync;
  final NoteStore _store;

  @override
  Future<int> get pollIntervalSecs => api.syncPollIntervalSecs();

  @override
  Future<void> setSyncAllowed(bool allowed) =>
      api.setSyncAllowed(svc: _sync, allowed: allowed);

  @override
  Future<void> pushPending() async {
    await api.pushPending(svc: _sync, store: _store);
  }

  @override
  Future<void> runSyncCycle() async {
    await api.runSyncCycle(svc: _sync, store: _store);
  }

  @override
  Future<void> startReceiver() async {
    await api.startReceiver(svc: _sync, store: _store);
  }

  @override
  Future<void> stopReceiver() async {
    await api.stopReceiver(svc: _sync);
  }

  @override
  Future<int> pendingCount() => api.pendingSyncCount(svc: _sync);

  @override
  Future<int> receiverContentRevision() async =>
      (await api.receiverContentRevision(svc: _sync)).toInt();
}

/// 自动同步调度器（任务 H + 任务 O 持续接收器）：
///
/// - **编辑保存即推送**（决策 4）：repository 保存成功后调用 [noteEdited]，
///   fire-and-forget 触发 `pushPending`（不阻塞编辑；失败静默，决策 18）。
/// - **周期拉取**（决策 4）：`Timer.periodic` 按 `SYNC_POLL_INTERVAL_SECS`
///   调 `runSyncCycle`（对等推拉：push 给所有对端 + 短窗口 accept 对端 push）。
/// - **持续接收器**（任务 O）：[start] 时启动 Rust 后台接收任务——不依赖周期
///   相位，A 任意时间 push，B 在 10 秒内 receive/import 并更新 last_seen；
///   [stop] 时停止（3 秒内返回，不留下永久 task）。
/// - **移动端 WiFi 条件**（决策 6）：监听 connectivity，蜂窝 → `setSyncAllowed(false)`
///   暂停推送与拉取；手动"立即同步"（模块 5）可调用 [pushNow] 无视限制。
///
/// 调度器不持有 Rust 对象生命周期（无 tokio spawn），由调用方保证
/// `api` 指向的 SyncService 在调度器运行期间存活。
class SyncScheduler {
  SyncScheduler({
    required this.monitor,
    required this.api,
    this.receiverPollInterval = const Duration(milliseconds: 300),
  });

  final NetworkTypeMonitor monitor;
  final SyncApi api;
  final Duration receiverPollInterval;
  Timer? _timer;
  Timer? _receiverTimer;
  StreamSubscription<bool>? _subscription;
  final _pendingCountController = StreamController<int>.broadcast();
  final _contentController = StreamController<int>.broadcast();
  int? _receiverRevision;
  bool _disposed = false;

  /// 待同步计数变化流（模块 5）：周期同步 / 编辑推送 / 立即同步完成后发出，
  /// UI 监听以刷新状态指示器与"立即同步"按钮。
  Stream<int> get pendingCountChanges => _pendingCountController.stream;

  Stream<int> get contentChanges => _contentController.stream;

  /// 是否运行中（测试诊断用）。
  bool get isRunning => _timer != null;

  /// 启动调度器：订阅网络类型变化 + 同步当前状态 + 启动周期拉取 + 启动接收器。
  Future<void> start() async {
    if (_disposed) return;
    _subscription ??= monitor.allowedChanges.listen(_onAllowedChanged);
    _syncAllowedNow();
    await _baselineReceiverRevision();
    _receiverTimer ??= Timer.periodic(receiverPollInterval, (_) {
      unawaited(_pollReceiverRevision());
    });
    // 任务 O：启动持续接收器（幂等；失败静默，周期任务仍会兜底）
    unawaited(_startReceiverQuietly());
    final intervalSecs = await api.pollIntervalSecs;
    _timer ??= Timer.periodic(
      Duration(seconds: intervalSecs),
      (_) => _runCycle(),
    );
  }

  /// 启动接收器（失败仅记日志，不阻断调度器启动）。
  Future<void> _startReceiverQuietly() async {
    final log = DebugLogger.instance;
    try {
      await api.startReceiver();
      log.event(
        'receiver.start',
        'receiver',
        fields: const {'action': 'success'},
      );
    } catch (e) {
      log.event(
        'receiver.start',
        'receiver',
        fields: const {'action': 'failed'},
        error: e.runtimeType.toString(),
        errorChain: e.toString(),
      );
    }
  }

  /// 停止调度器（应用退出 / 关闭时调用）：停止周期任务 + 网络监听 + 接收器。
  void stop() {
    _timer?.cancel();
    _timer = null;
    _subscription?.cancel();
    _subscription = null;
    _receiverTimer?.cancel();
    _receiverTimer = null;
    // 任务 O：停止接收器（异步有界；3 秒内返回，不留下永久 task）
    unawaited(_stopReceiverQuietly());
  }

  /// 停止接收器（失败仅记日志）。
  Future<void> _stopReceiverQuietly() async {
    final log = DebugLogger.instance;
    try {
      await api.stopReceiver();
      log.event(
        'receiver.stop',
        'receiver',
        fields: const {'action': 'success'},
      );
    } catch (e) {
      log.event(
        'receiver.stop',
        'receiver',
        fields: const {'action': 'failed'},
        error: e.runtimeType.toString(),
        errorChain: e.toString(),
      );
    }
  }

  /// 释放资源（关闭计数流；stop 后不再广播）。
  void dispose() {
    _disposed = true;
    stop();
    if (!_pendingCountController.isClosed) _pendingCountController.close();
    if (!_contentController.isClosed) _contentController.close();
  }

  /// 编辑保存后触发（repository 保存成功调用；fire-and-forget，不阻塞编辑）。
  ///
  /// 推送失败静默（决策 18）：不抛错，下个周期拉取兜底。
  /// 推送完成后刷新待同步计数（本地编辑会令计数上升/清零）。
  void noteEdited() {
    unawaited(() async {
      final log = DebugLogger.instance;
      // 事件 #10：后续同步——触发原因 + 待同步数量
      int pendingBefore = 0;
      try {
        pendingBefore = await api.pendingCount();
      } catch (_) {
        // 计数失败不影响推送主流程
      }
      log.event(
        'sync.trigger',
        'sync',
        fields: {'reason': 'edit_save', 'pending_count': '$pendingBefore'},
      );
      final sw = Stopwatch()..start();
      String? failure;
      try {
        await api.pushPending();
      } catch (e) {
        failure = '${e.runtimeType}: $e';
      }
      final pendingAfter = await refreshPendingCount();
      log.event(
        'sync.push',
        'sync',
        fields: {
          'reason': 'edit_save',
          'ok': failure == null ? 'true' : 'false',
          'pending_after': '$pendingAfter',
        },
        error: failure,
        errorChain: failure,
        duration: sw.elapsed,
      );
    }());
  }

  /// 手动"立即同步"（模块 5 入口）：临时打开同步开关（无视 WiFi，决策 6）
  /// → 执行完整同步周期 → 刷新待同步计数。失败静默（决策 18）。
  Future<void> syncNow() async {
    final log = DebugLogger.instance;
    log.event('sync.trigger', 'sync', fields: const {'reason': 'manual'});
    final sw = Stopwatch()..start();
    String? failure;
    try {
      await api.setSyncAllowed(true);
      await api.runSyncCycle();
    } catch (e) {
      failure = '${e.runtimeType}: $e';
      // 失败静默（决策 18）；下个周期兜底
    } finally {
      log.event(
        'sync.cycle',
        'sync',
        fields: {'reason': 'manual', 'ok': failure == null ? 'true' : 'false'},
        error: failure,
        errorChain: failure,
        duration: sw.elapsed,
      );
      await refreshPendingCount();
    }
  }

  /// 手动"立即推送"（旧入口，保留）：仅推送待办，无视同步开关（决策 6）。
  Future<void> pushNow() async {
    final log = DebugLogger.instance;
    log.event('sync.trigger', 'sync', fields: const {'reason': 'manual_push'});
    final sw = Stopwatch()..start();
    String? failure;
    try {
      await api.pushPending();
    } catch (e) {
      failure = '${e.runtimeType}: $e';
      // 失败静默（决策 18）
    } finally {
      log.event(
        'sync.push',
        'sync',
        fields: {
          'reason': 'manual_push',
          'ok': failure == null ? 'true' : 'false',
        },
        error: failure,
        errorChain: failure,
        duration: sw.elapsed,
      );
      await refreshPendingCount();
    }
  }

  /// 查询并广播当前待同步数。返回当前值（失败时返回 0）。
  Future<int> refreshPendingCount() async {
    int count;
    try {
      count = await api.pendingCount();
    } catch (_) {
      return 0;
    }
    if (!_pendingCountController.isClosed) _pendingCountController.add(count);
    return count;
  }

  Future<void> _baselineReceiverRevision() async {
    try {
      _receiverRevision = await api.receiverContentRevision();
    } catch (_) {
      // The first successful poll becomes the baseline after a transient error.
    }
  }

  Future<void> _pollReceiverRevision() async {
    if (_disposed) return;
    try {
      final revision = await api.receiverContentRevision();
      if (_disposed || _receiverRevision == null) {
        if (!_disposed) _receiverRevision = revision;
        return;
      }
      if (revision != _receiverRevision) {
        _receiverRevision = revision;
        if (!_contentController.isClosed) _contentController.add(revision);
      }
    } catch (_) {
      // Retry on the next lightweight poll.
    }
  }

  Future<void> _runCycle() async {
    final log = DebugLogger.instance;
    log.event('sync.trigger', 'sync', fields: const {'reason': 'cycle'});
    final sw = Stopwatch()..start();
    String? failure;
    try {
      await api.runSyncCycle();
    } catch (e) {
      failure = '${e.runtimeType}: $e';
      // 周期失败静默（决策 18）；下个周期重试
    } finally {
      log.event(
        'sync.cycle',
        'sync',
        fields: {'reason': 'cycle', 'ok': failure == null ? 'true' : 'false'},
        error: failure,
        errorChain: failure,
        duration: sw.elapsed,
      );
      await refreshPendingCount();
    }
  }

  void _onAllowedChanged(bool allowed) {
    unawaited(api.setSyncAllowed(allowed));
  }

  Future<void> _syncAllowedNow() async {
    try {
      final allowed = await monitor.currentAllowed();
      await api.setSyncAllowed(allowed);
    } catch (_) {
      // 保持 Rust 侧默认（true）
    }
  }
}
