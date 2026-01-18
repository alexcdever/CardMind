import 'package:flutter/widgets.dart';
import 'platform_detector.dart';

/// Breakpoint constants for responsive design
class AdaptiveBreakpoints {
  AdaptiveBreakpoints._();

  /// Desktop breakpoint (1024px)
  static const double desktop = 1024.0;

  /// Tablet breakpoint (768px)
  static const double tablet = 768.0;

  /// Mobile breakpoint (< 768px)
  static const double mobile = 0.0;
}

/// Functional adaptive widget builder
///
/// Provides a functional approach to building adaptive widgets without
/// needing to create a subclass. Accepts separate builder functions for
/// mobile and desktop platforms.
///
/// Example:
/// ```dart
/// AdaptiveBuilder(
///   mobile: (context) => Text('Mobile UI'),
///   desktop: (context) => Text('Desktop UI'),
/// )
/// ```
class AdaptiveBuilder extends StatelessWidget {

  const AdaptiveBuilder({
    super.key,
    required this.mobile,
    required this.desktop,
  });
  /// Builder function for mobile platforms
  final WidgetBuilder mobile;

  /// Builder function for desktop platforms
  final WidgetBuilder desktop;

  @override
  Widget build(BuildContext context) {
    return PlatformDetector.isMobile ? mobile(context) : desktop(context);
  }
}
