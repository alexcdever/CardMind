/// # PoolRequest 池请求领域实体
///
/// 知识池入池请求的领域实体，负责承载成员申请加入池的数据。
/// 接收 requestId、poolId、requesterId、displayName 与 requestedAtMicros，
/// 提供不可变的 [PoolRequest] 对象表达待审批入池请求。
///
/// ## 外部依赖
/// - 无外部依赖，纯 Dart 领域模型。
library pool_request;

/// 池入池请求领域实体。
///
/// 用于表达用户申请加入知识池的请求信息，包含请求标识、目标池、申请人信息和申请时间。
/// 该对象为不可变对象。
class PoolRequest {
  /// 创建池请求实例。
  ///
  /// [requestId] 请求唯一标识符。
  /// [poolId] 目标知识池的标识符。
  /// [requesterId] 申请人唯一标识符。
  /// [displayName] 申请人显示名称。
  /// [requestedAtMicros] 申请时间（微秒级时间戳）。
  const PoolRequest({
    required this.requestId,
    required this.poolId,
    required this.requesterId,
    required this.displayName,
    required this.requestedAtMicros,
  });

  /// 请求唯一标识符。
  final String requestId;

  /// 目标知识池的唯一标识符。
  final String poolId;

  /// 申请人唯一标识符。
  final String requesterId;

  /// 申请人显示名称。
  final String displayName;

  /// 申请时间（微秒级时间戳）。
  final int requestedAtMicros;
}
