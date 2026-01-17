import 'package:flutter/widgets.dart';
import '../platform_detector.dart';

/// Adaptive spacing utilities for platform-appropriate spacing
///
/// Mobile: Larger spacing for touch-friendly interaction
/// Desktop: Compact spacing for efficient use of screen space
class AdaptiveSpacing {
  AdaptiveSpacing._();

  /// Small spacing
  /// Mobile: 8.0, Desktop: 4.0
  static double get small => PlatformDetector.isMobile ? 8.0 : 4.0;

  /// Medium spacing
  /// Mobile: 16.0, Desktop: 8.0
  static double get medium => PlatformDetector.isMobile ? 16.0 : 8.0;

  /// Large spacing
  /// Mobile: 24.0, Desktop: 16.0
  static double get large => PlatformDetector.isMobile ? 24.0 : 16.0;

  /// Extra large spacing
  /// Mobile: 32.0, Desktop: 24.0
  static double get extraLarge => PlatformDetector.isMobile ? 32.0 : 24.0;

  /// List item spacing (between items)
  /// Mobile: 8.0, Desktop: 4.0
  static double get listItem => PlatformDetector.isMobile ? 8.0 : 4.0;

  /// Form field spacing (between fields)
  /// Mobile: 16.0, Desktop: 12.0
  static double get formField => PlatformDetector.isMobile ? 16.0 : 12.0;

  /// Section spacing (between sections)
  /// Mobile: 24.0, Desktop: 16.0
  static double get section => PlatformDetector.isMobile ? 24.0 : 16.0;

  /// Get SizedBox with small spacing
  static Widget get smallBox => SizedBox(width: small, height: small);

  /// Get SizedBox with medium spacing
  static Widget get mediumBox => SizedBox(width: medium, height: medium);

  /// Get SizedBox with large spacing
  static Widget get largeBox => SizedBox(width: large, height: large);

  /// Get SizedBox with extra large spacing
  static Widget get extraLargeBox =>
      SizedBox(width: extraLarge, height: extraLarge);

  /// Get horizontal spacing
  static Widget horizontal(double? customSpacing) =>
      SizedBox(width: customSpacing ?? medium);

  /// Get vertical spacing
  static Widget vertical(double? customSpacing) =>
      SizedBox(height: customSpacing ?? medium);
}
