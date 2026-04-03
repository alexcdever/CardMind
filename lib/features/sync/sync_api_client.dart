/// # 同步 API 客户端
///
/// 定义同步相关的 API 客户端抽象和 FRB 实现。
/// 提供状态查询、连接管理、数据推送拉取等操作的接口。
import 'package:cardmind/bridge_generated/api.dart' as frb;

/// 同步 API 客户端抽象接口。
abstract class SyncApiClient {
  /// 获取同步状态。
  Future<frb.SyncStatusDto> status({required BigInt networkId});

  /// 建立同步连接。
  Future<void> connect({required BigInt networkId, required String target});

  /// 断开同步连接。
  Future<void> disconnect({required BigInt networkId});

  /// 加入同步池。
  Future<void> joinPool({required BigInt networkId, required String poolId});

  /// 推送同步数据。
  Future<frb.SyncResultDto> push({required BigInt networkId});

  /// 拉取同步数据。
  Future<frb.SyncResultDto> pull({required BigInt networkId});
}

/// 基于 FRB 的同步 API 客户端实现。
///
/// 通过 Flutter Rust Bridge 调用 Rust 后端实现同步操作。
class FrbSyncApiClient implements SyncApiClient {
  @override
  Future<frb.SyncStatusDto> status({required BigInt networkId}) {
    return frb.syncStatus(networkId: networkId);
  }

  @override
  Future<void> connect({required BigInt networkId, required String target}) {
    return frb.syncConnect(networkId: networkId, target: target);
  }

  @override
  Future<void> disconnect({required BigInt networkId}) {
    return frb.syncDisconnect(networkId: networkId);
  }

  @override
  Future<void> joinPool({required BigInt networkId, required String poolId}) {
    return frb.syncJoinPool(networkId: networkId, poolId: poolId);
  }

  @override
  Future<frb.SyncResultDto> push({required BigInt networkId}) {
    return frb.syncPush(networkId: networkId);
  }

  @override
  Future<frb.SyncResultDto> pull({required BigInt networkId}) {
    return frb.syncPull(networkId: networkId);
  }
}
