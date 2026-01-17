import 'package:flutter/material.dart';
import '../platform_detector.dart';

/// Touch target wrapper for mobile platforms
///
/// Ensures all interactive elements meet the minimum touch target size
/// of 44x44 logical pixels on mobile platforms.
///
/// On desktop platforms, this widget does not expand the touch area
/// since mouse precision is higher.
class TouchTarget extends StatelessWidget {

  const TouchTarget({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.minSize = 44.0,
  });
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double minSize;

  @override
  Widget build(BuildContext context) {
    // Desktop: No need to expand touch area
    if (PlatformDetector.isDesktop) {
      return InkWell(onTap: onTap, onLongPress: onLongPress, child: child);
    }

    // Mobile: Ensure minimum touch target size
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
        child: child,
      ),
    );
  }
}
