// input: fake SyncService 返回 connect/reconnect/refresh 的不同状态。
// output: 断言 SyncController 更新状态并通知监听器。
// pos: SyncController 单元测试。修改本文件需同步更新所属 DIR.md。
import 'package:cardmind/features/sync/sync_controller.dart';
import 'package:cardmind/features/sync/sync_service.dart';
import 'package:cardmind/features/sync/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cardmind/bridge_generated/api.dart' as frb;

class _NoopGateway2 implements SyncGateway {
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
  Future<frb.SyncResultDto> syncPull({required BigInt networkId}) async =>
      const frb.SyncResultDto(
        state: 'ok',
        writeState: 'write_saved',
        projectionState: 'projection_ready',
        syncState: 'connected',
        continuityState: 'same_path',
        contentState: 'content_safe',
        nextAction: 'none',
        code: null,
      );

  @override
  Future<frb.SyncResultDto> syncPush({required BigInt networkId}) async =>
      const frb.SyncResultDto(
        state: 'ok',
        writeState: 'write_saved',
        projectionState: 'projection_ready',
        syncState: 'connected',
        continuityState: 'same_path',
        contentState: 'content_safe',
        nextAction: 'none',
        code: null,
      );

  @override
  Future<frb.SyncStatusDto> syncStatus({required BigInt networkId}) async =>
      const frb.SyncStatusDto(
        state: 'idle',
        writeState: 'write_saved',
        projectionState: 'projection_ready',
        syncState: 'idle',
        continuityState: 'same_path',
        contentState: 'content_safe',
        nextAction: 'none',
        code: null,
      );
}

class _FakeControllerService extends SyncService {
  _FakeControllerService()
    : super(gateway: _NoopGateway2(), networkId: BigInt.one);

  SyncStatus connectStatus = const SyncStatus.connected();
  SyncStatus reconnectStatus = const SyncStatus.connected();
  SyncStatus refreshStatus = const SyncStatus.idle();
  int connectCalls = 0;
  int reconnectCalls = 0;
  int statusCalls = 0;

  @override
  Future<SyncStatus> connect(String target) async {
    connectCalls += 1;
    return connectStatus;
  }

  @override
  Future<SyncStatus> reconnect(String target) async {
    reconnectCalls += 1;
    return reconnectStatus;
  }

  @override
  Future<SyncStatus> status() async {
    statusCalls += 1;
    return refreshStatus;
  }
}

void main() {
  test('connect_updatesStatusAndNotifiesListeners', () async {
    final service = _FakeControllerService();
    final controller = SyncController(service: service);
    final seen = <SyncStatusKind>[];
    controller.addListener(() => seen.add(controller.status.kind));

    await controller.connect('peer');

    expect(service.connectCalls, 1);
    expect(controller.status.kind, SyncStatusKind.connected);
    expect(seen, <SyncStatusKind>[
      SyncStatusKind.connecting,
      SyncStatusKind.connected,
    ]);
  });

  test('reconnect_updatesStatusAndNotifiesListeners', () async {
    final service = _FakeControllerService()
      ..reconnectStatus = const SyncStatus.degraded('REQUEST_TIMEOUT');
    final controller = SyncController(service: service);

    await controller.reconnect('peer');

    expect(service.reconnectCalls, 1);
    expect(controller.status.kind, SyncStatusKind.degraded);
    expect(controller.status.code, 'REQUEST_TIMEOUT');
  });

  test('refresh_updatesStatusFromService', () async {
    final service = _FakeControllerService()
      ..refreshStatus = const SyncStatus.projectionPending(
        'PROJECTION_NOT_CONVERGED',
      );
    final controller = SyncController(service: service);

    await controller.refresh();

    expect(service.statusCalls, 1);
    expect(controller.status.kind, SyncStatusKind.projectionPending);
    expect(controller.status.code, 'PROJECTION_NOT_CONVERGED');
  });
}
