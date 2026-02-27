// input: 当前导航分区、子页面内容与分区切换回调
// output: 移动端底栏或桌面侧栏的自适应导航壳层
// pos: 应用壳层布局；修改需同步对应测试与 DIR.md
import 'package:cardmind/app/navigation/app_section.dart';
import 'package:flutter/material.dart';

class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({
    super.key,
    required this.child,
    required this.section,
    required this.onSectionChanged,
  });

  final Widget child;
  final AppSection section;
  final ValueChanged<AppSection> onSectionChanged;

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
            onDestinationSelected: (index) {
              onSectionChanged(AppSection.values[index]);
            },
          ),
          Expanded(child: child),
        ],
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: section.index,
        onTap: (index) {
          onSectionChanged(AppSection.values[index]);
        },
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
