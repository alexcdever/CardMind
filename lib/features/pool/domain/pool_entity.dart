/// # PoolEntity 池领域实体
///
/// 知识池的领域实体，负责标识池信息与是否解散状态。
/// 接收 poolId、name、dissolved 与 updatedAtMicros 等池级字段，
/// 提供不可变的 [PoolEntity] 对象表达池读写生命周期状态。
///
/// ## 外部依赖
/// - 无外部依赖，纯 Dart 领域模型。
library pool_entity;

/// 知识池领域实体。
///
/// 用于表达知识池的完整状态，包括池标识、名称、解散状态和更新时间。
/// 该对象为不可变对象，所有修改通过 [copyWith] 方法创建新实例。
class PoolEntity {
  /// 创建知识池实体实例。
  ///
  /// [poolId] 知识池唯一标识符。
  /// [name] 知识池名称。
  /// [dissolved] 是否已解散。
  /// [updatedAtMicros] 最后更新时间（微秒级时间戳）。
  const PoolEntity({
    required this.poolId,
    required this.name,
    required this.dissolved,
    required this.updatedAtMicros,
  });

  /// 知识池唯一标识符。
  final String poolId;

  /// 知识池名称。
  final String name;

  /// 是否已解散标记。
  final bool dissolved;

  /// 最后更新时间（微秒级时间戳）。
  final int updatedAtMicros;

  /// 创建当前实例的副本，可覆盖指定字段。
  ///
  /// [poolId] 新的池标识符，默认为当前值。
  /// [name] 新的池名称，默认为当前值。
  /// [dissolved] 新的解散标记，默认为当前值。
  /// [updatedAtMicros] 新的更新时间，默认为当前值。
  ///
  /// 返回包含更新字段的新 [PoolEntity] 实例。
  PoolEntity copyWith({
    String? poolId,
    String? name,
    bool? dissolved,
    int? updatedAtMicros,
  }) {
    return PoolEntity(
      poolId: poolId ?? this.poolId,
      name: name ?? this.name,
      dissolved: dissolved ?? this.dissolved,
      updatedAtMicros: updatedAtMicros ?? this.updatedAtMicros,
    );
  }
}
