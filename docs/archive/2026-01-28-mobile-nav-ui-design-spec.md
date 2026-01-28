# 移动端底部导航栏 UI 设计规格

## 1. 概述

本文档定义移动端底部导航栏（MobileNav）的 UI 设计规格，基于 React UI 参考实现。

**设计原则**：
- 遵循移动端平台特定设计（非响应式）
- 提供清晰的导航反馈
- 支持徽章通知
- 保持简洁的视觉风格

**参考文件**：
- React UI: `react_ui_reference/src/components/mobile-nav.tsx`
- OpenSpec 规格: `openspec/specs/features/navigation/mobile_nav.md`

## 2. 组件结构

### 2.1 MobileNav 组件

```dart
class MobileNav extends StatelessWidget {
  final NavTab currentTab;
  final int notesCount;
  final int devicesCount;
  final OnTabChange onTabChange;

  const MobileNav({
    required this.currentTab,
    required this.notesCount,
    required this.devicesCount,
    required this.onTabChange,
  });
}

enum NavTab {
  notes,
  devices,
  settings,
}

typedef OnTabChange = void Function(NavTab tab);
```

### 2.2 NavTabItem 组件

```dart
class NavTabItem extends StatelessWidget {
  final NavTab tab;
  final bool isActive;
  final int? badgeCount;
  final VoidCallback onTap;

  const NavTabItem({
    required this.tab,
    required this.isActive,
    this.badgeCount,
    required this.onTap,
  });
}
```

## 3. 视觉设计

### 3.1 布局规格

- **高度**: 64px + SafeArea 底部安全区域
- **背景**: 白色（浅色模式）/ 深色（深色模式）
- **顶部边框**: 1px 分隔线
- **标签分布**: 3 个标签均匀分布

### 3.2 标签项设计

