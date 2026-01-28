/// Time formatting utility for note cards
///
/// Provides relative and absolute time formatting according to design specifications:
/// - 0-10 seconds: "刚刚" (just now)
/// - 11-59 seconds: "X秒前" (X seconds ago)
/// - 1-59 minutes: "X分钟前" (X minutes ago)
/// - 1-23 hours: "X小时前" (X hours ago)
/// - >24 hours: Absolute time format
///   - Same year: "MM-DD HH:mm"
///   - Different year: "YYYY-MM-DD HH:mm"
class TimeFormatter {
  /// Format timestamp to relative or absolute time string
  ///
  /// [timestamp] - Unix timestamp in milliseconds
  /// [now] - Optional current time for testing, defaults to DateTime.now()
  static String formatTime(int timestamp, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    final targetTime = DateTime.fromMillisecondsSinceEpoch(timestamp);

    // Handle invalid or future timestamps
    if (targetTime.isAfter(currentTime)) {
      return '刚刚'; // "Just now" for future timestamps (clock skew)
    }

    // Handle timestamps before 1970-01-01
    if (targetTime.year < 1970) {
      return '未知时间'; // "Unknown time" for invalid timestamps
    }

    final difference = currentTime.difference(targetTime);
    final secondsAgo = difference.inSeconds;

    // Relative time formatting (within 24 hours)
    if (secondsAgo <= 10) {
      return '刚刚'; // 0-10 seconds: "Just now"
    } else if (secondsAgo <= 59) {
      return '${secondsAgo}秒前'; // 11-59 seconds: "X seconds ago"
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前'; // 1-59 minutes: "X minutes ago"
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前'; // 1-23 hours: "X hours ago"
    }

    // Absolute time formatting (over 24 hours)
    return _formatAbsoluteTime(targetTime, currentTime);
  }

  /// Format absolute time according to year comparison
  static String _formatAbsoluteTime(DateTime targetTime, DateTime currentTime) {
    if (targetTime.year == currentTime.year) {
      // Same year: "MM-DD HH:mm"
      return '${targetTime.month.toString().padLeft(2, '0')}-${targetTime.day.toString().padLeft(2, '0')} '
          '${targetTime.hour.toString().padLeft(2, '0')}:${targetTime.minute.toString().padLeft(2, '0')}';
    } else {
      // Different year: "YYYY-MM-DD HH:mm"
      return '${targetTime.year}-${targetTime.month.toString().padLeft(2, '0')}-${targetTime.day.toString().padLeft(2, '0')} '
          '${targetTime.hour.toString().padLeft(2, '0')}:${targetTime.minute.toString().padLeft(2, '0')}';
    }
  }

  /// Check if timestamp is within relative time range (24 hours)
  static bool isRelativeTime(int timestamp, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    final targetTime = DateTime.fromMillisecondsSinceEpoch(timestamp);

    if (targetTime.isAfter(currentTime) || targetTime.year < 1970) {
      return false; // Invalid timestamps use absolute format
    }

    final difference = currentTime.difference(targetTime);
    return difference.inHours < 24;
  }

  /// Get the time difference in seconds for relative time calculation
  static int getSecondsAgo(int timestamp, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    final targetTime = DateTime.fromMillisecondsSinceEpoch(timestamp);

    if (targetTime.isAfter(currentTime)) {
      return 0; // Future timestamps return 0
    }

    return currentTime.difference(targetTime).inSeconds;
  }

  /// Check if timestamp should be considered as "just now"
  static bool isJustNow(int timestamp, {DateTime? now}) {
    return getSecondsAgo(timestamp, now: now) <= 10;
  }

  /// Batch format multiple timestamps for performance optimization
  static Map<String, String> batchFormatTimes(
    List<int> timestamps, {
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final results = <String, String>{};

    for (final timestamp in timestamps) {
      results[timestamp.toString()] = formatTime(timestamp, now: currentTime);
    }

    return results;
  }

  /// Create a time cache for performance optimization
  static TimeCache createTimeCache({Duration? ttl}) {
    return TimeCache(ttl: ttl);
  }
}

/// Cache-friendly time formatting with TTL
class TimeCache {
  final Map<String, _CacheEntry> _cache = {};
  final Duration _ttl;

  TimeCache({Duration? ttl}) : _ttl = ttl ?? const Duration(seconds: 60);

  String format(int timestamp, {DateTime? now}) {
    final key = timestamp.toString();
    final currentTime = now ?? DateTime.now();

    // Check if cached entry is still valid
    if (_cache.containsKey(key)) {
      final entry = _cache[key]!;
      if (currentTime.difference(entry.timestamp) < _ttl) {
        return entry.formattedTime;
      }
    }

    // Format and cache the result
    final formattedTime = TimeFormatter.formatTime(timestamp, now: currentTime);
    _cache[key] = _CacheEntry(formattedTime, currentTime);

    return formattedTime;
  }

  void clear() {
    _cache.clear();
  }
}

/// Cache entry for time formatting
class _CacheEntry {
  final String formattedTime;
  final DateTime timestamp;

  _CacheEntry(this.formattedTime, this.timestamp);
}
