/// # PoolCommandService 池命令服务
///
/// 提供知识池生命周期管理的命令服务。
/// 接收池生命周期命令参数并调用池写仓更新写模型真源，
/// 在 Loro 写侧执行创建、编辑、申请、审批、拒绝、退出、解散命令。
///
/// ⚠️ 仅保留给旧测试与迁移过渡使用；主页面流不得再直接依赖它。
/// 待 Flutter 主流程完全切换到 Rust 后端后删除。
///
/// ## 外部依赖
/// - 依赖 [PoolWriteRepository] 执行写侧数据持久化。
/// - 依赖 [PoolEntity]、[PoolMember] 和 [PoolRequest] 领域实体。
library pool_command_service;

import 'package:cardmind/features/pool/data/pool_write_repository.dart';
import 'package:cardmind/features/pool/domain/pool_entity.dart';
import 'package:cardmind/features/pool/domain/pool_member.dart';
import 'package:cardmind/features/pool/domain/pool_request.dart';

/// 池命令服务。
///
/// ⚠️ 临时兼容服务，提供对知识池的完整生命周期管理。
/// 仅用于旧测试和迁移过渡，新项目应使用 Rust 后端 API。
class PoolCommandService {
  /// 创建池命令服务实例。
  ///
  /// [writeRepository] 池写仓库，用于执行写操作。
  PoolCommandService(this._writeRepository);

  /// 池写仓库实例。
  final PoolWriteRepository _writeRepository;

  /// 创建新池。
  ///
  /// [poolId] 池唯一标识符。
  /// [name] 池名称。
  /// [ownerId] 所有者唯一标识符。
  /// [ownerName] 所有者显示名称。
  ///
  /// 返回异步操作结果，创建时自动将创建者添加为所有者角色。
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

  /// 编辑池信息。
  ///
  /// [poolId] 要编辑的池标识符。
  /// [name] 新的池名称。
  ///
  /// 如果池不存在则不执行任何操作。
  /// 更新时自动刷新 [updatedAtMicros] 为当前时间。
  Future<void> editPoolInfo({
    required String poolId,
    required String name,
  }) async {
    final existing = await _writeRepository.getPoolById(poolId);
    if (existing == null) {
      return;
    }
    await _writeRepository.upsertPool(
      existing.copyWith(name: name, updatedAtMicros: _nowMicros()),
    );
  }

  /// 申请加入池。
  ///
  /// [poolId] 目标池标识符。
  /// [requestId] 请求唯一标识符。
  /// [requesterId] 申请人唯一标识符。
  /// [displayName] 申请人显示名称。
  ///
  /// 返回异步操作结果，创建待审批的入池请求。
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

  /// 批准入池请求。
  ///
  /// [poolId] 池标识符。
  /// [requestId] 请求标识符。
  ///
  /// 如果请求不存在则不执行任何操作。
  /// 批准后将申请人添加为普通成员并删除该请求。
  Future<void> approve({
    required String poolId,
    required String requestId,
  }) async {
    final request = await _findRequest(poolId, requestId);
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

  /// 拒绝入池请求。
  ///
  /// [poolId] 池标识符。
  /// [requestId] 请求标识符。
  ///
  /// 直接删除该请求记录。
  Future<void> reject({required String poolId, required String requestId}) {
    return _writeRepository.removeRequest(poolId, requestId);
  }

  /// 离开池。
  ///
  /// [poolId] 池标识符。
  /// [memberId] 要离开的成员标识符。
  ///
  /// 从池中移除指定成员。
  Future<void> leavePool({required String poolId, required String memberId}) {
    return _writeRepository.removeMember(poolId, memberId);
  }

  /// 解散池。
  ///
  /// [poolId] 要解散的池标识符。
  ///
  /// 如果池不存在则不执行任何操作。
  /// 解散操作通过设置 [dissolved] 为 true 实现，不会物理删除数据。
  Future<void> dissolvePool({required String poolId}) async {
    final existing = await _writeRepository.getPoolById(poolId);
    if (existing == null) {
      return;
    }
    await _writeRepository.upsertPool(
      existing.copyWith(dissolved: true, updatedAtMicros: _nowMicros()),
    );
  }

  /// 查找指定请求。
  ///
  /// [poolId] 池标识符。
  /// [requestId] 请求标识符。
  ///
  /// 返回找到的 [PoolRequest] 实例，如果不存在则返回 null。
  Future<PoolRequest?> _findRequest(String poolId, String requestId) async {
    final requests = await _writeRepository.listRequests(poolId);
    return requests.where((r) => r.requestId == requestId).firstOrNull;
  }

  /// 获取当前时间的微秒级时间戳。
  ///
  /// 返回自 Unix 纪元以来的微秒数。
  int _nowMicros() => DateTime.now().microsecondsSinceEpoch;
}

/// Iterable 扩展，提供 firstOrNull 便捷方法。
extension<T> on Iterable<T> {
  /// 获取可迭代对象的第一个元素，如果为空则返回 null。
  T? get firstOrNull {
    if (isEmpty) {
      return null;
    }
    return first;
  }
}
