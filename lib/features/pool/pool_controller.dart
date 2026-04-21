import 'package:cardmind/features/pool/pool_api_client.dart';
import 'package:cardmind/features/pool/pool_state.dart';
import 'package:cardmind/features/sync/sync_service.dart';
import 'package:cardmind/features/sync/sync_status.dart';
import 'package:cardmind/bridge_generated/models/api_error.dart';
import 'package:flutter/foundation.dart';

List<PoolPendingRequest> _pendingFromApi(List<JoinRequestData> requests) {
  return requests
      .where((request) => request.status == 'pending')
      .map(
        (request) => PoolPendingRequest(
          id: request.requestId,
          displayName: request.displayName,
          status: request.status,
        ),
      )
      .toList(growable: false);
}

bool _isLastAdminLeaveError(ApiError error) {
  return error.code == 'INVALID_ARGUMENT' &&
      error.message.contains('last admin');
}

bool _isPartialCleanupError(ApiError error) {
  return error.code == 'PARTIAL_CLEANUP';
}

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

  /// 当前页面提示信息。
  String? _noticeMessage;

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

  /// 获取当前页面提示信息。
  String? get noticeMessage => _noticeMessage;

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
    _noticeMessage = null;
    _state = PoolState.joined(
      poolId: result.poolId,
      isDissolved: result.isDissolved,
      poolName: result.poolName,
      isOwner: result.isOwner,
      currentIdentityLabel: result.currentIdentityLabel,
      memberLabels: result.memberLabels,
      inviteCode: result.inviteCode,
    );
    notifyListeners();
  }

  /// 编辑池信息。
  void editPoolInfo(String newName) {
    final joined = _state;
    if (joined is! PoolJoined) return;
    _noticeMessage = null;
    _state = joined.copyWith(poolName: newName.trim());
    notifyListeners();
  }

  /// 解散数据池。
  Future<void> dissolvePool() async {
    final joined = _state;
    if (joined is! PoolJoined) {
      return;
    }

    try {
      final detail = await _apiClient.dissolvePool(joined.poolId);
      _noticeMessage = '数据池已解散，当前为只读状态';
      _state = joined.copyWith(isDissolved: detail.isDissolved);
    } on ApiError {
      _noticeMessage = '解散失败，请稍后重试';
      _state = joined;
    } catch (_) {
      _noticeMessage = '解散失败，请稍后重试';
      _state = joined;
    }
    notifyListeners();
  }

  /// 批准加入请求。
  Future<void> approve(String requestId) async {
    final joined = _state;
    if (joined is! PoolJoined) return;

    try {
      final requests = await _apiClient.approveJoinRequest(
        joined.poolId,
        requestId,
      );
      _noticeMessage = '审批已通过';
      _state = joined.copyWith(pending: _pendingFromApi(requests));
    } on ApiError {
      _noticeMessage = '审批失败，请稍后重试';
      _state = joined;
    } catch (_) {
      _noticeMessage = '审批失败，请稍后重试';
      _state = joined;
    }
    notifyListeners();
  }

  /// 拒绝加入请求。
  Future<void> reject(String requestId) async {
    final joined = _state;
    if (joined is! PoolJoined) return;

    try {
      final requests = await _apiClient.rejectJoinRequest(
        joined.poolId,
        requestId,
      );
      _noticeMessage = '拒绝已完成';
      _state = joined.copyWith(pending: _pendingFromApi(requests));
    } on ApiError {
      final updated = joined.pending
          .map((item) {
            if (item.id != requestId) return item;
            return item.copyWith(error: '拒绝失败：网络异常');
          })
          .toList(growable: false);
      _noticeMessage = '拒绝失败，请稍后重试';
      _state = joined.copyWith(pending: updated);
    } catch (_) {
      _noticeMessage = '拒绝失败，请稍后重试';
      _state = joined;
    }
    notifyListeners();
  }

  Future<void> submitJoinRequest() async {
    final pendingBase = switch (_state) {
      PoolJoinPending pending => pending,
      _ => const PoolJoinPending(),
    };

    try {
      final requests = await _apiClient.submitJoinRequest(pendingBase.poolId);
      final firstPending = requests.firstWhere(
        (request) => request.status == 'pending',
        orElse: () => const JoinRequestData(
          requestId: 'pending-request',
          displayName: '申请人',
          status: 'pending',
        ),
      );
      _noticeMessage = '加入申请已提交，等待管理员审批';
      _state = PoolState.joinPending(
        poolId: pendingBase.poolId,
        poolName: pendingBase.poolName,
        requestId: firstPending.requestId,
        applicantIdentityLabel: firstPending.displayName,
        pendingSinceLabel: '刚刚提交',
      );
    } on ApiError {
      _noticeMessage = '加入申请提交失败，请稍后重试';
      _state = pendingBase;
    } catch (_) {
      _noticeMessage = '加入申请提交失败，请稍后重试';
      _state = pendingBase;
    }
    notifyListeners();
  }

  Future<void> cancelJoinRequest(String requestId) async {
    final pending = _state;
    if (pending is! PoolJoinPending) return;

    try {
      await _apiClient.cancelJoinRequest(pending.poolId, requestId);
      _noticeMessage = '加入申请已取消';
      _state = const PoolState.notJoined();
    } on ApiError {
      _noticeMessage = '取消申请失败，请稍后重试';
      _state = pending;
    } catch (_) {
      _noticeMessage = '取消申请失败，请稍后重试';
      _state = pending;
    }
    notifyListeners();
  }

  /// 确认退出数据池。
  Future<void> confirmExit() async {
    final joined = _state;
    if (joined is! PoolJoined) {
      return;
    }

    try {
      await _apiClient.leavePool(joined.poolId);
      _noticeMessage = null;
      _state = const PoolState.notJoined();
    } on ApiError catch (error) {
      if (_isLastAdminLeaveError(error)) {
        _noticeMessage = '您是唯一的管理员，请先指定新的管理员';
        _state = joined;
      } else if (_isPartialCleanupError(error)) {
        _noticeMessage = null;
        _state = const PoolState.exitPartialCleanup();
      } else {
        _noticeMessage = '退出失败，请稍后重试';
        _state = joined;
      }
    } catch (_) {
      _noticeMessage = '退出失败，请稍后重试';
      _state = joined;
    }
    notifyListeners();
  }

  /// 重试清理操作。
  void retryCleanup() {
    _noticeMessage = null;
    _state = const PoolState.notJoined();
    notifyListeners();
  }

  /// 通过加入码加入数据池。
  Future<void> joinByCode(String code) async {
    _joining = true;
    _noticeMessage = null;
    notifyListeners();
    final result = await _apiClient.joinByCode(code);
    _joining = false;
    if (result.isPending) {
      _noticeMessage = '加入申请已提交，等待管理员审批';
      _state = PoolState.joinPending(
        poolId: result.poolId ?? 'pending-request-pool',
        poolName: result.poolName ?? '待加入数据池',
        requestId: result.requestId ?? 'pending-request',
        applicantIdentityLabel:
            result.applicantIdentityLabel ?? _reconnectTarget,
        pendingSinceLabel: '刚刚提交',
      );
    } else if (result.isSuccess) {
      try {
        final joined = await _apiClient.getJoinedPoolView();
        _state = PoolState.joined(
          poolId: joined?.poolId ?? 'default-pool',
          isDissolved: joined?.isDissolved ?? false,
          poolName: joined?.poolName ?? result.poolName ?? '默认数据池',
          isOwner: joined?.isOwner ?? false,
          currentIdentityLabel:
              joined?.currentIdentityLabel ?? _reconnectTarget,
          memberLabels: joined?.memberLabels ?? <String>[_reconnectTarget],
        );
      } on ApiError catch (error) {
        _noticeMessage = error.message;
        _state = PoolState.error(error.code);
      }
    } else {
      _noticeMessage = result.errorMessage;
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
