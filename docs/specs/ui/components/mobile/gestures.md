# Mobile Gestures Specification
# 移动端手势规格

**版本**: 1.0.0

**状态**: 生效中

**依赖**: 无

**相关测试**: `test/widgets/mobile_gestures_test.dart`

---

## 概述


本规格定义了基于触摸设备的移动端手势交互。移动端手势提供直观的方式来执行快速操作，如删除卡片、访问上下文菜单和刷新内容。

**适用平台**:
- Android
- iOS
- iPadOS

---

## 需求：支持滑动手势进行快速操作


系统应在卡片列表项上支持滑动手势进行快速操作。

### 场景：左滑显示删除按钮

- **前置条件**：用户在移动端查看卡片列表
- **操作**：用户在卡片上左滑
- **预期结果**：系统应显示红色删除按钮
- **并且**：卡片应平滑地带动画左滑
- **并且**：删除按钮应触摸友好（最小 48dp 高度）

### 场景：右滑关闭已显示的操作

- **前置条件**：卡片上的删除按钮已显示
- **操作**：用户在卡片上右滑
- **预期结果**：系统应隐藏删除按钮
- **并且**：卡片应滑回原始位置
- **并且**：使用流畅动画

### 场景：点击删除按钮移除卡片

- **前置条件**：删除按钮已显示
- **操作**：用户点击删除按钮
- **预期结果**：系统应将卡片标记为已删除
- **并且**：将卡片从列表中动画移出
- **并且**：显示带有"已删除"消息的提示条
- **并且**：在提示条中提供撤销选项

---

## 需求：支持长按手势打开上下文菜单


系统应在移动端支持长按手势打开上下文菜单。

### 场景：长按显示上下文菜单

- **前置条件**：用户在移动端查看卡片列表
- **操作**：用户长按卡片
- **预期结果**：系统应显示上下文菜单
- **并且**：提供触觉反馈
- **并且**：包含选项："编辑"、"删除"、"分享"、"复制"

### 场景：上下文菜单定位在触摸点附近

- **前置条件**：上下文菜单已显示
- **操作**：查看菜单
- **预期结果**：系统应将菜单定位在触摸点附近
- **并且**：确保菜单不超出屏幕
- **并且**：如有必要调整位置以保持在边界内

### 场景：点击外部关闭上下文菜单

- **前置条件**：上下文菜单已显示
- **操作**：用户点击菜单外部
- **预期结果**：系统应关闭菜单
- **并且**：不应执行任何操作
- **并且**：使用淡出动画

---

## 需求：支持下拉刷新手势


系统应在可滚动列表上支持下拉刷新手势。

### 场景：下拉显示刷新指示器

- **前置条件**：用户在卡片列表顶部
- **操作**：用户在列表上下拉
- **预期结果**：系统应显示刷新指示器
- **并且**：指示器应跟随下拉距离
- **并且**：使用平台适当的指示器样式

### 场景：释放超过阈值触发刷新

- **前置条件**：用户已下拉超过刷新阈值
- **操作**：用户释放下拉
- **预期结果**：系统应触发卡片列表刷新
- **并且**：显示加载指示器
- **并且**：从存储重新加载卡片
- **并且**：完成时隐藏指示器

### 场景：在阈值前释放取消刷新

- **前置条件**：用户已下拉但未超过阈值
- **操作**：用户释放下拉
- **预期结果**：系统应取消刷新
- **并且**：将指示器动画返回隐藏状态

---

## 需求：支持滑动导航手势


系统应支持平台特定的滑动导航手势。

### 场景：从左边缘滑动返回（iOS）

- **前置条件**：用户在 iOS 上的详情屏幕
- **操作**：用户从左边缘滑动
- **预期结果**：系统应导航回上一个屏幕
- **并且**：使用 iOS 风格的过渡动画

### 场景：使用系统返回手势（Android）

- **前置条件**：用户在 Android 上的详情屏幕
- **操作**：用户执行系统返回手势
- **预期结果**：系统应导航回上一个屏幕
- **并且**：使用 Android 风格的过渡动画

---

## 测试覆盖

**测试文件**: `test/widgets/mobile_gestures_test.dart`

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

## 相关文档

**相关规格**:
- [card_list_item.md](./card_list_item.md) - Mobile card list item
- [card_list_item.md](./card_list_item.md) - 移动端卡片列表项
- [home_screen.md](../../screens/mobile/home_screen.md) - Mobile home screen
- [home_screen.md](../../screens/mobile/home_screen.md) - 移动端主屏幕

---

**最后更新**: 2026-01-24

**作者**: CardMind Team
