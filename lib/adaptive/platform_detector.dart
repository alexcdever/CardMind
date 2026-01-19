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
/// mobile or desktop platform types.
///
/// ## Performance Note
/// This class uses [defaultTargetPlatform] which is a compile-time constant.
/// The Dart compiler optimizes away the switch statement, resulting in
/// zero runtime overhead. Each call to [isMobile] or [isDesktop] is
/// effectively a constant value lookup.
///
/// ## Usage
/// ```dart
/// // In build method - no performance concern
/// if (PlatformDetector.isMobile) {
///   return MobileLayout();
/// } else {
///   return DesktopLayout();
/// }
///
/// // Or use AdaptiveBuilder for cleaner code
/// return AdaptiveBuilder(
///   mobile: (context) => MobileLayout(),
///   desktop: (context) => DesktopLayout(),
/// );
/// ```
class PlatformDetector {
  PlatformDetector._();

  /// Override platform type for testing purposes only
  ///
  /// ⚠️ WARNING: Only use this in tests! Setting this in production
  /// code will cause inconsistent behavior.
  @visibleForTesting
  static PlatformType? debugOverridePlatform;

  /// Get the current platform type
  ///
  /// This uses Flutter's [defaultTargetPlatform] to determine the platform
  /// at compile time, ensuring zero runtime overhead.
  ///
  /// Platform classification:
  /// - Mobile: Android, iOS, iPadOS
  /// - Desktop: macOS, Windows, Linux
  /// - Unknown: defaults to mobile for safety
  ///
  /// In debug mode, this can be overridden using [debugOverridePlatform]
  /// for testing purposes.
  static PlatformType get currentPlatform {
    // Allow override in debug/test mode
    if (debugOverridePlatform != null) {
      assert(() {
        debugPrint(
          'PlatformDetector: Using override platform: $debugOverridePlatform',
        );
        return true;
      }());
      return debugOverridePlatform!;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return PlatformType.mobile;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return PlatformType.desktop;
      case TargetPlatform.fuchsia:
        debugPrint('Warning: Fuchsia platform detected, defaulting to mobile');
        return PlatformType.mobile;
    }
  }

  /// Check if current platform is mobile
  ///
  /// Returns true for Android, iOS, and iPadOS.
  /// This is a compile-time constant in release builds.
  static bool get isMobile => currentPlatform == PlatformType.mobile;

  /// Check if current platform is desktop
  ///
  /// Returns true for macOS, Windows, and Linux.
  /// This is a compile-time constant in release builds.
  static bool get isDesktop => currentPlatform == PlatformType.desktop;
}
