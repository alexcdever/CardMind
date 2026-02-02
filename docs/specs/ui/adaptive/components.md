# Adaptive Components Specification
# 自适应组件规格

**版本**: 1.0.0

**状态**: 活跃

**依赖**: [layouts.md](layouts.md), [platform_detection.md](platform_detection.md)

**相关测试**: `test/adaptive/components_test.dart`

---

## 概述


本规格定义了自适应 UI 组件，根据平台和屏幕尺寸自动调整其外观和行为。

---

## 需求：自适应按钮


系统应提供根据平台调整大小和样式的按钮。

### 场景：移动端触摸友好按钮

- **前置条件**：应用程序在移动端运行
- **操作**：显示按钮
- **预期结果**：按钮应具有至少 48dp 的高度以适应触摸目标
- **并且**：使用更大的填充以便于点击

### 场景：桌面端紧凑按钮

- **前置条件**：应用程序在桌面端运行
- **操作**：显示按钮
- **预期结果**：按钮应使用标准高度 36dp
- **并且**：使用针对鼠标交互优化的紧凑填充
- **并且**：显示悬停状态

---

## 需求：自适应 FAB（浮动操作按钮）


系统应提供根据布局模式调整位置和行为的 FAB。

### 场景：移动端右下角 FAB

- **前置条件**：应用程序处于移动布局模式
- **操作**：显示 FAB
- **预期结果**：FAB 应定位在右下角
- **并且**：浮动在底部导航栏上方
- **并且**：使用大尺寸（56dp 直径）

### 场景：桌面端工具栏集成 FAB

- **前置条件**：应用程序处于桌面布局模式
- **操作**：显示 FAB
- **预期结果**：FAB 应作为常规按钮集成到工具栏中
- **并且**：使用标准按钮样式
- **并且**：在图标旁边包含文本标签

### 场景：平板电脑带扩展标签的 FAB

- **前置条件**：应用程序处于平板布局模式
- **操作**：显示 FAB
- **预期结果**：FAB 应定位在右下角
- **并且**：可选地在悬停时或默认显示扩展标签
- **并且**：使用中等尺寸（48dp 直径）

---

## 需求：自适应列表项


系统应提供根据平台调整布局和交互的列表项。

### 场景：移动端带滑动操作的列表项

- **前置条件**：应用程序在移动端运行
- **操作**：显示卡片列表项
- **预期结果**：列表项应支持滑动手势
- **并且**：滑动时显示操作按钮（删除、归档）
- **并且**：使用单行或双行布局以实现紧凑显示

### 场景：桌面端带悬停操作的列表项

- **前置条件**：应用程序在桌面端运行
- **操作**：显示卡片列表项
- **预期结果**：列表项应在悬停时显示操作按钮
- **并且**：支持右键上下文菜单
- **并且**：使用带有更多间距的多行布局

### 场景：平板电脑混合交互列表项

- **前置条件**：应用程序在平板电脑上运行
- **操作**：显示卡片列表项
- **预期结果**：列表项应同时支持滑动和长按手势
- **并且**：长按时显示操作按钮
- **并且**：在项目之间使用舒适的间距

---

## 需求：自适应对话框


系统应提供根据屏幕尺寸调整大小和位置的对话框。

### 场景：移动端全屏对话框

- **前置条件**：应用程序在移动端运行
- **操作**：显示对话框
- **预期结果**：对话框应占据全屏
- **并且**：在应用栏中包含关闭按钮
- **并且**：从底部滑入并带有动画

### 场景：桌面端居中对话框

- **前置条件**：应用程序在桌面端运行
- **操作**：显示对话框
- **预期结果**：对话框应在屏幕上居中
- **并且**：最大宽度为 600dp
- **并且**：显示背景遮罩
- **并且**：淡入并带有动画

### 场景：平板电脑自适应对话框

- **前置条件**：应用程序在平板电脑上运行
- **操作**：显示对话框
- **预期结果**：对话框应居中并具有舒适的宽度（480-600dp）
- **并且**：显示背景遮罩
- **并且**：同时支持触摸和指针交互

---

## 需求：自适应文本字段


系统应提供根据输入方法调整行为的文本字段。

### 场景：移动端带虚拟键盘的文本字段

- **前置条件**：应用程序在移动端运行
- **操作**：用户聚焦文本字段
- **预期结果**：虚拟键盘应出现
- **并且**：视图应滚动以保持字段在键盘上方可见
- **并且**：使用更大的触摸目标进行光标定位

### 场景：桌面端带键盘快捷键的文本字段

- **前置条件**：应用程序在桌面端运行
- **操作**：用户聚焦文本字段
- **预期结果**：字段应支持标准键盘快捷键（Ctrl+A、Ctrl+C、Ctrl+V）
- **并且**：鼠标悬停时显示悬停状态
- **并且**：使用鼠标进行精确光标定位

---

## 需求：自适应菜单


系统应提供根据平台调整呈现方式的菜单。

### 场景：移动端底部表单菜单

- **前置条件**：应用程序在移动端运行
- **操作**：显示菜单
- **预期结果**：菜单应显示为底部表单
- **并且**：从底部滑上并带有动画
- **并且**：为菜单项使用大触摸目标

### 场景：桌面端下拉菜单

- **前置条件**：应用程序在桌面端运行
- **操作**：显示菜单
- **预期结果**：菜单应显示为触发器附近的下拉菜单
- **并且**：为菜单项显示键盘快捷键
- **并且**：支持悬停高亮

---

## 测试覆盖

**测试文件**: `test/adaptive/components_test.dart`

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

## 相关文档

**相关规格**:
- [layouts.md](layouts.md) - Adaptive layout system
- [layouts.md](layouts.md) - 自适应布局系统
- [platform_detection.md](platform_detection.md) - Platform detection
- [platform_detection.md](platform_detection.md) - 平台检测
- [../components/mobile/gestures.md](../components/mobile/gestures.md) - Mobile gestures
- [../components/mobile/gestures.md](../components/mobile/gestures.md) - 移动端手势

---

**最后更新**: 2026-01-24

**作者**: CardMind Team
