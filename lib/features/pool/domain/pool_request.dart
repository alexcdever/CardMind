// input: 接收 requestId、poolId、requesterId、displayName 与 requestedAtMicros。
// output: 提供 PoolRequest 不可变对象表达待审批入池请求。
// pos: 池请求领域实体，负责承载成员申请加入池的数据。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
class PoolRequest {
  const PoolRequest({
    required this.requestId,
    required this.poolId,
    required this.requesterId,
    required this.displayName,
    required this.requestedAtMicros,
  });

  final String requestId;
  final String poolId;
  final String requesterId;
  final String displayName;
  final int requestedAtMicros;
}
