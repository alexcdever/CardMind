/// # 数据池控制器
///
/// 负责数据池的状态管理和业务逻辑编排。
/// 处理池的创建、审批、拒绝、退出等操作，以及同步状态更新。
///
/// ## 外部依赖
/// - 依赖 [PoolApiClient] 提供数据池 API 调用。
/// - 依赖 [SyncService] 提供同步服务。
library pool_controller;

import 'package:cardmind/features/pool/pool_api_client.dart';
import 'package:cardmind/features/pool/pool_state.dart';
import 'package:cardmind/features/sync/sync_service.dart';
import 'package:cardmind/features/sync/sync_status.dart';
import 'package:flutter/foundation.dart';

/// 数据池状态控制器。
///
/// 管理池成员流转与同步状态编排，通过 [ChangeNotifier] 模式
/// 通知界面状态变化。
class PoolController extends ChangeNotifier {
  /// 创建数据池控制器。
  ///
  /// [initialState] - 初始池状态，默认为未加入状态。
  /// [initialSyncStatus] - 初始同步状态，默认为已连接。
  /// [apiClient] - 可选的 API 客户端，用于依赖注入测试。
  /// [syncService] - 可选的同步服务。
  /// [reconnectTarget] - 重新连接目标标识。
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

  /// 当前池状态。
  PoolState _state;

  /// 当前同步状态。
  SyncStatus _syncStatus;

  /// 是否正在加入中。
  bool _joining = false;

  /// API 客户端实例。
  final PoolApiClient _apiClient;

  /// 同步服务实例。
  final SyncService? _syncService;

  /// 重新连接目标标识。
  final String _reconnectTarget;

  /// 获取当前池状态。
  PoolState get state => _state;

  /// 获取当前同步状态。
  SyncStatus get syncStatus => _syncStatus;

  /// 获取是否正在加入中。
  bool get joining => _joining;

  /// 设置池状态并通知监听者。
  void setState(PoolState state) {
    _state = state;
    notifyListeners();
  }

  /// 设置同步状态并通知监听者。
  void setSyncStatus(SyncStatus status) {
    _syncStatus = status;
    notifyListeners();
  }

  /// 创建新的数据池。
  Future<void> createPool() async {
    final result = await _apiClient.createPool();
    _state = PoolState.joined(
      poolName: result.poolName,
      isOwner: result.isOwner,
      currentIdentityLabel: result.currentIdentityLabel,
      memberLabels: result.memberLabels,
    );
    notifyListeners();
  }

  /// 编辑池信息。
  void editPoolInfo(String newName) {
    final joined = _state;
    if (joined is! PoolJoined) return;
    _state = joined.copyWith(poolName: newName.trim());
    notifyListeners();
  }

  /// 解散数据池。
  void dissolvePool() {
    _state = const PoolState.notJoined();
    notifyListeners();
  }

  /// 批准加入请求。
  void approve(String requestId) {
    final joined = _state;
    if (joined is! PoolJoined) return;

    final updated = joined.pending
        .where((item) => item.id != requestId)
        .toList(growable: false);

    _state = joined.copyWith(pending: updated, approvalMessage: '审批已通过');
    notifyListeners();
  }

  /// 拒绝加入请求。
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

  /// 模拟拒绝失败的待处理请求。
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

  /// 确认退出数据池。
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

  /// 重试清理操作。
  void retryCleanup() {
    _state = const PoolState.notJoined();
    notifyListeners();
  }

  /// 通过加入码加入数据池。
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
        currentIdentityLabel: joined?.currentIdentityLabel ?? _reconnectTarget,
        memberLabels: joined?.memberLabels ?? <String>[_reconnectTarget],
      );
    } else {
      _state = PoolState.error(result.errorCode ?? 'REQUEST_TIMEOUT');
    }
    notifyListeners();
  }

  /// 重试同步操作。
  Future<void> retrySync() async {
    await _runSyncRecovery((service) => service.retry());
  }

  /// 重新连接同步服务。
  Future<void> reconnectSync() async {
    final syncService = _syncService;
    if (syncService == null) {
      return;
    }
    _syncStatus = const SyncStatus.connecting();
    notifyListeners();
    await _runSyncRecovery((service) => service.reconnect(_reconnectTarget));
  }

  /// 执行同步恢复操作的内部方法。
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
