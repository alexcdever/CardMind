// input: test/features/sync/sync_controller_test.dart 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Flutter 测试模块，验证 UI、交互守卫与文档门禁行为。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 测试模块，验证 UI、交互守卫与文档门禁行为。
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
