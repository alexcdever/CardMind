# Card List Item Specification (Mobile)
# 卡片列表项规格（移动端）

**Version**: 1.0.0
**版本**: 1.0.0

**Status**: Active
**状态**: 生效中

**Dependencies**: [card/model.md](../../domain/card/model.md)
**依赖**: [card/model.md](../../domain/card/model.md)

**Related Tests**: `test/widgets/card_list_item_mobile_test.dart`
**相关测试**: `test/widgets/card_list_item_mobile_test.dart`

---

## Overview
## 概述

This specification defines the mobile card list item component for displaying card summaries in list layouts. The mobile version is optimized for touch interaction with larger tap targets and mobile-specific gestures.

本规格定义了移动端卡片列表项组件，用于在列表布局中显示卡片摘要。移动端版本针对触摸交互进行了优化，具有更大的点击目标和移动端特定的手势。

---

## Requirement: Display card summary in mobile list
## 需求：在移动端列表中显示卡片摘要

The system SHALL provide a touch-optimized card list item component for mobile devices.

系统应为移动设备提供触摸优化的卡片列表项组件。

### Scenario: Show card title and preview on mobile
### 场景：在移动端显示卡片标题和预览

- **GIVEN**: card list item is rendered on mobile
- **前置条件**：卡片列表项在移动端渲染
- **WHEN**: displaying item
- **操作**：显示项
- **THEN**: the system SHALL display card title in large, readable font
- **预期结果**：系统应以大号可读字体显示卡片标题
- **AND**: show content preview (first 100 characters)
- **并且**：显示内容预览（前 100 个字符）
- **AND**: truncate with ellipsis if too long
- **并且**：如果太长则用省略号截断
- **AND**: use full width of screen
- **并且**：使用屏幕的全宽

### Scenario: Show card metadata on mobile
### 场景：在移动端显示卡片元数据

- **GIVEN**: card list item is rendered on mobile
- **前置条件**：卡片列表项在移动端渲染
- **WHEN**: displaying item
- **操作**：显示项
- **THEN**: the system SHALL display last modified timestamp in relative format
- **预期结果**：系统应以相对格式显示最后修改时间戳
- **AND**: show up to 3 tags as chips
- **并且**：将最多 3 个标签显示为芯片
- **AND**: show "+N" indicator if more tags exist
- **并且**：如果存在更多标签则显示"+N"指示器

---

## Requirement: Support mobile tap interaction
## 需求：支持移动端点击交互

The system SHALL handle tap interactions with touch-friendly targets on mobile.

系统应在移动端使用触摸友好的目标处理点击交互。

### Scenario: Tap to open card on mobile
### 场景：在移动端点击打开卡片

- **GIVEN**: user taps card list item on mobile
- **前置条件**：用户在移动端点击卡片列表项
- **WHEN**: tap occurs
- **操作**：点击发生
- **THEN**: the system SHALL provide haptic feedback
- **预期结果**：系统应提供触觉反馈
- **AND**: call onTap callback with card data
- **并且**：使用卡片数据调用 onTap 回调
- **AND**: navigate to card detail screen
- **并且**：导航到卡片详情屏幕

### Scenario: Long-press to enter selection mode on mobile
### 场景：在移动端长按进入选择模式

- **GIVEN**: user long-presses card list item on mobile
- **前置条件**：用户在移动端长按卡片列表项
- **WHEN**: long-press is detected
- **操作**：检测到长按
- **THEN**: the system SHALL provide haptic feedback
- **预期结果**：系统应提供触觉反馈
- **AND**: call onLongPress callback
- **并且**：调用 onLongPress 回调
- **AND**: enter selection mode
- **并且**：进入选择模式

---

## Requirement: Show mobile-optimized visual feedback
## 需求：显示移动端优化的视觉反馈

The system SHALL provide clear visual feedback for touch interactions on mobile.

系统应为移动端的触摸交互提供清晰的视觉反馈。

### Scenario: Show tap ripple effect on mobile
### 场景：在移动端显示点击涟漪效果

- **GIVEN**: user taps card list item on mobile
- **前置条件**：用户在移动端点击卡片列表项
- **WHEN**: tap occurs
- **操作**：点击发生
- **THEN**: the system SHALL show ripple animation from tap point
- **预期结果**：系统应从点击点显示涟漪动画
- **AND**: use platform-appropriate ripple color
- **并且**：使用平台适当的涟漪颜色

### Scenario: Highlight selected card on mobile
### 场景：在移动端高亮选中的卡片

- **GIVEN**: card list item is in selection mode on mobile
- **前置条件**：卡片列表项在移动端处于选择模式
- **WHEN**: item is selected
- **操作**：项被选中
- **THEN**: the system SHALL show checkbox on left side
- **预期结果**：系统应在左侧显示复选框
- **AND**: apply selection background color
- **并且**：应用选择背景颜色
- **AND**: show checkmark in checkbox
- **并且**：在复选框中显示勾选标记

---

## Requirement: Display sync status on mobile
## 需求：在移动端显示同步状态

The system SHALL show synchronization status for each card on mobile.

系统应在移动端为每张卡片显示同步状态。

### Scenario: Show synced indicator on mobile
### 场景：在移动端显示已同步指示器

