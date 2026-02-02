# 平台自适应 UI 系统使用文档

## 概述

CardMind 的平台自适应 UI 系统提供了一套完整的框架，让应用能够在移动端和桌面端提供最佳的用户体验。系统会自动检测设备平台，并根据平台特性选择合适的 UI 组件和交互模式。

## 核心概念

### 平台检测

系统使用 `PlatformDetector` 自动检测设备平台并分类为移动端或桌面端：

- **移动端**: Android、iOS、iPadOS
- **桌面端**: macOS、Windows、Linux

```dart
import 'package:cardmind/adaptive/platform_detector.dart';

// 检测当前平台
final platform = PlatformDetector.currentPlatform;

// 使用便捷方法
if (PlatformDetector.isMobile) {
  // 移动端特定代码
}

if (PlatformDetector.isDesktop) {
  // 桌面端特定代码
}
```

### 自适应组件

系统提供两种方式创建自适应组件：

#### 1. 继承 AdaptiveWidget

```dart
import 'package:cardmind/adaptive/adaptive_widget.dart';

class MyAdaptiveWidget extends AdaptiveWidget {
  const MyAdaptiveWidget({super.key});

  @override
  Widget buildMobile(BuildContext context) {
    return Text('移动端 UI');
  }

  @override
  Widget buildDesktop(BuildContext context) {
    return Text('桌面端 UI');
  }
}
```

#### 2. 使用 AdaptiveBuilder

```dart
import 'package:cardmind/adaptive/adaptive_builder.dart';

AdaptiveBuilder(
  mobile: (context) => Text('移动端 UI'),
  desktop: (context) => Text('桌面端 UI'),
)
```

## 布局系统

### AdaptiveScaffold

提供平台适配的页面脚手架：

```dart
import 'package:cardmind/adaptive/layouts/adaptive_scaffold.dart';

AdaptiveScaffold(
  appBar: AppBar(title: Text('标题')),
  body: MyContent(),
  floatingActionButton: FloatingActionButton(
    onPressed: () {},
    child: Icon(Icons.add),
  ),
)
```

**特性**:
- 移动端：单列布局 + FAB
- 桌面端：多列布局，无 FAB（使用工具栏按钮）
- 自动响应窗口大小变化

### 响应式布局

系统提供响应式工具类处理窗口大小和布局调整：

```dart
import 'package:cardmind/adaptive/layouts/responsive_utils.dart';

// 检测窗口大小
final width = ResponsiveUtils.getWidth(context);
final height = ResponsiveUtils.getHeight(context);

// 检测是否应该折叠布局（宽度 < 1024px）
if (ResponsiveUtils.shouldCollapseLayout(context)) {
  // 使用单列布局
}

// 检测键盘是否可见（移动端）
if (ResponsiveUtils.isKeyboardVisible(context)) {
  // 调整布局以适应键盘
}

// 检测屏幕方向
final orientation = ResponsiveUtils.getOrientation(context);
```

**断点定义**:
- 最小桌面宽度: 800px
- 布局折叠阈值: 1024px
- 最小桌面高度: 600px

## 导航系统

### AdaptiveNavigation

提供平台适配的导航组件：

```dart
import 'package:cardmind/adaptive/navigation/adaptive_navigation.dart';

AdaptiveNavigation(
  currentIndex: _currentIndex,
  onDestinationSelected: (index) {
    setState(() => _currentIndex = index);
  },
  destinations: [
    NavigationDestination(
      icon: Icon(Icons.home),
      label: '主页',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings),
      label: '设置',
    ),
  ],
  child: _pages[_currentIndex],
)
```

**特性**:
- 移动端：底部导航栏（BottomNavigationBar）
- 桌面端：侧边栏导航（NavigationRail）

## 排版系统

### AdaptiveTypography

提供平台适配的字体大小和排版：

```dart
import 'package:cardmind/adaptive/typography/adaptive_typography.dart';

// 使用上下文扩展
final textTheme = context.adaptiveTextTheme;
final bodySize = context.adaptiveBodyFontSize;
final headingSize = context.adaptiveHeadingFontSize;

// 或直接调用
final bodySize = AdaptiveTypography.getBodyFontSize();
final headingSize = AdaptiveTypography.getHeadingFontSize();
```

**字体大小**:

| 类型 | 移动端 | 桌面端 |
|------|--------|--------|
| Body | 16px | 14px |
| Heading | 24px | 20px |
| Title | 18px | 16px |
| Caption | 14px | 12px |
| Button | 16px | 14px |

### 自适应文本组件

```dart
import 'package:cardmind/adaptive/typography/adaptive_text.dart';

// 普通文本
AdaptiveText('内容文本')

// 标题文本（level 1-6）
AdaptiveHeading('标题', level: 1)

// 正文文本
AdaptiveBodyText('正文内容')

// 说明文本
AdaptiveCaptionText('说明文字')
```