#### 图标
- **尺寸**: 24x24px
- **颜色**:
  - 未激活: 灰色 (#666666)
  - 激活: 主题色 (#007AFF)

#### 文本
- **字体大小**: 12px
- **颜色**: 与图标颜色一致
- **位置**: 图标下方 4px

#### 激活状态指示器
- **位置**: 标签项顶部
- **尺寸**: 宽度 32px，高度 3px
- **颜色**: 主题色 (#007AFF)
- **圆角**: 1.5px

### 3.3 徽章设计

- **位置**: 图标右上角
- **尺寸**:
  - 单数字: 16x16px 圆形
  - 双数字: 20x16px 圆角矩形（圆角 8px）
  - "99+": 28x16px 圆角矩形（圆角 8px）
- **背景色**: 红色 (#FF3B30)
- **文字**: 白色，10px，粗体
- **显示规则**:
  - count = 0: 不显示徽章
  - 1 ≤ count ≤ 99: 显示实际数字
  - count > 99: 显示 "99+"

### 3.4 标签内容

| 标签 | 图标 | 文本 | 徽章 |
|------|------|------|------|
| Notes | 笔记图标 | "笔记" | 笔记数量 |
| Devices | 设备图标 | "设备" | 设备数量 |
| Settings | 设置图标 | "设置" | 无 |

## 4. 交互设计

### 4.1 标签切换

**触发方式**: 点击标签项

**视觉反馈**:
1. 图标和文字颜色变为主题色
2. 图标缩放动画（1.0 → 1.1 → 1.0）
3. 顶部指示器淡入显示
4. 其他标签恢复未激活状态

**动画时长**: 200ms

### 4.2 点击反馈

**触发方式**: 按下标签项

**视觉反馈**:
- 标签项背景色变为浅灰色（#F0F0F0）
- 松开后恢复原背景色

**动画时长**: 100ms

### 4.3 徽章更新

**触发时机**:
- Notes 标签: 笔记数量变化时
- Devices 标签: 设备数量变化时

**视觉反馈**:
- 徽章数字变化时，缩放动画（1.0 → 1.2 → 1.0）
- 徽章从 0 变为非 0 时，淡入 + 缩放动画
- 徽章从非 0 变为 0 时，淡出动画

**动画时长**: 200ms

## 5. 状态管理

### 5.1 导航状态

```dart
class NavState {
  final NavTab currentTab;
  final int notesCount;
  final int devicesCount;

  const NavState({
    required this.currentTab,
    required this.notesCount,
    required this.devicesCount,
  });
}
```

### 5.2 状态更新

- **currentTab**: 用户点击标签时更新
- **notesCount**: 监听笔记列表变化
- **devicesCount**: 监听设备列表变化

## 6. 边界情况

### 6.1 数据边界

| 场景 | 处理方式 |
|------|----------|
| notesCount < 0 | 视为 0，不显示徽章 |
| devicesCount < 0 | 视为 0，不显示徽章 |
| notesCount > 999 | 显示 "99+" |
| devicesCount > 999 | 显示 "99+" |

### 6.2 交互边界

| 场景 | 处理方式 |
|------|----------|
| 点击当前激活标签 | 不触发切换，保持当前状态 |
| 快速连续点击 | 防抖处理，忽略重复点击 |
| 切换动画进行中再次点击 | 取消当前动画，立即切换到新标签 |

### 6.3 布局边界

| 场景 | 处理方式 |
|------|----------|
| 无 SafeArea 底部安全区域 | 使用固定 64px 高度 |
| 有 SafeArea 底部安全区域 | 64px + SafeArea.bottom |
| 屏幕宽度 < 320px | 标签项等比缩小，保持布局 |

## 7. 可访问性

### 7.1 语义化标签

- Notes 标签: "笔记，当前有 {count} 条笔记"
- Devices 标签: "设备，当前有 {count} 台设备"
- Settings 标签: "设置"

### 7.2 触摸目标

- 最小触摸区域: 48x48px
- 标签项实际触摸区域: 整个标签项宽度 x 64px 高度

## 8. 测试用例

### 8.1 单元测试（5 个）

#### NavState 测试
1. **测试初始状态创建**
   - 验证 currentTab、notesCount、devicesCount 正确初始化

2. **测试徽章显示逻辑**
   - 验证 count = 0 时不显示徽章
   - 验证 1 ≤ count ≤ 99 时显示实际数字
   - 验证 count > 99 时显示 "99+"

3. **测试负数处理**
   - 验证 notesCount < 0 时视为 0
   - 验证 devicesCount < 0 时视为 0

4. **测试标签枚举**
   - 验证 NavTab 包含 notes、devices、settings
   - 验证枚举值可正确比较

5. **测试回调类型定义**
   - 验证 OnTabChange 类型定义正确

### 8.2 Widget 测试（41 个）

#### 渲染测试（9 个）

1. **测试基本渲染**
   - 验证 MobileNav 正确渲染
   - 验证包含 3 个标签项

2. **测试标签项内容**
   - 验证 Notes 标签显示笔记图标和文本
   - 验证 Devices 标签显示设备图标和文本
   - 验证 Settings 标签显示设置图标和文本

3. **测试激活状态**
   - 验证当前激活标签显示主题色
   - 验证当前激活标签显示顶部指示器
   - 验证未激活标签显示灰色

4. **测试徽章渲染**
   - 验证 notesCount > 0 时显示徽章
   - 验证 devicesCount > 0 时显示徽章
   - 验证 Settings 标签不显示徽章

5. **测试徽章数字显示**
   - 验证 count = 5 时显示 "5"
   - 验证 count = 99 时显示 "99"
   - 验证 count = 100 时显示 "99+"

6. **测试徽章隐藏**
   - 验证 notesCount = 0 时不显示徽章
   - 验证 devicesCount = 0 时不显示徽章

7. **测试布局高度**
   - 验证无 SafeArea 时高度为 64px
   - 验证有 SafeArea 时高度为 98px (64 + 34)

8. **测试顶部边框**
   - 验证存在 1px 顶部分隔线

9. **测试标签分布**
   - 验证 3 个标签均匀分布

#### 交互测试（20 个）

10. **测试点击 Notes 标签**
    - 点击 Notes 标签
    - 验证 onTabChange 被调用，参数为 NavTab.notes

11. **测试点击 Devices 标签**
    - 点击 Devices 标签
    - 验证 onTabChange 被调用，参数为 NavTab.devices

12. **测试点击 Settings 标签**
    - 点击 Settings 标签
    - 验证 onTabChange 被调用，参数为 NavTab.settings

13. **测试点击当前激活标签**
    - currentTab = NavTab.notes
    - 点击 Notes 标签
    - 验证 onTabChange 不被调用

14. **测试标签切换视觉反馈**
    - currentTab = NavTab.notes
    - 点击 Devices 标签
    - 验证 Devices 标签颜色变为主题色
    - 验证 Notes 标签颜色变为灰色

15. **测试图标缩放动画**
    - 点击标签项
    - 验证图标执行缩放动画（1.0 → 1.1 → 1.0）

16. **测试顶部指示器动画**
    - currentTab = NavTab.notes
    - 点击 Devices 标签
    - 验证 Devices 标签顶部指示器淡入显示
    - 验证 Notes 标签顶部指示器淡出隐藏

17. **测试点击反馈**
    - 按下标签项
    - 验证背景色变为浅灰色
    - 松开后验证背景色恢复

18. **测试快速连续点击**
    - 快速点击 Devices 标签 3 次
    - 验证 onTabChange 只被调用 1 次

19. **测试切换动画进行中再次点击**
    - 点击 Devices 标签（动画开始）
    - 立即点击 Settings 标签
    - 验证取消 Devices 动画，立即切换到 Settings

20. **测试触摸区域**
    - 点击标签项边缘
    - 验证 onTabChange 被正确调用

21. **测试徽章更新动画**
    - notesCount = 5
    - 更新 notesCount = 10
    - 验证徽章数字执行缩放动画

22. **测试徽章出现动画**
    - notesCount = 0
    - 更新 notesCount = 1
    - 验证徽章执行淡入 + 缩放动画

23. **测试徽章消失动画**
    - notesCount = 1
    - 更新 notesCount = 0
    - 验证徽章执行淡出动画

24. **测试多次标签切换**
    - 依次点击 Devices、Settings、Notes
    - 验证每次切换都正确更新激活状态

25. **测试标签切换后徽章保持**
    - notesCount = 5, devicesCount = 3
    - 切换到 Devices 标签
    - 验证 Notes 标签徽章仍显示 "5"

26. **测试同时更新多个徽章**
    - 同时更新 notesCount 和 devicesCount
    - 验证两个徽章都正确更新

27. **测试标签切换动画时长**
    - 点击标签项
    - 验证动画时长为 200ms

28. **测试点击反馈动画时长**
    - 按下标签项
    - 验证动画时长为 100ms

29. **测试徽章动画时长**
    - 更新徽章数字
    - 验证动画时长为 200ms

#### 边界测试（12 个）

30. **测试负数 notesCount**
    - notesCount = -1
    - 验证不显示徽章

31. **测试负数 devicesCount**
    - devicesCount = -5
    - 验证不显示徽章

32. **测试超大 notesCount**
    - notesCount = 1000
    - 验证显示 "99+"

33. **测试超大 devicesCount**
    - devicesCount = 9999
    - 验证显示 "99+"

34. **测试 notesCount = 0**
    - notesCount = 0
    - 验证不显示徽章

35. **测试 devicesCount = 0**
    - devicesCount = 0
    - 验证不显示徽章

36. **测试 notesCount = 1**
    - notesCount = 1
    - 验证显示 "1"

37. **测试 notesCount = 99**
    - notesCount = 99
    - 验证显示 "99"

38. **测试 notesCount = 100**
    - notesCount = 100
    - 验证显示 "99+"

39. **测试窄屏幕布局**
    - 屏幕宽度 = 300px
    - 验证标签项等比缩小，保持布局

40. **测试无 SafeArea**
    - SafeArea.bottom = 0
    - 验证高度为 64px

41. **测试有 SafeArea**
    - SafeArea.bottom = 34px
    - 验证高度为 98px (64 + 34)

## 9. 实现注意事项

### 9.1 性能优化

- 使用 `const` 构造函数减少重建
- 徽章数字变化时只重建徽章组件
- 标签切换时使用 `AnimatedSwitcher` 优化动画

### 9.2 状态管理

- 使用 `Provider` 或 `Riverpod` 管理导航状态
- 监听笔记和设备数据变化，自动更新徽章

### 9.3 主题适配

- 支持浅色和深色模式
- 使用 `Theme.of(context)` 获取主题色
- 图标和文字颜色根据主题自动调整

### 9.4 平台适配

- 仅在移动端显示（iOS/Android）
- 使用 `SafeArea` 处理底部安全区域
- 考虑不同屏幕尺寸的布局适配

## 10. 设计决策记录

### 10.1 为什么选择 3 个标签？

**决策**: 使用 Notes、Devices、Settings 三个标签

**理由**:
- 与 React UI 保持一致
- 覆盖核心功能：笔记管理、设备管理、应用设置
- 3 个标签在移动端底部导航栏中布局合理

### 10.2 为什么 Settings 标签不显示徽章？

**决策**: Settings 标签不显示徽章

**理由**:
- 与 React UI 保持一致
- 设置页面通常不需要通知提醒
- 保持视觉简洁

### 10.3 为什么使用顶部指示器而不是底部？

**决策**: 激活状态指示器位于标签项顶部

**理由**:
- 与 React UI 保持一致
- 顶部指示器更接近内容区域，视觉连贯性更好
- 符合常见移动端导航栏设计模式

### 10.4 为什么选择简单过渡动画？

**决策**: 使用简单的颜色和缩放过渡动画

**理由**:
- 与 React UI 保持一致
- 简单动画性能更好，不会影响用户体验
- 避免过度动画导致的视觉疲劳

### 10.5 为什么徽章超过 99 显示 "99+"？

**决策**: 徽章数字超过 99 时显示 "99+"

**理由**:
- 与 React UI 保持一致
- 避免徽章过大影响布局
- 99+ 已足够传达"数量很多"的信息

## 11. 后续工作

1. **实现阶段**:
   - 根据本规格实现 MobileNav 组件
   - 实现 NavTabItem 组件
   - 编写单元测试和 Widget 测试

2. **集成阶段**:
   - 集成到移动端主页面
   - 连接笔记和设备数据源
   - 实现页面切换逻辑

3. **优化阶段**:
   - 性能优化
   - 可访问性测试和优化
   - 多语言支持

## 12. 参考资料

- React UI 参考: `react_ui_reference/src/components/mobile-nav.tsx`
- Flutter 底部导航栏: https://api.flutter.dev/flutter/material/BottomNavigationBar-class.html
- Material Design 导航栏: https://m3.material.io/components/navigation-bar/overview
