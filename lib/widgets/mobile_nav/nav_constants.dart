import 'package:flutter/material.dart';

/// 移动端导航栏设计常量
class NavConstants {
  NavConstants._();

  // 动画时长
  static const Duration tabSwitchDuration = Duration(milliseconds: 200);
  static const Duration touchFeedbackDuration = Duration(milliseconds: 100);
  static const Duration badgeAnimationDuration = Duration(milliseconds: 200);
  static const Duration debounceDuration = Duration(milliseconds: 300);

  // 布局尺寸
  static const double navBarHeight = 64;
  static const double iconSize = 24;
  static const double indicatorWidth = 32;
  static const double indicatorHeight = 3;
  static const double indicatorBorderRadius = 1.5;

  // 徽章尺寸
  static const double badgeSingleDigitSize = 16;
  static const double badgeDoubleDigitWidth = 20;
  static const double badgeLargeWidth = 28;
  static const double badgeHeight = 16;
  static const double badgeBorderRadius = 8;

  // 文字尺寸
  static const double labelFontSize = 12;
  static const double badgeFontSize = 10;

  // 间距
  static const double iconLabelSpacing = 4;
  static const double indicatorIconSpacing = 8;

  // 颜色
  static const Color inactiveColor = Color(0xFF666666);
  static const Color activeColor = Color(0xFF007AFF);
  static const Color badgeColor = Color(0xFFFF3B30);
  static const Color touchFeedbackColor = Color(0xFFF0F0F0);
  static const Color splashColor = Color(0xFFE0E0E0);

  // 动画缩放
  static const double iconActiveScale = 1.1;
  static const double iconInactiveScale = 1;
  static const double badgeAppearScale = 1.2;

  // 徽章显示阈值
  static const int badgeMaxCount = 99;
  static const int badgeMaxDisplayCount = 999;
}
