import 'package:flutter/material.dart';
import '../adaptive_widget.dart';

/// Adaptive list item that adapts to platform conventions
class AdaptiveListItem extends AdaptiveWidget {
  const AdaptiveListItem({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
  });
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget buildMobile(BuildContext context) {
    // Mobile: Larger, touch-friendly list item
    return ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
      onLongPress: onLongPress,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      minVerticalPadding: 12,
    );
  }

  @override
  Widget buildDesktop(BuildContext context) {
    // Desktop: Compact list item with hover effect
    return ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
      onLongPress: onLongPress,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      minVerticalPadding: 8,
      hoverColor: Theme.of(context).hoverColor,
    );
  }
}

/// Adaptive dialog that adapts to platform conventions
class AdaptiveDialog extends AdaptiveWidget {
  const AdaptiveDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });
  final Widget title;
  final Widget content;
  final List<Widget> actions;

  @override
  Widget buildMobile(BuildContext context) {
    // Mobile: Full-width dialog with larger touch targets
    return AlertDialog(
      title: title,
      content: content,
      actions: actions,
      actionsPadding: const EdgeInsets.all(16),
      buttonPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  @override
  Widget buildDesktop(BuildContext context) {
    // Desktop: Compact dialog
    return AlertDialog(
      title: title,
      content: content,
      actions: actions,
      actionsPadding: const EdgeInsets.all(12),
      buttonPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}

/// Adaptive text field that adapts to platform conventions
class AdaptiveTextField extends AdaptiveWidget {
  const AdaptiveTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.maxLines = 1,
    this.onChanged,
    this.keyboardType,
  });
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;

  @override
  Widget buildMobile(BuildContext context) {
    // Mobile: Larger text field with touch-friendly padding
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      style: const TextStyle(fontSize: 16),
      maxLines: maxLines,
      onChanged: onChanged,
      keyboardType: keyboardType,
    );
  }

  @override
  Widget buildDesktop(BuildContext context) {
    // Desktop: Compact text field
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      style: const TextStyle(fontSize: 14),
      maxLines: maxLines,
      onChanged: onChanged,
      keyboardType: keyboardType,
    );
  }
}

/// Show adaptive dialog
Future<T?> showAdaptiveDialog<T>({
  required BuildContext context,
  required Widget title,
  required Widget content,
  required List<Widget> actions,
}) {
  return showDialog<T>(
    context: context,
    builder: (context) =>
        AdaptiveDialog(title: title, content: content, actions: actions),
  );
}
