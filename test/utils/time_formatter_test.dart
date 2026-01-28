import 'package:flutter_test/flutter_test.dart';
import 'package:cardmind/utils/time_formatter.dart';

/// Unit tests for TimeFormatter utility
/// Based on design specification section 5.2.1
void main() {
  group('TimeFormatter Unit Tests', () {
    group('Relative Time Formatting', () {
      test('it_should_format_just_now_for_0_to_10_seconds', () {
        // Given: Current time and timestamps within 0-10 seconds
        final now = DateTime.now();
        final timestamps = [
          now.millisecondsSinceEpoch - 0,
          now.millisecondsSinceEpoch - 5000,
          now.millisecondsSinceEpoch - 10000,
        ];

        // Then: All should format as "刚刚" (just now)
        for (final timestamp in timestamps) {
          expect(TimeFormatter.formatTime(timestamp, now: now), equals('刚刚'));
        }
      });

      test('it_should_format_seconds_ago_for_11_to_59_seconds', () {
        // Given: Current time and timestamps within 11-59 seconds
        final now = DateTime.now();
        final testCases = [
          (now.millisecondsSinceEpoch - 11000, '11秒前'),
          (now.millisecondsSinceEpoch - 30000, '30秒前'),
          (now.millisecondsSinceEpoch - 59000, '59秒前'),
        ];

        // Then: Should format as "X秒前"
        for (final (timestamp, expected) in testCases) {
          expect(
            TimeFormatter.formatTime(timestamp, now: now),
            equals(expected),
          );
        }
      });

      test('it_should_format_minutes_ago_for_1_to_59_minutes', () {
        // Given: Current time and timestamps within 1-59 minutes
        final now = DateTime.now();
        final testCases = [
          (now.millisecondsSinceEpoch - 60000, '1分钟前'),
          (now.millisecondsSinceEpoch - 1800000, '30分钟前'),
          (now.millisecondsSinceEpoch - 3540000, '59分钟前'),
        ];

        // Then: Should format as "X分钟前"
        for (final (timestamp, expected) in testCases) {
          expect(
            TimeFormatter.formatTime(timestamp, now: now),
            equals(expected),
          );
        }
      });

      test('it_should_format_hours_ago_for_1_to_23_hours', () {
        // Given: Current time and timestamps within 1-23 hours
        final now = DateTime.now();
        final testCases = [
          (now.millisecondsSinceEpoch - 3600000, '1小时前'),
          (now.millisecondsSinceEpoch - 43200000, '12小时前'),
          (now.millisecondsSinceEpoch - 82800000, '23小时前'),
        ];

        // Then: Should format as "X小时前"
        for (final (timestamp, expected) in testCases) {
          expect(
            TimeFormatter.formatTime(timestamp, now: now),
            equals(expected),
          );
        }
      });
    });

    group('Absolute Time Formatting', () {
      test('it_should_format_same_year_as_MM_DD_HH_mm', () {
        // Given: Current time in 2024 and timestamp from same year
        final now = DateTime(2024, 6, 15, 14, 30);
        final targetTime = DateTime(2024, 1, 20, 9, 15);
        final timestamp = targetTime.millisecondsSinceEpoch;

        // Then: Should format as "01-20 09:15"
        expect(
          TimeFormatter.formatTime(timestamp, now: now),
          equals('01-20 09:15'),
        );
      });

      test('it_should_format_different_year_as_YYYY_MM_DD_HH_mm', () {
        // Given: Current time in 2024 and timestamp from different year
        final now = DateTime(2024, 6, 15, 14, 30);
        final targetTime = DateTime(2023, 12, 25, 18, 45);
        final timestamp = targetTime.millisecondsSinceEpoch;

        // Then: Should format as "2023-12-25 18:45"
        expect(
          TimeFormatter.formatTime(timestamp, now: now),
          equals('2023-12-25 18:45'),
        );
      });
    });

    group('Boundary Conditions', () {
      test('it_should_handle_future_timestamps_as_just_now', () {
        // Given: Future timestamp (clock skew scenario)
        final now = DateTime.now();
        final futureTime = now.add(const Duration(minutes: 5));
        final timestamp = futureTime.millisecondsSinceEpoch;

        // Then: Should format as "刚刚"
        expect(TimeFormatter.formatTime(timestamp, now: now), equals('刚刚'));
      });

      test('it_should_handle_timestamps_before_1970_as_unknown_time', () {
        // Given: Timestamp before 1970-01-01
        final now = DateTime.now();
        final ancientTime = DateTime(1969, 12, 31, 23, 59, 59);
        final timestamp = ancientTime.millisecondsSinceEpoch;

        // Then: Should format as "未知时间"
        expect(TimeFormatter.formatTime(timestamp, now: now), equals('未知时间'));
      });

      test('it_should_handle_invalid_timestamps_gracefully', () {
        // Given: Very old timestamp
        final now = DateTime.now();
        final invalidTime = DateTime(1900, 1, 1);
        final timestamp = invalidTime.millisecondsSinceEpoch;

        // Then: Should format as "未知时间"
        expect(TimeFormatter.formatTime(timestamp, now: now), equals('未知时间'));
      });
    });

    group('Utility Functions', () {
      test('it_should_correctly_identify_relative_time_range', () {
        // Given: Current time and various timestamps
        final now = DateTime.now();
        final relativeTime = now.subtract(const Duration(hours: 12));
        final absoluteTime = now.subtract(const Duration(days: 2));

        // Then: Should correctly identify relative vs absolute time
        expect(
          TimeFormatter.isRelativeTime(
            relativeTime.millisecondsSinceEpoch,
            now: now,
          ),
          isTrue,
        );
        expect(
          TimeFormatter.isRelativeTime(
            absoluteTime.millisecondsSinceEpoch,
            now: now,
          ),
          isFalse,
        );
      });

      test('it_should_calculate_seconds_ago_correctly', () {
        // Given: Current time and specific timestamp
        final now = DateTime(2024, 1, 15, 12, 0, 0);
        final targetTime = DateTime(2024, 1, 15, 11, 30, 45);
        final timestamp = targetTime.millisecondsSinceEpoch;

        // Then: Should calculate 29 minutes and 15 seconds = 1755 seconds
        expect(TimeFormatter.getSecondsAgo(timestamp, now: now), equals(1755));
      });

      test('it_should_identify_just_now_correctly', () {
        // Given: Current time and timestamps
        final now = DateTime.now();
        final justNow = now.subtract(const Duration(seconds: 5));
        final notJustNow = now.subtract(const Duration(seconds: 15));

        // Then: Should correctly identify "just now"
        expect(
          TimeFormatter.isJustNow(justNow.millisecondsSinceEpoch, now: now),
          isTrue,
        );
        expect(
          TimeFormatter.isJustNow(notJustNow.millisecondsSinceEpoch, now: now),
          isFalse,
        );
      });

      test('it_should_batch_format_multiple_timestamps', () {
        // Given: Multiple timestamps
        final now = DateTime.now();
        final timestamps = [
          now.subtract(const Duration(seconds: 30)).millisecondsSinceEpoch,
          now.subtract(const Duration(minutes: 5)).millisecondsSinceEpoch,
          now.subtract(const Duration(hours: 2)).millisecondsSinceEpoch,
        ];

        // When: Batch format timestamps
        final results = TimeFormatter.batchFormatTimes(timestamps, now: now);

        // Then: Should format all timestamps correctly
        expect(results.length, equals(3));
        expect(results.values.any((time) => time.contains('秒前')), isTrue);
        expect(results.values.any((time) => time.contains('分钟前')), isTrue);
        expect(results.values.any((time) => time.contains('小时前')), isTrue);
      });
    });

    group('TimeCache Functionality', () {
      test('it_should_cache_time_formatting_results', () {
        // Given: Time cache and timestamp
        final cache = TimeFormatter.createTimeCache();
        final now = DateTime.now();
        final timestamp = now
            .subtract(const Duration(minutes: 10))
            .millisecondsSinceEpoch;

        // When: Format same timestamp multiple times
        final result1 = cache.format(timestamp, now: now);
        final result2 = cache.format(timestamp, now: now);

        // Then: Results should be identical (cached)
        expect(result1, equals(result2));
      });

      test('it_should_expire_cache_after_ttl', () async {
        // Given: Time cache with short TTL
        final cache = TimeFormatter.createTimeCache(
          ttl: const Duration(milliseconds: 100),
        );
        final now = DateTime.now();
        final timestamp = now
            .subtract(const Duration(minutes: 10))
            .millisecondsSinceEpoch;

        // When: Format, wait for expiration, format again
        final result1 = cache.format(timestamp, now: now);
        await Future.delayed(const Duration(milliseconds: 150));
        final result2 = cache.format(timestamp, now: now);

        // Then: Results should still be identical (same input)
        expect(result1, equals(result2));
      });

      test('it_should_clear_cache', () {
        // Given: Time cache with data
        final cache = TimeFormatter.createTimeCache();
        final now = DateTime.now();
        final timestamp = now.millisecondsSinceEpoch;

        // When: Format, clear cache, format again
        cache.format(timestamp, now: now);
        cache.clear();
        final result = cache.format(timestamp, now: now);

        // Then: Should work after clearing
        expect(result, isNotNull);
      });
    });
  });
}
