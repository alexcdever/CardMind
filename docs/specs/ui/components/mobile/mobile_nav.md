# Mobile Navigation Bar Specification
# 移动端导航栏规格

**版本**: 1.0.0

**状态**: 生效中

**依赖**: 无

**相关测试**: `test/widgets/mobile_nav_test.dart`

---

## 概述


本规格定义了移动端底部导航栏组件，提供对应用三个主要部分的访问：笔记、设备和设置。导航栏遵循平台约定，并为激活部分提供清晰的视觉反馈。

**适用平台**:
- Android
- iOS
- iPadOS

---

## 需求：显示带有三个标签页的底部导航


系统应提供带有三个主要部分的底部导航栏。

### 场景：显示三个导航标签页

- **前置条件**：用户在移动端应用上
- **操作**：查看任何主屏幕
- **预期结果**：系统应显示三个标签页：笔记、设备和设置
- **并且**：将它们均匀分布在底部栏上
- **并且**：在标签页之间使用一致的间距

### 场景：高亮激活的标签页

- **前置条件**：用户在特定部分
- **操作**：查看导航栏
- **预期结果**：系统应对当前标签页应用激活状态样式
- **并且**：为激活标签页使用不同颜色
- **并且**：为激活标签页使用填充图标
- **并且**：为非激活标签页使用轮廓图标

---

## 需求：在标签页上显示徽章计数


系统应为相关标签页显示徽章计数，以便一目了然地显示重要信息。

### 场景：在笔记标签页上显示笔记数量

- **前置条件**：用户在系统中有卡片
- **操作**：显示笔记标签页
- **预期结果**：系统应显示带有笔记总数的徽章
- **并且**：将徽章定位在标签页图标的右上角

### 场景：在设备标签页上显示设备数量

- **前置条件**：用户有配对设备
- **操作**：显示设备标签页
- **预期结果**：系统应显示带有配对设备数量的徽章
- **并且**：将徽章定位在标签页图标的右上角

### 场景：计数为零时隐藏徽章

- **前置条件**：标签页的计数为零
- **操作**：显示标签页
- **预期结果**：系统应隐藏该标签页的徽章

---

## 需求：处理标签页选择


系统应响应用户的标签页选择并导航到相应部分。

### 场景：切换到不同的标签页

- **前置条件**：用户点击非激活标签页
- **操作**：点击发生
- **预期结果**：系统应导航到选定部分
- **并且**：更新激活标签页的视觉状态
- **并且**：提供触觉反馈
- **并且**：使用流畅的过渡动画

### 场景：点击已激活的标签页

- **前置条件**：用户点击当前激活的标签页
- **操作**：点击发生
- **预期结果**：系统应将当前视图滚动到顶部
- **并且**：提供触觉反馈

---

## 需求：为标签页使用语义化图标


系统应为每个导航标签页显示清晰的语义化图标。

### 场景：显示适当的标签页图标

- **前置条件**：导航栏已渲染
- **操作**：查看标签页
- **预期结果**：系统应为笔记标签页显示笔记图标
- **并且**：为设备标签页显示设备图标
- **并且**：为设置标签页显示设置图标
- **并且**：图标应为 24x24 逻辑像素

### 场景：图标状态转换

- **前置条件**：用户在标签页之间切换
- **操作**：标签页变为激活状态
- **预期结果**：系统应为激活标签页使用填充图标
- **并且**：为非激活标签页使用轮廓图标
- **并且**：平滑地动画图标过渡

---

## 需求：遵守设备安全区域


系统应遵守设备安全区域，以避免干扰系统手势或刘海。

### 场景：在 iOS 上应用安全区域内边距

- **前置条件**：应用在带有主页指示器的 iOS 设备上运行
- **操作**：渲染导航栏
- **预期结果**：系统应添加适当的底部内边距
- **并且**：确保标签页在主页指示器上方
- **并且**：保持触摸目标

### 场景：在 Android 上应用安全区域内边距

- **前置条件**：应用在带有手势导航的 Android 设备上运行
- **操作**：渲染导航栏
- **预期结果**：系统应添加适当的底部内边距
- **并且**：确保标签页在手势区域上方

---

## 需求：提供可访问性支持


系统应使导航栏对所有用户可访问，包括使用辅助技术的用户。

### 场景：标签页有语义标签

- **前置条件**：屏幕阅读器已启用
- **操作**：标签页获得焦点
- **预期结果**：系统应朗读标签页名称
- **并且**：如果存在则朗读徽章计数
- **并且**：朗读激活状态

### 场景：标签页有最小触摸目标

- **前置条件**：导航栏已显示
- **操作**：测量触摸目标
- **预期结果**：系统应为每个标签页提供至少 48x48 逻辑像素的触摸目标

---

## 测试覆盖

**测试文件**: `test/widgets/mobile_nav_test.dart`

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

## 相关文档

**相关规格**:
- [home_screen.md](../../screens/mobile/home_screen.md) - Mobile home screen
- [home_screen.md](../../screens/mobile/home_screen.md) - 移动端主屏幕
- [sync_screen.md](../../screens/mobile/sync_screen.md) - Mobile sync screen
- [sync_screen.md](../../screens/mobile/sync_screen.md) - 移动端同步屏幕
- [settings_screen.md](../../screens/mobile/settings_screen.md) - Mobile settings screen
- [settings_screen.md](../../screens/mobile/settings_screen.md) - 移动端设置屏幕

---

**最后更新**: 2026-01-24

**作者**: CardMind Team
