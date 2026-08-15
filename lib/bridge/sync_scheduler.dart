import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../src/rust/api.dart' as api;
import '../src/rust/store.dart';
import '../src/rust/sync.dart';

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
}

/// 自动同步调度器（任务 H）：
///
/// - **编辑保存即推送**（决策 4）：repository 保存成功后调用 [noteEdited]，
///   fire-and-forget 触发 `pushPending`（不阻塞编辑；失败静默，决策 18）。
/// - **周期拉取**（决策 4）：`Timer.periodic` 按 `SYNC_POLL_INTERVAL_SECS`
///   调 `runSyncCycle`（对等推拉：push 给所有对端 + 短窗口 accept 对端 push）。
/// - **移动端 WiFi 条件**（决策 6）：监听 connectivity，蜂窝 → `setSyncAllowed(false)`
///   暂停推送与拉取；手动"立即同步"（模块 5）可调用 [pushNow] 无视限制。
///
/// 调度器不持有 Rust 对象生命周期（无 tokio spawn），由调用方保证
/// `api` 指向的 SyncService 在调度器运行期间存活。
class SyncScheduler {
  SyncScheduler({required this.monitor, required this.api});

  final NetworkTypeMonitor monitor;
  final SyncApi api;
  Timer? _timer;
  StreamSubscription<bool>? _subscription;

  /// 是否运行中（测试诊断用）。
  bool get isRunning => _timer != null;

  /// 启动调度器：订阅网络类型变化 + 同步当前状态 + 启动周期拉取。
  Future<void> start() async {
    _subscription ??= monitor.allowedChanges.listen(_onAllowedChanged);
    _syncAllowedNow();
    final intervalSecs = await api.pollIntervalSecs;
    _timer ??= Timer.periodic(
      Duration(seconds: intervalSecs),
      (_) => _runCycle(),
    );
  }

  /// 停止调度器（应用退出 / 关闭时调用）。
  void stop() {
    _timer?.cancel();
    _timer = null;
    _subscription?.cancel();
    _subscription = null;
  }

  /// 编辑保存后触发（repository 保存成功调用；fire-and-forget，不阻塞编辑）。
  ///
  /// 推送失败静默（决策 18）：不抛错，下个周期拉取兜底。
  void noteEdited() {
    unawaited(api.pushPending());
  }

  /// 手动"立即同步"（模块 5 入口）：无视同步开关强制推送（决策 6）。
  Future<void> pushNow() async {
    try {
      await api.pushPending();
    } catch (_) {
      // 失败静默（决策 18）
    }
  }

  Future<void> _runCycle() async {
    try {
      await api.runSyncCycle();
    } catch (_) {
      // 周期失败静默（决策 18）；下个周期重试
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
