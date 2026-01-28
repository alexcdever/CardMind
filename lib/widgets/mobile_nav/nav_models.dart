/// 导航标签枚举
enum NavTab { notes, devices, settings }

/// 导航状态类
class NavState {
  const NavState({
    required this.currentTab,
    required this.notesCount,
    required this.devicesCount,
  });

  final NavTab currentTab;
  final int notesCount;
  final int devicesCount;
}

/// 标签切换回调类型
typedef OnTabChange = void Function(NavTab tab);
