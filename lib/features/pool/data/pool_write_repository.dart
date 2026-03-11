// input: 接收池实体、成员实体、请求实体以及 lifecycle 写操作参数。
// output: 定义旧 Loro 写侧池仓接口，提供池/成员/请求读写与删除能力。
// pos: 池写模型仓储抽象，当前仅保留给测试与短期兼容路径使用；主页面流不得再直接依赖它。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：临时兼容接口，待 Flutter 主流程完全切换到 Rust 后端后删除。
import 'package:cardmind/features/pool/domain/pool_entity.dart';
import 'package:cardmind/features/pool/domain/pool_member.dart';
import 'package:cardmind/features/pool/domain/pool_request.dart';

abstract class PoolWriteRepository {
  Future<void> upsertPool(PoolEntity pool);

  Future<PoolEntity?> getPoolById(String poolId);

  Future<void> upsertMember(PoolMember member);

  Future<List<PoolMember>> listMembers(String poolId);

  Future<void> removeMember(String poolId, String memberId);

  Future<void> upsertRequest(PoolRequest request);

  Future<List<PoolRequest>> listRequests(String poolId);

  Future<void> removeRequest(String poolId, String requestId);
}
