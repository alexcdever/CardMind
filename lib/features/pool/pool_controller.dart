// input: lib/features/pool/pool_controller.dart 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Flutter 功能模块，负责状态编排、交互反馈与页面渲染。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
import 'package:cardmind/features/pool/pool_state.dart';
import 'package:cardmind/features/sync/sync_status.dart';
import 'package:flutter/foundation.dart';

class PoolController extends ChangeNotifier {
  PoolController({
    PoolState initialState = const PoolState.notJoined(),
    SyncStatus initialSyncStatus = const SyncStatus.connected(),
  }) : _state = initialState,
       _syncStatus = initialSyncStatus;

  PoolState _state;
  SyncStatus _syncStatus;

  PoolState get state => _state;
  SyncStatus get syncStatus => _syncStatus;

  void setState(PoolState state) {
    _state = state;
    notifyListeners();
  }

  void setSyncStatus(SyncStatus status) {
    _syncStatus = status;
    notifyListeners();
  }

  void createPool() {
    _state = const PoolState.joined();
    notifyListeners();
  }

  void approve(String requestId) {
    final joined = _state;
    if (joined is! PoolJoined) return;

    final updated = joined.pending
        .where((item) => item.id != requestId)
        .toList(growable: false);

    _state = PoolState.joined(
      pending: updated,
      exitShouldFail: joined.exitShouldFail,
      approvalMessage: '审批已通过',
    );
    notifyListeners();
  }

  void reject(String requestId) {
    final joined = _state;
    if (joined is! PoolJoined) return;

    final updated = joined.pending
        .map((item) {
          if (item.id != requestId) return item;
          if (item.rejectShouldFail) {
            return item.copyWith(error: '拒绝失败：网络异常');
          }
          return null;
        })
        .whereType<PoolPendingRequest>()
        .toList(growable: false);

    _state = PoolState.joined(
      pending: updated,
      exitShouldFail: joined.exitShouldFail,
      approvalMessage: joined.approvalMessage,
    );
    notifyListeners();
  }

  void simulateRejectFailurePending() {
    _state = const PoolState.joined(
      pending: <PoolPendingRequest>[
        PoolPendingRequest(
          id: 'bob',
          displayName: 'bob@pending-fail',
          rejectShouldFail: true,
        ),
      ],
    );
    notifyListeners();
  }

  void confirmExit() {
    final joined = _state;
    if (joined is PoolJoined && joined.exitShouldFail) {
      _state = const PoolState.exitPartialCleanup();
      notifyListeners();
      return;
    }

    _state = const PoolState.notJoined();
    notifyListeners();
  }

  void retryCleanup() {
    _state = const PoolState.notJoined();
    notifyListeners();
  }

  Future<void> retrySync() async {
    _syncStatus = const SyncStatus.connected();
    notifyListeners();
  }

  Future<void> reconnectSync() async {
    _syncStatus = const SyncStatus.connecting();
    notifyListeners();
    _syncStatus = const SyncStatus.connected();
    notifyListeners();
  }
}
