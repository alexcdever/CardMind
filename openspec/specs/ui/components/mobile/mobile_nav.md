# Mobile Navigation Bar Specification
# 移动端导航栏规格

**Version**: 1.0.0
**版本**: 1.0.0

**Status**: Active
**状态**: 生效中

**Dependencies**: None
**依赖**: 无

**Related Tests**: `test/widgets/mobile_nav_test.dart`
**相关测试**: `test/widgets/mobile_nav_test.dart`

---

## Overview
## 概述

This specification defines the mobile bottom navigation bar component that provides access to the three main sections of the application: Notes, Devices, and Settings. The navigation bar follows platform conventions and provides clear visual feedback for the active section.

本规格定义了移动端底部导航栏组件，提供对应用三个主要部分的访问：笔记、设备和设置。导航栏遵循平台约定，并为激活部分提供清晰的视觉反馈。

**Applicable Platforms**:
**适用平台**:
- Android
- iOS
- iPadOS

---

## Requirement: Display bottom navigation with three tabs
## 需求：显示带有三个标签页的底部导航

The system SHALL provide a bottom navigation bar with three main sections.

系统应提供带有三个主要部分的底部导航栏。

### Scenario: Show three navigation tabs
### 场景：显示三个导航标签页

- **GIVEN**: user is on mobile app
- **前置条件**：用户在移动端应用上
- **WHEN**: viewing any main screen
- **操作**：查看任何主屏幕
- **THEN**: the system SHALL display three tabs: Notes, Devices, and Settings
- **预期结果**：系统应显示三个标签页：笔记、设备和设置
- **AND**: position them evenly across the bottom bar
- **并且**：将它们均匀分布在底部栏上
- **AND**: use consistent spacing between tabs
- **并且**：在标签页之间使用一致的间距

### Scenario: Highlight active tab
### 场景：高亮激活的标签页

- **GIVEN**: user is on a specific section
- **前置条件**：用户在特定部分
- **WHEN**: viewing the navigation bar
- **操作**：查看导航栏
- **THEN**: the system SHALL apply active styling to the current tab
- **预期结果**：系统应对当前标签页应用激活状态样式
- **AND**: use distinct color for active tab
- **并且**：为激活标签页使用不同颜色
- **AND**: use filled icon for active tab
- **并且**：为激活标签页使用填充图标
- **AND**: use outlined icon for inactive tabs
- **并且**：为非激活标签页使用轮廓图标

---

## Requirement: Show badge counts on tabs
## 需求：在标签页上显示徽章计数

The system SHALL display badge counts for relevant tabs to show important information at a glance.

系统应为相关标签页显示徽章计数，以便一目了然地显示重要信息。

### Scenario: Show note count on Notes tab
### 场景：在笔记标签页上显示笔记数量

- **GIVEN**: user has cards in the system
- **前置条件**：用户在系统中有卡片
- **WHEN**: displaying Notes tab
- **操作**：显示笔记标签页
- **THEN**: the system SHALL show a badge with the total number of notes
- **预期结果**：系统应显示带有笔记总数的徽章
- **AND**: position badge at top-right of tab icon
- **并且**：将徽章定位在标签页图标的右上角

### Scenario: Show device count on Devices tab
### 场景：在设备标签页上显示设备数量

- **GIVEN**: user has paired devices
- **前置条件**：用户有配对设备
- **WHEN**: displaying Devices tab
- **操作**：显示设备标签页
- **THEN**: the system SHALL show a badge with the number of paired devices
- **预期结果**：系统应显示带有配对设备数量的徽章
- **AND**: position badge at top-right of tab icon
- **并且**：将徽章定位在标签页图标的右上角

### Scenario: Hide badge when count is zero
### 场景：计数为零时隐藏徽章

- **GIVEN**: a tab's count is zero
- **前置条件**：标签页的计数为零
- **WHEN**: displaying the tab
- **操作**：显示标签页
- **THEN**: the system SHALL hide the badge for that tab
- **预期结果**：系统应隐藏该标签页的徽章

---

## Requirement: Handle tab selection
## 需求：处理标签页选择

