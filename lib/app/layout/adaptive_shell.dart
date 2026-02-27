import 'package:cardmind/app/navigation/app_section.dart';
import 'package:flutter/material.dart';

class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({super.key, required this.child, required this.section});

  final Widget child;
  final AppSection section;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 900;
    final destinations = const <NavigationDestination>[
      NavigationDestination(icon: Icon(Icons.style_outlined), label: '卡片'),
      NavigationDestination(
        icon: Icon(Icons.group_work_outlined),
        label: '数据池',
      ),
      NavigationDestination(icon: Icon(Icons.settings_outlined), label: '设置'),
    ];

    if (desktop) {
      return Row(
        children: [
          NavigationRail(
            destinations: const <NavigationRailDestination>[
              NavigationRailDestination(
                icon: Icon(Icons.style_outlined),
                label: Text('卡片'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.group_work_outlined),
                label: Text('数据池'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                label: Text('设置'),
              ),
            ],
            selectedIndex: section.index,
          ),
          Expanded(child: child),
        ],
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: section.index,
        items: destinations
            .map(
              (item) =>
                  BottomNavigationBarItem(icon: item.icon, label: item.label),
            )
            .toList(),
      ),
    );
  }
}
