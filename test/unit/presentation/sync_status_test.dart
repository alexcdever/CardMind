// input: SyncStatus 各具名构造参数。
// output: 断言状态种类、错误码与 writeSaved 标记正确。
// pos: 同步状态值对象测试。修改本文件需同步更新所属 DIR.md。
import 'package:cardmind/features/sync/sync_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('idle_constructor_setsExpectedFields', () {
    const status = SyncStatus.idle();
    expect(status.kind, SyncStatusKind.idle);
    expect(status.code, isNull);
    expect(status.isWriteSaved, isFalse);
  });

  test('connecting_constructor_setsExpectedFields', () {
    const status = SyncStatus.connecting();
    expect(status.kind, SyncStatusKind.connecting);
    expect(status.code, isNull);
    expect(status.isWriteSaved, isFalse);
  });

  test('connected_constructor_allowsWriteSaved', () {
    const status = SyncStatus.connected(isWriteSaved: true);
    expect(status.kind, SyncStatusKind.connected);
    expect(status.isWriteSaved, isTrue);
  });

  test('syncing_constructor_allowsWriteSaved', () {
    const status = SyncStatus.syncing(isWriteSaved: true);
    expect(status.kind, SyncStatusKind.syncing);
    expect(status.isWriteSaved, isTrue);
  });

  test('queryConvergencePending_constructor_setsCodeAndWriteSaved', () {
    const status = SyncStatus.queryConvergencePending(
      'PROJECTION_NOT_CONVERGED',
    );
    expect(status.kind, SyncStatusKind.queryConvergencePending);
    expect(status.code, 'PROJECTION_NOT_CONVERGED');
    expect(status.isWriteSaved, isTrue);
  });

  test('degraded_constructor_defaultsWriteSavedToFalse', () {
    const status = SyncStatus.degraded('REQUEST_TIMEOUT');
    expect(status.kind, SyncStatusKind.degraded);
    expect(status.code, 'REQUEST_TIMEOUT');
    expect(status.isWriteSaved, isFalse);
  });

  test('healthy_constructor_mapsToConnected', () {
    const status = SyncStatus.healthy();
    expect(status.kind, SyncStatusKind.connected);
    expect(status.code, isNull);
  });
}
