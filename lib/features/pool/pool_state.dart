/// # 数据池状态模型
///
/// 定义数据池相关的所有状态类型和数据结构。
/// 使用密封类模式描述入池流程的全部状态形态。
library pool_state;

/// 数据池状态的密封基类。
///
/// 提供工厂构造方法创建不同类型的状态实例。
sealed class PoolState {
  /// 创建基础状态。
  const PoolState();

  /// 创建未加入池状态。
  const factory PoolState.notJoined() = PoolNotJoined;

  /// 创建已加入池状态。
  const factory PoolState.joined({
    String poolId,
    List<PoolPendingRequest> pending,
    bool exitShouldFail,
    bool isDissolved,
    String poolName,
    bool isOwner,
    String currentIdentityLabel,
    List<String> memberLabels,
    String? approvalMessage,
  }) = PoolJoined;

  /// 创建错误状态。
  const factory PoolState.error(String code) = PoolError;

  /// 创建退出部分清理状态。
  const factory PoolState.exitPartialCleanup() = PoolExitPartialCleanup;

  /// 创建带有待处理请求的已加入状态。
  static PoolState joinedWithPending() {
    return const PoolState.joined(
      poolId: 'default-pool',
      pending: <PoolPendingRequest>[
        PoolPendingRequest(id: 'alice', displayName: 'alice@pending'),
      ],
    );
  }
}

/// 未加入任何数据池的状态。
class PoolNotJoined extends PoolState {
  /// 创建未加入状态实例。
  const PoolNotJoined();
}

/// 已加入数据池的状态。
class PoolJoined extends PoolState {
  /// 创建已加入池状态实例。
  const PoolJoined({
    this.poolId = 'default-pool',
    this.pending = const <PoolPendingRequest>[],
    this.exitShouldFail = false,
    this.isDissolved = false,
    this.poolName = '默认数据池',
    this.isOwner = true,
    this.currentIdentityLabel = '未知身份',
    this.memberLabels = const <String>[],
    this.approvalMessage,
  });

  /// 数据池标识。
  final String poolId;

  /// 待处理的加入请求列表。
  final List<PoolPendingRequest> pending;

  /// 退出操作是否应该失败（用于测试）。
  final bool exitShouldFail;

  /// 数据池是否已解散。
  final bool isDissolved;

  /// 数据池名称。
  final String poolName;

  /// 当前用户是否为池所有者。
  final bool isOwner;

  /// 当前用户身份标识标签。
  final String currentIdentityLabel;

  /// 成员标识标签列表。
  final List<String> memberLabels;

  /// 审批操作后的消息提示。
  final String? approvalMessage;

  /// 创建状态的副本，允许更新部分字段。
  PoolJoined copyWith({
    String? poolId,
    List<PoolPendingRequest>? pending,
    bool? exitShouldFail,
    bool? isDissolved,
    String? poolName,
    bool? isOwner,
    String? currentIdentityLabel,
    List<String>? memberLabels,
    String? approvalMessage,
  }) {
    return PoolJoined(
      pending: pending ?? this.pending,
      poolId: poolId ?? this.poolId,
      exitShouldFail: exitShouldFail ?? this.exitShouldFail,
      isDissolved: isDissolved ?? this.isDissolved,
      poolName: poolName ?? this.poolName,
      isOwner: isOwner ?? this.isOwner,
      currentIdentityLabel: currentIdentityLabel ?? this.currentIdentityLabel,
      memberLabels: memberLabels ?? this.memberLabels,
      approvalMessage: approvalMessage ?? this.approvalMessage,
    );
  }
}

/// 发生错误时的池状态。
class PoolError extends PoolState {
  /// 创建错误状态实例。
  const PoolError(this.code);

  /// 错误码。
  final String code;
}

/// 退出操作部分清理失败的状态。
class PoolExitPartialCleanup extends PoolState {
  /// 创建部分清理状态实例。
  const PoolExitPartialCleanup();
}

/// 待处理的加入请求数据。
class PoolPendingRequest {
  /// 创建待处理请求实例。
  const PoolPendingRequest({
    required this.id,
    required this.displayName,
    this.status = 'pending',
    this.rejectShouldFail = false,
    this.error,
  });

  /// 请求唯一标识。
  final String id;

  /// 显示名称。
  final String displayName;

  /// 请求状态。
  final String status;

  /// 拒绝操作是否应该失败（用于测试）。
  final bool rejectShouldFail;

  /// 错误信息。
  final String? error;

  /// 创建请求的副本，允许更新错误信息。
  PoolPendingRequest copyWith({String? error}) {
    return PoolPendingRequest(
      id: id,
      displayName: displayName,
      status: status,
      rejectShouldFail: rejectShouldFail,
      error: error,
    );
  }
}
