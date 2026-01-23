# Mobile Gestures Specification
# 移动端手势规格

**Version**: 1.0.0
**版本**: 1.0.0

**Status**: Active
**状态**: 生效中

**Dependencies**: None
**依赖**: 无

**Related Tests**: `test/widgets/mobile_gestures_test.dart`
**相关测试**: `test/widgets/mobile_gestures_test.dart`

---

## Overview
## 概述

This specification defines mobile gesture interactions for touch-based devices. Mobile gestures provide intuitive ways to perform quick actions like deleting cards, accessing context menus, and refreshing content.

本规格定义了基于触摸设备的移动端手势交互。移动端手势提供直观的方式来执行快速操作，如删除卡片、访问上下文菜单和刷新内容。

**Applicable Platforms**:
**适用平台**:
- Android
- iOS
- iPadOS

---

## Requirement: Support swipe gestures for quick actions
## 需求：支持滑动手势进行快速操作

The system SHALL support swipe gestures on card list items for quick actions.

系统应在卡片列表项上支持滑动手势进行快速操作。

### Scenario: Swipe left reveals delete button
### 场景：左滑显示删除按钮

- **GIVEN**: user is viewing card list on mobile
- **前置条件**：用户在移动端查看卡片列表
- **WHEN**: user swipes left on a card
- **操作**：用户在卡片上左滑
- **THEN**: the system SHALL reveal a red delete button
- **预期结果**：系统应显示红色删除按钮
- **AND**: the card SHALL slide left smoothly with animation
- **并且**：卡片应平滑地带动画左滑
- **AND**: the delete button SHALL be touch-friendly (minimum 48dp height)
- **并且**：删除按钮应触摸友好（最小 48dp 高度）

### Scenario: Swipe right dismisses revealed action
### 场景：右滑关闭已显示的操作

- **GIVEN**: delete button is revealed on a card
- **前置条件**：卡片上的删除按钮已显示
- **WHEN**: user swipes right on the card
- **操作**：用户在卡片上右滑
- **THEN**: the system SHALL hide the delete button
- **预期结果**：系统应隐藏删除按钮
- **AND**: the card SHALL slide back to original position
- **并且**：卡片应滑回原始位置
- **AND**: use smooth animation
- **并且**：使用流畅动画

### Scenario: Tap delete button removes card
### 场景：点击删除按钮移除卡片

- **GIVEN**: delete button is revealed
- **前置条件**：删除按钮已显示
- **WHEN**: user taps the delete button
- **操作**：用户点击删除按钮
- **THEN**: the system SHALL mark the card as deleted
- **预期结果**：系统应将卡片标记为已删除
- **AND**: animate the card out of the list
- **并且**：将卡片从列表中动画移出
- **AND**: show snackbar with "已删除" message
- **并且**：显示带有"已删除"消息的提示条
- **AND**: provide undo option in snackbar
- **并且**：在提示条中提供撤销选项

---

## Requirement: Support long-press gesture for context menu
## 需求：支持长按手势打开上下文菜单

The system SHALL support long-press gesture to open context menu on mobile.

系统应在移动端支持长按手势打开上下文菜单。

### Scenario: Long-press shows context menu
### 场景：长按显示上下文菜单

- **GIVEN**: user is viewing card list on mobile
- **前置条件**：用户在移动端查看卡片列表
- **WHEN**: user long-presses on a card
- **操作**：用户长按卡片
- **THEN**: the system SHALL show context menu
- **预期结果**：系统应显示上下文菜单
- **AND**: provide haptic feedback
- **并且**：提供触觉反馈
- **AND**: include options: "编辑", "删除", "分享", "复制"
- **并且**：包含选项："编辑"、"删除"、"分享"、"复制"

### Scenario: Context menu positioned near touch point
### 场景：上下文菜单定位在触摸点附近

- **GIVEN**: context menu is shown
- **前置条件**：上下文菜单已显示
- **WHEN**: viewing menu
- **操作**：查看菜单
- **THEN**: the system SHALL position menu near the touch point
- **预期结果**：系统应将菜单定位在触摸点附近
- **AND**: ensure menu does not extend off screen
- **并且**：确保菜单不超出屏幕
- **AND**: adjust position if necessary to stay within bounds
- **并且**：如有必要调整位置以保持在边界内

### Scenario: Tap outside dismisses context menu
### 场景：点击外部关闭上下文菜单

- **GIVEN**: context menu is shown
- **前置条件**：上下文菜单已显示
- **WHEN**: user taps outside the menu
- **操作**：用户点击菜单外部
- **THEN**: the system SHALL close the menu
- **预期结果**：系统应关闭菜单
- **AND**: no action SHALL be performed
- **并且**：不应执行任何操作
- **AND**: use fade-out animation
- **并且**：使用淡出动画

---

## Requirement: Support pull-to-refresh gesture
## 需求：支持下拉刷新手势

The system SHALL support pull-to-refresh gesture on scrollable lists.

系统应在可滚动列表上支持下拉刷新手势。

### Scenario: Pull down shows refresh indicator
### 场景：下拉显示刷新指示器

- **GIVEN**: user is at the top of card list
- **前置条件**：用户在卡片列表顶部
- **WHEN**: user pulls down on the list
- **操作**：用户在列表上下拉
- **THEN**: the system SHALL show refresh indicator
- **预期结果**：系统应显示刷新指示器
- **AND**: the indicator SHALL follow pull distance
- **并且**：指示器应跟随下拉距离
- **AND**: use platform-appropriate indicator style
- **并且**：使用平台适当的指示器样式

