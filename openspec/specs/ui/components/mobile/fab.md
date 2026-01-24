# Floating Action Button Specification (Mobile)
# 浮动操作按钮规格（移动端）

**Version**: 1.0.0
**版本**: 1.0.0

**Status**: Active
**状态**: 生效中

**Dependencies**: None
**依赖**: 无

**Related Tests**: `test/widgets/mobile_fab_test.dart`
**相关测试**: `test/widgets/mobile_fab_test.dart`

---

## Overview
## 概述

This specification defines the mobile floating action button (FAB) component that provides quick access to the primary action of creating a new card. The FAB follows Material Design guidelines and is optimized for touch interaction.

本规格定义了移动端浮动操作按钮（FAB）组件，提供快速访问创建新卡片的主要操作。FAB 遵循 Material Design 指南，并针对触摸交互进行了优化。

**Applicable Platforms**:
**适用平台**:
- Android
- iOS
- iPadOS

---

## Requirement: Display FAB in accessible position
## 需求：在可访问位置显示 FAB

The system SHALL display the FAB in a consistent, easily reachable position on mobile screens.

系统应在移动端屏幕上以一致、易于触达的位置显示 FAB。

### Scenario: FAB positioned at bottom-right
### 场景：FAB 定位在右下角

- **GIVEN**: user is on home screen on mobile
- **前置条件**：用户在移动端主屏幕上
- **WHEN**: viewing screen
- **操作**：查看屏幕
- **THEN**: the system SHALL display FAB at bottom-right corner
- **预期结果**：系统应在右下角显示 FAB
- **AND**: FAB SHALL be 56x56 logical pixels in size
- **并且**：FAB 应为 56x56 逻辑像素大小
- **AND**: FAB SHALL use primary theme color
- **并且**：FAB 应使用主题主色
- **AND**: maintain 16dp margin from screen edges
- **并且**：与屏幕边缘保持 16dp 边距

### Scenario: FAB shows plus icon
### 场景：FAB 显示加号图标

- **GIVEN**: FAB is displayed
- **前置条件**：FAB 已显示
- **WHEN**: viewing FAB
- **操作**：查看 FAB
- **THEN**: the system SHALL show "+" icon
- **预期结果**：系统应显示"+"图标
- **AND**: icon SHALL be white color
- **并且**：图标应为白色
- **AND**: icon SHALL be 24x24 logical pixels
- **并且**：图标应为 24x24 逻辑像素
- **AND**: icon SHALL be centered in FAB
- **并且**：图标应在 FAB 中居中

### Scenario: FAB has elevation shadow
### 场景：FAB 有高度阴影

- **GIVEN**: FAB is displayed
- **前置条件**：FAB 已显示
- **WHEN**: viewing FAB
- **操作**：查看 FAB
- **THEN**: the system SHALL apply 6dp elevation
- **预期结果**：系统应应用 6dp 高度
- **AND**: shadow SHALL be visible
- **并且**：阴影应可见
- **AND**: shadow SHALL follow Material Design guidelines
- **并且**：阴影应遵循 Material Design 指南

---

## Requirement: Handle FAB touch interaction
## 需求：处理 FAB 触摸交互

The system SHALL respond to touch interactions on the FAB with appropriate feedback and actions.

系统应对 FAB 上的触摸交互做出适当的反馈和操作响应。

### Scenario: Tap FAB opens card editor
### 场景：点击 FAB 打开卡片编辑器

- **GIVEN**: user taps FAB on mobile
- **前置条件**：用户在移动端点击 FAB
- **WHEN**: FAB is tapped
- **操作**：FAB 被点击
- **THEN**: the system SHALL open fullscreen card editor
- **预期结果**：系统应打开全屏卡片编辑器
- **AND**: create a new empty card
- **并且**：创建新的空卡片
- **AND**: focus the title field
- **并且**：聚焦标题字段
- **AND**: show keyboard automatically
- **并且**：自动显示键盘

### Scenario: FAB shows ripple effect on tap
### 场景：点击时 FAB 显示波纹效果

- **GIVEN**: user taps FAB
- **前置条件**：用户点击 FAB
- **WHEN**: touch occurs
- **操作**：触摸发生
- **THEN**: the system SHALL show ripple effect
- **预期结果**：系统应显示波纹效果
- **AND**: ripple SHALL be white color
- **并且**：波纹应为白色
- **AND**: ripple SHALL expand from touch point
- **并且**：波纹应从触摸点扩展
- **AND**: provide haptic feedback
- **并且**：提供触觉反馈

### Scenario: FAB is interactive within 1 second
### 场景：FAB 在 1 秒内可交互

- **GIVEN**: home screen loads
- **前置条件**：主屏幕加载
- **WHEN**: 1 second has passed since load
- **操作**：加载后 1 秒已过
- **THEN**: the system SHALL make FAB interactive
- **预期结果**：系统应使 FAB 可交互
- **AND**: tapping SHALL work correctly
- **并且**：点击应正常工作

---

## Requirement: Ensure FAB accessibility
## 需求：确保 FAB 可访问性

The system SHALL make the FAB accessible to all users including those using assistive technologies.

系统应使 FAB 对所有用户可访问，包括使用辅助技术的用户。

### Scenario: FAB has minimum touch target
### 场景：FAB 有最小触摸目标

- **GIVEN**: FAB is displayed
- **前置条件**：FAB 已显示
- **WHEN**: measuring touch target
- **操作**：测量触摸目标
- **THEN**: the system SHALL provide at least 48x48 logical pixels touch target
- **预期结果**：系统应提供至少 48x48 逻辑像素的触摸目标
- **AND**: touch target SHALL extend beyond visual bounds if necessary
- **并且**：如有必要，触摸目标应超出视觉边界

