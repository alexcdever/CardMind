import 'package:flutter/material.dart';

import '../adaptive_widget.dart';
import 'desktop_navigation.dart';
import 'mobile_navigation.dart';

/// Navigation destination for adaptive navigation
class AdaptiveNavigationDestination {
  const AdaptiveNavigationDestination({
    required this.icon,
    required this.label,
    required this.builder,
  });
  final IconData icon;
  final String label;
  final Widget Function(BuildContext) builder;
}

/// Adaptive navigation component
///
/// Provides platform-appropriate navigation:
/// - Mobile: BottomNavigationBar
/// - Desktop: NavigationRail (side navigation)
class AdaptiveNavigation extends AdaptiveWidget {
  const AdaptiveNavigation({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onDestinationSelected,
  });
  final List<AdaptiveNavigationDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget buildMobile(BuildContext context) {
    return MobileNavigation(
      destinations: destinations,
      currentIndex: currentIndex,
      onDestinationSelected: onDestinationSelected,
    );
  }

  @override
  Widget buildDesktop(BuildContext context) {
    return DesktopNavigation(
      destinations: destinations,
      currentIndex: currentIndex,
      onDestinationSelected: onDestinationSelected,
    );
  }
}