### Scenario: Release past threshold triggers refresh
### 场景：释放超过阈值触发刷新

- **GIVEN**: user has pulled past refresh threshold
- **前置条件**：用户已下拉超过刷新阈值
- **WHEN**: user releases the pull
- **操作**：用户释放下拉
- **THEN**: the system SHALL trigger card list refresh
- **预期结果**：系统应触发卡片列表刷新
- **AND**: show loading indicator
- **并且**：显示加载指示器
- **AND**: reload cards from storage
- **并且**：从存储重新加载卡片
- **AND**: hide indicator when complete
- **并且**：完成时隐藏指示器

### Scenario: Release before threshold cancels refresh
### 场景：在阈值前释放取消刷新

- **GIVEN**: user has pulled but not past threshold
- **前置条件**：用户已下拉但未超过阈值
- **WHEN**: user releases the pull
- **操作**：用户释放下拉
- **THEN**: the system SHALL cancel the refresh
- **预期结果**：系统应取消刷新
- **AND**: animate indicator back to hidden state
- **并且**：将指示器动画返回隐藏状态

---

## Requirement: Support swipe navigation gestures
## 需求：支持滑动导航手势

The system SHALL support platform-specific swipe navigation gestures.

系统应支持平台特定的滑动导航手势。

### Scenario: Swipe from left edge to go back (iOS)
### 场景：从左边缘滑动返回（iOS）

- **GIVEN**: user is on a detail screen on iOS
- **前置条件**：用户在 iOS 上的详情屏幕
- **WHEN**: user swipes from left edge
- **操作**：用户从左边缘滑动
- **THEN**: the system SHALL navigate back to previous screen
- **预期结果**：系统应导航回上一个屏幕
- **AND**: use iOS-style transition animation
- **并且**：使用 iOS 风格的过渡动画

### Scenario: Use system back gesture (Android)
### 场景：使用系统返回手势（Android）

- **GIVEN**: user is on a detail screen on Android
- **前置条件**：用户在 Android 上的详情屏幕
- **WHEN**: user performs system back gesture
- **操作**：用户执行系统返回手势
- **THEN**: the system SHALL navigate back to previous screen
- **预期结果**：系统应导航回上一个屏幕
- **AND**: use Android-style transition animation
- **并且**：使用 Android 风格的过渡动画

---

## Test Coverage
## 测试覆盖

**Test File**: `test/widgets/mobile_gestures_test.dart`
**测试文件**: `test/widgets/mobile_gestures_test.dart`

**Widget Tests**:
**组件测试**:
- `it_should_reveal_delete_on_swipe_left()` - Reveal delete button
- `it_should_reveal_delete_on_swipe_left()` - 显示删除按钮
- `it_should_hide_delete_on_swipe_right()` - Hide delete button
- `it_should_hide_delete_on_swipe_right()` - 隐藏删除按钮
- `it_should_delete_card_on_button_tap()` - Delete card
- `it_should_delete_card_on_button_tap()` - 删除卡片
- `it_should_show_context_menu_on_long_press()` - Show context menu
- `it_should_show_context_menu_on_long_press()` - 显示上下文菜单
- `it_should_position_menu_near_touch()` - Position menu correctly
- `it_should_position_menu_near_touch()` - 正确定位菜单
- `it_should_dismiss_menu_on_outside_tap()` - Dismiss menu
- `it_should_dismiss_menu_on_outside_tap()` - 关闭菜单
- `it_should_show_refresh_indicator_on_pull()` - Show refresh indicator
- `it_should_show_refresh_indicator_on_pull()` - 显示刷新指示器
- `it_should_trigger_refresh_on_release()` - Trigger refresh
- `it_should_trigger_refresh_on_release()` - 触发刷新
- `it_should_cancel_refresh_before_threshold()` - Cancel refresh
- `it_should_cancel_refresh_before_threshold()` - 取消刷新
- `it_should_navigate_back_on_swipe()` - Navigate back
- `it_should_navigate_back_on_swipe()` - 导航返回

**Acceptance Criteria**:
**验收标准**:
- [ ] All widget tests pass
- [ ] 所有组件测试通过
- [ ] Swipe gestures are smooth and responsive
- [ ] 滑动手势流畅且响应灵敏
- [ ] Long-press provides haptic feedback
- [ ] 长按提供触觉反馈
- [ ] Pull-to-refresh works reliably
- [ ] 下拉刷新可靠工作
- [ ] Platform-specific gestures work correctly
- [ ] 平台特定手势正确工作
- [ ] Code review approved
- [ ] 代码审查通过
- [ ] Documentation updated
- [ ] 文档已更新

---

## Related Documents
## 相关文档

**Related Specs**:
**相关规格**:
- [card_list_item.md](./card_list_item.md) - Mobile card list item
- [card_list_item.md](./card_list_item.md) - 移动端卡片列表项
- [home_screen.md](../../screens/mobile/home_screen.md) - Mobile home screen
- [home_screen.md](../../screens/mobile/home_screen.md) - 移动端主屏幕

---

**Last Updated**: 2026-01-24
**最后更新**: 2026-01-24

**Authors**: CardMind Team
**作者**: CardMind Team