### Scenario: FAB has semantic label for screen readers
### 场景：FAB 有屏幕阅读器的语义标签

- **GIVEN**: screen reader is enabled
- **前置条件**：屏幕阅读器已启用
- **WHEN**: FAB receives focus
- **操作**：FAB 获得焦点
- **THEN**: the system SHALL announce "创建新笔记"
- **预期结果**：系统应朗读"创建新笔记"
- **AND**: announcement SHALL be clear and descriptive
- **并且**：朗读应清晰且描述性强

### Scenario: FAB supports keyboard navigation
### 场景：FAB 支持键盘导航

- **GIVEN**: user is using keyboard navigation
- **前置条件**：用户正在使用键盘导航
- **WHEN**: FAB receives keyboard focus
- **操作**：FAB 获得键盘焦点
- **THEN**: the system SHALL show focus indicator
- **预期结果**：系统应显示焦点指示器
- **AND**: pressing Enter or Space SHALL activate FAB
- **并且**：按 Enter 或空格应激活 FAB

---

## Requirement: Handle FAB visibility during scroll
## 需求：处理滚动时 FAB 的可见性

The system SHALL manage FAB visibility appropriately during list scrolling.

系统应在列表滚动时适当管理 FAB 的可见性。

### Scenario: Hide FAB when scrolling down
### 场景：向下滚动时隐藏 FAB

- **GIVEN**: user is scrolling down card list
- **前置条件**：用户正在向下滚动卡片列表
- **WHEN**: scroll direction is downward
- **操作**：滚动方向向下
- **THEN**: the system SHALL hide FAB with slide-down animation
- **预期结果**：系统应使用向下滑动动画隐藏 FAB
- **AND**: animation SHALL be smooth
- **并且**：动画应流畅

### Scenario: Show FAB when scrolling up
### 场景：向上滚动时显示 FAB

- **GIVEN**: FAB is hidden and user scrolls up
- **前置条件**：FAB 已隐藏且用户向上滚动
- **WHEN**: scroll direction is upward
- **操作**：滚动方向向上
- **THEN**: the system SHALL show FAB with slide-up animation
- **预期结果**：系统应使用向上滑动动画显示 FAB
- **AND**: animation SHALL be smooth
- **并且**：动画应流畅

### Scenario: Always show FAB when at top of list
### 场景：在列表顶部时始终显示 FAB

- **GIVEN**: user is at top of card list
- **前置条件**：用户在卡片列表顶部
- **WHEN**: viewing top of list
- **操作**：查看列表顶部
- **THEN**: the system SHALL always show FAB
- **预期结果**：系统应始终显示 FAB
- **AND**: FAB SHALL be fully visible
- **并且**：FAB 应完全可见

---

## Test Coverage
## 测试覆盖

**Test File**: `test/widgets/mobile_fab_test.dart`
**测试文件**: `test/widgets/mobile_fab_test.dart`

**Widget Tests**:
**组件测试**:
- `it_should_position_at_bottom_right()` - Position at bottom-right
- `it_should_position_at_bottom_right()` - 定位在右下角
- `it_should_show_plus_icon()` - Show plus icon
- `it_should_show_plus_icon()` - 显示加号图标
- `it_should_have_elevation_shadow()` - Have elevation shadow
- `it_should_have_elevation_shadow()` - 有高度阴影
- `it_should_open_editor_on_tap()` - Open editor on tap
- `it_should_open_editor_on_tap()` - 点击时打开编辑器
- `it_should_show_ripple_effect()` - Show ripple effect
- `it_should_show_ripple_effect()` - 显示波纹效果
- `it_should_be_interactive_quickly()` - Be interactive quickly
- `it_should_be_interactive_quickly()` - 快速可交互
- `it_should_have_minimum_touch_target()` - Have minimum touch target
- `it_should_have_minimum_touch_target()` - 有最小触摸目标
- `it_should_have_semantic_label()` - Have semantic label
- `it_should_have_semantic_label()` - 有语义标签
- `it_should_support_keyboard_navigation()` - Support keyboard navigation
- `it_should_support_keyboard_navigation()` - 支持键盘导航
- `it_should_hide_on_scroll_down()` - Hide on scroll down
- `it_should_hide_on_scroll_down()` - 向下滚动时隐藏
- `it_should_show_on_scroll_up()` - Show on scroll up
- `it_should_show_on_scroll_up()` - 向上滚动时显示
- `it_should_always_show_at_top()` - Always show at top
- `it_should_always_show_at_top()` - 在顶部时始终显示

**Acceptance Criteria**:
**验收标准**:
- [ ] All widget tests pass
- [ ] 所有组件测试通过
- [ ] FAB is easily reachable with thumb
- [ ] FAB 易于用拇指触达
- [ ] Touch feedback is immediate and clear
- [ ] 触摸反馈即时且清晰
- [ ] Accessibility requirements are met
- [ ] 满足可访问性要求
- [ ] Scroll behavior is smooth
- [ ] 滚动行为流畅
- [ ] Code review approved
- [ ] 代码审查通过
- [ ] Documentation updated
- [ ] 文档已更新

---

## Related Documents
## 相关文档

**Related Specs**:
**相关规格**:
- [home_screen.md](../../screens/mobile/home_screen.md) - Mobile home screen
- [home_screen.md](../../screens/mobile/home_screen.md) - 移动端主屏幕
- [card_editor_screen.md](../../screens/mobile/card_editor_screen.md) - Mobile card editor
- [card_editor_screen.md](../../screens/mobile/card_editor_screen.md) - 移动端卡片编辑器

---

**Last Updated**: 2026-01-24
**最后更新**: 2026-01-24

**Authors**: CardMind Team
**作者**: CardMind Team
