## Context

CardMind 当前使用 Flutter 构建跨平台应用，但 UI 设计没有针对不同平台的交互特性进行优化。现有代码结构：

- `lib/screens/`: 主要页面（home_screen, card_editor_screen, settings_screen 等）
- `lib/widgets/`: 可复用组件（card_list_item, sync_status_indicator 等）
- `lib/models/`: 数据模型
- `lib/bridge/`: Rust bridge 接口

**当前问题**:
- 所有平台使用相同的 UI 布局和交互模式
- 桌面端没有利用键盘快捷键和鼠标交互优势
- 移动端的触摸区域和手势操作未优化
- 导航模式不符合各平台的用户习惯

**约束条件**:
- 必须保持现有 Rust API 不变（UI 层改造）
- 需要支持 6 个平台：Android、iOS、iPadOS、macOS、Windows、Linux
- 需要保持代码可维护性，避免大量平台判断代码
- 需要支持逐步迁移，不能一次性重写所有 UI

## Goals / Non-Goals

**Goals:**
- 实现平台自动检测和分类（移动端 vs 桌面端）
- 提供统一的自适应 UI 框架，让组件根据平台自动选择实现
- 为移动端提供触摸优化的 UI（底部导航、FAB、手势操作）
- 为桌面端提供键鼠优化的 UI（侧边栏、快捷键、右键菜单）
- 保持业务逻辑代码与平台无关
- 支持现有代码逐步迁移到新架构

**Non-Goals:**
- 不改变 Rust 后端 API
- 不实现平台特有的原生功能（如 iOS 的 3D Touch）
- 不支持平板电脑的特殊布局（iPadOS 视为移动端）
- 不实现主题系统（与平台自适应分离）
- 不支持运行时动态切换平台模式（仅在启动时检测）

## Decisions

### 1. 平台检测策略

**决策**: 使用 Flutter 的 `defaultTargetPlatform` API 进行平台检测，创建 `PlatformType` 枚举。

**理由**:
- `defaultTargetPlatform` 是 Flutter 官方推荐的平台检测方式
- 在编译时确定，性能开销为零
- 支持所有目标平台

**实现**:
```dart
enum PlatformType { mobile, desktop }

class PlatformDetector {
  static PlatformType get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return PlatformType.mobile;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return PlatformType.desktop;
      default:
        return PlatformType.mobile; // 默认移动端
    }
  }
}
```

**替代方案**:
- ❌ 使用 `dart:io` 的 `Platform` API：Web 平台不支持
- ❌ 使用屏幕尺寸判断：不可靠，大屏手机会被误判为桌面端

### 2. 自适应 UI 架构

**决策**: 采用 **Builder Pattern** + **Strategy Pattern** 的混合架构。

**架构层次**:
```
AdaptiveWidget (抽象层)
    ↓
AdaptiveBuilder (构建器)
    ↓
MobileWidget / DesktopWidget (具体实现)
```

**理由**:
- Builder Pattern 提供统一的构建接口
- Strategy Pattern 允许运行时选择不同的实现策略
- 业务代码只需使用 `AdaptiveWidget`，无需关心平台差异
- 易于测试和扩展

**核心 API**:
```dart
// 自适应组件基类
abstract class AdaptiveWidget extends StatelessWidget {
  const AdaptiveWidget({Key? key}) : super(key: key);

  Widget buildMobile(BuildContext context);
  Widget buildDesktop(BuildContext context);

  @override
  Widget build(BuildContext context) {
    return PlatformDetector.currentPlatform == PlatformType.mobile
        ? buildMobile(context)
        : buildDesktop(context);
  }
}

// 自适应构建器（用于函数式组件）
class AdaptiveBuilder extends StatelessWidget {
  final WidgetBuilder mobile;
  final WidgetBuilder desktop;

  const AdaptiveBuilder({
    Key? key,
    required this.mobile,
    required this.desktop,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PlatformDetector.currentPlatform == PlatformType.mobile
        ? mobile(context)
        : desktop(context);
  }
}
```

