import 'package:cardmind/app/theme/cardmind_colors.dart';
import 'package:cardmind/app/theme/cardmind_theme.dart';
import 'package:flutter/material.dart';

class StyledSearchField extends StatelessWidget {
  const StyledSearchField({
    super.key,
    this.hintText = '搜索...',
    this.onChanged,
    this.focusNode,
    this.semanticId,
    this.semanticLabel,
    this.compact = false,
  });

  final String hintText;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final String? semanticId;
  final String? semanticLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fillColor = compact ? CardMindColors.bgInput : CardMindColors.bgCanvas;
    final borderRadius = compact ? CardMindRadii.sm : CardMindRadii.md;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      identifier: semanticId,
      label: semanticLabel,
      textField: true,
      child: TextField(
        focusNode: focusNode,
        decoration: InputDecoration(
          hintText: hintText,
          filled: true,
          fillColor: fillColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          prefixIcon: const Icon(
            Icons.search,
            size: 14,
            color: CardMindColors.textMuted,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 30, minHeight: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            borderSide: BorderSide.none,
          ),
          hintStyle: const TextStyle(
            color: CardMindColors.textMuted,
            fontSize: 12,
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
