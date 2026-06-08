import 'package:cardmind/app/theme/cardmind_colors.dart';
import 'package:cardmind/app/theme/cardmind_theme.dart';
import 'package:flutter/material.dart';

class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    this.tag,
    required this.title,
    required this.body,
    this.selected = false,
    this.onTap,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.tagColor,
    this.compact = false,
  });

  final String? tag;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback? onTap;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final Color? tagColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final unselectedBg = compact
        ? CardMindColors.bgSubtle
        : CardMindColors.bgCanvas;
    final bg = selected ? CardMindColors.bgSurface : unselectedBg;
    final border = selected
        ? const Border(left: BorderSide(color: CardMindColors.brand, width: 3))
        : null;
    final cardPadding = EdgeInsets.all(compact ? 14 : 16);
    final cardRadius = compact ? CardMindRadii.md : CardMindRadii.lg;
    final titleSize = compact ? 14.0 : 15.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        key: const ValueKey('note_card.container'),
        width: double.infinity,
        padding: cardPadding,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(cardRadius),
          border: border,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tag != null) ...[
              Text(
                tag!,
                style: TextStyle(
                  color: tagColor ?? CardMindColors.brand,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              title,
              style: TextStyle(
                color: CardMindColors.textPrimary,
                fontSize: titleSize,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                body,
                style: const TextStyle(
                  color: CardMindColors.textSecondary,
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
            if (actionLabel != null &&
                actionIcon != null &&
                onAction != null) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onAction,
                  icon: Icon(actionIcon, size: 14),
                  label: Text(actionLabel!),
                  style: TextButton.styleFrom(
                    foregroundColor: CardMindColors.textSecondary,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
