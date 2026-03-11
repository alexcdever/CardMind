// input: 接收同步状态、连接、重试等参数并路由到 FRB 同步接口。
// output: 提供同步用例 ApiClient 抽象与 FRB 实现。
// pos: 同步后端调用客户端，负责收敛 Flutter 到 Rust 的同步入口。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件定义同步 ApiClient，供后续控制器逐步切换使用。
import 'package:cardmind/bridge_generated/api.dart' as frb;

abstract class SyncApiClient {
  Future<frb.SyncStatusDto> status({required BigInt networkId});

  Future<void> connect({required BigInt networkId, required String target});

  Future<void> disconnect({required BigInt networkId});

  Future<void> joinPool({required BigInt networkId, required String poolId});

  Future<frb.SyncResultDto> push({required BigInt networkId});

  Future<frb.SyncResultDto> pull({required BigInt networkId});
}

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