**替代方案**:
- ❌ 在每个组件内部使用 `if-else` 判断：代码重复，难以维护
- ❌ 为每个平台创建独立的 Widget 树：代码量翻倍，难以共享逻辑
- ❌ 使用 `LayoutBuilder` 根据屏幕尺寸判断：不可靠，无法区分大屏手机和小屏平板

### 3. 导航模式

**决策**: 移动端使用 **BottomNavigationBar**，桌面端使用 **NavigationRail**（侧边栏）。

**移动端导航**:
```dart
Scaffold(
  body: _currentPage,
  bottomNavigationBar: BottomNavigationBar(
    items: [
      BottomNavigationBarItem(icon: Icon(Icons.home), label: '主页'),
      BottomNavigationBarItem(icon: Icon(Icons.sync), label: '同步'),
      BottomNavigationBarItem(icon: Icon(Icons.settings), label: '设置'),
    ],
    currentIndex: _currentIndex,
    onTap: _onTabTapped,
  ),
  floatingActionButton: FloatingActionButton(
    onPressed: _createCard,
    child: Icon(Icons.add),
  ),
)
```

**桌面端导航**:
```dart
Scaffold(
  body: Row(
    children: [
      NavigationRail(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabTapped,
        destinations: [
          NavigationRailDestination(icon: Icon(Icons.home), label: Text('主页')),
          NavigationRailDestination(icon: Icon(Icons.sync), label: Text('同步')),
          NavigationRailDestination(icon: Icon(Icons.settings), label: Text('设置')),
        ],
      ),
      VerticalDivider(thickness: 1, width: 1),
      Expanded(child: _currentPage),
    ],
  ),
)
```

**理由**:
- 符合各平台的用户习惯（iOS/Android 使用底部导航，macOS/Windows 使用侧边栏）
- NavigationRail 在桌面端提供更多垂直空间
- BottomNavigationBar 在移动端更易于触摸操作

### 4. 卡片编辑器布局

**决策**: 移动端使用 **全屏编辑器**，桌面端使用 **分栏编辑器**（列表 + 编辑器）。

**移动端**:
- 点击卡片 → 全屏编辑器（新页面）
- 使用 `Navigator.push` 进行页面跳转
- 编辑器占据整个屏幕

**桌面端**:
- 点击卡片 → 右侧显示编辑器（分栏布局）
- 使用 `Row` 布局：左侧列表 + 右侧编辑器
- 支持同时查看列表和编辑内容

**理由**:
- 移动端屏幕小，全屏编辑器提供更好的专注体验
- 桌面端屏幕大，分栏布局提高效率
- 符合各平台的应用习惯（如 macOS Mail、Windows Outlook）

### 5. 键盘快捷键系统

**决策**: 仅在桌面端启用键盘快捷键，使用 Flutter 的 `Shortcuts` 和 `Actions` API。

**实现**:
```dart
class KeyboardShortcuts extends StatelessWidget {
  final Widget child;

  const KeyboardShortcuts({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (PlatformDetector.currentPlatform == PlatformType.mobile) {
      return child; // 移动端不启用快捷键
    }

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyN):
            const CreateCardIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS):
            const SaveCardIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape):
            const CloseEditorIntent(),
      },
      child: Actions(
        actions: {
          CreateCardIntent: CallbackAction<CreateCardIntent>(
            onInvoke: (_) => _createCard(context),
          ),
          SaveCardIntent: CallbackAction<SaveCardIntent>(
            onInvoke: (_) => _saveCard(context),
          ),
          CloseEditorIntent: CallbackAction<CloseEditorIntent>(
            onInvoke: (_) => _closeEditor(context),
          ),
        },
        child: child,
      ),
    );
  }
}
```

**支持的快捷键**:
- `Ctrl+N` / `Cmd+N`: 新建卡片
- `Ctrl+S` / `Cmd+S`: 保存卡片
- `Ctrl+F` / `Cmd+F`: 搜索
- `Esc`: 关闭编辑器
- `Ctrl+,` / `Cmd+,`: 打开设置

**理由**:
- 桌面端用户期望键盘快捷键
- Flutter 的 `Shortcuts` API 提供跨平台的快捷键支持
- 移动端不需要快捷键（虚拟键盘）

