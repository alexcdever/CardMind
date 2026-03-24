// input: fake SyncGateway 返回不同 dto、ApiError 与普通异常。
// output: 断言 SyncService 正确映射同步状态与错误分支。
// pos: 同步服务单元测试，覆盖状态映射与异常处理。修改本文件需同步更新所属 DIR.md。
import 'package:cardmind/bridge_generated/api.dart' as frb;
import 'package:cardmind/bridge_generated/models/api_error.dart';
import 'package:cardmind/features/sync/sync_service.dart';
import 'package:cardmind/features/sync/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';

const _samePath = 'same_path';
const _contentSafe = 'content_safe';
const _contentSafeLocalOnly = 'content_safe_local_only';
const _nextActionNone = 'none';

frb.SyncStatusDto _statusDto({
  required String state,
  required String writeState,
  required String projectionState,
  required String syncState,
  String continuityState = _samePath,
  String contentState = _contentSafe,
  String nextAction = _nextActionNone,
  String? code,
  String queryConvergenceState = 'ready',
  String instanceContinuityState = 'ready',
  String localContentSafety = 'safe',
  String recoveryStage = 'stable',
  List<String> allowedOperations = const ['view', 'continue_edit'],
  List<String> forbiddenOperations = const [],
}) => frb.SyncStatusDto(
  state: state,
  writeState: writeState,
  projectionState: projectionState,
  syncState: syncState,
  continuityState: continuityState,
  contentState: contentState,
  nextAction: nextAction,
  code: code,
  queryConvergenceState: queryConvergenceState,
  instanceContinuityState: instanceContinuityState,
  localContentSafety: localContentSafety,
  recoveryStage: recoveryStage,
  allowedOperations: allowedOperations,
  forbiddenOperations: forbiddenOperations,
);

frb.SyncResultDto _resultDto({
  required String state,
  required String writeState,
  required String projectionState,
  required String syncState,
  String continuityState = _samePath,
  String contentState = _contentSafe,
  String nextAction = _nextActionNone,
  String? code,
  String queryConvergenceState = 'ready',
  String instanceContinuityState = 'ready',
  String localContentSafety = 'safe',
  String recoveryStage = 'stable',
  List<String> allowedOperations = const ['view', 'continue_edit'],
  List<String> forbiddenOperations = const [],
}) => frb.SyncResultDto(
  state: state,
  writeState: writeState,
  projectionState: projectionState,
  syncState: syncState,
  continuityState: continuityState,
  contentState: contentState,
  nextAction: nextAction,
  code: code,
  queryConvergenceState: queryConvergenceState,
  instanceContinuityState: instanceContinuityState,
  localContentSafety: localContentSafety,
  recoveryStage: recoveryStage,
  allowedOperations: allowedOperations,
  forbiddenOperations: forbiddenOperations,
);

class _FakeGateway implements SyncGateway {
  _FakeGateway({
    this.statusDto,
    this.statusError,
    this.statusException,
    this.connectError,
    this.connectException,
    this.disconnectError,
    this.pullException,
  });

  frb.SyncStatusDto? statusDto;
  ApiError? statusError;
  Object? statusException;
  ApiError? connectError;
  Object? connectException;
  ApiError? disconnectError;
  Object? pullException;
  int connectCalls = 0;
  int disconnectCalls = 0;
  int pullCalls = 0;

  @override
  Future<void> syncConnect({
    required BigInt networkId,
    required String target,
  }) async {
    connectCalls += 1;
    if (connectError != null) throw connectError!;
    if (connectException != null) throw connectException!;
  }

  @override
  Future<void> syncDisconnect({required BigInt networkId}) async {
    disconnectCalls += 1;
    if (disconnectError != null) throw disconnectError!;
  }

  @override
  Future<void> syncJoinPool({
    required BigInt networkId,
    required String poolId,
  }) async {}

  @override
  Future<frb.SyncResultDto> syncPull({required BigInt networkId}) async {
    pullCalls += 1;
    if (pullException != null) throw pullException!;
    return _resultDto(
      state: 'ok',
      writeState: 'write_saved',
      projectionState: 'projection_ready',
      syncState: 'connected',
    );
  }

  @override
  Future<frb.SyncResultDto> syncPush({required BigInt networkId}) async {
    return _resultDto(
      state: 'ok',
      writeState: 'write_saved',
      projectionState: 'projection_ready',
      syncState: 'connected',
    );
  }

  @override
  Future<frb.SyncStatusDto> syncStatus({required BigInt networkId}) async {
    if (statusError != null) throw statusError!;
    if (statusException != null) throw statusException!;
    return statusDto!;
  }
}

SyncService _service(_FakeGateway gateway) =>
    SyncService(gateway: gateway, networkId: BigInt.one);

