// input: 接收池生命周期命令参数并调用池写仓更新写模型真源。
// output: 在 Loro 写侧执行创建、编辑、申请、审批、拒绝、退出、解散命令。
// pos: 池命令服务，负责封装池全生命周期写侧操作。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 功能模块，负责状态编排、交互反馈与页面渲染。
import 'package:cardmind/features/pool/data/pool_write_repository.dart';
import 'package:cardmind/features/pool/domain/pool_entity.dart';
import 'package:cardmind/features/pool/domain/pool_member.dart';
import 'package:cardmind/features/pool/domain/pool_request.dart';

class PoolCommandService {
  PoolCommandService(this._writeRepository);

  final PoolWriteRepository _writeRepository;

  Future<void> createPool({
    required String poolId,
    required String name,
    required String ownerId,
    required String ownerName,
  }) async {
    await _writeRepository.upsertPool(
      PoolEntity(
        poolId: poolId,
        name: name,
        dissolved: false,
        updatedAtMicros: _nowMicros(),
      ),
    );
    await _writeRepository.upsertMember(
      PoolMember(
        poolId: poolId,
        memberId: ownerId,
        displayName: ownerName,
        role: PoolRole.owner,
        joinedAtMicros: _nowMicros(),
      ),
    );
  }

  Future<void> editPoolInfo({
    required String poolId,
    required String name,
  }) async {
    final existing = await _writeRepository.getPoolById(poolId);
    if (existing == null) {
      return;
    }
    await _writeRepository.upsertPool(
      PoolEntity(
        poolId: existing.poolId,
        name: name,
        dissolved: existing.dissolved,
        updatedAtMicros: _nowMicros(),
      ),
    );
  }

  Future<void> requestJoin({
    required String poolId,
    required String requestId,
    required String requesterId,
    required String displayName,
  }) {
    return _writeRepository.upsertRequest(
      PoolRequest(
        requestId: requestId,
        poolId: poolId,
        requesterId: requesterId,
        displayName: displayName,
        requestedAtMicros: _nowMicros(),
      ),
    );
  }

  Future<void> approve({
    required String poolId,
    required String requestId,
  }) async {
    final requests = await _writeRepository.listRequests(poolId);
    final request = requests.where((r) => r.requestId == requestId).firstOrNull;
    if (request == null) {
      return;
    }
    await _writeRepository.upsertMember(
      PoolMember(
        poolId: poolId,
        memberId: request.requesterId,
        displayName: request.displayName,
        role: PoolRole.member,
        joinedAtMicros: _nowMicros(),
      ),
    );
    await _writeRepository.removeRequest(poolId, requestId);
  }

  Future<void> reject({required String poolId, required String requestId}) {
    return _writeRepository.removeRequest(poolId, requestId);
  }

  Future<void> leavePool({required String poolId, required String memberId}) {
    return _writeRepository.removeMember(poolId, memberId);
  }

  Future<void> dissolvePool({required String poolId}) async {
    final existing = await _writeRepository.getPoolById(poolId);
    if (existing == null) {
      return;
    }
    await _writeRepository.upsertPool(
      PoolEntity(
        poolId: existing.poolId,
        name: existing.name,
        dissolved: true,
        updatedAtMicros: _nowMicros(),
      ),
    );
  }

  int _nowMicros() => DateTime.now().microsecondsSinceEpoch;
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    if (isEmpty) {
      return null;
    }
    return first;
  }
}
