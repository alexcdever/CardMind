# Card List Item Specification (Desktop)
# 卡片列表项规格（桌面端）

**Version**: 1.0.0
**版本**: 1.0.0

**Status**: Active
**状态**: 生效中

**Dependencies**: [card/model.md](../../domain/card/model.md)
**依赖**: [card/model.md](../../domain/card/model.md)

**Related Tests**: `test/widgets/card_list_item_desktop_test.dart`
**相关测试**: `test/widgets/card_list_item_desktop_test.dart`

---

## Overview
## 概述

This specification defines the desktop card list item component for displaying card summaries in grid layouts. The desktop version is optimized for mouse interaction with hover effects and inline actions.

本规格定义了桌面端卡片列表项组件,用于在网格布局中显示卡片摘要。桌面端版本针对鼠标交互进行了优化,具有悬停效果和内联操作。

---

## Requirement: Display card summary in desktop grid
## 需求:在桌面端网格中显示卡片摘要

The system SHALL provide a mouse-optimized card list item component for desktop devices.

系统应为桌面设备提供鼠标优化的卡片列表项组件。

### Scenario: Show card title and preview on desktop
### 场景:在桌面端显示卡片标题和预览

- **GIVEN**: card list item is rendered on desktop
- **前置条件**:卡片列表项在桌面端渲染
- **WHEN**: displaying item
- **操作**:显示项
- **THEN**: the system SHALL display card title in bold 20px font
- **预期结果**:系统应以粗体 20px 字体显示卡片标题
- **AND**: show content preview (first 5 lines)
- **并且**:显示内容预览（前 5 行）
- **AND**: truncate with ellipsis if too long
- **并且**:如果太长则用省略号截断
- **AND**: use card-sized container (max 400px width)
- **并且**:使用卡片大小的容器（最大 400px 宽度）

### Scenario: Show card metadata on desktop
### 场景:在桌面端显示卡片元数据

- **GIVEN**: card list item is rendered on desktop
- **前置条件**:卡片列表项在桌面端渲染
- **WHEN**: displaying item
- **操作**:显示项
- **THEN**: the system SHALL display last modified timestamp in relative format
- **预期结果**:系统应以相对格式显示最后修改时间戳
- **AND**: show all tags as chips
- **并且**:将所有标签显示为芯片
- **AND**: use 14px font for metadata
- **并且**:元数据使用 14px 字体

---

## Requirement: Support desktop mouse interaction
## 需求:支持桌面端鼠标交互

The system SHALL handle mouse interactions with hover effects on desktop.

系统应在桌面端使用悬停效果处理鼠标交互。

### Scenario: Click to open card on desktop
### 场景:在桌面端点击打开卡片

- **GIVEN**: user clicks card list item on desktop
- **前置条件**:用户在桌面端点击卡片列表项
- **WHEN**: click occurs
- **操作**:点击发生
- **THEN**: the system SHALL call onClick callback with card data
- **预期结果**:系统应使用卡片数据调用 onClick 回调
- **AND**: navigate to card detail view
- **并且**:导航到卡片详情视图

### Scenario: Right-click to show context menu on desktop
### 场景:在桌面端右键点击显示上下文菜单

- **GIVEN**: user right-clicks card list item on desktop
- **前置条件**:用户在桌面端右键点击卡片列表项
- **WHEN**: right-click is detected
- **操作**:检测到右键点击
- **THEN**: the system SHALL call onContextMenu callback
- **预期结果**:系统应调用 onContextMenu 回调
- **AND**: show context menu near cursor
- **并且**:在光标附近显示上下文菜单

---

## Requirement: Show desktop-optimized hover effects
## 需求:显示桌面端优化的悬停效果

The system SHALL provide clear hover effects for mouse interactions on desktop.

系统应为桌面端的鼠标交互提供清晰的悬停效果。

### Scenario: Show elevation on hover
### 场景:悬停时显示提升

- **GIVEN**: user hovers over card list item on desktop
- **前置条件**:用户在桌面端悬停在卡片列表项上
- **WHEN**: mouse enters card area
- **操作**:鼠标进入卡片区域
- **THEN**: the system SHALL increase card elevation with shadow
- **预期结果**:系统应增加卡片提升并显示阴影
- **AND**: use 200ms smooth transition
- **并且**:使用 200ms 流畅过渡

