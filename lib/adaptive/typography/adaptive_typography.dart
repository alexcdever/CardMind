import 'package:flutter/material.dart';
import '../platform_detector.dart';

/// Adaptive typography system for platform-specific font sizes
///
/// Mobile: Larger fonts for touch-friendly reading (body: 16px, heading: 20px+)
/// Desktop: Smaller fonts for information density (body: 14-16px, heading: 18px+)
class AdaptiveTypography {
  AdaptiveTypography._();

  /// Get platform-appropriate text theme
  static TextTheme getTextTheme(BuildContext context) {
    final baseTheme = Theme.of(context).textTheme;

    if (PlatformDetector.isMobile) {
      return _getMobileTextTheme(baseTheme);
    } else {
      return _getDesktopTextTheme(baseTheme);
    }
  }

  /// Mobile text theme with larger fonts
  static TextTheme _getMobileTextTheme(TextTheme baseTheme) {
    return baseTheme.copyWith(
      // Display styles (largest)
      displayLarge: baseTheme.displayLarge?.copyWith(fontSize: 57),
      displayMedium: baseTheme.displayMedium?.copyWith(fontSize: 45),
      displaySmall: baseTheme.displaySmall?.copyWith(fontSize: 36),

      // Headline styles
      headlineLarge: baseTheme.headlineLarge?.copyWith(fontSize: 32),
      headlineMedium: baseTheme.headlineMedium?.copyWith(fontSize: 28),
      headlineSmall: baseTheme.headlineSmall?.copyWith(fontSize: 24),

      // Title styles
      titleLarge: baseTheme.titleLarge?.copyWith(fontSize: 22),
      titleMedium: baseTheme.titleMedium?.copyWith(fontSize: 18),
      titleSmall: baseTheme.titleSmall?.copyWith(fontSize: 16),

      // Body styles (main content)
      bodyLarge: baseTheme.bodyLarge?.copyWith(fontSize: 18),
      bodyMedium: baseTheme.bodyMedium?.copyWith(fontSize: 16),
      bodySmall: baseTheme.bodySmall?.copyWith(fontSize: 14),

      // Label styles (buttons, chips)
      labelLarge: baseTheme.labelLarge?.copyWith(fontSize: 16),
      labelMedium: baseTheme.labelMedium?.copyWith(fontSize: 14),
      labelSmall: baseTheme.labelSmall?.copyWith(fontSize: 12),
    );
  }

  /// Desktop text theme with smaller fonts
  static TextTheme _getDesktopTextTheme(TextTheme baseTheme) {
    return baseTheme.copyWith(
      // Display styles (largest)
      displayLarge: baseTheme.displayLarge?.copyWith(fontSize: 48),
      displayMedium: baseTheme.displayMedium?.copyWith(fontSize: 40),
      displaySmall: baseTheme.displaySmall?.copyWith(fontSize: 32),

      // Headline styles
      headlineLarge: baseTheme.headlineLarge?.copyWith(fontSize: 28),
      headlineMedium: baseTheme.headlineMedium?.copyWith(fontSize: 24),
      headlineSmall: baseTheme.headlineSmall?.copyWith(fontSize: 20),

      // Title styles
      titleLarge: baseTheme.titleLarge?.copyWith(fontSize: 18),
      titleMedium: baseTheme.titleMedium?.copyWith(fontSize: 16),
      titleSmall: baseTheme.titleSmall?.copyWith(fontSize: 14),

      // Body styles (main content)
      bodyLarge: baseTheme.bodyLarge?.copyWith(fontSize: 16),
      bodyMedium: baseTheme.bodyMedium?.copyWith(fontSize: 14),
      bodySmall: baseTheme.bodySmall?.copyWith(fontSize: 12),

      // Label styles (buttons, chips)
      labelLarge: baseTheme.labelLarge?.copyWith(fontSize: 14),
      labelMedium: baseTheme.labelMedium?.copyWith(fontSize: 12),
      labelSmall: baseTheme.labelSmall?.copyWith(fontSize: 11),
    );
  }

  /// Get adaptive font size for body text
  static double getBodyFontSize() {
    return PlatformDetector.isMobile ? 16.0 : 14.0;
  }

  /// Get adaptive font size for headings
  static double getHeadingFontSize() {
    return PlatformDetector.isMobile ? 24.0 : 20.0;
  }

  /// Get adaptive font size for titles
  static double getTitleFontSize() {
    return PlatformDetector.isMobile ? 18.0 : 16.0;
  }

  /// Get adaptive font size for captions
  static double getCaptionFontSize() {
    return PlatformDetector.isMobile ? 14.0 : 12.0;
  }

  /// Get adaptive font size for buttons
  static double getButtonFontSize() {
    return PlatformDetector.isMobile ? 16.0 : 14.0;
  }

  /// Get adaptive line height
  static double getLineHeight() {
    return PlatformDetector.isMobile ? 1.5 : 1.4;
  }

  /// Get adaptive letter spacing
  static double getLetterSpacing() {
    return PlatformDetector.isMobile ? 0.15 : 0.1;
  }
}

/// Extension on BuildContext for easy access to adaptive typography
extension AdaptiveTypographyExtension on BuildContext {
  /// Get platform-appropriate text theme
  TextTheme get adaptiveTextTheme => AdaptiveTypography.getTextTheme(this);

  /// Get adaptive body font size
  double get adaptiveBodyFontSize => AdaptiveTypography.getBodyFontSize();

  /// Get adaptive heading font size
  double get adaptiveHeadingFontSize => AdaptiveTypography.getHeadingFontSize();

  /// Get adaptive title font size
  double get adaptiveTitleFontSize => AdaptiveTypography.getTitleFontSize();

  /// Get adaptive caption font size
  double get adaptiveCaptionFontSize => AdaptiveTypography.getCaptionFontSize();

  /// Get adaptive button font size
  double get adaptiveButtonFontSize => AdaptiveTypography.getButtonFontSize();

  /// Get adaptive line height
  double get adaptiveLineHeight => AdaptiveTypography.getLineHeight();

  /// Get adaptive letter spacing
  double get adaptiveLetterSpacing => AdaptiveTypography.getLetterSpacing();
}
