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
    return IconButton(
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
    return TextField(
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
            border: Border.all(
              color: selected ? tokens.accent : tokens.border,
            ),
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
  const CardMindSyncStatus({super.key, this.label = '本地已就绪'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.cardMind;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: tokens.accent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: CardMindSpacing.sm),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.mutedInk,
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
