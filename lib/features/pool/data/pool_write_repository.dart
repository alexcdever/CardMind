// input: 接收池实体、成员实体、请求实体以及 lifecycle 写操作参数。
// output: 定义 Loro 写侧池仓接口，提供池/成员/请求读写与删除能力。
// pos: 池写模型仓储抽象，负责隔离命令服务与具体写存储实现。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
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