void main() {
  test('status_withIdleSyncState_returnsIdle', () async {
    final status = await _service(
      _FakeGateway(
        statusDto: _statusDto(
          state: 'idle',
          writeState: 'write_saved',
          projectionState: 'projection_ready',
          syncState: 'idle',
          recoveryStage: 'stable',
        ),
      ),
    ).status();

    expect(status.kind, SyncStatusKind.idle);
  });

  test('status_withSyncingSyncState_returnsSyncing', () async {
    final status = await _service(
      _FakeGateway(
        statusDto: _statusDto(
          state: 'syncing',
          writeState: 'write_saved',
          projectionState: 'projection_ready',
          syncState: 'syncing',
          contentState: _contentSafeLocalOnly,
          nextAction: 'check_status',
          recoveryStage: 'retrying',
        ),
      ),
    ).status();

    expect(status.kind, SyncStatusKind.syncing);
    // Phase 2: SyncStatus.syncing 默认 isWriteSaved = false
    expect(status.isWriteSaved, isFalse);
  });

  test('status_withDegradedSyncState_returnsDegraded', () async {
    final status = await _service(
      _FakeGateway(
        statusDto: _statusDto(
          state: 'degraded',
          writeState: 'write_saved',
          projectionState: 'projection_ready',
          syncState: 'degraded',
          contentState: _contentSafeLocalOnly,
          nextAction: 'reconnect',
          code: 'REQUEST_TIMEOUT',
          recoveryStage: 'needs_user_action',
        ),
      ),
    ).status();

    expect(status.kind, SyncStatusKind.degraded);
    expect(status.code, 'REQUEST_TIMEOUT');
  });

  test('status_withUnknownSyncState_returnsInternalError', () async {
    final status = await _service(
      _FakeGateway(
        statusDto: _statusDto(
          state: 'weird',
          writeState: 'write_saved',
          projectionState: 'projection_ready',
          syncState: 'weird',
          recoveryStage: 'unsafe_unknown',
          code: 'UNKNOWN_SYNC_STATE',
        ),
      ),
    ).status();

    expect(status.kind, SyncStatusKind.error);
    expect(status.code, 'UNKNOWN_SYNC_STATE');
  });

  test('status_withApiError_returnsBackendCode', () async {
    final status = await _service(
      _FakeGateway(
        statusError: const ApiError(code: 'INVALID_HANDLE', message: 'bad'),
      ),
    ).status();

    expect(status.kind, SyncStatusKind.error);
    expect(status.code, 'INVALID_HANDLE');
  });

  test('status_withUnknownException_returnsInternal', () async {
    final status = await _service(
      _FakeGateway(statusException: StateError('boom')),
    ).status();

    expect(status.kind, SyncStatusKind.error);
    expect(status.code, 'INTERNAL');
  });

  test('connect_success_refreshesStatus', () async {
    final gateway = _FakeGateway(
      statusDto: _statusDto(
        state: 'connected',
        writeState: 'write_saved',
        projectionState: 'projection_ready',
        syncState: 'connected',
      ),
    );

    final status = await _service(gateway).connect('peer');

    expect(gateway.connectCalls, 1);
    expect(status.kind, SyncStatusKind.connected);
  });

  test('connect_withApiError_returnsMappedError', () async {
    final status = await _service(
      _FakeGateway(
        statusDto: _statusDto(
          state: 'idle',
          writeState: 'write_saved',
          projectionState: 'projection_ready',
          syncState: 'idle',
        ),
        connectError: const ApiError(
          code: 'REQUEST_TIMEOUT',
          message: 'timeout',
        ),
      ),
    ).connect('peer');

    expect(status.kind, SyncStatusKind.error);
    expect(status.code, 'REQUEST_TIMEOUT');
  });

  test('connect_withUnknownException_returnsInternal', () async {
    final status = await _service(
      _FakeGateway(
        statusDto: _statusDto(
          state: 'idle',
          writeState: 'write_saved',
          projectionState: 'projection_ready',
          syncState: 'idle',
        ),
        connectException: StateError('boom'),
      ),
    ).connect('peer');

    expect(status.kind, SyncStatusKind.error);
    expect(status.code, 'INTERNAL');
  });

  test('retry_withUnknownException_returnsInternal', () async {
    final status = await _service(
      _FakeGateway(
        statusDto: _statusDto(
          state: 'idle',
          writeState: 'write_saved',
          projectionState: 'projection_ready',
          syncState: 'idle',
        ),
        pullException: StateError('boom'),
      ),
    ).retry();

    expect(status.kind, SyncStatusKind.error);
    expect(status.code, 'INTERNAL');
  });

  test('reconnect_withApiError_returnsMappedError', () async {
    final status = await _service(
      _FakeGateway(
        statusDto: _statusDto(
          state: 'idle',
          writeState: 'write_saved',
          projectionState: 'projection_ready',
          syncState: 'idle',
        ),
        disconnectError: const ApiError(
          code: 'REQUEST_TIMEOUT',
          message: 'timeout',
        ),
      ),
    ).reconnect('peer');

    expect(status.kind, SyncStatusKind.error);
    expect(status.code, 'REQUEST_TIMEOUT');
  });
}
