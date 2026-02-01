import 'package:flutter/material.dart';

enum ErrorLevel { error, warning, info }

class ErrorToast extends StatefulWidget {
  const ErrorToast({
    super.key,
    required this.message,
    required this.level,
    this.onDismiss,
    this.autoDismissDuration = const Duration(seconds: 3),
  });

  final String message;
  final ErrorLevel level;
  final VoidCallback? onDismiss;
  final Duration autoDismissDuration;

  static void show(
    BuildContext context, {
    required String message,
    required ErrorLevel level,
    VoidCallback? onDismiss,
    Duration autoDismissDuration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: ErrorToast(
          message: message,
          level: level,
          onDismiss: onDismiss,
          autoDismissDuration: autoDismissDuration,
        ),
        duration: autoDismissDuration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );
  }

  @override
  State<ErrorToast> createState() => _ErrorToastState();
}

class _ErrorToastState extends State<ErrorToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Color _getColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (widget.level) {
      case ErrorLevel.error:
        return theme.colorScheme.error;
      case ErrorLevel.warning:
        return const Color(0xFFFF9800);
      case ErrorLevel.info:
        return theme.colorScheme.primary;
    }
  }

  Color _getBackgroundColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (widget.level) {
      case ErrorLevel.error:
        return theme.colorScheme.errorContainer;
      case ErrorLevel.warning:
        return const Color(0xFFFFF3E0);
      case ErrorLevel.info:
        return theme.colorScheme.primaryContainer;
    }
  }

  IconData _getIcon() {
    switch (widget.level) {
      case ErrorLevel.error:
        return Icons.error;
      case ErrorLevel.warning:
        return Icons.warning;
      case ErrorLevel.info:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(context);
    final backgroundColor = _getBackgroundColor(context);
    final icon = _getIcon();

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.message,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (widget.onDismiss != null)
            GestureDetector(
              onTap: () {
                widget.onDismiss?.call();
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
              child: Icon(Icons.close, color: color, size: 20),
            ),
        ],
      ),
    );
  }
}
