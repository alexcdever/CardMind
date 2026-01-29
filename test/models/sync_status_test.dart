import 'package:flutter_test/flutter_test.dart';
import 'package:cardmind/models/sync_status.dart';

void main() {
  group('SyncStatus Model Tests', () {
    group('Factory Constructors', () {
      test('it_should_create_not_yet_synced_status', () {
        // WHEN: 创建 notYetSynced 状态
        final status = SyncStatus.notYetSynced();

        // THEN: 状态应为 notYetSynced
        expect(status.state, SyncState.notYetSynced);
        // AND: lastSyncTime 应为 null
        expect(status.lastSyncTime, isNull);
        // AND: errorMessage 应为 null
        expect(status.errorMessage, isNull);
        // AND: isValid() 应返回 true
        expect(status.isValid(), isTrue);
      });

      test('it_should_create_syncing_status', () {
        // WHEN: 创建 syncing 状态
        final status = SyncStatus.syncing();

        // THEN: 状态应为 syncing
        expect(status.state, SyncState.syncing);
        // AND: lastSyncTime 可以为 null
        expect(status.lastSyncTime, isNull);
        // AND: errorMessage 应为 null
        expect(status.errorMessage, isNull);
        // AND: isValid() 应返回 true
        expect(status.isValid(), isTrue);

        // WHEN: 创建 syncing 状态（带上次同步时间）
        final lastSyncTime = DateTime.now().subtract(const Duration(seconds: 5));
        final statusWithTime = SyncStatus.syncing(lastSyncTime: lastSyncTime);

        // THEN: lastSyncTime 应非空
        expect(statusWithTime.lastSyncTime, lastSyncTime);
        // AND: isValid() 应返回 true
        expect(statusWithTime.isValid(), isTrue);
      });

      test('it_should_create_synced_status_with_time', () {
        // WHEN: 创建 synced 状态（带时间）
        final lastSyncTime = DateTime.now();
        final status = SyncStatus.synced(lastSyncTime: lastSyncTime);

        // THEN: 状态应为 synced
        expect(status.state, SyncState.synced);
        // AND: lastSyncTime 应非空
        expect(status.lastSyncTime, lastSyncTime);
        // AND: errorMessage 应为 null
        expect(status.errorMessage, isNull);
        // AND: isValid() 应返回 true
        expect(status.isValid(), isTrue);
      });

      test('it_should_create_failed_status_with_error', () {
        // WHEN: 创建 failed 状态（带错误信息）
        final status = SyncStatus.failed(
          errorMessage: SyncErrorType.noAvailablePeers,
        );

        // THEN: 状态应为 failed
        expect(status.state, SyncState.failed);
        // AND: errorMessage 应为 "未发现可用设备"
        expect(status.errorMessage, SyncErrorType.noAvailablePeers);
        // AND: isValid() 应返回 true
        expect(status.isValid(), isTrue);

        // WHEN: 创建 failed 状态（带错误信息和上次同步时间）
        final lastSyncTime = DateTime.now().subtract(const Duration(minutes: 5));
        final statusWithTime = SyncStatus.failed(
          errorMessage: SyncErrorType.connectionTimeout,
          lastSyncTime: lastSyncTime,
        );

        // THEN: lastSyncTime 应非空
        expect(statusWithTime.lastSyncTime, lastSyncTime);
        // AND: isValid() 应返回 true
        expect(statusWithTime.isValid(), isTrue);
      });
    });

    group('State Consistency Validation', () {
      test('it_should_enforce_not_yet_synced_has_null_time', () {
        // WHEN: 创建 notYetSynced 状态（带时间）
        final status = SyncStatus(
          state: SyncState.notYetSynced,
          lastSyncTime: DateTime.now(),
        );

        // THEN: isValid() 应返回 false
        expect(status.isValid(), isFalse);
      });

      test('it_should_enforce_failed_has_error_message', () {
        // WHEN: 创建 failed 状态（errorMessage 为 null）
        final statusWithNull = SyncStatus(
          state: SyncState.failed,
          errorMessage: null,
        );

        // THEN: isValid() 应返回 false
        expect(statusWithNull.isValid(), isFalse);

        // WHEN: 创建 failed 状态（errorMessage 为空字符串）
        final statusWithEmpty = SyncStatus(
          state: SyncState.failed,
          errorMessage: '',
        );

        // THEN: isValid() 应返回 false
        expect(statusWithEmpty.isValid(), isFalse);
      });

      test('it_should_enforce_synced_has_non_null_time', () {
        // WHEN: 创建 synced 状态（lastSyncTime 为 null）
        final status = SyncStatus(
          state: SyncState.synced,
          lastSyncTime: null,
        );

        // THEN: isValid() 应返回 false
        expect(status.isValid(), isFalse);
      });
    });

    group('Equality and HashCode', () {
      test('should have correct equality', () {
        final time = DateTime.now();
        final status1 = SyncStatus.synced(lastSyncTime: time);
        final status2 = SyncStatus.synced(lastSyncTime: time);
        final status3 = SyncStatus.notYetSynced();

        expect(status1, equals(status2));
        expect(status1, isNot(equals(status3)));
      });

      test('should have correct hashCode', () {
        final time = DateTime.now();
        final status1 = SyncStatus.synced(lastSyncTime: time);
        final status2 = SyncStatus.synced(lastSyncTime: time);

        expect(status1.hashCode, equals(status2.hashCode));
      });
    });

    group('Helper Properties', () {
      test('isActive should return true for syncing and synced', () {
        expect(SyncStatus.syncing().isActive, isTrue);
        expect(
          SyncStatus.synced(lastSyncTime: DateTime.now()).isActive,
          isTrue,
        );
        expect(SyncStatus.notYetSynced().isActive, isFalse);
        expect(
          SyncStatus.failed(errorMessage: 'error').isActive,
          isFalse,
        );
      });
    });

    group('Error Types', () {
      test('should have correct error messages', () {
        expect(SyncErrorType.noAvailablePeers, '未发现可用设备');
        expect(SyncErrorType.connectionTimeout, '连接超时');
        expect(SyncErrorType.dataTransmissionFailed, '数据传输失败');
        expect(SyncErrorType.crdtMergeFailed, '数据合并失败');
        expect(SyncErrorType.localStorageError, '本地存储错误');
      });
    });

    group('State Transition Validation', () {
      test('notYetSynced can transition to syncing or failed', () {
        final status = SyncStatus.notYetSynced();

        // 允许的转换
        expect(status.canTransitionTo(SyncState.syncing), isTrue);
        expect(status.canTransitionTo(SyncState.failed), isTrue);

        // 禁止的转换
        expect(status.canTransitionTo(SyncState.synced), isFalse);
        expect(status.canTransitionTo(SyncState.notYetSynced), isTrue); // 相同状态允许
      });

      test('syncing can transition to synced or failed', () {
        final status = SyncStatus.syncing();

        // 允许的转换
        expect(status.canTransitionTo(SyncState.synced), isTrue);
        expect(status.canTransitionTo(SyncState.failed), isTrue);

        // 禁止的转换
        expect(status.canTransitionTo(SyncState.notYetSynced), isFalse);
        expect(status.canTransitionTo(SyncState.syncing), isTrue); // 相同状态允许
      });

      test('synced can transition to syncing or failed', () {
        final status = SyncStatus.synced(lastSyncTime: DateTime.now());

        // 允许的转换
        expect(status.canTransitionTo(SyncState.syncing), isTrue);
        expect(status.canTransitionTo(SyncState.failed), isTrue);

        // 禁止的转换
        expect(status.canTransitionTo(SyncState.notYetSynced), isFalse);
        expect(status.canTransitionTo(SyncState.synced), isTrue); // 相同状态允许
      });

      test('failed can only transition to syncing', () {
        final status = SyncStatus.failed(errorMessage: 'error');

        // 允许的转换
        expect(status.canTransitionTo(SyncState.syncing), isTrue);

        // 禁止的转换
        expect(status.canTransitionTo(SyncState.synced), isFalse);
        expect(status.canTransitionTo(SyncState.notYetSynced), isFalse);
        expect(status.canTransitionTo(SyncState.failed), isTrue); // 相同状态允许
      });
    });
  });
}
