# Adaptive Components Specification
# 自适应组件规格

**Version**: 1.0.0
**版本**: 1.0.0

**Status**: Active
**状态**: Active

**Dependencies**: [layouts.md](layouts.md), [platform_detection.md](platform_detection.md)
**依赖**: [layouts.md](layouts.md), [platform_detection.md](platform_detection.md)

**Related Tests**: `test/adaptive/components_test.dart`
**相关测试**: `test/adaptive/components_test.dart`

---

## Overview
## 概述

This specification defines adaptive UI components that automatically adjust their appearance and behavior based on platform and screen size.

本规格定义了自适应 UI 组件，根据平台和屏幕尺寸自动调整其外观和行为。

---

## Requirement: Adaptive buttons
## 需求：自适应按钮

The system SHALL provide buttons that adapt their size and style based on platform.

系统应提供根据平台调整大小和样式的按钮。

### Scenario: Mobile touch-friendly buttons
### 场景：移动端触摸友好按钮

- **GIVEN**: the application is running on mobile
- **前置条件**：应用程序在移动端运行
- **WHEN**: displaying buttons
- **操作**：显示按钮
- **THEN**: buttons SHALL have minimum height of 48dp for touch targets
- **预期结果**：按钮应具有至少 48dp 的高度以适应触摸目标
- **AND**: use larger padding for easier tapping
- **并且**：使用更大的填充以便于点击

### Scenario: Desktop compact buttons
### 场景：桌面端紧凑按钮

- **GIVEN**: the application is running on desktop
- **前置条件**：应用程序在桌面端运行
- **WHEN**: displaying buttons
- **操作**：显示按钮
- **THEN**: buttons SHALL use standard height of 36dp
- **预期结果**：按钮应使用标准高度 36dp
- **AND**: use compact padding optimized for mouse interaction
- **并且**：使用针对鼠标交互优化的紧凑填充
- **AND**: show hover states
- **并且**：显示悬停状态

---

## Requirement: Adaptive FAB (Floating Action Button)
## 需求：自适应 FAB（浮动操作按钮）

The system SHALL provide a FAB that adapts its position and behavior based on layout mode.

系统应提供根据布局模式调整位置和行为的 FAB。

### Scenario: Mobile FAB at bottom-right
### 场景：移动端右下角 FAB

- **GIVEN**: the application is in mobile layout mode
- **前置条件**：应用程序处于移动布局模式
- **WHEN**: displaying the FAB
- **操作**：显示 FAB
- **THEN**: the FAB SHALL be positioned at bottom-right corner
- **预期结果**：FAB 应定位在右下角
- **AND**: float above bottom navigation bar
- **并且**：浮动在底部导航栏上方
- **AND**: use large size (56dp diameter)
- **并且**：使用大尺寸（56dp 直径）

### Scenario: Desktop FAB integrated with toolbar
### 场景：桌面端工具栏集成 FAB

- **GIVEN**: the application is in desktop layout mode
- **前置条件**：应用程序处于桌面布局模式
- **WHEN**: displaying the FAB
- **操作**：显示 FAB
- **THEN**: the FAB SHALL be integrated into the toolbar as a regular button
- **预期结果**：FAB 应作为常规按钮集成到工具栏中
- **AND**: use standard button styling
- **并且**：使用标准按钮样式
- **AND**: include text label alongside icon
- **并且**：在图标旁边包含文本标签

### Scenario: Tablet FAB with extended label
### 场景：平板电脑带扩展标签的 FAB

- **GIVEN**: the application is in tablet layout mode
- **前置条件**：应用程序处于平板布局模式
- **WHEN**: displaying the FAB
- **操作**：显示 FAB
- **THEN**: the FAB SHALL be positioned at bottom-right
- **预期结果**：FAB 应定位在右下角
- **AND**: optionally show extended label on hover or by default
- **并且**：可选地在悬停时或默认显示扩展标签
- **AND**: use medium size (48dp diameter)
- **并且**：使用中等尺寸（48dp 直径）

---

## Requirement: Adaptive list items
## 需求：自适应列表项

The system SHALL provide list items that adapt their layout and interaction based on platform.

系统应提供根据平台调整布局和交互的列表项。

### Scenario: Mobile list items with swipe actions
### 场景：移动端带滑动操作的列表项

- **GIVEN**: the application is running on mobile
- **前置条件**：应用程序在移动端运行
- **WHEN**: displaying card list items
- **操作**：显示卡片列表项
- **THEN**: list items SHALL support swipe gestures
- **预期结果**：列表项应支持滑动手势
- **AND**: reveal action buttons on swipe (delete, archive)
- **并且**：滑动时显示操作按钮（删除、归档）
- **AND**: use single-line or two-line layout for compact display
- **并且**：使用单行或双行布局以实现紧凑显示