### Scenario: Show action buttons on hover
### 场景:悬停时显示操作按钮

- **GIVEN**: user hovers over card list item on desktop
- **前置条件**:用户在桌面端悬停在卡片列表项上
- **WHEN**: mouse enters card area
- **操作**:鼠标进入卡片区域
- **THEN**: the system SHALL show edit and delete buttons
- **预期结果**:系统应显示编辑和删除按钮
- **AND**: position buttons in top-right corner
- **并且**:将按钮定位在右上角
- **AND**: fade in buttons smoothly
- **并且**:平滑地淡入按钮

### Scenario: Hide effects when mouse leaves
### 场景:鼠标离开时隐藏效果

- **GIVEN**: hover effects are shown on desktop
- **前置条件**:桌面端悬停效果已显示
- **WHEN**: mouse leaves card area
- **操作**:鼠标离开卡片区域
- **THEN**: the system SHALL return elevation to normal
- **预期结果**:系统应将提升恢复正常
- **AND**: fade out action buttons
- **并且**:淡出操作按钮
- **AND**: use smooth transition
- **并且**:使用流畅过渡

---

## Requirement: Display sync status on desktop
## 需求:在桌面端显示同步状态

The system SHALL show synchronization status for each card on desktop.

系统应在桌面端为每张卡片显示同步状态。

### Scenario: Show synced indicator on desktop
### 场景:在桌面端显示已同步指示器

- **GIVEN**: card is fully synchronized on desktop
- **前置条件**:卡片在桌面端已完全同步
- **WHEN**: displaying item
- **操作**:显示项
- **THEN**: the system SHALL display small sync icon in corner
- **预期结果**:系统应在角落显示小型同步图标
- **AND**: use subtle color to avoid distraction
- **并且**:使用柔和的颜色以避免分散注意力

### Scenario: Show pending sync indicator on desktop
### 场景:在桌面端显示待同步指示器

- **GIVEN**: card has unsynchronized changes on desktop
- **前置条件**:卡片在桌面端有未同步的更改
- **WHEN**: displaying item
- **操作**:显示项
- **THEN**: the system SHALL display pending sync icon
- **预期结果**:系统应显示待同步图标
- **AND**: use more prominent color to indicate action needed
- **并且**:使用更突出的颜色以指示需要操作

---

## Requirement: Support keyboard navigation
## 需求:支持键盘导航

The system SHALL support keyboard navigation for card list items on desktop.

系统应在桌面端支持卡片列表项的键盘导航。

### Scenario: Focus card with keyboard
### 场景:用键盘聚焦卡片

- **GIVEN**: user navigates with keyboard on desktop
- **前置条件**:用户在桌面端使用键盘导航
- **WHEN**: card receives focus
- **操作**:卡片获得焦点
- **THEN**: the system SHALL show focus indicator
- **预期结果**:系统应显示焦点指示器
- **AND**: use visible outline
- **并且**:使用可见的轮廓

### Scenario: Press Enter to open card
### 场景:按 Enter 打开卡片

- **GIVEN**: card has keyboard focus on desktop
- **前置条件**:卡片在桌面端有键盘焦点
- **WHEN**: user presses Enter
- **操作**:用户按 Enter
- **THEN**: the system SHALL open card detail view
- **预期结果**:系统应打开卡片详情视图

---

## Requirement: Optimize for desktop performance
## 需求:优化桌面端性能

The system SHALL optimize card list item rendering for desktop devices.

系统应优化桌面设备的卡片列表项渲染。

### Scenario: Use efficient rendering on desktop
### 场景:在桌面端使用高效渲染

- **GIVEN**: card grid contains many items on desktop
- **前置条件**:卡片网格在桌面端包含许多项
- **WHEN**: scrolling grid
- **操作**:滚动网格
- **THEN**: the system SHALL maintain 60fps scrolling
- **预期结果**:系统应保持 60fps 滚动
- **AND**: use lazy loading for off-screen items
- **并且**:对屏幕外项使用延迟加载
- **AND**: recycle list item widgets
- **并且**:回收列表项组件

