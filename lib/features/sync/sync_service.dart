import 'package:cardmind/bridge_generated/api.dart' as frb;
import 'package:cardmind/bridge_generated/models/api_error.dart';
import 'package:cardmind/features/sync/sync_status.dart';

abstract class SyncGateway {
  Future<frb.SyncStatusDto> syncStatus({required BigInt networkId});

  Future<void> syncConnect({required BigInt networkId, required String target});

  Future<void> syncDisconnect({required BigInt networkId});

  Future<void> syncJoinPool({
    required BigInt networkId,
    required String poolId,
  });

  Future<frb.SyncResultDto> syncPush({required BigInt networkId});

  Future<frb.SyncResultDto> syncPull({required BigInt networkId});
}

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

class SyncService {
  SyncService({required this.gateway, required this.networkId});

  final SyncGateway gateway;
  final BigInt networkId;

  Future<SyncStatus> status() async {
    try {
      final dto = await gateway.syncStatus(networkId: networkId);
      return _mapState(dto.state);
    } on ApiError catch (error) {
      return SyncStatus.error(error.code);
    } catch (_) {
      return const SyncStatus.error('INTERNAL');
    }
  }

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

  Future<SyncStatus> retry() async {
    try {
      await gateway.syncPull(networkId: networkId);
      return status();
    } on ApiError catch (error) {
      return SyncStatus.error(error.code);
    } catch (_) {
      return const SyncStatus.error('INTERNAL');
    }
  }

  SyncStatus _mapState(String state) {
    switch (state) {
      case 'idle':
        return const SyncStatus.idle();
      case 'connected':
        return const SyncStatus.connected();
      case 'syncing':
        return const SyncStatus.syncing();
      case 'degraded':
        return const SyncStatus.degraded();
      default:
        return const SyncStatus.error('UNKNOWN_SYNC_STATE');
    }
  }
}
