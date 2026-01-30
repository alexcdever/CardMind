/// 同步详情对话框数据格式化工具
library;

/// 格式化数据大小
class SyncDialogFormatters {
  /// 格式化字节数为人类可读格式
  ///
  /// 示例:
  /// - 0 → "0 B"
  /// - 1024 → "1.0 KB"
  /// - 1536 → "1.5 KB"
  /// - 1048576 → "1.0 MB"
  static String formatBytes(int bytes) {
    if (bytes < 0) return '0 B';
    if (bytes == 0) return '0 B';

    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    int unitIndex = 0;
    double size = bytes.toDouble();

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    // 如果是字节，不显示小数
    if (unitIndex == 0) {
      return '${size.toInt()} ${units[unitIndex]}';
    }

    // 其他单位显示一位小数
    return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
  }

  /// 格式化时间戳为相对时间
  ///
  /// 示例:
  /// - null → "从未同步"
  /// - 刚刚 → "刚刚"
  /// - 1 分钟前 → "1 分钟前"
  /// - 1 小时前 → "1 小时前"
  /// - 昨天 → "昨天"
  /// - 2 天前 → "2 天前"
  /// - 具体日期 → "2026-01-30 14:30"
  static String formatRelativeTime(DateTime? timestamp) {
    if (timestamp == null) return '从未同步';

    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return '刚刚';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} 分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} 小时前';
    } else if (difference.inDays == 1) {
      return '昨天';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} 天前';
    } else {
      // 显示具体日期时间
      return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} '
          '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  /// 格式化耗时（毫秒）
  ///
  /// 示例:
  /// - 0 → "< 1 ms"
  /// - 500 → "500 ms"
  /// - 1500 → "1.5 s"
  /// - 65000 → "1 分 5 秒"
  static String formatDuration(int milliseconds) {
    if (milliseconds < 1) return '< 1 ms';

    if (milliseconds < 1000) {
      return '$milliseconds ms';
    }

    final seconds = milliseconds / 1000;
    if (seconds < 60) {
      return '${seconds.toStringAsFixed(1)} s';
    }

    final minutes = (seconds / 60).floor();
    final remainingSeconds = (seconds % 60).floor();

    if (remainingSeconds == 0) {
      return '$minutes 分钟';
    }

    return '$minutes 分 $remainingSeconds 秒';
  }

  /// 格式化卡片数量
  ///
  /// 示例:
  /// - 0 → "0 张卡片"
  /// - 1 → "1 张卡片"
  /// - 100 → "100 张卡片"
  static String formatCardCount(int count) {
    return '$count 张卡片';
  }

  /// 格式化设备状态
  ///
  /// 示例:
  /// - true → "在线"
  /// - false → "离线"
  static String formatDeviceStatus(bool isOnline) {
    return isOnline ? '在线' : '离线';
  }

  /// 格式化同步状态
  ///
  /// 示例:
  /// - "syncing" → "同步中"
  /// - "synced" → "已同步"
  /// - "failed" → "同步失败"
  /// - "idle" → "空闲"
  static String formatSyncStatus(String status) {
    switch (status.toLowerCase()) {
      case 'syncing':
        return '同步中';
      case 'synced':
        return '已同步';
      case 'failed':
        return '同步失败';
      case 'idle':
        return '空闲';
      default:
        return status;
    }
  }

  /// 截断长文本并添加省略号
  ///
  /// 示例:
  /// - formatEllipsis("Hello World", 5) → "Hello..."
  /// - formatEllipsis("Hi", 10) → "Hi"
  static String formatEllipsis(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }
}

/// 格式化缓存（用于性能优化）
class SyncDialogFormatterCache {
  final Map<String, String> _cache = {};

  /// 获取或计算格式化结果
  String getOrCompute(String key, String Function() compute) {
    if (_cache.containsKey(key)) {
      return _cache[key]!;
    }

    final result = compute();
    _cache[key] = result;
    return result;
  }

  /// 清除缓存
  void clear() {
    _cache.clear();
  }

  /// 清除特定键的缓存
  void remove(String key) {
    _cache.remove(key);
  }
}