- **GIVEN**: card is fully synchronized on mobile
- **前置条件**：卡片在移动端已完全同步
- **WHEN**: displaying item
- **操作**：显示项
- **THEN**: the system SHALL display small sync icon in corner
- **预期结果**：系统应在角落显示小型同步图标
- **AND**: use subtle color to avoid distraction
- **并且**：使用柔和的颜色以避免分散注意力

### Scenario: Show pending sync indicator on mobile
### 场景：在移动端显示待同步指示器

- **GIVEN**: card has unsynchronized changes on mobile
- **前置条件**：卡片在移动端有未同步的更改
- **WHEN**: displaying item
- **操作**：显示项
- **THEN**: the system SHALL display pending sync icon
- **预期结果**：系统应显示待同步图标
- **AND**: use more prominent color to indicate action needed
- **并且**：使用更突出的颜色以指示需要操作

---

## Requirement: Support mobile swipe gestures
## 需求：支持移动端滑动手势

The system SHALL support swipe gestures for quick actions on mobile.

系统应在移动端支持滑动手势以进行快速操作。

### Scenario: Swipe to reveal actions on mobile
### 场景：在移动端滑动显示操作

- **GIVEN**: user swipes card list item left on mobile
- **前置条件**：用户在移动端向左滑动卡片列表项
- **WHEN**: swipe is detected
- **操作**：检测到滑动
- **THEN**: the system SHALL reveal action buttons
- **预期结果**：系统应显示操作按钮
- **AND**: show actions: 删除、分享
- **并且**：显示操作：删除、分享
- **AND**: allow tapping action to execute
- **并且**：允许点击操作以执行

### Scenario: Swipe to dismiss actions on mobile
### 场景：在移动端滑动关闭操作

- **GIVEN**: action buttons are revealed on mobile
- **前置条件**：操作按钮在移动端已显示
- **WHEN**: user swipes right or taps elsewhere
- **操作**：用户向右滑动或点击其他地方
- **THEN**: the system SHALL hide action buttons
- **预期结果**：系统应隐藏操作按钮
- **AND**: return item to normal state
- **并且**：将项返回到正常状态

---

## Requirement: Optimize for mobile performance
## 需求：优化移动端性能

The system SHALL optimize card list item rendering for mobile devices.

系统应优化移动设备的卡片列表项渲染。

### Scenario: Use efficient rendering on mobile
### 场景：在移动端使用高效渲染

- **GIVEN**: card list contains many items on mobile
- **前置条件**：卡片列表在移动端包含许多项
- **WHEN**: scrolling list
- **操作**：滚动列表
- **THEN**: the system SHALL use lazy loading for off-screen items
- **预期结果**：系统应对屏幕外项使用延迟加载
- **AND**: maintain 60fps scrolling performance
- **并且**：保持 60fps 滚动性能
- **AND**: recycle list item widgets
- **并且**：回收列表项组件

---

## Test Coverage
## 测试覆盖

**Test File**: `test/widgets/card_list_item_mobile_test.dart`
**测试文件**: `test/widgets/card_list_item_mobile_test.dart`

**Widget Tests**:
**组件测试**:
- `it_should_display_title_mobile()` - Display title on mobile
- `it_should_display_title_mobile()` - 在移动端显示标题
- `it_should_show_content_preview_mobile()` - Show preview on mobile
- `it_should_show_content_preview_mobile()` - 在移动端显示预览
- `it_should_display_metadata_mobile()` - Show metadata on mobile
- `it_should_display_metadata_mobile()` - 在移动端显示元数据
- `it_should_handle_tap_mobile()` - Handle tap on mobile
- `it_should_handle_tap_mobile()` - 在移动端处理点击
- `it_should_handle_long_press()` - Handle long-press
- `it_should_handle_long_press()` - 处理长按
- `it_should_show_ripple_effect()` - Show ripple effect
- `it_should_show_ripple_effect()` - 显示涟漪效果
- `it_should_highlight_selection_mobile()` - Highlight selection on mobile
- `it_should_highlight_selection_mobile()` - 在移动端高亮选择
- `it_should_show_synced_indicator_mobile()` - Show synced indicator on mobile
- `it_should_show_synced_indicator_mobile()` - 在移动端显示已同步指示器
- `it_should_show_pending_indicator_mobile()` - Show pending indicator on mobile
- `it_should_show_pending_indicator_mobile()` - 在移动端显示待同步指示器
- `it_should_reveal_swipe_actions()` - Reveal swipe actions
- `it_should_reveal_swipe_actions()` - 显示滑动操作
- `it_should_dismiss_swipe_actions()` - Dismiss swipe actions
- `it_should_dismiss_swipe_actions()` - 关闭滑动操作
- `it_should_maintain_scroll_performance()` - Maintain scroll performance
- `it_should_maintain_scroll_performance()` - 保持滚动性能

**Acceptance Criteria**:
**验收标准**:
- [ ] All widget tests pass
- [ ] 所有组件测试通过
- [ ] Touch targets are at least 48x48dp
- [ ] 触摸目标至少为 48x48dp
- [ ] Haptic feedback works correctly
- [ ] 触觉反馈正常工作
- [ ] Swipe gestures are responsive
- [ ] 滑动手势响应灵敏
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
- [home_screen.md](../../screens/mobile/home_screen.md) - Mobile home screen
- [home_screen.md](../../screens/mobile/home_screen.md) - 移动端主屏幕

---

**Last Updated**: 2026-01-23
**最后更新**: 2026-01-23

**Authors**: CardMind Team
**作者**: CardMind Team
