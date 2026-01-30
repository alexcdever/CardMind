import 'package:flutter/material.dart';

import '../adaptive_widget.dart';
import 'desktop_layout.dart';
import 'mobile_layout.dart';

/// Adaptive scaffold that provides platform-appropriate layout structure
///
/// Mobile: Single-column layout with optional FAB
/// Desktop: Multi-column layout with side navigation
class AdaptiveScaffold extends AdaptiveWidget {
  const AdaptiveScaffold({
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
  Widget buildMobile(BuildContext context) {
    return MobileLayout(
      body: body,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      actions: actions,
    );
  }

  @override
  Widget buildDesktop(BuildContext context) {
    return DesktopLayout(body: body, appBar: appBar, actions: actions);
  }
}
