// input: child、section、onSectionChanged 与当前屏幕宽度。
// output: 根据宽度返回 NavigationRail 或 BottomNavigationBar 容器。
// pos: 自适应导航壳组件，负责桌面与移动端导航布局切换。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Flutter 应用壳层模块，负责导航与跨端布局。
import 'package:cardmind/app/navigation/app_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    const destinations = <_ShellDestination>[
      _ShellDestination(icon: Icons.style_outlined, label: '卡片'),
      _ShellDestination(icon: Icons.group_work_outlined, label: '数据池'),
      _ShellDestination(icon: Icons.settings_outlined, label: '设置'),
    ];

    if (desktop) {
      return FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) {
              return KeyEventResult.ignored;
            }
            switch (event.logicalKey) {
              case LogicalKeyboardKey.digit1:
                onSectionChanged(AppSection.cards);
                return KeyEventResult.handled;
              case LogicalKeyboardKey.digit2:
                onSectionChanged(AppSection.pool);
                return KeyEventResult.handled;
              case LogicalKeyboardKey.digit3:
                onSectionChanged(AppSection.settings);
                return KeyEventResult.handled;
              case LogicalKeyboardKey.arrowLeft:
              case LogicalKeyboardKey.arrowUp:
                onSectionChanged(
                  AppSection.values[(section.index - 1) %
                      AppSection.values.length],
                );
                return KeyEventResult.handled;
              case LogicalKeyboardKey.arrowRight:
              case LogicalKeyboardKey.arrowDown:
                onSectionChanged(
                  AppSection.values[(section.index + 1) %
                      AppSection.values.length],
                );
                return KeyEventResult.handled;
              case LogicalKeyboardKey.enter:
              case LogicalKeyboardKey.space:
                onSectionChanged(section);
                return KeyEventResult.handled;
              default:
                return KeyEventResult.ignored;
            }
          },
          child: Row(
            children: [
              NavigationRail(
                destinations: destinations
                    .map(
                      (item) => NavigationRailDestination(
                        icon: Icon(item.icon),
                        label: Text(item.label),
                      ),
                    )
                    .toList(growable: false),
                selectedIndex: section.index,
                useIndicator: true,
                onDestinationSelected: (index) {
                  onSectionChanged(AppSection.values[index]);
                },
              ),
              Expanded(child: child),
            ],
          ),
        ),
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
              (item) => BottomNavigationBarItem(
                icon: Icon(item.icon),
                label: item.label,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _ShellDestination {
  const _ShellDestination({required this.icon, required this.label});

  final IconData icon;
  final String label;
}
