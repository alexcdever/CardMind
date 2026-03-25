/// # PoolMember 池成员领域实体
///
/// 知识池成员的领域实体，负责表示 owner/member 角色信息。
/// 接收 poolId、memberId、displayName、role 与 joinedAtMicros 字段，
/// 提供不可变的 [PoolMember] 领域对象表达池成员身份与加入时间。
///
/// ## 外部依赖
/// - 依赖 [PoolRole] 枚举定义成员角色。
library pool_member;

/// 池成员角色枚举。
///
/// 定义成员在知识池中的角色类型。
enum PoolRole { owner, member }

/// 池成员领域实体。
///
/// 用于表达知识池成员的身份信息，包括所属池、成员标识、显示名称、角色和加入时间。
/// 该对象为不可变对象。
class PoolMember {
  /// 创建池成员实例。
  ///
  /// [poolId] 所属知识池的标识符。
  /// [memberId] 成员唯一标识符。
  /// [displayName] 成员显示名称。
  /// [role] 成员角色（所有者或普通成员）。
  /// [joinedAtMicros] 加入时间（微秒级时间戳）。
  const PoolMember({
    required this.poolId,
    required this.memberId,
    required this.displayName,
    required this.role,
    required this.joinedAtMicros,
  });

  /// 所属知识池的唯一标识符。
  final String poolId;

  /// 成员唯一标识符。
  final String memberId;

  /// 成员显示名称。
  final String displayName;

  /// 成员角色。
  ///
  /// 使用 [PoolRole.owner] 表示所有者，[PoolRole.member] 表示普通成员。
  final PoolRole role;

  /// 加入时间（微秒级时间戳）。
  final int joinedAtMicros;
}
