/// # 自适应主页脚手架
///
/// 自适应主页脚手架组件，负责桌面与移动端导航布局切换。
///
/// ## 主要功能
/// - 根据屏幕宽度自动切换导航布局
/// - 屏幕宽度 >= 900px：显示左侧 [NavigationRail]
/// - 屏幕宽度 < 900px：显示底部 [BottomNavigationBar]
/// - 支持键盘快捷键导航（桌面端）
///
/// ## 键盘快捷键（桌面端）
/// - `1` - 切换到卡片分区
/// - `2` - 切换到数据池分区
/// - `↑/←` - 切换到上一个分区
/// - `↓/→` - 切换到下一个分区
/// - `Enter/Space` - 确认当前分区选择
///
/// ## 外部依赖
/// - 依赖 [AppSection] 枚举定义导航分区
/// - 依赖 [SemanticIds] 提供无障碍标识
import 'package:cardmind/app/navigation/app_section.dart';
import 'package:cardmind/features/shared/testing/semantic_ids.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 自适应主页脚手架。
///
/// 根据屏幕尺寸自动选择合适的导航布局：
/// - 桌面端：使用 [NavigationRail] 左侧导航栏
/// - 移动端：使用 [BottomNavigationBar] 底部导航栏
///
/// 支持自定义内容和分区切换回调。
class AdaptiveHomepageScaffold extends StatelessWidget {
  /// 构造函数。
  ///
  /// [child] - 主内容区域 Widget（必需）
  /// [section] - 当前选中的分区（必需）
  /// [onSectionChanged] - 分区切换回调（必需）
  const AdaptiveHomepageScaffold({
    super.key,
    required this.child,
    required this.section,
    required this.onSectionChanged,
  });

  /// 主内容区域 Widget。
  ///
  /// 显示当前选中分区对应的页面内容。
  final Widget child;

  /// 当前选中的分区。
  ///
  /// 决定导航栏中哪个项目处于选中状态。
  final AppSection section;

  /// 分区切换回调。
  ///
  /// 当用户点击导航项或触发快捷键时调用。
  /// 参数为要切换到的目标分区。
  final ValueChanged<AppSection> onSectionChanged;

  @override
  Widget build(BuildContext context) {
    final desktop = switch (Theme.of(context).platform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.fuchsia => false,
    };
    const destinations = <_HomepageDestination>[
      _HomepageDestination(
        icon: Icons.style_outlined,
        label: '卡片',
        identifier: SemanticIds.navCards,
        semanticLabel: '卡片导航',
      ),
      _HomepageDestination(
        icon: Icons.group_work_outlined,
        label: '数据池',
        identifier: SemanticIds.navPool,
        semanticLabel: '数据池导航',
      ),
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
                        icon: Semantics(
                          container: true,
                          explicitChildNodes: true,
                          identifier: item.identifier,
                          label: item.semanticLabel,
                          child: Icon(
                            item.icon,
                            key: ValueKey(item.identifier),
                          ),
                        ),
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
                icon: Semantics(
                  container: true,
                  explicitChildNodes: true,
                  identifier: item.identifier,
                  label: item.semanticLabel,
                  child: Icon(item.icon, key: ValueKey(item.identifier)),
                ),
                label: item.label,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

/// 主页导航目的地定义。
///
/// 内部类，用于定义导航项的配置信息。
/// 包含图标、标签、无障碍标识和语义标签。
class _HomepageDestination {
  /// 构造函数。
  ///
  /// [icon] - 导航项图标（必需）
  /// [label] - 导航项显示文本（必需）
  /// [identifier] - 无障碍标识符（必需）
  /// [semanticLabel] - 语义标签，用于屏幕阅读器（必需）
  const _HomepageDestination({
    required this.icon,
    required this.label,
    required this.identifier,
    required this.semanticLabel,
  });

  /// 导航项图标。
  final IconData icon;

  /// 导航项显示文本。
  final String label;

  /// 无障碍标识符。
  ///
  /// 用于自动化测试和无障碍功能。
  final String identifier;

  /// 语义标签。
  ///
  /// 用于屏幕阅读器读取的文本描述。
  final String semanticLabel;
}
