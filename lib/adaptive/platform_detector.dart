import 'package:flutter/foundation.dart';

/// Platform type classification for adaptive UI
enum PlatformType {
  /// Mobile platforms: Android, iOS, iPadOS
  mobile,

  /// Desktop platforms: macOS, Windows, Linux
  desktop,
}

/// Platform detector for adaptive UI system
///
/// Detects the device's operating system and classifies it into
/// mobile or desktop platform types at compile time.
class PlatformDetector {
  PlatformDetector._();

  /// Get the current platform type
  ///
  /// This uses Flutter's [defaultTargetPlatform] to determine the platform
  /// at compile time, ensuring zero runtime overhead.
  ///
  /// Platform classification:
  /// - Mobile: Android, iOS, iPadOS
  /// - Desktop: macOS, Windows, Linux
  /// - Unknown: defaults to mobile for safety
  static PlatformType get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return PlatformType.mobile;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return PlatformType.desktop;
      case TargetPlatform.fuchsia:
        // Fuchsia defaults to mobile
        debugPrint('Warning: Fuchsia platform detected, defaulting to mobile');
        return PlatformType.mobile;
    }
  }

  /// Check if current platform is mobile
  static bool get isMobile => currentPlatform == PlatformType.mobile;

  /// Check if current platform is desktop
  static bool get isDesktop => currentPlatform == PlatformType.desktop;
}
