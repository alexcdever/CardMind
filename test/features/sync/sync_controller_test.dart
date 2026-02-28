// input: 使用假服务驱动 SyncController 连续执行两次 retry。
// output: 状态从错误态经历 connecting 后转为 connected。
// pos: 覆盖同步控制器重试状态机迁移，防止恢复流程卡死。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/features/sync/sync_controller.dart';
import 'package:cardmind/features/sync/sync_service.dart';
import 'package:cardmind/features/sync/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardmind/bridge_generated/api.dart' as frb;

class _FakeSyncService extends SyncService {
  _FakeSyncService({required super.gateway, required super.networkId});

  int _retryCount = 0;

  @override
  Future<SyncStatus> retry() async {
    _retryCount += 1;
    if (_retryCount == 1) {
      return const SyncStatus.error('REQUEST_TIMEOUT');
    }
    return const SyncStatus.connected();
  }
}

class _NoopGateway implements SyncGateway {
  @override
  Future<void> syncConnect({
    required BigInt networkId,
    required String target,
  }) async {}

  @override
  Future<void> syncDisconnect({required BigInt networkId}) async {}

  @override
  Future<void> syncJoinPool({
    required BigInt networkId,
    required String poolId,
  }) async {}

  @override
  Future<frb.SyncResultDto> syncPull({required BigInt networkId}) async {
    return const frb.SyncResultDto(state: 'ok');
  }

  @override
  Future<frb.SyncResultDto> syncPush({required BigInt networkId}) async {
    return const frb.SyncResultDto(state: 'ok');
  }

  @override
  Future<frb.SyncStatusDto> syncStatus({required BigInt networkId}) async {
    return const frb.SyncStatusDto(state: 'idle');
  }
}

void main() {
  test('retry after error should move to connecting then connected', () async {
    final service = _FakeSyncService(
      gateway: _NoopGateway(),
      networkId: BigInt.one,
    );
    final controller = SyncController(service: service);
    final seen = <SyncStatusKind>[];
    controller.addListener(() {
      seen.add(controller.status.kind);
    });

    await controller.retry();
    expect(controller.status.kind, SyncStatusKind.error);

    await controller.retry();
    expect(controller.status.kind, SyncStatusKind.connected);
    expect(
      seen,
      containsAllInOrder([SyncStatusKind.connecting, SyncStatusKind.connected]),
    );
  });
}
