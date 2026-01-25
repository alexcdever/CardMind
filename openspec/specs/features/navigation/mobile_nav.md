---
version: 2.0.0
status: draft
platform: mobile
---

# 移动端底部导航栏规格

## 元数据

- **功能名称**: 移动端底部导航栏 (MobileNav)
- **版本**: 2.0.0
- **状态**: 草稿
- **平台**: 移动端 (iOS/Android)
- **依赖**: 无
- **参考**: `react_ui_reference/src/components/mobile-nav.tsx`

## 业务逻辑

### 核心功能

移动端底部导航栏提供应用的主要导航功能，包含三个标签页：

1. **Notes（笔记）**: 显示笔记列表，徽章显示笔记数量
2. **Devices（设备）**: 显示设备列表，徽章显示设备数量
3. **Settings（设置）**: 显示应用设置，无徽章

### 导航状态

```dart
enum NavTab {
  notes,    // 笔记标签
  devices,  // 设备标签
  settings, // 设置标签
}

class NavState {
  final NavTab currentTab;      // 当前激活的标签
  final int notesCount;         // 笔记数量
  final int devicesCount;       // 设备数量
}
```

### 徽章规则

- **显示条件**: count > 0
- **数字显示**:
  - 1 ≤ count ≤ 99: 显示实际数字
  - count > 99: 显示 "99+"
- **隐藏条件**: count = 0
- **Settings 标签**: 始终不显示徽章

### 状态更新

- **currentTab**: 用户点击标签时更新
- **notesCount**: 监听笔记列表变化，自动更新
- **devicesCount**: 监听设备列表变化，自动更新

## 交互逻辑

### 标签切换

**触发条件**: 用户点击标签项

**前置条件**: 无

**执行流程**:
1. 检查点击的标签是否为当前激活标签
2. 如果是当前激活标签，不执行任何操作
3. 如果不是当前激活标签：
   - 更新 currentTab 为新标签
   - 触发视觉反馈动画
   - 通知父组件切换页面

**后置条件**: currentTab 更新为新标签

**视觉反馈**:
- 新激活标签：图标和文字变为主题色，显示顶部指示器，图标缩放动画
- 原激活标签：图标和文字变为灰色，隐藏顶部指示器

**动画时长**: 200ms

### 点击反馈

**触发条件**: 用户按下标签项

