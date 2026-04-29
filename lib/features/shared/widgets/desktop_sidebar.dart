import 'package:cardmind/app/theme/cardmind_colors.dart';
import 'package:cardmind/app/theme/cardmind_theme.dart';
import 'package:flutter/material.dart';

class DesktopSidebar extends StatelessWidget {
  const DesktopSidebar({
    super.key,
    required this.currentSection,
    required this.onSectionChanged,
    this.onNewNote,
  });

  final String currentSection;
  final ValueChanged<String> onSectionChanged;
  final VoidCallback? onNewNote;

  bool get _isNotes => currentSection == 'cards';
  bool get _isPool => currentSection == 'pool';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      color: CardMindColors.bgSidebar,
      padding: const EdgeInsets.fromLTRB(12, 26, 12, 24),
      child: Column(
        children: [
          const _SidebarBrand(),
          const SizedBox(height: 22),
          _NewNoteButton(onTap: onNewNote),
          const SizedBox(height: 22),
          _SidebarNavItem(
            icon: Icons.book_outlined,
            label: '笔记',
            active: _isNotes,
            onTap: () => onSectionChanged('cards'),
          ),
          const SizedBox(height: 8),
          _SidebarNavItem(
            icon: Icons.hub_outlined,
            label: '数据池',
            active: _isPool,
            onTap: () => onSectionChanged('pool'),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _SidebarBrand extends StatelessWidget {
  const _SidebarBrand();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.grid_view_rounded, size: 24, color: CardMindColors.brand),
        SizedBox(width: 8),
        Text(
          'Card Mind',
          style: TextStyle(
            color: CardMindColors.brand,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _NewNoteButton extends StatelessWidget {
  const _NewNoteButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('cards.create_fab'),
      onTap: onTap,
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: CardMindColors.brand,
          borderRadius: BorderRadius.circular(CardMindRadii.sm),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 14, color: CardMindColors.textOnBrand),
            SizedBox(width: 8),
            Text(
              '新建笔记',
              style: TextStyle(
                color: CardMindColors.textOnBrand,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarNavItem extends StatelessWidget {
  const _SidebarNavItem({
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
        height: active ? 36 : 34,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? CardMindColors.bgSurface : Colors.transparent,
          borderRadius: active
              ? BorderRadius.circular(CardMindRadii.sm)
              : BorderRadius.zero,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: active
                  ? CardMindColors.brand
                  : CardMindColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: active
                    ? CardMindColors.textPrimary
                    : CardMindColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
