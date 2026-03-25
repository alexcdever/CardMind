/// # 池写模型仓储接口
///
/// 定义旧 Loro 写侧池仓接口，提供池/成员/请求读写与删除能力。
/// 当前仅保留给测试与短期兼容路径使用；主页面流不得再直接依赖它。
/// 待 Flutter 主流程完全切换到 Rust 后端后删除。
///
/// ## 外部依赖
/// - 依赖 [PoolEntity] 定义池实体数据结构。
/// - 依赖 [PoolMember] 定义成员数据结构。
/// - 依赖 [PoolRequest] 定义请求数据结构。
library pool_write_repository;

import 'package:cardmind/features/pool/domain/pool_entity.dart';
import 'package:cardmind/features/pool/domain/pool_member.dart';
import 'package:cardmind/features/pool/domain/pool_request.dart';

/// 池写模型仓储抽象接口。
///
/// 定义池写操作的临时兼容契约，支持池、成员、请求的增删改查。
/// 此接口为过渡性质，仅供测试和兼容路径使用。
abstract class PoolWriteRepository {
  /// 插入或更新池。
  ///
  /// [pool] 为要写入的池实体数据。
  Future<void> upsertPool(PoolEntity pool);

  /// 根据 ID 查询池。
  ///
  /// [poolId] 为池的唯一标识符。
  /// 返回匹配的 [PoolEntity]，若不存在则返回 null。
  Future<PoolEntity?> getPoolById(String poolId);

  /// 插入或更新成员。
  ///
  /// [member] 为要写入的成员数据。
  Future<void> upsertMember(PoolMember member);

  /// 查询池的成员列表。
  ///
  /// [poolId] 为池的唯一标识符。
  /// 返回该池下的所有成员列表。
  Future<List<PoolMember>> listMembers(String poolId);

  /// 移除成员。
  ///
  /// [poolId] 为池的唯一标识符。
  /// [memberId] 为成员的唯一标识符。
  Future<void> removeMember(String poolId, String memberId);

  /// 插入或更新请求。
  ///
  /// [request] 为要写入的请求数据。
  Future<void> upsertRequest(PoolRequest request);

  /// 查询池的请求列表。
  ///
  /// [poolId] 为池的唯一标识符。
  /// 返回该池下的所有加入请求列表。
  Future<List<PoolRequest>> listRequests(String poolId);

  /// 移除请求。
  ///
  /// [poolId] 为池的唯一标识符。
  /// [requestId] 为请求的唯一标识符。
  Future<void> removeRequest(String poolId, String requestId);
}
