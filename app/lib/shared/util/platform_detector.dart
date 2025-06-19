import 'package:flutter/foundation.dart';

/// 平台检测工具类
class PlatformDetector {
  /// 是否是桌面平台
  static bool get isDesktop {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  /// 是否是移动平台
  static bool get isMobile {
    if (kIsWeb) {
      return false;
    }
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }
}
