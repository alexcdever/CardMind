// input: 接收 poolId、name、dissolved 与 updatedAtMicros 等池级字段。
// output: 提供 PoolEntity 不可变对象表达池读写生命周期状态。
// pos: 池领域主实体，负责标识池信息与是否解散状态。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
class PoolEntity {
  const PoolEntity({
    required this.poolId,
    required this.name,
    required this.dissolved,
    required this.updatedAtMicros,
  });

  final String poolId;
  final String name;
  final bool dissolved;
  final int updatedAtMicros;

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
