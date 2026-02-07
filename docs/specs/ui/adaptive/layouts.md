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
```

### 场景：桌面端三列布局

- **前置条件**: 应用程序在桌面上运行
- **操作**: 屏幕宽度大于 840dp
- **预期结果**: 系统应使用三列布局
- **并且**: 在左列显示导航抽屉
- **并且**: 在中列显示卡片列表
- **并且**: 在右列显示卡片详情/编辑器

enum LayoutMode {
  mobile,
  tablet,
  desktop,
}

class LayoutBreakpoints {
  static const double mobileMax = 600;
  static const double tabletMax = 840;
}

LayoutMode getLayoutMode(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  
  if (width < LayoutBreakpoints.mobileMax) {
    return LayoutMode.mobile;
  } else if (width < LayoutBreakpoints.tabletMax) {
    return LayoutMode.tablet;
  } else {
    return LayoutMode.desktop;
  }
}
```

### 场景：定义平板电脑断点

- **前置条件**: 布局系统已初始化
- **操作**: 确定布局模式
- **预期结果**: 宽度 >= 600dp 且 < 840dp 的屏幕应分类为平板电脑

bool isDesktopLayout(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  return width >= LayoutBreakpoints.tabletMax;
}
```

---

## 需求：动态布局切换

系统应在屏幕尺寸更改时自动切换布局。

### 场景：窗口调整大小时切换布局

- **前置条件**: 应用程序正在运行
- **操作**: 用户调整窗口大小跨越断点
- **预期结果**: 系统应转换到适当的布局模式
- **并且**: 保留用户的当前上下文（选定的卡片、滚动位置）
- **并且**: 平滑地动画转换

class OrientationAwareLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        final layoutMode = getLayoutMode(context);
        
        // 根据方向和布局模式调整
        if (orientation == Orientation.landscape) {
          return buildLandscapeLayout(layoutMode);
        } else {
          return buildPortraitLayout(layoutMode);
        }
      },
    );
  }
  
  Widget buildLandscapeLayout(LayoutMode mode) {
    // 横屏布局
    return Row(
      children: [
        Expanded(child: CardListView()),
        Expanded(child: CardDetailView()),
      ],
    );
  }
  
  Widget buildPortraitLayout(LayoutMode mode) {
    // 竖屏布局
    return Column(
      children: [
        Expanded(child: CardListView()),
      ],
    );
  }
}
```

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
```

### 场景：桌面端抽屉导航

- **前置条件**: 应用程序处于桌面布局模式
- **操作**: 显示导航
- **预期结果**: 系统应显示永久导航抽屉
- **并且**: 显示完整的导航标签
- **并且**: 允许折叠为仅图标模式

class MobileDensity {
  static const double padding = 8.0;
  static const double margin = 16.0;
  static const double spacing = 8.0;
  static const double cardHeight = 80.0;
}

Widget buildMobileContent(List<Card> cards) {
  return ListView.builder(
    padding: EdgeInsets.all(MobileDensity.padding),
    itemCount: cards.length,
    itemBuilder: (context, index) {
      return Container(
        height: MobileDensity.cardHeight,
        margin: EdgeInsets.only(bottom: MobileDensity.spacing),
        child: CardListItem(card: cards[index]),
      );
    },
  );
}
```

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
```

---

## 测试覆盖

**测试文件**: `test/feature/adaptive/layout_feature_test.dart`

**功能测试（Widget）**:
- `it_should_use_single_column_for_mobile()` - 移动端布局
- `it_should_use_two_column_for_tablet()` - 平板布局
- `it_should_use_three_column_for_desktop()` - 桌面布局
- `it_should_classify_mobile_breakpoint()` - 移动端断点
- `it_should_classify_tablet_breakpoint()` - 平板断点
- `it_should_classify_desktop_breakpoint()` - 桌面断点
- `it_should_switch_layout_on_resize()` - 布局切换
- `it_should_preserve_context_on_switch()` - 上下文保留
- `it_should_adapt_navigation_to_layout()` - 导航适配
- `it_should_adjust_content_density()` - 内容密度调整

**验收标准**:
- [x] 所有单元测试通过
- [x] 布局转换流畅
- [x] 布局更改时保留上下文
- [x] 导航正确适应每种布局模式
- [x] 内容密度适当调整
- [x] 代码审查通过
