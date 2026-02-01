import 'package:flutter/material.dart';

/// 同步历史条目模型
///
/// 记录每次同步操作的详细信息
class SyncHistoryEntry {
  /// 创建同步历史条目
  const SyncHistoryEntry({
    required this.id,
    required this.timestamp,
    required this.status,
    required this.deviceId,
    required this.deviceName,
    required this.dataTransferred,
    this.errorMessage,
  });

  /// 同步记录唯一标识
  final String id;

  /// 同步时间戳（毫秒）
  final int timestamp;

  /// 同步状态
  final SyncHistoryStatus status;

  /// 同步设备ID
  final String deviceId;

  /// 同步设备名称
  final String deviceName;

  /// 数据传输量（字节）
  final int dataTransferred;

  /// 错误信息（仅在失败状态时有值）
  final String? errorMessage;

  /// 是否成功
  bool get isSuccess => status == SyncHistoryStatus.success;

  /// 是否失败
  bool get isFailed => status == SyncHistoryStatus.failed;

  /// 格式化数据传输量
  String get formattedDataTransferred {
    if (dataTransferred < 1024) {
      return '$dataTransferred B';
    } else if (dataTransferred < 1024 * 1024) {
      return '${(dataTransferred / 1024).toStringAsFixed(1)} KB';
    } else if (dataTransferred < 1024 * 1024 * 1024) {
      return '${(dataTransferred / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(dataTransferred / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncHistoryEntry && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'SyncHistoryEntry(id: $id, timestamp: $timestamp, status: $status, '
        'deviceId: $deviceId, deviceName: $deviceName, '
        'dataTransferred: $dataTransferred)';
  }
}

/// 同步历史状态枚举
enum SyncHistoryStatus {
  /// 同步成功
  success,

  /// 同步失败
  failed,

  /// 同步中（进行中）
  inProgress,
}

/// 同步历史状态扩展方法
extension SyncHistoryStatusExtension on SyncHistoryStatus {
  /// 获取状态显示名称
  String get displayName {
    switch (this) {
      case SyncHistoryStatus.success:
        return '成功';
      case SyncHistoryStatus.failed:
        return '失败';
      case SyncHistoryStatus.inProgress:
        return '进行中';
    }
  }

  /// 获取状态图标
  IconData get icon {
    switch (this) {
      case SyncHistoryStatus.success:
        return Icons.check_circle;
      case SyncHistoryStatus.failed:
        return Icons.error;
      case SyncHistoryStatus.inProgress:
        return Icons.sync;
    }
  }

  /// 获取状态颜色
  Color get color {
    switch (this) {
      case SyncHistoryStatus.success:
        return Colors.green;
      case SyncHistoryStatus.failed:
        return Colors.red;
      case SyncHistoryStatus.inProgress:
        return Colors.orange;
    }
  }
}
