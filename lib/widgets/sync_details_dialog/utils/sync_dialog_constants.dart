/// 同步详情对话框常量定义
library;

import 'package:flutter/material.dart';

/// 对话框尺寸
class SyncDialogSize {
  static const double width = 600;
  static const double maxHeightRatio = 0.8; // 80vh
  static const double borderRadius = 12;
  static const double padding = 24;
  static const double sectionSpacing = 24;
}

/// 动画时长
class SyncDialogDuration {
  static const Duration dialogOpen = Duration(milliseconds: 200);
  static const Duration dialogClose = Duration(milliseconds: 150);
  static const Duration rotation = Duration(seconds: 2);
  static const Duration hover = Duration(milliseconds: 150);
}

/// 动画曲线
class SyncDialogCurve {
  static const Curve dialogOpen = Curves.easeOut;
  static const Curve dialogClose = Curves.easeIn;
  static const Curve hover = Curves.easeInOut;
}

/// 缩放参数
class SyncDialogScale {
  static const double dialogOpenStart = 0.95;
  static const double dialogOpenEnd = 1;
  static const double dialogCloseStart = 1;
  static const double dialogCloseEnd = 0.95;
}

/// 颜色
class SyncDialogColor {
  static const Color hoverBackground = Color(0xFFFAFAFA);
  static const Color divider = Color(0xFFE0E0E0);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFF44336);
  static const Color warning = Color(0xFFFF9800);
  static const Color syncing = Color(0xFF2196F3);
}

/// 图标大小
class SyncDialogIconSize {
  static const double status = 48;
  static const double device = 24;
  static const double history = 20;
}

/// 文本样式
class SyncDialogTextStyle {
  static const TextStyle title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: SyncDialogColor.textPrimary,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: SyncDialogColor.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: SyncDialogColor.textPrimary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: SyncDialogColor.textSecondary,
  );

  static const TextStyle emptyState = TextStyle(
    fontSize: 14,
    color: SyncDialogColor.textSecondary,
  );
}

/// 轮询间隔
class SyncDialogPolling {
  static const Duration deviceList = Duration(seconds: 5);
}

/// 限制
class SyncDialogLimit {
  static const int historyMaxCount = 20;
  static const int deviceNameMaxLines = 1;
  static const int errorMessageMaxLines = 3;
}

/// 间距
class SyncDialogSpacing {
  static const double itemVertical = 12;
  static const double itemHorizontal = 16;
  static const double iconText = 12;
  static const double statisticGrid = 16;
}
