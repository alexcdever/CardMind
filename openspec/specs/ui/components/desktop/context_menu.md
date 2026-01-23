# Desktop Context Menu Specification
# 桌面端右键菜单规格

**Version**: 1.0.0
**版本**: 1.0.0

**Status**: Active
**状态**: 生效中

**Dependencies**: None
**依赖**: 无

**Related Tests**: `test/widgets/desktop_context_menu_test.dart`
**相关测试**: `test/widgets/desktop_context_menu_test.dart`

---

## Overview
## 概述

This specification defines the desktop right-click context menu component that provides quick access to common card actions. The context menu follows desktop application conventions and appears near the mouse cursor.

本规格定义了桌面端右键菜单组件,提供对常见卡片操作的快速访问。右键菜单遵循桌面应用约定,在鼠标光标附近出现。

**Applicable Platforms**:
**适用平台**:
- macOS
- Windows
- Linux

---

## Requirement: Support right-click to show context menu
## 需求:支持右键点击显示上下文菜单

The system SHALL display a context menu when user right-clicks on a card.

系统应在用户右键点击卡片时显示上下文菜单。

### Scenario: Right-click shows context menu
### 场景:右键点击显示上下文菜单

- **GIVEN**: user is viewing card list on desktop
- **前置条件**:用户在桌面端查看卡片列表
- **WHEN**: user right-clicks on a card
- **操作**:用户右键点击卡片
- **THEN**: the system SHALL display context menu
- **预期结果**:系统应显示上下文菜单
- **AND**: position menu near mouse cursor
- **并且**:将菜单定位在鼠标光标附近
- **AND**: ensure menu does not extend off screen
- **并且**:确保菜单不超出屏幕

### Scenario: Menu appears quickly
### 场景:菜单快速出现

- **GIVEN**: user right-clicks on a card
- **前置条件**:用户右键点击卡片
- **WHEN**: right-click occurs
- **操作**:右键点击发生
- **THEN**: the system SHALL show menu within 100ms
- **预期结果**:系统应在 100ms 内显示菜单
- **AND**: use smooth fade-in animation
- **并且**:使用流畅的淡入动画

---

## Requirement: Display card action options
## 需求:显示卡片操作选项

The system SHALL display relevant action options in the context menu.

系统应在上下文菜单中显示相关的操作选项。

### Scenario: Menu includes Edit option
### 场景:菜单包含编辑选项

- **GIVEN**: context menu is displayed
- **前置条件**:上下文菜单已显示
- **WHEN**: viewing menu
- **操作**:查看菜单
- **THEN**: the system SHALL show "编辑" option first
- **预期结果**:系统应首先显示"编辑"选项
- **AND**: show edit icon next to option
- **并且**:在选项旁显示编辑图标
- **AND**: show keyboard shortcut hint
- **并且**:显示键盘快捷键提示

### Scenario: Menu includes Delete option
### 场景:菜单包含删除选项

- **GIVEN**: context menu is displayed
- **前置条件**:上下文菜单已显示
- **WHEN**: viewing menu
- **操作**:查看菜单
- **THEN**: the system SHALL show "删除" option
- **预期结果**:系统应显示"删除"选项
- **AND**: show delete icon next to option
- **并且**:在选项旁显示删除图标
- **AND**: use red color for delete option
- **并且**:删除选项使用红色

### Scenario: Menu includes Copy option
### 场景:菜单包含复制选项

- **GIVEN**: context menu is displayed
- **前置条件**:上下文菜单已显示
- **WHEN**: viewing menu
- **操作**:查看菜单
- **THEN**: the system SHALL show "复制" option
- **预期结果**:系统应显示"复制"选项
- **AND**: show copy icon next to option
- **并且**:在选项旁显示复制图标

### Scenario: Menu includes Share option
### 场景:菜单包含分享选项

- **GIVEN**: context menu is displayed
- **前置条件**:上下文菜单已显示
- **WHEN**: viewing menu
- **操作**:查看菜单
- **THEN**: the system SHALL show "分享" option
- **预期结果**:系统应显示"分享"选项
- **AND**: show share icon next to option
- **并且**:在选项旁显示分享图标

---

## Requirement: Handle menu option selection
## 需求:处理菜单选项选择

The system SHALL execute the appropriate action when user selects a menu option.

系统应在用户选择菜单选项时执行相应的操作。

### Scenario: Clicking Edit enters edit mode
### 场景:点击编辑进入编辑模式

- **GIVEN**: context menu is displayed
- **前置条件**:上下文菜单已显示
- **WHEN**: user clicks "编辑" option
- **操作**:用户点击"编辑"选项
- **THEN**: the system SHALL close menu
- **预期结果**:系统应关闭菜单
- **AND**: enter edit mode for the card
- **并且**:进入卡片的编辑模式
- **AND**: focus title field
- **并且**:聚焦标题字段

