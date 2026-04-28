import 'package:cardmind/app/theme/cardmind_colors.dart';
import 'package:cardmind/app/theme/cardmind_theme.dart';
import 'package:flutter/material.dart';

class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.currentSection,
    required this.onSectionChanged,
  });

  final String currentSection;
  final ValueChanged<String> onSectionChanged;

  bool get _isNotes => currentSection == 'cards';
  bool get _isPool => currentSection == 'pool';

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: CardMindColors.bgCanvas,
        borderRadius: BorderRadius.circular(CardMindRadii.xl),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _NavItem(
            icon: Icons.book_outlined,
            label: '笔记',
            active: _isNotes,
            onTap: () => onSectionChanged('cards'),
          ),
          _NavItem(
            icon: Icons.hub_outlined,
            label: '数据池',
            active: _isPool,
            onTap: () => onSectionChanged('pool'),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 78,
        height: 44,
        decoration: BoxDecoration(
          color: active ? CardMindColors.brandLightBg : Colors.transparent,
          borderRadius: BorderRadius.circular(CardMindRadii.md),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? CardMindColors.brand : CardMindColors.textPrimary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: active ? CardMindColors.brand : CardMindColors.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