The system SHALL respond to user tab selections and navigate to the appropriate section.

系统应响应用户的标签页选择并导航到相应部分。

### Scenario: Switch to different tab
### 场景：切换到不同的标签页

- **GIVEN**: user taps on a non-active tab
- **前置条件**：用户点击非激活标签页
- **WHEN**: tap occurs
- **操作**：点击发生
- **THEN**: the system SHALL navigate to the selected section
- **预期结果**：系统应导航到选定部分
- **AND**: update the active tab visual state
- **并且**：更新激活标签页的视觉状态
- **AND**: provide haptic feedback
- **并且**：提供触觉反馈
- **AND**: use smooth transition animation
- **并且**：使用流畅的过渡动画

### Scenario: Tap on already active tab
### 场景：点击已激活的标签页

- **GIVEN**: user taps on the currently active tab
- **前置条件**：用户点击当前激活的标签页
- **WHEN**: tap occurs
- **操作**：点击发生
- **THEN**: the system SHALL scroll the current view to top
- **预期结果**：系统应将当前视图滚动到顶部
- **AND**: provide haptic feedback
- **并且**：提供触觉反馈

---

## Requirement: Use semantic icons for tabs
## 需求：为标签页使用语义化图标

The system SHALL display clear, semantic icons for each navigation tab.

系统应为每个导航标签页显示清晰的语义化图标。

### Scenario: Display appropriate tab icons
### 场景：显示适当的标签页图标

- **GIVEN**: navigation bar is rendered
- **前置条件**：导航栏已渲染
- **WHEN**: viewing tabs
- **操作**：查看标签页
- **THEN**: the system SHALL show notes icon for the Notes tab
- **预期结果**：系统应为笔记标签页显示笔记图标
- **AND**: show devices icon for the Devices tab
- **并且**：为设备标签页显示设备图标
- **AND**: show settings icon for the Settings tab
- **并且**：为设置标签页显示设置图标
- **AND**: icons SHALL be 24x24 logical pixels
- **并且**：图标应为 24x24 逻辑像素

### Scenario: Icon state transitions
### 场景：图标状态转换

- **GIVEN**: user switches between tabs
- **前置条件**：用户在标签页之间切换
- **WHEN**: tab becomes active
- **操作**：标签页变为激活状态
- **THEN**: the system SHALL use filled icon for active tab
- **预期结果**：系统应为激活标签页使用填充图标
- **AND**: use outlined icon for inactive tabs
- **并且**：为非激活标签页使用轮廓图标
- **AND**: animate icon transition smoothly
- **并且**：平滑地动画图标过渡

---

## Requirement: Respect device safe area
## 需求：遵守设备安全区域

The system SHALL respect device safe area to avoid interfering with system gestures or notches.

系统应遵守设备安全区域，以避免干扰系统手势或刘海。

### Scenario: Apply safe area padding on iOS
### 场景：在 iOS 上应用安全区域内边距

- **GIVEN**: app is running on iOS device with home indicator
- **前置条件**：应用在带有主页指示器的 iOS 设备上运行
- **WHEN**: rendering navigation bar
- **操作**：渲染导航栏
- **THEN**: the system SHALL add appropriate bottom padding
- **预期结果**：系统应添加适当的底部内边距
- **AND**: ensure tabs are above home indicator
- **并且**：确保标签页在主页指示器上方
- **AND**: maintain touch targets
- **并且**：保持触摸目标

### Scenario: Apply safe area padding on Android
### 场景：在 Android 上应用安全区域内边距

- **GIVEN**: app is running on Android device with gesture navigation
- **前置条件**：应用在带有手势导航的 Android 设备上运行
- **WHEN**: rendering navigation bar
- **操作**：渲染导航栏
- **THEN**: the system SHALL add appropriate bottom padding
- **预期结果**：系统应添加适当的底部内边距
- **AND**: ensure tabs are above gesture area
- **并且**：确保标签页在手势区域上方

---

## Requirement: Provide accessibility support
## 需求：提供可访问性支持

