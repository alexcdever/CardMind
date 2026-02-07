import 'package:flutter/material.dart';

/// 排序选项枚举
///
/// 定义卡片列表的排序方式
enum SortOption {
  /// 按创建时间排序
  createdAt,

  /// 按更新时间排序
  updatedAt,

  /// 按标题排序
  title,
}

/// 排序选项扩展方法
extension SortOptionExtension on SortOption {
  /// 获取排序选项的显示名称
  String get displayName {
    switch (this) {
      case SortOption.createdAt:
        return '创建时间';
      case SortOption.updatedAt:
        return '更新时间';
      case SortOption.title:
        return '标题';
    }
  }

  /// 获取排序选项的图标
  IconData get icon {
    switch (this) {
      case SortOption.createdAt:
        return Icons.schedule;
      case SortOption.updatedAt:
        return Icons.update;
      case SortOption.title:
        return Icons.title;
    }
  }
}