### Scenario: Desktop list items with hover actions
### 场景：桌面端带悬停操作的列表项

- **GIVEN**: the application is running on desktop
- **前置条件**：应用程序在桌面端运行
- **WHEN**: displaying card list items
- **操作**：显示卡片列表项
- **THEN**: list items SHALL show action buttons on hover
- **预期结果**：列表项应在悬停时显示操作按钮
- **AND**: support right-click context menu
- **并且**：支持右键上下文菜单
- **AND**: use multi-line layout with more spacing
- **并且**：使用带有更多间距的多行布局

### Scenario: Tablet list items with hybrid interaction
### 场景：平板电脑混合交互列表项

- **GIVEN**: the application is running on tablet
- **前置条件**：应用程序在平板电脑上运行
- **WHEN**: displaying card list items
- **操作**：显示卡片列表项
- **THEN**: list items SHALL support both swipe and long-press gestures
- **预期结果**：列表项应同时支持滑动和长按手势
- **AND**: show action buttons on long-press
- **并且**：长按时显示操作按钮
- **AND**: use comfortable spacing between items
- **并且**：在项目之间使用舒适的间距

---

## Requirement: Adaptive dialogs
## 需求：自适应对话框

The system SHALL provide dialogs that adapt their size and position based on screen size.

系统应提供根据屏幕尺寸调整大小和位置的对话框。

### Scenario: Mobile full-screen dialogs
### 场景：移动端全屏对话框

- **GIVEN**: the application is running on mobile
- **前置条件**：应用程序在移动端运行
- **WHEN**: displaying a dialog
- **操作**：显示对话框
- **THEN**: the dialog SHALL occupy full screen
- **预期结果**：对话框应占据全屏
- **AND**: include a close button in the app bar
- **并且**：在应用栏中包含关闭按钮
- **AND**: slide in from bottom with animation
- **并且**：从底部滑入并带有动画

### Scenario: Desktop centered dialogs
### 场景：桌面端居中对话框

- **GIVEN**: the application is running on desktop
- **前置条件**：应用程序在桌面端运行
- **WHEN**: displaying a dialog
- **操作**：显示对话框
- **THEN**: the dialog SHALL be centered on screen
- **预期结果**：对话框应在屏幕上居中
- **AND**: have maximum width of 600dp
- **并且**：最大宽度为 600dp
- **AND**: show backdrop overlay
- **并且**：显示背景遮罩
- **AND**: fade in with animation
- **并且**：淡入并带有动画

### Scenario: Tablet adaptive dialogs
### 场景：平板电脑自适应对话框

- **GIVEN**: the application is running on tablet
- **前置条件**：应用程序在平板电脑上运行
- **WHEN**: displaying a dialog
- **操作**：显示对话框
- **THEN**: the dialog SHALL be centered with comfortable width (480-600dp)
- **预期结果**：对话框应居中并具有舒适的宽度（480-600dp）
- **AND**: show backdrop overlay
- **并且**：显示背景遮罩
- **AND**: support both touch and pointer interactions
- **并且**：同时支持触摸和指针交互

---

## Requirement: Adaptive text fields
## 需求：自适应文本字段

The system SHALL provide text fields that adapt their behavior based on input method.

系统应提供根据输入方法调整行为的文本字段。

### Scenario: Mobile text fields with virtual keyboard
### 场景：移动端带虚拟键盘的文本字段

- **GIVEN**: the application is running on mobile
- **前置条件**：应用程序在移动端运行
- **WHEN**: user focuses a text field
- **操作**：用户聚焦文本字段
- **THEN**: the virtual keyboard SHALL appear
- **预期结果**：虚拟键盘应出现
- **AND**: the view SHALL scroll to keep the field visible above keyboard
- **并且**：视图应滚动以保持字段在键盘上方可见
- **AND**: use larger touch targets for cursor positioning
- **并且**：使用更大的触摸目标进行光标定位

### Scenario: Desktop text fields with keyboard shortcuts
### 场景：桌面端带键盘快捷键的文本字段

- **GIVEN**: the application is running on desktop
- **前置条件**：应用程序在桌面端运行
- **WHEN**: user focuses a text field
- **操作**：用户聚焦文本字段
- **THEN**: the field SHALL support standard keyboard shortcuts (Ctrl+A, Ctrl+C, Ctrl+V)
- **预期结果**：字段应支持标准键盘快捷键（Ctrl+A、Ctrl+C、Ctrl+V）
- **AND**: show hover state on mouse over
- **并且**：鼠标悬停时显示悬停状态
- **AND**: use precise cursor positioning with mouse
- **并且**：使用鼠标进行精确光标定位

---

## Requirement: Adaptive menus
## 需求：自适应菜单

