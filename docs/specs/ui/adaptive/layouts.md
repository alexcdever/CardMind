# 自适应布局系统规格

## 概述

本规格定义自适应布局系统，根据屏幕尺寸和平台能力自动调整应用程序布局。

**技术栈**:
- Flutter 3.x - UI 框架
- MediaQuery - 屏幕尺寸检测
- LayoutBuilder - 响应式布局
- OrientationBuilder - 方向检测

**核心原则**:
- 响应式设计
- 断点驱动布局
- 上下文保留
- 平滑过渡

**布局断点**:
- 移动端: < 600dp (单列)
- 平板电脑: 600-840dp (双列)
- 桌面端: >= 840dp (三列)

**密度规范**:
- 移动端: 紧凑(8dp/16dp)
- 平板电脑: 舒适(16dp/24dp)
- 桌面端: 宽松(24dp/32dp)

**过渡动画**:
- 持续时间: 300ms
- 曲线: easeInOut
- 类型: 淡入淡出

---

## 需求：布局模式

系统应提供针对不同屏幕尺寸优化的不同布局模式。

### 场景：移动端单列布局

- **前置条件**: 应用程序在移动设备上运行
- **操作**: 屏幕宽度小于 600dp
- **预期结果**: 系统应使用单列布局
- **并且**: 编辑时显示全屏卡片编辑器
- **并且**: 使用底部导航栏

Widget buildTabletLayout(BuildContext context) {
  return Scaffold(
    body: Row(
      children: [
        // 侧边导航栏
        NavigationRail(
          destinations: [
            NavigationRailDestination(icon: Icon(Icons.home), label: Text('主页')),
            NavigationRailDestination(icon: Icon(Icons.search), label: Text('搜索')),
            NavigationRailDestination(icon: Icon(Icons.settings), label: Text('设置')),
          ],
          selectedIndex: 0,
        ),
        VerticalDivider(width: 1),
        // 左列：卡片列表
        Expanded(
          flex: 2,
          child: CardListView(),
        ),
        VerticalDivider(width: 1),
        // 右列：卡片详情/编辑器
        Expanded(
          flex: 3,
          child: CardDetailView(),
        ),
      ],
    ),
  );
}

### 场景：定义平板电脑断点

- **前置条件**: 布局系统已初始化
- **操作**: 确定布局模式
- **预期结果**: 宽度 >= 600dp 且 < 840dp 的屏幕应分类为平板电脑

bool isDesktopLayout(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  return width >= LayoutBreakpoints.tabletMax;
}

---

## 需求：特定于布局的导航

系统应根据当前布局模式调整导航模式。

### 场景：移动端底部栏导航

- **前置条件**: 应用程序处于移动布局模式
- **操作**: 显示导航
- **预期结果**: 系统应显示底部导航栏
- **并且**: 包含主要导航项（主页、搜索、设置）

Widget buildTabletNavigation(int selectedIndex, Function(int) onTap) {
  return NavigationRail(
    selectedIndex: selectedIndex,
    onDestinationSelected: onTap,
    labelType: NavigationRailLabelType.selected,
    destinations: [
      NavigationRailDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: Text('主页'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.search_outlined),
        selectedIcon: Icon(Icons.search),
        label: Text('搜索'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: Text('设置'),
      ),
    ],
  );
}

### 场景：平板电脑舒适密度

- **前置条件**: 应用程序处于平板布局模式
- **操作**: 显示内容
- **预期结果**: 系统应使用舒适的间距和填充
- **并且**: 平衡水平和垂直空间使用

class DesktopDensity {
  static const double padding = 24.0;
  static const double margin = 32.0;
  static const double spacing = 16.0;
  static const double cardHeight = 120.0;
}

Widget buildDesktopContent(List<Card> cards) {
  return ListView.builder(
    padding: EdgeInsets.all(DesktopDensity.padding),
    itemCount: cards.length,
    itemBuilder: (context, index) {
      return Container(
        height: DesktopDensity.cardHeight,
        margin: EdgeInsets.only(bottom: DesktopDensity.spacing),
        padding: EdgeInsets.all(DesktopDensity.padding),
        child: CardListItem(card: cards[index]),
      );
    },
  );
}
