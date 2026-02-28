// input: 接收 poolId、memberId、displayName、role 与 joinedAtMicros 字段。
// output: 提供 PoolMember 领域对象表达池成员身份与加入时间。
// pos: 池成员实体模型，负责表示 owner/member 角色信息。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
enum PoolRole { owner, member }

class PoolMember {
  const PoolMember({
    required this.poolId,
    required this.memberId,
    required this.displayName,
    required this.role,
    required this.joinedAtMicros,
  });

  final String poolId;
  final String memberId;
  final String displayName;
  final PoolRole role;
  final int joinedAtMicros;
}
