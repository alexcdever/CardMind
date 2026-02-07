import 'package:flutter/material.dart';
import 'responsive_utils.dart';

/// Mobile layout with single-column structure
///
/// Features:
/// - Single-column layout
/// - Optional FloatingActionButton
/// - Bottom-aligned primary actions
/// - Handles screen rotation automatically
/// - Adjusts for keyboard visibility
class MobileLayout extends StatelessWidget {
  const MobileLayout({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.actions,
  });
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    // Get keyboard visibility for layout adjustments
    final isKeyboardVisible = ResponsiveUtils.isKeyboardVisible(context);
    final orientation = ResponsiveUtils.getOrientation(context);

    return Scaffold(
      appBar: appBar,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Adjust layout based on orientation and keyboard visibility
            return SingleChildScrollView(
              // Disable scroll when keyboard is not visible and content fits
              physics: isKeyboardVisible
                  ? const AlwaysScrollableScrollPhysics()
                  : const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: body,
              ),
            );
          },
        ),
      ),
      // Hide FAB when keyboard is visible to avoid overlap
      floatingActionButton: isKeyboardVisible ? null : floatingActionButton,
      // Adjust FAB position based on orientation
      floatingActionButtonLocation: orientation == Orientation.landscape
          ? FloatingActionButtonLocation.endFloat
          : FloatingActionButtonLocation.endFloat,
    );
  }
}