The system SHALL provide menus that adapt their presentation based on platform.

系统应提供根据平台调整呈现方式的菜单。

### Scenario: Mobile bottom sheet menus
### 场景：移动端底部表单菜单

- **GIVEN**: the application is running on mobile
- **前置条件**：应用程序在移动端运行
- **WHEN**: displaying a menu
- **操作**：显示菜单
- **THEN**: the menu SHALL appear as a bottom sheet
- **预期结果**：菜单应显示为底部表单
- **AND**: slide up from bottom with animation
- **并且**：从底部滑上并带有动画
- **AND**: use large touch targets for menu items
- **并且**：为菜单项使用大触摸目标

### Scenario: Desktop dropdown menus
### 场景：桌面端下拉菜单

- **GIVEN**: the application is running on desktop
- **前置条件**：应用程序在桌面端运行
- **WHEN**: displaying a menu
- **操作**：显示菜单
- **THEN**: the menu SHALL appear as a dropdown near the trigger
- **预期结果**：菜单应显示为触发器附近的下拉菜单
- **AND**: show keyboard shortcuts for menu items
- **并且**：为菜单项显示键盘快捷键
- **AND**: support hover highlighting
- **并且**：支持悬停高亮

---

## Test Coverage
## 测试覆盖

**Test File**: `test/adaptive/components_test.dart`
**测试文件**: `test/adaptive/components_test.dart`

**Widget Tests**:
**Widget 测试**:
- `it_should_use_touch_friendly_buttons_on_mobile()` - Mobile buttons
- `it_should_use_touch_friendly_buttons_on_mobile()` - 移动端按钮
- `it_should_use_compact_buttons_on_desktop()` - Desktop buttons
- `it_should_use_compact_buttons_on_desktop()` - 桌面端按钮
- `it_should_position_fab_correctly_on_mobile()` - Mobile FAB
- `it_should_position_fab_correctly_on_mobile()` - 移动端 FAB
- `it_should_integrate_fab_in_toolbar_on_desktop()` - Desktop FAB
- `it_should_integrate_fab_in_toolbar_on_desktop()` - 桌面端 FAB
- `it_should_support_swipe_on_mobile_list_items()` - Mobile list swipe
- `it_should_support_swipe_on_mobile_list_items()` - 移动端列表滑动
- `it_should_show_hover_actions_on_desktop_list_items()` - Desktop list hover
- `it_should_show_hover_actions_on_desktop_list_items()` - 桌面端列表悬停
- `it_should_show_fullscreen_dialogs_on_mobile()` - Mobile dialogs
- `it_should_show_fullscreen_dialogs_on_mobile()` - 移动端对话框
- `it_should_show_centered_dialogs_on_desktop()` - Desktop dialogs
- `it_should_show_centered_dialogs_on_desktop()` - 桌面端对话框
- `it_should_handle_virtual_keyboard_on_mobile()` - Mobile keyboard
- `it_should_handle_virtual_keyboard_on_mobile()` - 移动端键盘
- `it_should_support_keyboard_shortcuts_on_desktop()` - Desktop shortcuts
- `it_should_support_keyboard_shortcuts_on_desktop()` - 桌面端快捷键
- `it_should_show_bottom_sheet_menus_on_mobile()` - Mobile menus
- `it_should_show_bottom_sheet_menus_on_mobile()` - 移动端菜单
- `it_should_show_dropdown_menus_on_desktop()` - Desktop menus
- `it_should_show_dropdown_menus_on_desktop()` - 桌面端菜单

**Acceptance Criteria**:
**验收标准**:
- [ ] All widget tests pass
- [ ] 所有 Widget 测试通过
- [ ] Components adapt correctly to each platform
- [ ] 组件正确适应每个平台
- [ ] Touch targets meet accessibility guidelines
- [ ] 触摸目标符合可访问性指南
- [ ] Hover states work correctly on desktop
- [ ] 桌面端悬停状态正常工作
- [ ] Gestures work correctly on mobile
- [ ] 移动端手势正常工作
- [ ] Code review approved
- [ ] 代码审查通过
- [ ] Documentation updated
- [ ] 文档已更新

---

## Related Documents
## 相关文档

**Related Specs**:
**相关规格**:
- [layouts.md](layouts.md) - Adaptive layout system
- [layouts.md](layouts.md) - 自适应布局系统
- [platform_detection.md](platform_detection.md) - Platform detection
- [platform_detection.md](platform_detection.md) - 平台检测
- [../components/mobile/gestures.md](../components/mobile/gestures.md) - Mobile gestures
- [../components/mobile/gestures.md](../components/mobile/gestures.md) - 移动端手势

---

**Last Updated**: 2026-01-24
**最后更新**: 2026-01-24

**Authors**: CardMind Team
**作者**: CardMind Team
