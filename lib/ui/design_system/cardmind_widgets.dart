import 'package:flutter/material.dart';

import 'cardmind_theme.dart';

class CardMindPrimaryButton extends StatelessWidget {
  const CardMindPrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.expanded = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final tokens = context.cardMind;
    final button = FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: Size(expanded ? double.infinity : 0, 48),
        padding: const EdgeInsets.symmetric(horizontal: CardMindSpacing.lg),
        backgroundColor: tokens.accent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: tokens.border,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CardMindRadii.md),
        ),
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class CardMindIconButton extends StatelessWidget {
  const CardMindIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.cardMind;
    return Semantics(
      button: true,
      identifier: 'action-${tooltip.replaceAll(' ', '-')}',
      label: tooltip,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 19),
        color: selected ? tokens.accent : tokens.mutedInk,
        style: IconButton.styleFrom(
          fixedSize: const Size(
            CardMindLayout.mobileTouchTarget,
            CardMindLayout.mobileTouchTarget,
          ),
          minimumSize: const Size(
            CardMindLayout.mobileTouchTarget,
            CardMindLayout.mobileTouchTarget,
          ),
          padding: EdgeInsets.zero,
          backgroundColor: selected
              ? tokens.accent.withValues(alpha: 0.10)
              : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CardMindRadii.md),
          ),
        ),
      ),
    );
  }
}

class CardMindSearchField extends StatelessWidget {
  const CardMindSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    this.mobile = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      identifier: 'note-search-field',
      label: '搜索笔记',
      child: TextField(
        key: const ValueKey('note-search-input'),
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: '搜索笔记',
          prefixIcon: const Icon(Icons.search, size: 20),
          prefixIconConstraints: const BoxConstraints(
            minWidth: CardMindLayout.mobileTouchTarget,
            minHeight: CardMindLayout.mobileTouchTarget,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: '清除搜索',
                  onPressed: onClear,
                  icon: const Icon(Icons.close, size: 18),
                ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: CardMindLayout.mobileTouchTarget,
            minHeight: CardMindLayout.mobileTouchTarget,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: CardMindSpacing.md,
            vertical: mobile ? 12 : 10,
          ),
        ),
        style: TextStyle(fontSize: mobile ? 16 : 15),
      ),
    );
  }
}

class CardMindTag extends StatelessWidget {
  const CardMindTag({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.comfortable = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool comfortable;

  @override
  Widget build(BuildContext context) {
    final tokens = context.cardMind;
    return Semantics(
      button: onTap != null,
      label: label,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CardMindRadii.md),
        child: Container(
          constraints: comfortable
              ? const BoxConstraints(
                  minHeight: CardMindLayout.mobileTouchTarget,
                )
              : null,
          padding: EdgeInsets.symmetric(
            horizontal: CardMindSpacing.sm,
            vertical: comfortable ? 14 : 4,
          ),
          decoration: BoxDecoration(
            color: selected
                ? tokens.accent.withValues(alpha: 0.10)
                : tokens.surfaceLow,
            border: Border.all(color: selected ? tokens.accent : tokens.border),
            borderRadius: BorderRadius.circular(CardMindRadii.md),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? tokens.accent : tokens.mutedInk,
              fontSize: comfortable ? 13 : 12,
              height: comfortable ? 20 / 13 : 16 / 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class CardMindSyncStatus extends StatelessWidget {
  const CardMindSyncStatus({
    super.key,
    this.label = '本地已就绪',
    this.pendingCount = 0,
    this.lastSyncFailedFor,
  });

  /// 静态（无动态状态时）展示的兜底文字。
  final String label;

  /// 待同步笔记数（决策 16：>0 时显示"N 篇待同步"）。
  final int pendingCount;

  /// 连续同步失败累计时长（决策 18：>24h 时圆点变色提示"长时间未同步"）。
  final Duration? lastSyncFailedFor;

  /// 连续失败超时圆点颜色（灰黄，用于测试断言）。
  static const Color staleDotColor = Color(0xFFB08D2E);

  /// 连续失败是否超过 24 小时（决策 18 提示阈值）。
  static const Duration staleThreshold = Duration(hours: 24);

  bool get _stale => lastSyncFailedFor != null && lastSyncFailedFor! > staleThreshold;

  String get _effectiveLabel {
    if (_stale) {
      return pendingCount > 0
          ? '长时间未同步 · $pendingCount 篇待同步'
          : '长时间未同步';
    }
    if (pendingCount > 0) return '$pendingCount 篇待同步';
    return label;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.cardMind;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          key: const ValueKey('sync-status-dot'),
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: _stale ? staleDotColor : tokens.accent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: CardMindSpacing.sm),
        Flexible(
          child: Text(
            _effectiveLabel,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _stale ? staleDotColor : tokens.mutedInk,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class CardMindEmptyState extends StatelessWidget {
  const CardMindEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.cardMind;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.all(CardMindSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42, color: tokens.border),
              const SizedBox(height: CardMindSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: CardMindSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: tokens.mutedInk),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