### 6. 触摸区域优化

**决策**: 移动端所有可点击元素最小尺寸为 **44x44 逻辑像素**（iOS HIG 标准）。

**实现**:
```dart
class TouchTarget extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const TouchTarget({Key? key, required this.child, this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (PlatformDetector.currentPlatform == PlatformType.desktop) {
      return InkWell(onTap: onTap, child: child); // 桌面端无需扩大点击区域
    }

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: 44, minHeight: 44),
        child: child,
      ),
    );
  }
}
```

**理由**:
- 符合 iOS Human Interface Guidelines 和 Material Design 规范
- 提高移动端的可点击性和用户体验
- 桌面端鼠标精度高，无需扩大点击区域

### 7. 代码组织结构

**决策**: 创建新的 `lib/adaptive/` 目录，包含所有自适应相关代码。

**目录结构**:
```
lib/
├── adaptive/
│   ├── platform_detector.dart      # 平台检测
│   ├── adaptive_widget.dart        # 自适应组件基类
│   ├── adaptive_builder.dart       # 自适应构建器
│   ├── keyboard_shortcuts.dart     # 键盘快捷键
│   ├── navigation/
│   │   ├── adaptive_navigation.dart     # 自适应导航
│   │   ├── mobile_navigation.dart       # 移动端导航
│   │   └── desktop_navigation.dart      # 桌面端导航
│   ├── layouts/
│   │   ├── adaptive_scaffold.dart       # 自适应脚手架
│   │   ├── mobile_layout.dart           # 移动端布局
│   │   └── desktop_layout.dart          # 桌面端布局
│   └── widgets/
│       ├── touch_target.dart            # 触摸目标
│       ├── adaptive_button.dart         # 自适应按钮
│       └── adaptive_list_item.dart      # 自适应列表项
├── screens/
│   ├── home_screen.dart            # 主页（使用自适应组件）
│   ├── card_editor_screen.dart     # 编辑器（使用自适应布局）
│   └── settings_screen.dart        # 设置（使用自适应组件）
└── widgets/
    ├── card_list_item.dart         # 卡片列表项（使用自适应组件）
    └── sync_status_indicator.dart  # 同步状态指示器
```

**理由**:
- 清晰的代码组织，易于查找和维护
- 自适应逻辑集中管理，避免散落在各处
- 现有代码可以逐步迁移，无需一次性重写

## Risks / Trade-offs

### 风险 1: 代码量增加

**风险**: 每个组件需要实现移动端和桌面端两个版本，代码量可能翻倍。

**缓解措施**:
- 提取共享逻辑到基类或 mixin
- 只对关键组件实现平台差异化，次要组件可以共享实现
- 使用 `AdaptiveBuilder` 进行函数式组件复用

### 风险 2: 测试复杂度增加

**风险**: 需要为每个平台编写独立的 UI 测试，测试用例数量翻倍。

**缓解措施**:
- 使用参数化测试，共享测试逻辑
- 优先测试自适应框架本身，确保平台切换逻辑正确
- 使用 Golden Test 进行视觉回归测试

### 风险 3: 性能开销

**风险**: 每次构建 Widget 都需要检查平台类型，可能影响性能。

**缓解措施**:
- `defaultTargetPlatform` 是编译时常量，JIT 编译器会优化掉分支
- 在 Release 模式下，未使用的平台代码会被 Tree Shaking 移除
- 实际性能开销可以忽略不计

### 风险 4: 迁移成本

**风险**: 现有代码需要逐步迁移到新架构，可能导致代码风格不一致。

**缓解措施**:
- 制定迁移优先级：先迁移主要页面（主页、编辑器），再迁移次要组件
- 新旧代码可以共存，逐步替换
- 提供迁移指南和代码示例

### 权衡 1: iPadOS 分类

**权衡**: iPadOS 被归类为移动端，但实际上它支持键鼠操作和多任务。

**决策**: 当前版本将 iPadOS 视为移动端，未来可以扩展为第三种平台类型（tablet）。

