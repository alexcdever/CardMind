// input: fake backend 网关返回业务写成功/投影未收敛/同步失败语义。
// output: 断言前端 SyncStatus 能区分本地保存成功、投影待收敛与同步失败。
// pos: 覆盖同步状态语义分离场景，防止前端混淆不同恢复动作。修改本文件需同步更新文件头与所属 DIR.md。
import 'package:cardmind/bridge_generated/api.dart' as frb;
import 'package:cardmind/bridge_generated/models/api_error.dart';
import 'package:cardmind/features/sync/sync_service.dart';
import 'package:cardmind/features/sync/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';

class _SemanticsGateway implements SyncGateway {
  _SemanticsGateway({required this.statusDto, this.pullError});

  final frb.SyncStatusDto statusDto;
  final ApiError? pullError;

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
    if (pullError != null) throw pullError!;
    return const frb.SyncResultDto(
      state: 'ok',
      writeState: 'write_saved',
      projectionState: 'ready',
      syncState: 'connected',
      code: null,
    );
  }

  @override
  Future<frb.SyncResultDto> syncPush({required BigInt networkId}) async {
    return const frb.SyncResultDto(
      state: 'ok',
      writeState: 'write_saved',
      projectionState: 'ready',
      syncState: 'connected',
      code: null,
    );
  }

  @override
  Future<frb.SyncStatusDto> syncStatus({required BigInt networkId}) async =>
      statusDto;
}

void main() {
  test(
    'frontend should distinguish write success projection pending and sync failure',
    () async {
      final projectionPendingService = SyncService(
        gateway: _SemanticsGateway(
          statusDto: const frb.SyncStatusDto(
            state: 'connected',
            writeState: 'write_saved',
            projectionState: 'pending',
            syncState: 'idle',
            code: 'PROJECTION_NOT_CONVERGED',
          ),
        ),
        networkId: BigInt.one,
      );
      final syncFailureService = SyncService(
        gateway: _SemanticsGateway(
          statusDto: const frb.SyncStatusDto(
            state: 'connected',
            writeState: 'write_saved',
            projectionState: 'ready',
            syncState: 'failed',
            code: 'REQUEST_TIMEOUT',
          ),
          pullError: const ApiError(
            code: 'REQUEST_TIMEOUT',
            message: 'timeout',
          ),
        ),
        networkId: BigInt.two,
      );

      final projectionPending = await projectionPendingService.status();
      final syncFailure = await syncFailureService.retry();

      expect(projectionPending.kind, SyncStatusKind.projectionPending);
      expect(projectionPending.code, 'PROJECTION_NOT_CONVERGED');
      expect(projectionPending.isWriteSaved, isTrue);

      expect(syncFailure.kind, SyncStatusKind.error);
      expect(syncFailure.code, 'REQUEST_TIMEOUT');
      expect(syncFailure.isWriteSaved, isFalse);
    },
  );
}
