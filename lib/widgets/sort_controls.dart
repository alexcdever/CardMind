import 'package:cardmind/adaptive/platform_detector.dart';
import 'package:cardmind/models/sort_option.dart';
import 'package:flutter/material.dart';

/// 排序控制组件
///
/// 提供排序选项和升序/降序切换功能，支持响应式布局。
///
/// ## 功能特性
/// - 支持三种排序方式：创建时间、更新时间、标题
/// - 支持升序/降序切换
/// - 响应式布局：移动端显示下拉菜单，桌面端显示按钮组
/// - 当前排序状态高亮显示
///
/// ## 使用示例
/// ```dart
/// SortControls(
///   currentSort: SortOption.updatedAt,
///   ascending: false,
///   onSortChanged: (sort, ascending) {
///     // 处理排序变化
///   },
/// )
/// ```
///
/// ## 设计原理
/// - 移动端：使用 DropdownButton 节省空间
/// - 桌面端：使用 ButtonGroup 提供更好的可访问性
/// - 使用 Chip 显示当前排序状态
/// - 平滑的动画过渡
class SortControls extends StatelessWidget {
  /// 创建排序控制组件
  ///
  /// [currentSort] 当前排序选项
  /// [ascending] 是否升序排序
  /// [onSortChanged] 排序变化回调函数
  const SortControls({
    super.key,
    required this.currentSort,
    required this.ascending,
    required this.onSortChanged,
  });

  /// 当前排序选项
  final SortOption currentSort;

  /// 是否升序排序
  final bool ascending;

  /// 排序变化回调函数
  ///
  /// 参数：
  /// - [sort] 新的排序选项
  /// - [ascending] 是否升序
  final void Function(SortOption sort, bool ascending) onSortChanged;

  @override
  Widget build(BuildContext context) {
    // 根据平台选择不同的布局
    if (PlatformDetector.isMobile) {
      return _buildMobileLayout(context);
    } else {
      return _buildDesktopLayout(context);
    }
  }

  /// 移动端布局（下拉菜单）
  Widget _buildMobileLayout(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.sort,
            size: 20,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 8),
          // 排序选项下拉菜单
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<SortOption>(
                value: currentSort,
                isDense: true,
                style: theme.textTheme.bodyMedium,
                items: SortOption.values.map((sort) {
                  return DropdownMenuItem<SortOption>(
                    value: sort,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(sort.icon, size: 18),
                        const SizedBox(width: 8),
                        Text(sort.displayName),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    onSortChanged(value, ascending);
                  }
                },
              ),
            ),
          ),
          // 升序/降序切换按钮
          IconButton(
            icon: Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: () => onSortChanged(currentSort, !ascending),
            tooltip: ascending ? '升序' : '降序',
            iconSize: 20,
          ),
        ],
      ),
    );
  }

  /// 桌面端布局（按钮组）
  Widget _buildDesktopLayout(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 排序选项按钮组
        SegmentedButton<SortOption>(
          segments: SortOption.values.map((sort) {
            return ButtonSegment<SortOption>(
              value: sort,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(sort.icon, size: 18),
                  const SizedBox(width: 8),
                  Text(sort.displayName),
                ],
              ),
              icon: null,
            );
          }).toList(),
          selected: {currentSort},
          onSelectionChanged: (Set<SortOption> selection) {
            if (selection.isNotEmpty) {
              onSortChanged(selection.first, ascending);
            }
          },
        ),
        const SizedBox(width: 12),
        // 升序/降序切换
        OutlinedButton.icon(
          onPressed: () => onSortChanged(currentSort, !ascending),
          icon: Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward),
          label: Text(ascending ? '升序' : '降序'),
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.primary,
            side: BorderSide(color: theme.colorScheme.primary),
          ),
        ),
      ],
    );
  }
}

/// 排序状态标签组件
///
/// 显示当前排序状态的简洁标签，用于在卡片列表顶部显示。
///
/// ## 使用示例
/// ```dart
/// SortStatusChip(
///   sort: SortOption.updatedAt,
///   ascending: false,
///   onClear: () {
///     // 清除排序，恢复默认
///   },
/// )
/// ```
class SortStatusChip extends StatelessWidget {
  /// 创建排序状态标签
  ///
  /// [sort] 当前排序选项
  /// [ascending] 是否升序排序
  /// [onClear] 清除排序回调（可选）
  const SortStatusChip({
    super.key,
    required this.sort,
    required this.ascending,
    this.onClear,
  });

  /// 当前排序选项
  final SortOption sort;

  /// 是否升序排序
  final bool ascending;

  /// 清除排序回调
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Chip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward, size: 16),
          const SizedBox(width: 4),
          Text(sort.displayName),
        ],
      ),
      avatar: Icon(sort.icon, size: 18),
      deleteIcon: onClear != null ? const Icon(Icons.close, size: 18) : null,
      onDeleted: onClear,
      backgroundColor: theme.colorScheme.secondaryContainer,
      labelStyle: TextStyle(
        color: theme.colorScheme.onSecondaryContainer,
        fontSize: 13,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}