The system SHALL make the navigation bar accessible to all users including those using assistive technologies.

系统应使导航栏对所有用户可访问，包括使用辅助技术的用户。

### Scenario: Tabs have semantic labels
### 场景：标签页有语义标签

- **GIVEN**: screen reader is enabled
- **前置条件**：屏幕阅读器已启用
- **WHEN**: tab receives focus
- **操作**：标签页获得焦点
- **THEN**: the system SHALL announce tab name
- **预期结果**：系统应朗读标签页名称
- **AND**: announce badge count if present
- **并且**：如果存在则朗读徽章计数
- **AND**: announce active state
- **并且**：朗读激活状态

### Scenario: Tabs have minimum touch target
### 场景：标签页有最小触摸目标

- **GIVEN**: navigation bar is displayed
- **前置条件**：导航栏已显示
- **WHEN**: measuring touch targets
- **操作**：测量触摸目标
- **THEN**: the system SHALL provide at least 48x48 logical pixels touch target for each tab
- **预期结果**：系统应为每个标签页提供至少 48x48 逻辑像素的触摸目标

---

## Test Coverage
## 测试覆盖

**Test File**: `test/widgets/mobile_nav_test.dart`
**测试文件**: `test/widgets/mobile_nav_test.dart`

**Widget Tests**:
**组件测试**:
- `it_should_display_three_tabs()` - Display three tabs
- `it_should_display_three_tabs()` - 显示三个标签页
- `it_should_position_tabs_evenly()` - Position tabs evenly
- `it_should_position_tabs_evenly()` - 均匀定位标签页
- `it_should_highlight_active_tab()` - Highlight active tab
- `it_should_highlight_active_tab()` - 高亮激活标签页
- `it_should_show_note_count_badge()` - Show note count badge
- `it_should_show_note_count_badge()` - 显示笔记计数徽章
- `it_should_show_device_count_badge()` - Show device count badge
- `it_should_show_device_count_badge()` - 显示设备计数徽章
- `it_should_hide_zero_badges()` - Hide zero badges
- `it_should_hide_zero_badges()` - 隐藏零计数徽章
- `it_should_switch_tabs()` - Switch tabs
- `it_should_switch_tabs()` - 切换标签页
- `it_should_scroll_to_top_on_active_tap()` - Scroll to top on active tap
- `it_should_scroll_to_top_on_active_tap()` - 点击激活标签页滚动到顶部
- `it_should_use_semantic_icons()` - Use semantic icons
- `it_should_use_semantic_icons()` - 使用语义化图标
- `it_should_transition_icon_states()` - Transition icon states
- `it_should_transition_icon_states()` - 过渡图标状态
- `it_should_apply_safe_area_padding()` - Apply safe area padding
- `it_should_apply_safe_area_padding()` - 应用安全区域内边距
- `it_should_have_semantic_labels()` - Have semantic labels
- `it_should_have_semantic_labels()` - 有语义标签
- `it_should_have_minimum_touch_targets()` - Have minimum touch targets
- `it_should_have_minimum_touch_targets()` - 有最小触摸目标

**Acceptance Criteria**:
**验收标准**:
- [ ] All widget tests pass
- [ ] 所有组件测试通过
- [ ] Tab switching is smooth and responsive
- [ ] 标签页切换流畅且响应灵敏
- [ ] Badge counts update correctly
- [ ] 徽章计数正确更新
- [ ] Safe area is respected on all devices
- [ ] 在所有设备上遵守安全区域
- [ ] Accessibility requirements are met
- [ ] 满足可访问性要求
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
- [sync_screen.md](../../screens/mobile/sync_screen.md) - Mobile sync screen
- [sync_screen.md](../../screens/mobile/sync_screen.md) - 移动端同步屏幕
- [settings_screen.md](../../screens/mobile/settings_screen.md) - Mobile settings screen
- [settings_screen.md](../../screens/mobile/settings_screen.md) - 移动端设置屏幕

---

**Last Updated**: 2026-01-24
**最后更新**: 2026-01-24

**Authors**: CardMind Team
**作者**: CardMind Team
