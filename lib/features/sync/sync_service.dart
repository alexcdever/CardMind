/// # 同步服务
///
/// 负责同步相关的业务逻辑和状态管理。
/// 桥接 FRB 网关与前端同步状态模型。
///
/// ## 外部依赖
/// - 依赖 [SyncGateway] 提供底层同步网关接口。
/// - 依赖 [SyncStatus] 提供同步状态模型。
library sync_service;

import 'package:cardmind/bridge_generated/api.dart' as frb;
import 'package:cardmind/bridge_generated/models/api_error.dart';
import 'package:cardmind/features/sync/sync_status.dart';

/// 同步网关抽象接口。
///
/// 定义与底层同步服务交互的方法。
abstract class SyncGateway {
  /// 获取同步状态。
  Future<frb.SyncStatusDto> syncStatus({required BigInt networkId});

  /// 建立同步连接。
  Future<void> syncConnect({required BigInt networkId, required String target});

  /// 断开同步连接。
  Future<void> syncDisconnect({required BigInt networkId});

  /// 加入同步池。
  Future<void> syncJoinPool({
    required BigInt networkId,
    required String poolId,
  });

  /// 推送同步数据。
  Future<frb.SyncResultDto> syncPush({required BigInt networkId});

  /// 拉取同步数据。
  Future<frb.SyncResultDto> syncPull({required BigInt networkId});
}

/// FRB 同步网关实现。
///
/// 通过 Flutter Rust Bridge 调用 Rust 后端实现同步操作。
class FrbSyncGateway implements SyncGateway {
  @override
  Future<frb.SyncStatusDto> syncStatus({required BigInt networkId}) {
    return frb.syncStatus(networkId: networkId);
  }

  @override
  Future<void> syncConnect({
    required BigInt networkId,
    required String target,
  }) {
    return frb.syncConnect(networkId: networkId, target: target);
  }

  @override
  Future<void> syncDisconnect({required BigInt networkId}) {
    return frb.syncDisconnect(networkId: networkId);
  }

  @override
  Future<void> syncJoinPool({
    required BigInt networkId,
    required String poolId,
  }) {
    return frb.syncJoinPool(networkId: networkId, poolId: poolId);
  }

  @override
  Future<frb.SyncResultDto> syncPush({required BigInt networkId}) {
    return frb.syncPush(networkId: networkId);
  }

  @override
  Future<frb.SyncResultDto> syncPull({required BigInt networkId}) {
    return frb.syncPull(networkId: networkId);
  }
}

/// 同步服务类。
///
/// 封装同步业务逻辑，处理异常并映射为 [SyncStatus]。
class SyncService {
  /// 创建同步服务。
  SyncService({required this.gateway, required this.networkId});

  /// 同步网关实例。
  final SyncGateway gateway;

  /// 网络ID。
  final BigInt networkId;

  /// 获取当前同步状态。
  Future<SyncStatus> status() async {
    try {
      final dto = await gateway.syncStatus(networkId: networkId);
      return _mapDtoToStatus(dto);
    } on ApiError catch (error) {
      return SyncStatus.error(error.code);
    } catch (_) {
      return const SyncStatus.error('INTERNAL');
    }
  }

  /// 建立同步连接。
  Future<SyncStatus> connect(String target) async {
    try {
      await gateway.syncConnect(networkId: networkId, target: target);
      return status();
    } on ApiError catch (error) {
      return SyncStatus.error(error.code);
    } catch (_) {
      return const SyncStatus.error('INTERNAL');
    }
  }

  /// 重试同步操作。
  Future<SyncStatus> retry() async {
    try {
      await gateway.syncPull(networkId: networkId);
      return status();
    } on ApiError catch (error) {
      return SyncStatus.error(error.code, isWriteSaved: true);
    } catch (_) {
      return const SyncStatus.error('INTERNAL');
    }
  }

  /// 重新建立同步连接。
  Future<SyncStatus> reconnect(String target) async {
    try {
      await gateway.syncDisconnect(networkId: networkId);
      await gateway.syncConnect(networkId: networkId, target: target);
      return status();
    } on ApiError catch (error) {
      return SyncStatus.error(error.code);
    } catch (_) {
      return const SyncStatus.error('INTERNAL');
    }
  }

  /// 将 DTO 映射为 SyncStatus（Phase 2 契约字段映射）。
  SyncStatus _mapDtoToStatus(frb.SyncStatusDto dto) {
    return SyncStatus.fromDto(dto);
  }
}
