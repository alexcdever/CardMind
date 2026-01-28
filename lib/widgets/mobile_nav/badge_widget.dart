import 'package:flutter/material.dart';
import 'nav_constants.dart';

/// 徽章组件
///
/// 显示数字徽章，支持不同尺寸和格式化显示
class BadgeWidget extends StatelessWidget {
  const BadgeWidget({super.key, required this.count});

  final int count;

  String _formatCount() {
    if (count > NavConstants.badgeMaxCount) {
      return '99+';
    }
    return count.toString();
  }

  double _getBadgeWidth() {
    if (count > NavConstants.badgeMaxCount) {
      return NavConstants.badgeLargeWidth;
    } else if (count > 9) {
      return NavConstants.badgeDoubleDigitWidth;
    } else {
      return NavConstants.badgeSingleDigitSize;
    }
  }

  EdgeInsets _getBadgePadding() {
    if (count > NavConstants.badgeMaxCount) {
      return const EdgeInsets.symmetric(horizontal: 8, vertical: 2);
    } else if (count > 9) {
      return const EdgeInsets.symmetric(horizontal: 6, vertical: 2);
    } else {
      return const EdgeInsets.symmetric(horizontal: 4, vertical: 2);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: NavConstants.badgeAnimationDuration,
      padding: _getBadgePadding(),
      decoration: BoxDecoration(
        color: NavConstants.badgeColor,
        borderRadius: BorderRadius.circular(NavConstants.badgeBorderRadius),
      ),
      constraints: BoxConstraints(
        minWidth: _getBadgeWidth(),
        minHeight: NavConstants.badgeHeight,
      ),
      child: Text(
        _formatCount(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: NavConstants.badgeFontSize,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