**视觉反馈**:
- 按下时：标签项背景色变为浅灰色 (#F0F0F0)
- 松开时：背景色恢复原色

**动画时长**: 100ms

### 徽章更新

**触发条件**: notesCount 或 devicesCount 变化

**执行流程**:
1. 检查新旧值是否相同
2. 如果相同，不执行任何操作
3. 如果不同：
   - 更新徽章数字
   - 触发徽章动画

**视觉反馈**:
- 数字变化：缩放动画（1.0 → 1.2 → 1.0）
- 从 0 变为非 0：淡入 + 缩放动画
- 从非 0 变为 0：淡出动画

**动画时长**: 200ms

## 边界与约束

### 数据边界

| 场景 | 约束 | 处理方式 |
|------|------|----------|
| notesCount < 0 | 不允许 | 视为 0，不显示徽章 |
| devicesCount < 0 | 不允许 | 视为 0，不显示徽章 |
| notesCount > 999 | 允许 | 显示 "99+" |
| devicesCount > 999 | 允许 | 显示 "99+" |
| currentTab 为 null | 不允许 | 必须提供有效的 NavTab 值 |

### 交互边界

| 场景 | 约束 | 处理方式 |
|------|------|----------|
| 点击当前激活标签 | 允许 | 不触发切换，保持当前状态 |
| 快速连续点击 | 允许 | 防抖处理，忽略重复点击 |
| 切换动画进行中再次点击 | 允许 | 取消当前动画，立即切换到新标签 |
| 同时更新多个徽章 | 允许 | 独立更新，互不影响 |

### 布局边界

| 场景 | 约束 | 处理方式 |
|------|------|----------|
| 无 SafeArea 底部安全区域 | 允许 | 使用固定 64px 高度 |
| 有 SafeArea 底部安全区域 | 允许 | 64px + SafeArea.bottom |
| 屏幕宽度 < 320px | 允许 | 标签项等比缩小，保持布局 |
| 屏幕宽度 > 768px | 不允许 | 仅在移动端显示，不支持平板 |

### 性能约束

- 标签切换响应时间 < 50ms
- 动画帧率 ≥ 60fps
- 徽章更新响应时间 < 100ms

## 组件接口

### MobileNav 组件

```dart
class MobileNav extends StatelessWidget {
  /// 当前激活的标签
  final NavTab currentTab;
  
  /// 笔记数量（用于徽章显示）
  final int notesCount;
  
  /// 设备数量（用于徽章显示）
  final int devicesCount;
  
  /// 标签切换回调
  final OnTabChange onTabChange;

  const MobileNav({
    required this.currentTab,
    required this.notesCount,
    required this.devicesCount,
    required this.onTabChange,
  });
}

typedef OnTabChange = void Function(NavTab tab);
```

### NavTabItem 组件

```dart
class NavTabItem extends StatelessWidget {
  /// 标签类型
  final NavTab tab;
  
  /// 是否为激活状态
  final bool isActive;
  
  /// 徽章数量（null 表示不显示徽章）
  final int? badgeCount;
  
  /// 点击回调
  final VoidCallback onTap;

  const NavTabItem({
    required this.tab,
    required this.isActive,
    this.badgeCount,
    required this.onTap,
  });
}
```

## 测试用例

### 单元测试（5 个）

#### NavState 测试

**UT-001: 测试初始状态创建**
- **输入**: currentTab = NavTab.notes, notesCount = 5, devicesCount = 3
- **预期**: NavState 正确初始化，所有字段值正确

**UT-002: 测试徽章显示逻辑**
- **输入**: count = 0, 50, 100
- **预期**:
  - count = 0: 不显示徽章
  - count = 50: 显示 "50"
  - count = 100: 显示 "99+"

**UT-003: 测试负数处理**
- **输入**: notesCount = -1, devicesCount = -5
- **预期**: 视为 0，不显示徽章

**UT-004: 测试标签枚举**
- **输入**: NavTab.notes, NavTab.devices, NavTab.settings
- **预期**: 枚举值可正确比较和使用

**UT-005: 测试回调类型定义**
- **输入**: OnTabChange 回调函数
- **预期**: 类型定义正确，可正确调用

### Widget 测试（41 个）

#### 渲染测试（9 个）

**WT-001: 测试基本渲染**
- **输入**: MobileNav 组件
- **预期**: 正确渲染，包含 3 个标签项

**WT-002: 测试标签项内容**
- **输入**: 3 个标签项
- **预期**:
  - Notes 标签显示笔记图标和 "笔记" 文本
  - Devices 标签显示设备图标和 "设备" 文本
  - Settings 标签显示设置图标和 "设置" 文本

**WT-003: 测试激活状态**
- **输入**: currentTab = NavTab.notes
- **预期**:
  - Notes 标签显示主题色和顶部指示器
  - Devices 和 Settings 标签显示灰色

**WT-004: 测试徽章渲染**
- **输入**: notesCount = 5, devicesCount = 3
- **预期**:
  - Notes 标签显示徽章 "5"
  - Devices 标签显示徽章 "3"
  - Settings 标签不显示徽章

**WT-005: 测试徽章数字显示**
- **输入**: count = 5, 99, 100
- **预期**:
  - count = 5: 显示 "5"
  - count = 99: 显示 "99"
  - count = 100: 显示 "99+"

**WT-006: 测试徽章隐藏**
- **输入**: notesCount = 0, devicesCount = 0
- **预期**: 不显示徽章

**WT-007: 测试布局高度**
- **输入**: SafeArea.bottom = 0 和 34
- **预期**:
  - SafeArea.bottom = 0: 高度 64px
  - SafeArea.bottom = 34: 高度 98px

**WT-008: 测试顶部边框**
- **输入**: MobileNav 组件
- **预期**: 存在 1px 顶部分隔线

**WT-009: 测试标签分布**
- **输入**: MobileNav 组件
- **预期**: 3 个标签均匀分布

#### 交互测试（20 个）

**WT-010: 测试点击 Notes 标签**
- **操作**: 点击 Notes 标签
- **预期**: onTabChange 被调用，参数为 NavTab.notes

**WT-011: 测试点击 Devices 标签**
- **操作**: 点击 Devices 标签
- **预期**: onTabChange 被调用，参数为 NavTab.devices

**WT-012: 测试点击 Settings 标签**
- **操作**: 点击 Settings 标签
- **预期**: onTabChange 被调用，参数为 NavTab.settings

**WT-013: 测试点击当前激活标签**
- **输入**: currentTab = NavTab.notes
- **操作**: 点击 Notes 标签
- **预期**: onTabChange 不被调用

**WT-014: 测试标签切换视觉反馈**
- **输入**: currentTab = NavTab.notes
- **操作**: 点击 Devices 标签
- **预期**:
  - Devices 标签颜色变为主题色
  - Notes 标签颜色变为灰色

**WT-015: 测试图标缩放动画**
- **操作**: 点击标签项
- **预期**: 图标执行缩放动画（1.0 → 1.1 → 1.0）

**WT-016: 测试顶部指示器动画**
- **输入**: currentTab = NavTab.notes
- **操作**: 点击 Devices 标签
- **预期**:
  - Devices 标签顶部指示器淡入显示
  - Notes 标签顶部指示器淡出隐藏

**WT-017: 测试点击反馈**
- **操作**: 按下标签项
- **预期**: 背景色变为浅灰色，松开后恢复

**WT-018: 测试快速连续点击**
- **操作**: 快速点击 Devices 标签 3 次
- **预期**: onTabChange 只被调用 1 次

**WT-019: 测试切换动画进行中再次点击**
- **操作**: 点击 Devices 标签（动画开始），立即点击 Settings 标签
- **预期**: 取消 Devices 动画，立即切换到 Settings

**WT-020: 测试触摸区域**
- **操作**: 点击标签项边缘
- **预期**: onTabChange 被正确调用

**WT-021: 测试徽章更新动画**
- **输入**: notesCount = 5
- **操作**: 更新 notesCount = 10
- **预期**: 徽章数字执行缩放动画

**WT-022: 测试徽章出现动画**
- **输入**: notesCount = 0
- **操作**: 更新 notesCount = 1
- **预期**: 徽章执行淡入 + 缩放动画

**WT-023: 测试徽章消失动画**
- **输入**: notesCount = 1
- **操作**: 更新 notesCount = 0
- **预期**: 徽章执行淡出动画

**WT-024: 测试多次标签切换**
- **操作**: 依次点击 Devices、Settings、Notes
- **预期**: 每次切换都正确更新激活状态

**WT-025: 测试标签切换后徽章保持**
- **输入**: notesCount = 5, devicesCount = 3
- **操作**: 切换到 Devices 标签
- **预期**: Notes 标签徽章仍显示 "5"

**WT-026: 测试同时更新多个徽章**
- **操作**: 同时更新 notesCount 和 devicesCount
- **预期**: 两个徽章都正确更新

**WT-027: 测试标签切换动画时长**
- **操作**: 点击标签项
- **预期**: 动画时长为 200ms

**WT-028: 测试点击反馈动画时长**
- **操作**: 按下标签项
- **预期**: 动画时长为 100ms

**WT-029: 测试徽章动画时长**
- **操作**: 更新徽章数字
- **预期**: 动画时长为 200ms

#### 边界测试（12 个）

**WT-030: 测试负数 notesCount**
- **输入**: notesCount = -1
- **预期**: 不显示徽章

**WT-031: 测试负数 devicesCount**
- **输入**: devicesCount = -5
- **预期**: 不显示徽章

**WT-032: 测试超大 notesCount**
- **输入**: notesCount = 1000
- **预期**: 显示 "99+"

**WT-033: 测试超大 devicesCount**
- **输入**: devicesCount = 9999
- **预期**: 显示 "99+"

**WT-034: 测试 notesCount = 0**
- **输入**: notesCount = 0
- **预期**: 不显示徽章

**WT-035: 测试 devicesCount = 0**
- **输入**: devicesCount = 0
- **预期**: 不显示徽章

**WT-036: 测试 notesCount = 1**
- **输入**: notesCount = 1
- **预期**: 显示 "1"

**WT-037: 测试 notesCount = 99**
- **输入**: notesCount = 99
- **预期**: 显示 "99"

**WT-038: 测试 notesCount = 100**
- **输入**: notesCount = 100
- **预期**: 显示 "99+"

**WT-039: 测试窄屏幕布局**
- **输入**: 屏幕宽度 = 300px
- **预期**: 标签项等比缩小，保持布局

**WT-040: 测试无 SafeArea**
- **输入**: SafeArea.bottom = 0
- **预期**: 高度为 64px

**WT-041: 测试有 SafeArea**
- **输入**: SafeArea.bottom = 34px
- **预期**: 高度为 98px (64 + 34)

## 实现建议

### 性能优化

- 使用 `const` 构造函数减少重建
- 徽章数字变化时只重建徽章组件
- 标签切换时使用 `AnimatedSwitcher` 优化动画

### 状态管理

- 使用 `Provider` 或 `Riverpod` 管理导航状态
- 监听笔记和设备数据变化，自动更新徽章

### 主题适配

- 支持浅色和深色模式
- 使用 `Theme.of(context)` 获取主题色
- 图标和文字颜色根据主题自动调整

### 平台适配

- 仅在移动端显示（iOS/Android）
- 使用 `SafeArea` 处理底部安全区域
- 考虑不同屏幕尺寸的布局适配

## 参考资料

- React UI 参考: `react_ui_reference/src/components/mobile-nav.tsx`
- 设计文档: `docs/plans/2026-01-25-mobile-nav-ui-design.md`
- Flutter 底部导航栏: https://api.flutter.dev/flutter/material/BottomNavigationBar-class.html
- Material Design 导航栏: https://m3.material.io/components/navigation-bar/overview
