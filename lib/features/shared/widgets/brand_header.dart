import 'package:cardmind/app/theme/cardmind_colors.dart';
import 'package:flutter/material.dart';

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.iconSize = 14, this.fontSize = 14});

  final double iconSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.grid_view_rounded, size: iconSize, color: CardMindColors.brand),
        const SizedBox(width: 8),
        Text(
          'Card Mind',
          style: TextStyle(
            color: CardMindColors.brand,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
