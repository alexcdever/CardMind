import 'package:flutter/material.dart';
import 'adaptive_navigation.dart';

/// Mobile navigation using BottomNavigationBar
class MobileNavigation extends StatelessWidget {

  const MobileNavigation({
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
      body: destinations[currentIndex].builder(context),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onDestinationSelected,
        items: destinations
            .map(
              (dest) => BottomNavigationBarItem(
                icon: Icon(dest.icon),
                label: dest.label,
              ),
            )
            .toList(),
      ),
    );
  }
}
