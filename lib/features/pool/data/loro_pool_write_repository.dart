// input: 接收池、成员与请求写模型操作并按 poolId 聚合管理。
// output: 提供池写侧 upsert/list/remove 实现，作为 Loro 写模型真源仓。
// pos: 池 Loro 写仓实现，负责维护池生命周期相关写模型状态。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
import 'package:cardmind/features/pool/data/pool_write_repository.dart';
import 'package:cardmind/features/pool/domain/pool_entity.dart';
import 'package:cardmind/features/pool/domain/pool_member.dart';
import 'package:cardmind/features/pool/domain/pool_request.dart';

class LoroPoolWriteRepository implements PoolWriteRepository {
  LoroPoolWriteRepository();

  factory LoroPoolWriteRepository.inMemory() {
    return LoroPoolWriteRepository();
  }

  final Map<String, PoolEntity> _pools = <String, PoolEntity>{};
  final Map<String, Map<String, PoolMember>> _members =
      <String, Map<String, PoolMember>>{};
  final Map<String, Map<String, PoolRequest>> _requests =
      <String, Map<String, PoolRequest>>{};

  @override
  Future<PoolEntity?> getPoolById(String poolId) async {
    return _pools[poolId];
  }

  @override
  Future<List<PoolMember>> listMembers(String poolId) async {
    final rows =
        _members[poolId]?.values.toList(growable: false) ??
        const <PoolMember>[];
    return rows;
  }

  @override
  Future<List<PoolRequest>> listRequests(String poolId) async {
    final rows =
        _requests[poolId]?.values.toList(growable: false) ??
        const <PoolRequest>[];
    return rows;
  }

  @override
  Future<void> removeMember(String poolId, String memberId) async {
    _members.putIfAbsent(poolId, () => <String, PoolMember>{}).remove(memberId);
  }

  @override
  Future<void> removeRequest(String poolId, String requestId) async {
    _requests
        .putIfAbsent(poolId, () => <String, PoolRequest>{})
        .remove(requestId);
  }

  @override
  Future<void> upsertMember(PoolMember member) async {
    _members.putIfAbsent(
      member.poolId,
      () => <String, PoolMember>{},
    )[member.memberId] = member;
  }

  @override
  Future<void> upsertPool(PoolEntity pool) async {
    _pools[pool.poolId] = pool;
  }

  @override
  Future<void> upsertRequest(PoolRequest request) async {
    _requests.putIfAbsent(
      request.poolId,
      () => <String, PoolRequest>{},
    )[request.requestId] = request;
  }
}
