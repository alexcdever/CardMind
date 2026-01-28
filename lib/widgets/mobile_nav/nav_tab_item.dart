import 'package:flutter/material.dart';
import 'badge_widget.dart';
import 'nav_constants.dart';
import 'nav_models.dart';

/// 导航标签项组件
///
/// 单独的导航标签项，包含图标、文字、徽章和动画效果
class NavTabItem extends StatelessWidget {
  const NavTabItem({
    super.key,
    required this.tab,
    required this.isActive,
    this.badgeCount,
    required this.onTap,
  });

  final NavTab tab;
  final bool isActive;
  final int? badgeCount;
  final VoidCallback onTap;

  IconData _getIcon() {
    switch (tab) {
      case NavTab.notes:
        return Icons.note;
      case NavTab.devices:
        return Icons.wifi;
      case NavTab.settings:
        return Icons.settings;
    }
  }

  String _getLabel() {
    switch (tab) {
      case NavTab.notes:
        return '笔记';
      case NavTab.devices:
        return '设备';
      case NavTab.settings:
        return '设置';
    }
  }

  String _getSemanticLabel() {
    switch (tab) {
      case NavTab.notes:
        return badgeCount != null && badgeCount! > 0
            ? '笔记，当前有 $badgeCount 条笔记'
            : '笔记';
      case NavTab.devices:
        return badgeCount != null && badgeCount! > 0
            ? '设备，当前有 $badgeCount 台设备'
            : '设备';
      case NavTab.settings:
        return '设置';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive ? theme.colorScheme.primary : theme.disabledColor;
    final effectiveBadgeCount =
        badgeCount?.clamp(0, NavConstants.badgeMaxDisplayCount) ?? 0;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        highlightColor: NavConstants.touchFeedbackColor,
        splashColor: NavConstants.splashColor,
        borderRadius: BorderRadius.circular(8),
        child: Semantics(
          label: _getSemanticLabel(),
          selected: isActive,
          button: true,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 顶部指示条
              AnimatedContainer(
                duration: NavConstants.tabSwitchDuration,
                height: NavConstants.indicatorHeight,
                width: NavConstants.indicatorWidth,
                decoration: BoxDecoration(
                  color: isActive
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(NavConstants.indicatorBorderRadius),
                  ),
                ),
              ),
              SizedBox(height: NavConstants.indicatorIconSpacing),
              // 图标和徽章
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedScale(
                    duration: NavConstants.tabSwitchDuration,
                    scale: isActive
                        ? NavConstants.iconActiveScale
                        : NavConstants.iconInactiveScale,
                    child: Icon(
                      _getIcon(),
                      size: NavConstants.iconSize,
                      color: color,
                    ),
                  ),
                  if (effectiveBadgeCount > 0)
                    Positioned(
                      right: -8,
                      top: -4,
                      child: BadgeWidget(count: effectiveBadgeCount),
                    ),
                ],
              ),
              SizedBox(height: NavConstants.iconLabelSpacing),
              // 标签文字
              AnimatedDefaultTextStyle(
                duration: NavConstants.tabSwitchDuration,
                style: TextStyle(
                  fontSize: NavConstants.labelFontSize,
                  color: color,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
                child: Text(_getLabel()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
