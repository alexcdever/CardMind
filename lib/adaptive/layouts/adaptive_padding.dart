import 'package:flutter/widgets.dart';
import '../platform_detector.dart';

/// Adaptive padding utilities for platform-appropriate padding
///
/// Mobile: Larger padding for touch-friendly interaction
/// Desktop: Compact padding for efficient use of screen space
class AdaptivePadding {
  AdaptivePadding._();

  /// Small padding
  /// Mobile: 8.0, Desktop: 4.0
  static EdgeInsets get small =>
      EdgeInsets.all(PlatformDetector.isMobile ? 8.0 : 4.0);

  /// Medium padding
  /// Mobile: 16.0, Desktop: 8.0
  static EdgeInsets get medium =>
      EdgeInsets.all(PlatformDetector.isMobile ? 16.0 : 8.0);

  /// Large padding
  /// Mobile: 24.0, Desktop: 16.0
  static EdgeInsets get large =>
      EdgeInsets.all(PlatformDetector.isMobile ? 24.0 : 16.0);

  /// Extra large padding
  /// Mobile: 32.0, Desktop: 24.0
  static EdgeInsets get extraLarge =>
      EdgeInsets.all(PlatformDetector.isMobile ? 32.0 : 24.0);

  /// Horizontal padding (left and right)
  /// Mobile: 16.0, Desktop: 8.0
  static EdgeInsets get horizontal =>
      EdgeInsets.symmetric(horizontal: PlatformDetector.isMobile ? 16.0 : 8.0);

  /// Vertical padding (top and bottom)
  /// Mobile: 16.0, Desktop: 8.0
  static EdgeInsets get vertical =>
      EdgeInsets.symmetric(vertical: PlatformDetector.isMobile ? 16.0 : 8.0);

  /// Screen edge padding (safe area padding)
  /// Mobile: 16.0, Desktop: 24.0
  static EdgeInsets get screenEdge =>
      EdgeInsets.all(PlatformDetector.isMobile ? 16.0 : 24.0);

  /// List item padding
  /// Mobile: 16.0, Desktop: 12.0
  static EdgeInsets get listItem =>
      EdgeInsets.all(PlatformDetector.isMobile ? 16.0 : 12.0);

  /// Card padding
  /// Mobile: 16.0, Desktop: 12.0
  static EdgeInsets get card =>
      EdgeInsets.all(PlatformDetector.isMobile ? 16.0 : 12.0);

  /// Dialog padding
  /// Mobile: 24.0, Desktop: 20.0
  static EdgeInsets get dialog =>
      EdgeInsets.all(PlatformDetector.isMobile ? 24.0 : 20.0);

  /// Custom padding with platform-aware scaling
  static EdgeInsets custom({
    double? all,
    double? horizontal,
    double? vertical,
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) {
    final scale = PlatformDetector.isMobile ? 1.0 : 0.75;

    if (all != null) {
      return EdgeInsets.all(all * scale);
    }

    return EdgeInsets.only(
      left: (left ?? horizontal ?? 0) * scale,
      top: (top ?? vertical ?? 0) * scale,
      right: (right ?? horizontal ?? 0) * scale,
      bottom: (bottom ?? vertical ?? 0) * scale,
    );
  }

  /// Get padding value for a specific size
  static double getValue(double mobileValue) {
    return PlatformDetector.isMobile ? mobileValue : mobileValue * 0.75;
  }
}
