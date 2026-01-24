# Mobile Navigation Specification | 移动端导航规格

**Version** | **版本**: 1.0.0
**Status** | **状态**: Active
**Dependencies** | **依赖**: None
**Related Tests** | **相关测试**: `test/widgets/mobile_nav_test.dart`

---

## Overview | 概述

This specification defines the mobile bottom navigation bar component that provides access to the three main sections of the application.

本规格定义了移动端底部导航栏组件，提供对应用三个主要部分的访问。

---

## Requirement: Display bottom navigation bar with three tabs | 需求：显示带有三个标签页的底部导航栏

The system SHALL provide a mobile bottom navigation bar with three main sections.

系统应提供带有三个主要部分的移动端底部导航栏。

### Scenario: Show navigation tabs | 场景：显示导航标签页

- **WHEN** rendering mobile navigation
- **操作**：渲染移动端导航
- **THEN** the system SHALL display three tabs: Notes, Devices, and Settings
- **预期结果**：系统应显示三个标签页：笔记、设备和设置
- **AND** position them evenly across the bottom bar
- **并且**：将它们均匀分布在底部栏上

### Scenario: Highlight active tab | 场景：高亮激活的标签页

- **WHEN** a tab is active
- **操作**：标签页处于激活状态
- **THEN** the system SHALL apply active styling to the tab
- **预期结果**：系统应对标签页应用激活状态样式
- **AND** use distinct color and icon fill to indicate selection
- **并且**：使用不同的颜色和图标填充来指示选择

---

## Requirement: Show badge counts on tabs | 需求：在标签页上显示徽章计数

The system SHALL display badge counts for relevant tabs.

系统应为相关标签页显示徽章计数。

### Scenario: Show note count on Notes tab | 场景：在笔记标签页上显示笔记数量

- **WHEN** displaying Notes tab
- **操作**：显示笔记标签页
- **THEN** the system SHALL show a badge with the total number of notes
- **预期结果**：系统应显示带有笔记总数的徽章

### Scenario: Show device count on Devices tab | 场景：在设备标签页上显示设备数量

- **WHEN** displaying Devices tab
- **操作**：显示设备标签页
- **THEN** the system SHALL show a badge with the number of paired devices
- **预期结果**：系统应显示带有配对设备数量的徽章

### Scenario: Hide badge when count is zero | 场景：计数为零时隐藏徽章

- **WHEN** a tab's count is zero
- **操作**：标签页的计数为零
- **THEN** the system SHALL hide the badge for that tab
- **预期结果**：系统应隐藏该标签页的徽章

---

## Requirement: Handle tab selection | 需求：处理标签页选择

The system SHALL respond to user tab selections and notify the parent component.

系统应响应用户的标签页选择并通知父组件。

### Scenario: Switch to different tab | 场景：切换到不同的标签页

- **WHEN** user taps on a non-active tab
- **操作**：用户点击非激活标签页
- **THEN** the system SHALL call onTabChange callback with the new tab index
- **预期结果**：系统应使用新标签页索引调用 onTabChange 回调
- **AND** update the active tab visual state
- **并且**：更新激活标签页的视觉状态

### Scenario: Tap on already active tab | 场景：点击已激活的标签页

- **WHEN** user taps on the currently active tab
- **操作**：用户点击当前激活的标签页
- **THEN** the system SHALL NOT call onTabChange callback
- **预期结果**：系统不应调用 onTabChange 回调
- **AND** optionally scroll the current view to top
- **并且**：可选地将当前视图滚动到顶部

---

## Requirement: Use appropriate icons for tabs | 需求：为标签页使用适当的图标

The system SHALL display semantic icons for each navigation tab.

系统应为每个导航标签页显示语义化图标。

### Scenario: Display tab icons | 场景：显示标签页图标

- **WHEN** rendering navigation tabs
- **操作**：渲染导航标签页
- **THEN** the system SHALL show a notes icon for the Notes tab
- **预期结果**：系统应为笔记标签页显示笔记图标
- **AND** show a devices icon for the Devices tab
- **并且**：为设备标签页显示设备图标
- **AND** show a settings icon for the Settings tab
- **并且**：为设置标签页显示设置图标

### Scenario: Icon state transition | 场景：图标状态转换

- **WHEN** switching between tabs
- **操作**：在标签页之间切换
- **THEN** the system SHALL use filled icons for active tab
- **预期结果**：系统应为激活标签页使用填充图标
- **AND** use outlined icons for inactive tabs
- **并且**：为非激活标签页使用轮廓图标

---

## Requirement: Provide safe area insets | 需求：提供安全区域内边距

The system SHALL respect device safe area to avoid interfering with system gestures or notches.

系统应遵守设备安全区域，以避免干扰系统手势或刘海。

### Scenario: Apply safe area padding | 场景：应用安全区域内边距

- **WHEN** rendering on devices with bottom safe area (e.g., iPhone with home indicator)
- **操作**：在带有底部安全区域的设备上渲染（例如带主页指示器的 iPhone）
- **THEN** the navigation bar SHALL add appropriate padding to avoid overlap
- **预期结果**：导航栏应添加适当的内边距以避免重叠

---

## Test Coverage | 测试覆盖

**Test File** | **测试文件**: `test/widgets/mobile_nav_test.dart`

**Widget Tests** | **Widget 测试**:
- `it_should_display_three_tabs()` - Display three tabs | 显示三个标签页
- `it_should_position_tabs_evenly()` - Even positioning | 均匀定位
- `it_should_highlight_active_tab()` - Highlight active | 高亮激活标签
- `it_should_show_note_count_badge()` - Note count badge | 笔记计数徽章
- `it_should_show_device_count_badge()` - Device count badge | 设备计数徽章
- `it_should_hide_zero_badges()` - Hide zero badges | 隐藏零计数徽章
- `it_should_switch_tabs()` - Switch tabs | 切换标签页
- `it_should_not_callback_on_active_tap()` - No callback on active tap | 点击激活标签无回调
- `it_should_scroll_to_top_on_active_tap()` - Scroll to top | 滚动到顶部
- `it_should_use_semantic_icons()` - Semantic icons | 语义化图标
- `it_should_transition_icon_states()` - Icon state transition | 图标状态转换
- `it_should_apply_safe_area_padding()` - Safe area padding | 安全区域内边距

**Acceptance Criteria** | **验收标准**:
- [ ] All widget tests pass | 所有 Widget 测试通过
- [ ] Tab switching is smooth | 标签页切换流畅
- [ ] Badge counts update correctly | 徽章计数正确更新
- [ ] Safe area is respected on all devices | 在所有设备上遵守安全区域
- [ ] Code review approved | 代码审查通过
- [ ] Documentation updated | 文档已更新

---

## Related Documents | 相关文档

**Related Specs** | **相关规格**:
- [home_screen.md](../home_screen/home_screen.md) - Home screen | 主屏幕
- [sync_screen.md](../sync/sync_screen.md) - Sync screen | 同步屏幕

---

**Last Updated** | **最后更新**: 2026-01-21
**Authors** | **作者**: CardMind Team
