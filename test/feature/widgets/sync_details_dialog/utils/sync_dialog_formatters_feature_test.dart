import 'package:cardmind/widgets/sync_details_dialog/utils/sync_dialog_formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SyncDialogFormatters', () {
    group('formatBytes', () {
      test('it_should_formats 0 bytes', () {
        expect(SyncDialogFormatters.formatBytes(0), '0 B');
      });

      test('it_should_formats bytes', () {
        expect(SyncDialogFormatters.formatBytes(512), '512 B');
        expect(SyncDialogFormatters.formatBytes(1023), '1023 B');
      });

      test('it_should_formats kilobytes', () {
        expect(SyncDialogFormatters.formatBytes(1024), '1.0 KB');
        expect(SyncDialogFormatters.formatBytes(1536), '1.5 KB');
        expect(SyncDialogFormatters.formatBytes(10240), '10.0 KB');
      });

      test('it_should_formats megabytes', () {
        expect(SyncDialogFormatters.formatBytes(1048576), '1.0 MB');
        expect(SyncDialogFormatters.formatBytes(1572864), '1.5 MB');
      });

      test('it_should_formats gigabytes', () {
        expect(SyncDialogFormatters.formatBytes(1073741824), '1.0 GB');
        expect(SyncDialogFormatters.formatBytes(1610612736), '1.5 GB');
      });

      test('it_should_formats terabytes', () {
        expect(SyncDialogFormatters.formatBytes(1099511627776), '1.0 TB');
      });

      test('it_should_handles negative values', () {
        expect(SyncDialogFormatters.formatBytes(-100), '0 B');
      });
    });

    group('formatRelativeTime', () {
      test('it_should_formats null as "从未同步"', () {
        expect(SyncDialogFormatters.formatRelativeTime(null), '从未同步');
      });

      test('it_should_formats recent time as "刚刚"', () {
        final now = DateTime.now();
        final recent = now.subtract(const Duration(seconds: 30));
        expect(SyncDialogFormatters.formatRelativeTime(recent), '刚刚');
      });

      test('it_should_formats minutes ago', () {
        final now = DateTime.now();
        final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));
        expect(
          SyncDialogFormatters.formatRelativeTime(fiveMinutesAgo),
          '5 分钟前',
        );
      });

      test('it_should_formats hours ago', () {
        final now = DateTime.now();
        final twoHoursAgo = now.subtract(const Duration(hours: 2));
        expect(SyncDialogFormatters.formatRelativeTime(twoHoursAgo), '2 小时前');
      });

      test('it_should_formats yesterday', () {
        final now = DateTime.now();
        final yesterday = now.subtract(const Duration(days: 1));
        expect(SyncDialogFormatters.formatRelativeTime(yesterday), '昨天');
      });

      test('it_should_formats days ago', () {
        final now = DateTime.now();
        final threeDaysAgo = now.subtract(const Duration(days: 3));
        expect(SyncDialogFormatters.formatRelativeTime(threeDaysAgo), '3 天前');
      });

      test('it_should_formats specific date for old timestamps', () {
        final oldDate = DateTime(2026, 1, 15, 14, 30);
        final result = SyncDialogFormatters.formatRelativeTime(oldDate);
        expect(result, contains('2026-01-15'));
        expect(result, contains('14:30'));
      });
    });

    group('formatDuration', () {
      test('it_should_formats very short duration', () {
        expect(SyncDialogFormatters.formatDuration(0), '< 1 ms');
      });

      test('it_should_formats milliseconds', () {
        expect(SyncDialogFormatters.formatDuration(500), '500 ms');
        expect(SyncDialogFormatters.formatDuration(999), '999 ms');
      });

      test('it_should_formats seconds', () {
        expect(SyncDialogFormatters.formatDuration(1000), '1.0 s');
        expect(SyncDialogFormatters.formatDuration(1500), '1.5 s');
        expect(SyncDialogFormatters.formatDuration(30000), '30.0 s');
      });

      test('it_should_formats minutes and seconds', () {
        expect(SyncDialogFormatters.formatDuration(65000), '1 分 5 秒');
        expect(SyncDialogFormatters.formatDuration(125000), '2 分 5 秒');
      });

      test('it_should_formats minutes without seconds', () {
        expect(SyncDialogFormatters.formatDuration(60000), '1 分钟');
        expect(SyncDialogFormatters.formatDuration(120000), '2 分钟');
      });
    });

    group('formatCardCount', () {
      test('it_should_formats zero cards', () {
        expect(SyncDialogFormatters.formatCardCount(0), '0 张卡片');
      });

      test('it_should_formats single card', () {
        expect(SyncDialogFormatters.formatCardCount(1), '1 张卡片');
      });

      test('it_should_formats multiple cards', () {
        expect(SyncDialogFormatters.formatCardCount(100), '100 张卡片');
        expect(SyncDialogFormatters.formatCardCount(1000), '1000 张卡片');
      });
    });

    group('formatDeviceStatus', () {
      test('it_should_formats online status', () {
        expect(SyncDialogFormatters.formatDeviceStatus(true), '在线');
      });

      test('it_should_formats offline status', () {
        expect(SyncDialogFormatters.formatDeviceStatus(false), '离线');
      });
    });

    group('formatSyncStatus', () {
      test('it_should_formats syncing status', () {
        expect(SyncDialogFormatters.formatSyncStatus('syncing'), '同步中');
        expect(SyncDialogFormatters.formatSyncStatus('SYNCING'), '同步中');
      });

      test('it_should_formats synced status', () {
        expect(SyncDialogFormatters.formatSyncStatus('synced'), '已同步');
      });

      test('it_should_formats failed status', () {
        expect(SyncDialogFormatters.formatSyncStatus('failed'), '同步失败');
      });

      test('it_should_formats idle status', () {
        expect(SyncDialogFormatters.formatSyncStatus('idle'), '空闲');
      });

      test('it_should_returns original for unknown status', () {
        expect(SyncDialogFormatters.formatSyncStatus('unknown'), 'unknown');
      });
    });

    group('formatEllipsis', () {
      test('it_should_returns original text if shorter than max length', () {
        expect(SyncDialogFormatters.formatEllipsis('Hello', 10), 'Hello');
      });

      test('it_should_truncates and adds ellipsis if longer than max length', () {
        expect(
          SyncDialogFormatters.formatEllipsis('Hello World', 5),
          'Hello...',
        );
      });

      test('it_should_handles exact length', () {
        expect(SyncDialogFormatters.formatEllipsis('Hello', 5), 'Hello');
      });
    });
  });

  group('SyncDialogFormatterCache', () {
    late SyncDialogFormatterCache cache;

    setUp(() {
      cache = SyncDialogFormatterCache();
    });

    test('it_should_computes and caches value', () {
      var computeCount = 0;
      final result1 = cache.getOrCompute('key1', () {
        computeCount++;
        return 'value1';
      });
      final result2 = cache.getOrCompute('key1', () {
        computeCount++;
        return 'value1';
      });

      expect(result1, 'value1');
      expect(result2, 'value1');
      expect(computeCount, 1); // Should only compute once
    });

    test('it_should_clears cache', () {
      cache
        ..getOrCompute('key1', () => 'value1')
        ..clear();

      var computeCount = 0;
      cache.getOrCompute('key1', () {
        computeCount++;
        return 'value1';
      });

      expect(computeCount, 1); // Should recompute after clear
    });

    test('it_should_removes specific key', () {
      cache
        ..getOrCompute('key1', () => 'value1')
        ..getOrCompute('key2', () => 'value2')
        ..remove('key1');

      var computeCount = 0;
      cache
        ..getOrCompute('key1', () {
          computeCount++;
          return 'value1';
        })
        ..getOrCompute('key2', () {
          computeCount++;
          return 'value2';
        });

      expect(computeCount, 1); // Only key1 should recompute
    });
  });
}
