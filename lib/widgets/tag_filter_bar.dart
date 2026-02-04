import 'package:flutter/material.dart';

/// Tag Filter Bar
///
/// 规格编号: SP-UI-TAG-001
/// 标签过滤组件，支持：
/// - 水平滚动标签列表
/// - 多选支持
/// - 过滤计数显示
/// - 清除过滤按钮
class TagFilterBar extends StatefulWidget {
  const TagFilterBar({
    super.key,
    required this.availableTags,
    required this.selectedTags,
    required this.onTagToggle,
    required this.onClearFilter,
    this.totalCardCount = 0,
    this.filteredCardCount = 0,
  });

  /// 所有可用的标签
  final List<String> availableTags;

  /// 当前选中的标签
  final Set<String> selectedTags;

  /// 切换标签选择
  final ValueChanged<String> onTagToggle;

  /// 清除所有标签过滤
  final VoidCallback onClearFilter;

  /// 总卡片数
  final int totalCardCount;

  /// 过滤后的卡片数
  final int filteredCardCount;

  @override
  State<TagFilterBar> createState() => _TagFilterBarState();
}

class _TagFilterBarState extends State<TagFilterBar> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFilter = widget.selectedTags.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 过滤计数显示
          if (hasFilter)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.filter_list,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '已筛选 ${widget.filteredCardCount} / ${widget.totalCardCount} 张卡片',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: widget.onClearFilter,
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('清除'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ),
            ),

          // 水平滚动标签列表
          Row(
            children: [
              // 过滤图标
              Icon(
                Icons.tag,
                size: 20,
                color: hasFilter
                    ? theme.colorScheme.primary
                    : theme.disabledColor,
              ),
              const SizedBox(width: 8),
              // 标签提示或标签列表
              Expanded(
                child: widget.availableTags.isEmpty
                    ? Text(
                        '暂无标签',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.disabledColor,
                        ),
                      )
                    : SizedBox(
                        height: 36,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.availableTags.length,
                          itemBuilder: (context, index) {
                            final tag = widget.availableTags[index];
                            final isSelected = widget.selectedTags.contains(
                              tag,
                            );
                            return Padding(
                              padding: EdgeInsets.only(
                                right: index == widget.availableTags.length - 1
                                    ? 0
                                    : 8,
                              ),
                              child: _TagChip(
                                tag: tag,
                                isSelected: isSelected,
                                onTap: () => widget.onTagToggle(tag),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 标签芯片组件
class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.tag,
    required this.isSelected,
    required this.onTap,
  });

  final String tag;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Icon(Icons.check, size: 14, color: theme.colorScheme.primary)
            else
              Icon(Icons.add, size: 14, color: theme.disabledColor),
            const SizedBox(width: 4),
            Text(
              tag,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
