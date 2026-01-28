import 'package:flutter/material.dart';
import 'nav_constants.dart';
import 'nav_models.dart';
import 'nav_tab_item.dart';

/// 移动端底部导航栏
///
/// 包含三个标签页：笔记、设备、设置
/// 支持徽章通知、动画效果、防重复点击
class MobileNav extends StatefulWidget {
  const MobileNav({
    super.key,
    required this.currentTab,
    required this.onTabChange,
    required this.notesCount,
    required this.devicesCount,
  });

  final NavTab currentTab;
  final OnTabChange onTabChange;
  final int notesCount;
  final int devicesCount;

  @override
  State<MobileNav> createState() => _MobileNavState();
}

class _MobileNavState extends State<MobileNav> {
  // 用于防抖处理
  DateTime? _lastTapTime;

  void _handleTabTap(NavTab tab) {
    final now = DateTime.now();

    // 防抖处理：忽略快速连续点击
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) < NavConstants.debounceDuration) {
      return;
    }

    // 如果点击的是当前激活标签，不触发切换
    if (widget.currentTab == tab) {
      return;
    }

    _lastTapTime = now;
    widget.onTabChange(tab);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: theme.dividerColor, width: 1)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: NavConstants.navBarHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              NavTabItem(
                tab: NavTab.notes,
                isActive: widget.currentTab == NavTab.notes,
                badgeCount: widget.notesCount > 0 ? widget.notesCount : null,
                onTap: () => _handleTabTap(NavTab.notes),
              ),
              NavTabItem(
                tab: NavTab.devices,
                isActive: widget.currentTab == NavTab.devices,
                badgeCount: widget.devicesCount > 0
                    ? widget.devicesCount
                    : null,
                onTap: () => _handleTabTap(NavTab.devices),
              ),
              NavTabItem(
                tab: NavTab.settings,
                isActive: widget.currentTab == NavTab.settings,
                onTap: () => _handleTabTap(NavTab.settings),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