### Scenario: Hover effects appear quickly
### 场景:悬停效果快速出现

- **GIVEN**: user hovers over card on desktop
- **前置条件**:用户在桌面端悬停在卡片上
- **WHEN**: mouse enters
- **操作**:鼠标进入
- **THEN**: the system SHALL show effects within 50ms
- **预期结果**:系统应在 50ms 内显示效果
- **AND**: use smooth transitions
- **并且**:使用流畅过渡

---

## Test Coverage
## 测试覆盖

**Test File**: `test/widgets/card_list_item_desktop_test.dart`
**测试文件**: `test/widgets/card_list_item_desktop_test.dart`

**Widget Tests**:
**组件测试**:
- `it_should_display_title_desktop()` - Display title on desktop
- `it_should_display_title_desktop()` - 在桌面端显示标题
- `it_should_show_content_preview_desktop()` - Show preview on desktop
- `it_should_show_content_preview_desktop()` - 在桌面端显示预览
- `it_should_display_metadata_desktop()` - Show metadata on desktop
- `it_should_display_metadata_desktop()` - 在桌面端显示元数据
- `it_should_handle_click_desktop()` - Handle click on desktop
- `it_should_handle_click_desktop()` - 在桌面端处理点击
- `it_should_handle_right_click()` - Handle right-click
- `it_should_handle_right_click()` - 处理右键点击
- `it_should_show_elevation_on_hover()` - Show elevation on hover
- `it_should_show_elevation_on_hover()` - 悬停时显示提升
- `it_should_show_action_buttons_on_hover()` - Show action buttons on hover
- `it_should_show_action_buttons_on_hover()` - 悬停时显示操作按钮
- `it_should_hide_effects_on_leave()` - Hide effects when mouse leaves
- `it_should_hide_effects_on_leave()` - 鼠标离开时隐藏效果
- `it_should_show_synced_indicator_desktop()` - Show synced indicator on desktop
- `it_should_show_synced_indicator_desktop()` - 在桌面端显示已同步指示器
- `it_should_show_pending_indicator_desktop()` - Show pending indicator on desktop
- `it_should_show_pending_indicator_desktop()` - 在桌面端显示待同步指示器
- `it_should_support_keyboard_focus()` - Support keyboard focus
- `it_should_support_keyboard_focus()` - 支持键盘焦点
- `it_should_open_on_enter()` - Open on Enter key
- `it_should_open_on_enter()` - 按 Enter 打开
- `it_should_maintain_scroll_performance()` - Maintain scroll performance
- `it_should_maintain_scroll_performance()` - 保持滚动性能
- `it_should_show_hover_quickly()` - Show hover effects quickly
- `it_should_show_hover_quickly()` - 快速显示悬停效果

**Acceptance Criteria**:
**验收标准**:
- [ ] All widget tests pass
- [ ] 所有组件测试通过
- [ ] Hover effects are smooth and responsive
- [ ] 悬停效果流畅且响应灵敏
- [ ] Keyboard navigation works correctly
- [ ] 键盘导航正常工作
- [ ] Scrolling maintains 60fps
- [ ] 滚动保持 60fps
- [ ] Code review approved
- [ ] 代码审查通过
- [ ] Documentation updated
- [ ] 文档已更新

---

## Related Documents
## 相关文档

**Related Specs**:
**相关规格**:
- [card/model.md](../../domain/card/model.md) - Card domain model
- [card/model.md](../../domain/card/model.md) - 卡片领域模型
- [sync_status_indicator.md](../shared/sync_status_indicator.md) - Sync status indicator
- [sync_status_indicator.md](../shared/sync_status_indicator.md) - 同步状态指示器
- [home_screen.md](../../screens/desktop/home_screen.md) - Desktop home screen
- [home_screen.md](../../screens/desktop/home_screen.md) - 桌面端主屏幕
- [context_menu.md](./context_menu.md) - Desktop context menu
- [context_menu.md](./context_menu.md) - 桌面端右键菜单

---

**Last Updated**: 2026-01-24
**最后更新**: 2026-01-24

**Authors**: CardMind Team
**作者**: CardMind Team
