import 'package:flutter/material.dart';
import '../adaptive_widget.dart';

/// Adaptive button that adapts to platform conventions
class AdaptiveButton extends AdaptiveWidget {
  const AdaptiveButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isPrimary = false,
  });
  final VoidCallback? onPressed;
  final Widget child;
  final bool isPrimary;

  @override
  Widget buildMobile(BuildContext context) {
    // Mobile: Larger, touch-friendly button
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(88, 44),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      child: child,
    );
  }

  @override
  Widget buildDesktop(BuildContext context) {
    // Desktop: Compact button
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(64, 36),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: child,
    );
  }
}

/// Adaptive text button
class AdaptiveTextButton extends AdaptiveWidget {
  const AdaptiveTextButton({
    super.key,
    required this.onPressed,
    required this.child,
  });
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget buildMobile(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(88, 44),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      child: child,
    );
  }

  @override
  Widget buildDesktop(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: const Size(64, 36),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: child,
    );
  }
}

/// Adaptive icon button
class AdaptiveIconButton extends AdaptiveWidget {
  const AdaptiveIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
  });
  final VoidCallback? onPressed;
  final Icon icon;
  final String? tooltip;

  @override
  Widget buildMobile(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: icon,
      tooltip: tooltip,
      iconSize: 24,
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    );
  }

  @override
  Widget buildDesktop(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: icon,
      tooltip: tooltip,
      iconSize: 20,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }
}
