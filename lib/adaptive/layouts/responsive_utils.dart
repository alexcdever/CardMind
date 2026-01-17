import 'package:flutter/material.dart';

/// Responsive breakpoints for adaptive layouts
class ResponsiveBreakpoints {
  ResponsiveBreakpoints._();

  /// Minimum width for desktop layout (800px)
  static const double minDesktopWidth = 800;

  /// Width threshold for collapsing multi-column layout (1024px)
  static const double collapseThreshold = 1024;

  /// Minimum height for desktop layout (600px)
  static const double minDesktopHeight = 600;
}

/// Responsive layout utilities for window size detection
class ResponsiveUtils {
  ResponsiveUtils._();

  /// Get the current window width
  static double getWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// Get the current window height
  static double getHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// Check if the window width is below the collapse threshold
  ///
  /// Returns true if width < 1024px, indicating that multi-column
  /// layouts should collapse to single-column on desktop
  static bool shouldCollapseLayout(BuildContext context) {
    return getWidth(context) < ResponsiveBreakpoints.collapseThreshold;
  }

  /// Check if the window meets minimum desktop dimensions
  ///
  /// Returns true if width >= 800px and height >= 600px
  static bool meetsMinimumDesktopSize(BuildContext context) {
    final width = getWidth(context);
    final height = getHeight(context);
    return width >= ResponsiveBreakpoints.minDesktopWidth &&
        height >= ResponsiveBreakpoints.minDesktopHeight;
  }

  /// Get the current orientation
  static Orientation getOrientation(BuildContext context) {
    return MediaQuery.of(context).orientation;
  }

  /// Check if keyboard is visible (mobile)
  ///
  /// Returns true if the bottom inset (keyboard) is visible
  static bool isKeyboardVisible(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom > 0;
  }

  /// Get the keyboard height
  static double getKeyboardHeight(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom;
  }

  /// Get safe area insets (for notches, status bars, etc.)
  static EdgeInsets getSafeAreaInsets(BuildContext context) {
    return MediaQuery.of(context).padding;
  }
}