**理由**:
- 简化初始实现，避免过度设计
- iPadOS 用户主要使用触摸操作
- 未来可以通过扩展 `PlatformType` 枚举来支持平板电脑

### 权衡 2: 运行时切换

**权衡**: 不支持运行时动态切换平台模式（如桌面端切换到移动端模式）。

**决策**: 平台类型在应用启动时确定，运行期间不可更改。

**理由**:
- 简化实现，避免状态管理复杂度
- 用户不太可能需要在运行时切换平台模式
- 如果需要切换，可以重启应用

## Migration Plan

### 阶段 1: 基础设施（第 1-2 周）

1. 创建 `lib/adaptive/` 目录结构
2. 实现 `PlatformDetector`
3. 实现 `AdaptiveWidget` 和 `AdaptiveBuilder`
4. 编写单元测试

**验收标准**:
- 所有平台检测测试通过
- 自适应组件基类可以正常工作

### 阶段 2: 导航系统（第 3-4 周）

1. 实现 `AdaptiveNavigation`
2. 实现移动端 `BottomNavigationBar`
3. 实现桌面端 `NavigationRail`
4. 迁移主页导航

**验收标准**:
- 移动端和桌面端导航正常工作
- 导航状态正确同步

### 阶段 3: 主要页面（第 5-7 周）

1. 迁移主页（`home_screen.dart`）
2. 迁移卡片编辑器（`card_editor_screen.dart`）
   - 移动端：全屏编辑器
   - 桌面端：分栏编辑器
3. 迁移设置页面（`settings_screen.dart`）

**验收标准**:
- 所有主要页面在移动端和桌面端正常工作
- UI 测试通过

### 阶段 4: 键盘快捷键（第 8 周）

1. 实现 `KeyboardShortcuts` 系统
2. 添加常用快捷键（Ctrl+N, Ctrl+S, Esc 等）
3. 在桌面端启用快捷键

**验收标准**:
- 所有快捷键在桌面端正常工作
- 移动端不受影响

### 阶段 5: 组件优化（第 9-10 周）

1. 实现 `TouchTarget` 组件
2. 优化移动端触摸区域
3. 优化桌面端鼠标悬停效果
4. 迁移次要组件

**验收标准**:
- 移动端所有可点击元素符合 44x44 标准
- 桌面端鼠标悬停效果正常

### 阶段 6: 测试和优化（第 11-12 周）

1. 编写集成测试
2. 在所有平台上进行测试
3. 性能优化
4. 文档更新

**验收标准**:
- 所有测试通过
- 性能符合预期
- 文档完整

### 回滚策略

如果在迁移过程中遇到严重问题，可以按以下步骤回滚：

1. **部分回滚**: 保留自适应框架，回滚特定页面的迁移
2. **完全回滚**: 删除 `lib/adaptive/` 目录，恢复原有代码
3. **Feature Flag**: 使用 feature flag 控制是否启用自适应 UI

## Open Questions

### Q1: 是否需要支持 Web 平台？

**问题**: Web 平台应该归类为移动端还是桌面端？

**建议**: 根据屏幕尺寸动态判断（使用 `MediaQuery`），但这与当前的编译时检测策略冲突。

**待决策**: 是否需要为 Web 平台单独设计一套检测逻辑？

### Q2: 是否需要支持平板电脑（iPadOS）的特殊布局？

**问题**: iPadOS 支持分屏和多任务，是否需要单独处理？

**建议**: 当前版本将 iPadOS 视为移动端，未来可以扩展为第三种平台类型。

**待决策**: 是否在 v1.0 中支持平板电脑布局？

### Q3: 键盘快捷键是否需要支持自定义？

**问题**: 用户是否需要自定义键盘快捷键？

**建议**: 当前版本使用固定的快捷键，未来可以添加自定义功能。

**待决策**: 是否在 v1.0 中支持快捷键自定义？

### Q4: 是否需要支持右键菜单？

**问题**: 桌面端是否需要支持右键菜单（如右键卡片显示删除、编辑等选项）？

**建议**: 右键菜单是桌面端的常见交互模式，建议支持。

**待决策**: 是否在 v1.0 中实现右键菜单？
