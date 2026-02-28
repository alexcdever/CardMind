// input: child、section、onSectionChanged 与当前屏幕宽度。
// output: 根据宽度返回 NavigationRail 或 BottomNavigationBar 容器。
// pos: 自适应导航壳组件，负责桌面与移动端导航布局切换。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 应用壳层模块，负责导航与跨端布局。
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
