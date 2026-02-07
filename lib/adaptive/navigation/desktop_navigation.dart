import 'package:flutter/material.dart';
import 'adaptive_navigation.dart';

/// Desktop navigation using NavigationRail
class DesktopNavigation extends StatelessWidget {
  const DesktopNavigation({
    super.key,
    required this.destinations,
    required this.currentIndex,
    required this.onDestinationSelected,
  });
  final List<AdaptiveNavigationDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: currentIndex,
            onDestinationSelected: onDestinationSelected,
            labelType: NavigationRailLabelType.all,
            destinations: destinations
                .map(
                  (dest) => NavigationRailDestination(
                    icon: Icon(dest.icon),
                    label: Text(dest.label),
                  ),
                )
                .toList(),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: destinations[currentIndex].builder(context)),
        ],
      ),
    );
  }
}