## 键盘快捷键（桌面端）

系统在桌面端自动启用键盘快捷键：

```dart
import 'package:cardmind/adaptive/keyboard_shortcuts.dart';

KeyboardShortcuts(
  child: MyApp(),
)
```

**支持的快捷键**:
- `Ctrl/Cmd + N`: 新建卡片
- `Ctrl/Cmd + S`: 保存卡片
- `Ctrl/Cmd + F`: 搜索
- `Ctrl/Cmd + ,`: 打开设置
- `Esc`: 关闭编辑器
- `Delete`: 删除卡片
- `Ctrl/Cmd + Z`: 撤销
- `Ctrl/Cmd + Shift + Z`: 重做

**注意**: 快捷键仅在桌面端启用，移动端会自动禁用。

## 触摸优化（移动端）

### TouchTarget

确保移动端可点击元素符合最小尺寸要求（44x44 逻辑像素）：

```dart
import 'package:cardmind/adaptive/widgets/touch_target.dart';

TouchTarget(
  onTap: () {
    // 处理点击
  },
  child: Icon(Icons.star),
)
```

**特性**:
- 移动端：自动扩大点击区域到 44x44
- 桌面端：保持原始尺寸（鼠标精度高）

## 自适应组件库

### AdaptiveButton

```dart
import 'package:cardmind/adaptive/widgets/adaptive_button.dart';

AdaptiveButton(
  onPressed: () {},
  child: Text('按钮'),
)
```

### AdaptiveListItem

```dart
import 'package:cardmind/adaptive/widgets/adaptive_list_item.dart';

AdaptiveListItem(
  title: Text('标题'),
  subtitle: Text('副标题'),
  onTap: () {},
)
```

## 最佳实践

### 1. 优先使用自适应组件

```dart
// ✅ 推荐
AdaptiveScaffold(
  body: MyContent(),
)

// ❌ 不推荐
Scaffold(
  body: PlatformDetector.isMobile
    ? MobileContent()
    : DesktopContent(),
)
```

### 2. 使用响应式工具类

```dart
// ✅ 推荐
if (ResponsiveUtils.shouldCollapseLayout(context)) {
  // 折叠布局
}

// ❌ 不推荐
if (MediaQuery.of(context).size.width < 1024) {
  // 折叠布局
}
```

### 3. 使用自适应排版

```dart
// ✅ 推荐
Text(
  '内容',
  style: context.adaptiveTextTheme.bodyMedium,
)

// ❌ 不推荐
Text(
  '内容',
  style: TextStyle(
    fontSize: PlatformDetector.isMobile ? 16 : 14,
  ),
)
```

### 4. 避免硬编码平台判断

```dart
// ✅ 推荐
class MyWidget extends AdaptiveWidget {
  @override
  Widget buildMobile(BuildContext context) => MobileUI();

  @override
  Widget buildDesktop(BuildContext context) => DesktopUI();
}

// ❌ 不推荐
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (PlatformDetector.isMobile) {
      return MobileUI();
    } else {
      return DesktopUI();
    }
  }
}
```

## 性能考虑

### 零性能开销

- 平台检测使用 `defaultTargetPlatform`，在编译时确定
- Release 模式下，未使用的平台代码会被 Tree Shaking 移除
- 自适应组件的性能开销可以忽略不计

### 优化建议

1. **避免频繁重建**: 使用 `const` 构造函数
2. **缓存计算结果**: 对于复杂的布局计算，使用 `useMemoized`
3. **延迟加载**: 对于大型组件，使用懒加载

## 测试

### 单元测试

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cardmind/adaptive/platform_detector.dart';

test('should detect platform', () {
  final platform = PlatformDetector.currentPlatform;
  expect(platform, isA<PlatformType>());
});
```

### Widget 测试

```dart
testWidgets('should render adaptive widget', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MyAdaptiveWidget(),
    ),
  );

  expect(find.byType(MyAdaptiveWidget), findsOneWidget);
});
```

## 故障排除

### 问题：组件没有自适应

**解决方案**: 确保使用了自适应组件基类或 AdaptiveBuilder

### 问题：键盘快捷键不工作

**解决方案**:
1. 确保在桌面端运行
2. 确保 `KeyboardShortcuts` 包裹了应用根组件
3. 检查是否有其他组件拦截了键盘事件

### 问题：布局在小窗口下显示异常

**解决方案**: 使用 `ResponsiveUtils.shouldCollapseLayout()` 检测并调整布局

## 更多资源

- [设计文档](../design.md)
- [规范文档](../specs/)
- [测试示例](../../test/adaptive/)
- [项目约束](../../../project-guardian.toml)

---

*最后更新: 2026-01-17*
