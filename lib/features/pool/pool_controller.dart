// input: 接收池状态操作（创建、审批、拒绝、退出）与同步状态更新请求。
// output: 更新 PoolState/SyncStatus 并通过 notifyListeners() 触发界面刷新。
// pos: 数据池状态控制器，负责池成员流转与同步状态编排。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
import 'package:cardmind/features/pool/pool_api_client.dart';
import 'package:cardmind/features/pool/pool_state.dart';
import 'package:cardmind/features/sync/sync_service.dart';
import 'package:cardmind/features/sync/sync_status.dart';
import 'package:flutter/foundation.dart';

class PoolController extends ChangeNotifier {
  PoolController({
    PoolState initialState = const PoolState.notJoined(),
    SyncStatus initialSyncStatus = const SyncStatus.connected(),
    PoolApiClient? apiClient,
    SyncService? syncService,
    String reconnectTarget = 'owner@this-device',
  }) : _state = initialState,
       _syncStatus = initialSyncStatus,
       _apiClient =
           apiClient ??
           FrbPoolApiClient(
             endpointId: 'owner@this-device',
             nickname: 'owner',
             os: defaultTargetPlatform.name,
           ),
       _syncService = syncService,
       _reconnectTarget = reconnectTarget;

  PoolState _state;
  SyncStatus _syncStatus;
  bool _joining = false;
  final PoolApiClient _apiClient;
  final SyncService? _syncService;
  final String _reconnectTarget;

  PoolState get state => _state;
  SyncStatus get syncStatus => _syncStatus;
  bool get joining => _joining;

  void setState(PoolState state) {
    _state = state;
    notifyListeners();
  }

  void setSyncStatus(SyncStatus status) {
    _syncStatus = status;
    notifyListeners();
  }

  Future<void> createPool() async {
    final result = await _apiClient.createPool();
    _state = PoolState.joined(
      poolName: result.poolName,
      isOwner: result.isOwner,
    );
    notifyListeners();
  }

  void editPoolInfo(String newName) {
    final joined = _state;
    if (joined is! PoolJoined) return;
    _state = joined.copyWith(poolName: newName.trim());
    notifyListeners();
  }

  void dissolvePool() {
    _state = const PoolState.notJoined();
    notifyListeners();
  }

  void approve(String requestId) {
    final joined = _state;
    if (joined is! PoolJoined) return;

    final updated = joined.pending
        .where((item) => item.id != requestId)
        .toList(growable: false);

    _state = joined.copyWith(pending: updated, approvalMessage: '审批已通过');
    notifyListeners();
  }

  void reject(String requestId) {
    final joined = _state;
    if (joined is! PoolJoined) return;

    final updated = joined.pending
        .map((item) {
          if (item.id != requestId) return item;
          if (item.rejectShouldFail) {
            if (item.error != null) {
              return null;
            }
            return item.copyWith(error: '拒绝失败：网络异常');
          }
          return null;
        })
        .whereType<PoolPendingRequest>()
        .toList(growable: false);

    _state = joined.copyWith(
      pending: updated,
      approvalMessage: updated.length == joined.pending.length ? null : '拒绝已完成',
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

  Future<void> joinByCode(String code) async {
    _joining = true;
    notifyListeners();
    final result = await _apiClient.joinByCode(code);
    _joining = false;
    if (result.isSuccess) {
      final joined = await _apiClient.getJoinedPoolView();
      _state = PoolState.joined(
        poolName: joined?.poolName ?? result.poolName ?? '默认数据池',
        isOwner: joined?.isOwner ?? false,
      );
    } else {
      _state = PoolState.error(result.errorCode ?? 'REQUEST_TIMEOUT');
    }
    notifyListeners();
  }

  Future<void> retrySync() async {
    await _runSyncRecovery((service) => service.retry());
  }

  Future<void> reconnectSync() async {
    final syncService = _syncService;
    if (syncService == null) {
      return;
    }
    _syncStatus = const SyncStatus.connecting();
    notifyListeners();
    await _runSyncRecovery((service) => service.reconnect(_reconnectTarget));
  }

  Future<void> _runSyncRecovery(
    Future<SyncStatus> Function(SyncService service) action,
  ) async {
    final syncService = _syncService;
    if (syncService == null) {
      return;
    }
    _syncStatus = await action(syncService);
    notifyListeners();
  }
}
