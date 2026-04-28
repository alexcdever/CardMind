import 'package:cardmind/app/theme/cardmind_colors.dart';
import 'package:cardmind/app/theme/cardmind_theme.dart';
import 'package:flutter/material.dart';

class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.tag,
    required this.title,
    required this.body,
    this.selected = false,
    this.onTap,
    this.tagColor,
  });

  final String tag;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback? onTap;
  final Color? tagColor;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? CardMindColors.bgSurface : CardMindColors.bgCanvas;
    final border = selected
        ? const Border(
            left: BorderSide(
              color: CardMindColors.brand,
              width: 3,
            ),
          )
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(CardMindRadii.lg),
          border: border,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tag,
              style: TextStyle(
                color: tagColor ?? CardMindColors.brand,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: CardMindColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
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
        ),
      ),
    );
  }
}
