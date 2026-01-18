import 'package:flutter/material.dart';

/// 移动端底部导航栏
///
/// 包含三个标签页：笔记、设备、设置
class MobileNav extends StatelessWidget {
  const MobileNav({
    super.key,
    required this.activeTab,
    required this.onTabChange,
    required this.noteCount,
    required this.deviceCount,
  });

  final int activeTab;
  final Function(int) onTabChange;
  final int noteCount;
  final int deviceCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTab(
                context: context,
                index: 0,
                icon: Icons.note,
                label: '笔记',
                badge: noteCount,
              ),
              _buildTab(
                context: context,
                index: 1,
                icon: Icons.wifi,
                label: '设备',
                badge: deviceCount,
              ),
              _buildTab(
                context: context,
                index: 2,
                icon: Icons.settings,
                label: '设置',
                badge: 0,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab({
    required BuildContext context,
    required int index,
    required IconData icon,
    required String label,
    required int badge,
  }) {
    final theme = Theme.of(context);
    final isActive = activeTab == index;
    final color = isActive ? theme.colorScheme.primary : theme.disabledColor;

    return Expanded(
      child: InkWell(
        onTap: () => onTabChange(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 顶部指示条
            Container(
              height: 3,
              width: 48,
              decoration: BoxDecoration(
                color: isActive ? theme.colorScheme.primary : Colors.transparent,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // 图标和徽章
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: isActive ? 26 : 24,
                  color: color,
                ),
                if (badge > 0)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        badge > 99 ? '99+' : badge.toString(),
                        style: TextStyle(
                          color: theme.colorScheme.onError,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            // 标签文字
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
