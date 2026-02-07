import 'package:flutter/material.dart';
import 'responsive_utils.dart';

/// Desktop layout with multi-column structure
///
/// Features:
/// - Multi-column layout optimized for wider screens
/// - No FloatingActionButton (uses toolbar buttons instead)
/// - Horizontal space optimization
/// - Responsive: collapses to single column when width < 1024px
class DesktopLayout extends StatelessWidget {
  const DesktopLayout({
    super.key,
    required this.body,
    this.appBar,
    this.actions,
  });
  final Widget body;
  final PreferredSizeWidget? appBar;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    // Check if layout should collapse based on window width
    final shouldCollapse = ResponsiveUtils.shouldCollapseLayout(context);

    return Scaffold(
      appBar: appBar,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // If window is too narrow, use single-column layout
          if (shouldCollapse) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: body,
              ),
            );
          }

          // Otherwise, use the normal multi-column layout
          return body;
        },
      ),
      // Desktop: No FAB, actions are in the toolbar
    );
  }
}