### Scenario: Clicking Delete shows confirmation
### 场景:点击删除显示确认

- **GIVEN**: context menu is displayed
- **前置条件**:上下文菜单已显示
- **WHEN**: user clicks "删除" option
- **操作**:用户点击"删除"选项
- **THEN**: the system SHALL close menu
- **预期结果**:系统应关闭菜单
- **AND**: show confirmation dialog
- **并且**:显示确认对话框
- **AND**: dialog SHALL ask "确定删除这张笔记?"
- **并且**:对话框应询问"确定删除这张笔记?"

### Scenario: Clicking outside dismisses menu
### 场景:点击外部关闭菜单

- **GIVEN**: context menu is displayed
- **前置条件**:上下文菜单已显示
- **WHEN**: user clicks outside menu area
- **操作**:用户点击菜单区域外部
- **THEN**: the system SHALL close menu
- **预期结果**:系统应关闭菜单
- **AND**: no action SHALL be performed
- **并且**:不应执行任何操作

---

## Requirement: Apply platform-appropriate styling
## 需求:应用平台适当的样式

The system SHALL style the context menu according to platform conventions.

系统应根据平台约定为上下文菜单设置样式。

### Scenario: Menu has proper visual styling
### 场景:菜单有适当的视觉样式

- **GIVEN**: context menu is displayed
- **前置条件**:上下文菜单已显示
- **WHEN**: viewing menu
- **操作**:查看菜单
- **THEN**: the system SHALL use white background
- **预期结果**:系统应使用白色背景
- **AND**: apply subtle shadow
- **并且**:应用微妙的阴影
- **AND**: use rounded corners
- **并且**:使用圆角

### Scenario: Menu items show hover effect
### 场景:菜单项显示悬停效果

- **GIVEN**: context menu is displayed
- **前置条件**:上下文菜单已显示
- **WHEN**: user hovers over menu item
- **操作**:用户悬停在菜单项上
- **THEN**: the system SHALL highlight the item
- **预期结果**:系统应高亮该项
- **AND**: change background color
- **并且**:改变背景颜色
- **AND**: change cursor to pointer
- **并且**:将光标改为指针

---

## Test Coverage
## 测试覆盖

**Test File**: `test/widgets/desktop_context_menu_test.dart`
**测试文件**: `test/widgets/desktop_context_menu_test.dart`

**Widget Tests**:
**组件测试**:
- `it_should_show_on_right_click()` - Show on right-click
- `it_should_show_on_right_click()` - 右键点击时显示
- `it_should_position_near_cursor()` - Position near cursor
- `it_should_position_near_cursor()` - 定位在光标附近
- `it_should_appear_quickly()` - Appear quickly
- `it_should_appear_quickly()` - 快速出现
- `it_should_show_edit_option()` - Show edit option
- `it_should_show_edit_option()` - 显示编辑选项
- `it_should_show_delete_option()` - Show delete option
- `it_should_show_delete_option()` - 显示删除选项
- `it_should_show_copy_option()` - Show copy option
- `it_should_show_copy_option()` - 显示复制选项
- `it_should_show_share_option()` - Show share option
- `it_should_show_share_option()` - 显示分享选项
- `it_should_enter_edit_mode()` - Enter edit mode
- `it_should_enter_edit_mode()` - 进入编辑模式
- `it_should_show_delete_confirmation()` - Show delete confirmation
- `it_should_show_delete_confirmation()` - 显示删除确认
- `it_should_dismiss_on_outside_click()` - Dismiss on outside click
- `it_should_dismiss_on_outside_click()` - 点击外部时关闭
- `it_should_have_proper_styling()` - Have proper styling
- `it_should_have_proper_styling()` - 有适当的样式
- `it_should_show_hover_effect()` - Show hover effect
- `it_should_show_hover_effect()` - 显示悬停效果

**Acceptance Criteria**:
**验收标准**:
- [ ] All widget tests pass
- [ ] 所有组件测试通过
- [ ] Menu appears quickly and smoothly
- [ ] 菜单快速且流畅地出现
- [ ] All actions work correctly
- [ ] 所有操作正常工作
- [ ] Styling matches platform conventions
- [ ] 样式符合平台约定
- [ ] Code review approved
- [ ] 代码审查通过
- [ ] Documentation updated
- [ ] 文档已更新

---

## Related Documents
## 相关文档

**Related Specs**:
**相关规格**:
- [card_list_item.md](./card_list_item.md) - Desktop card list item
- [card_list_item.md](./card_list_item.md) - 桌面端卡片列表项
- [home_screen.md](../../screens/desktop/home_screen.md) - Desktop home screen
- [home_screen.md](../../screens/desktop/home_screen.md) - 桌面端主屏幕

---

**Last Updated**: 2026-01-24
**最后更新**: 2026-01-24

**Authors**: CardMind Team
**作者**: CardMind Team
