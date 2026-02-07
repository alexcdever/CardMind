import 'package:cardmind/models/sync_history_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('it_should_format_data_transferred_by_thresholds', () {
    const base = SyncHistoryEntry(
      id: 'sync-1',
      timestamp: 0,
      status: SyncHistoryStatus.success,
      deviceId: 'dev-1',
      deviceName: 'Device',
      dataTransferred: 500,
    );
    const kb = SyncHistoryEntry(
      id: 'sync-2',
      timestamp: 0,
      status: SyncHistoryStatus.success,
      deviceId: 'dev-1',
      deviceName: 'Device',
      dataTransferred: 1024,
    );
    const mb = SyncHistoryEntry(
      id: 'sync-3',
      timestamp: 0,
      status: SyncHistoryStatus.success,
      deviceId: 'dev-1',
      deviceName: 'Device',
      dataTransferred: 1024 * 1024,
    );
    const gb = SyncHistoryEntry(
      id: 'sync-4',
      timestamp: 0,
      status: SyncHistoryStatus.success,
      deviceId: 'dev-1',
      deviceName: 'Device',
      dataTransferred: 1024 * 1024 * 1024,
    );

    expect(base.formattedDataTransferred, '500 B');
    expect(kb.formattedDataTransferred, '1.0 KB');
    expect(mb.formattedDataTransferred, '1.0 MB');
    expect(gb.formattedDataTransferred, '1.0 GB');
  });

  test('it_should_detect_success_and_failure_states', () {
    const success = SyncHistoryEntry(
      id: 'sync-1',
      timestamp: 0,
      status: SyncHistoryStatus.success,
      deviceId: 'dev-1',
      deviceName: 'Device',
      dataTransferred: 0,
    );
    const failed = SyncHistoryEntry(
      id: 'sync-2',
      timestamp: 0,
      status: SyncHistoryStatus.failed,
      deviceId: 'dev-1',
      deviceName: 'Device',
      dataTransferred: 0,
    );

    expect(success.isSuccess, isTrue);
    expect(success.isFailed, isFalse);
    expect(failed.isSuccess, isFalse);
    expect(failed.isFailed, isTrue);
  });

  test('it_should_compare_entries_by_id', () {
    const entryA = SyncHistoryEntry(
      id: 'same-id',
      timestamp: 0,
      status: SyncHistoryStatus.success,
      deviceId: 'dev-1',
      deviceName: 'Device',
      dataTransferred: 10,
    );
    const entryB = SyncHistoryEntry(
      id: 'same-id',
      timestamp: 1,
      status: SyncHistoryStatus.failed,
      deviceId: 'dev-2',
      deviceName: 'Other',
      dataTransferred: 20,
    );
    const entryC = SyncHistoryEntry(
      id: 'different-id',
      timestamp: 0,
      status: SyncHistoryStatus.success,
      deviceId: 'dev-1',
      deviceName: 'Device',
      dataTransferred: 10,
    );

    expect(entryA, equals(entryB));
    expect(entryA.hashCode, equals(entryB.hashCode));
    expect(entryA, isNot(equals(entryC)));
  });

  test('it_should_return_display_attributes_for_status', () {
    expect(SyncHistoryStatus.success.displayName, '成功');
    expect(SyncHistoryStatus.failed.displayName, '失败');
    expect(SyncHistoryStatus.inProgress.displayName, '进行中');

    expect(SyncHistoryStatus.success.icon, Icons.check_circle);
    expect(SyncHistoryStatus.failed.icon, Icons.error);
    expect(SyncHistoryStatus.inProgress.icon, Icons.sync);

    expect(SyncHistoryStatus.success.color, Colors.green);
    expect(SyncHistoryStatus.failed.color, Colors.red);
    expect(SyncHistoryStatus.inProgress.color, Colors.orange);
  });

  test('it_should_format_fractional_kilobytes', () {
    const entry = SyncHistoryEntry(
      id: 'sync-5',
      timestamp: 0,
      status: SyncHistoryStatus.success,
      deviceId: 'dev-1',
      deviceName: 'Device',
      dataTransferred: 1536,
    );

    expect(entry.formattedDataTransferred, '1.5 KB');
  });

  test('it_should_toString_contains_id', () {
    const entry = SyncHistoryEntry(
      id: 'sync-6',
      timestamp: 0,
      status: SyncHistoryStatus.failed,
      deviceId: 'dev-1',
      deviceName: 'Device',
      dataTransferred: 0,
    );

    expect(entry.toString(), contains('sync-6'));
  });
}
