import 'package:flutter/widgets.dart';
import 'platform_detector.dart';

/// Abstract base class for adaptive widgets
///
/// Provides a unified interface for creating widgets that adapt to different
/// platform types (mobile vs desktop). Subclasses must implement both
/// [buildMobile] and [buildDesktop] methods.
///
/// Example:
/// ```dart
/// class MyAdaptiveWidget extends AdaptiveWidget {
///   @override
///   Widget buildMobile(BuildContext context) {
///     return Text('Mobile UI');
///   }
///
///   @override
///   Widget buildDesktop(BuildContext context) {
///     return Text('Desktop UI');
///   }
/// }
/// ```
abstract class AdaptiveWidget extends StatelessWidget {
  const AdaptiveWidget({super.key});

  /// Build the mobile version of this widget
  ///
  /// This method is called when the app runs on mobile platforms
  /// (Android, iOS, iPadOS).
  Widget buildMobile(BuildContext context);

  /// Build the desktop version of this widget
  ///
  /// This method is called when the app runs on desktop platforms
  /// (macOS, Windows, Linux).
  Widget buildDesktop(BuildContext context);

  @override
  Widget build(BuildContext context) {
    return PlatformDetector.isMobile
        ? buildMobile(context)
        : buildDesktop(context);
  }
}
