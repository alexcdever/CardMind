# Desktop Toolbar Specification
# 桌面端工具栏规格

**Version**: 1.0.0
**版本**: 1.0.0

**Status**: Active
**状态**: 生效中

**Dependencies**: None
**依赖**: 无

**Related Tests**: `test/widgets/desktop_toolbar_test.dart`
**相关测试**: `test/widgets/desktop_toolbar_test.dart`

---

## Overview
## 概述

This specification defines the desktop toolbar component that provides quick access to primary actions and search functionality. The toolbar follows desktop application conventions with a horizontal layout at the top of the window.

本规格定义了桌面端工具栏组件,提供对主要操作和搜索功能的快速访问。工具栏遵循桌面应用约定,在窗口顶部采用水平布局。

**Applicable Platforms**:
**适用平台**:
- macOS
- Windows
- Linux

---

## Requirement: Display toolbar at top of window
## 需求:在窗口顶部显示工具栏

The system SHALL display a toolbar at the top of the desktop window with primary actions and search.

系统应在桌面窗口顶部显示工具栏,包含主要操作和搜索功能。

### Scenario: Toolbar positioned at top
### 场景:工具栏定位在顶部

- **GIVEN**: user is on desktop home screen
- **前置条件**:用户在桌面端主屏幕上
- **WHEN**: viewing window
- **操作**:查看窗口
- **THEN**: the system SHALL display toolbar at top
- **预期结果**:系统应在顶部显示工具栏
- **AND**: toolbar SHALL span full window width
- **并且**:工具栏应占满窗口宽度
- **AND**: toolbar SHALL have 64px height
- **并且**:工具栏应有 64px 高度

### Scenario: App title displayed on left
### 场景:应用标题显示在左侧

- **GIVEN**: toolbar is displayed
- **前置条件**:工具栏已显示
- **WHEN**: viewing toolbar
- **操作**:查看工具栏
- **THEN**: the system SHALL show "CardMind" title on left side
- **预期结果**:系统应在左侧显示"CardMind"标题
- **AND**: title SHALL use 24px font size
- **并且**:标题应使用 24px 字号
- **AND**: title SHALL be bold
- **并且**:标题应加粗

### Scenario: Action buttons positioned on right
### 场景:操作按钮定位在右侧

- **GIVEN**: toolbar is displayed
- **前置条件**:工具栏已显示
- **WHEN**: viewing toolbar
- **操作**:查看工具栏
- **THEN**: the system SHALL position action buttons on right side
- **预期结果**:系统应将操作按钮定位在右侧
- **AND**: buttons SHALL be horizontally aligned
- **并且**:按钮应水平对齐
- **AND**: use 8px spacing between buttons
- **并且**:按钮之间使用 8px 间距

---

## Requirement: Provide New Card button
## 需求:提供新建笔记按钮

The system SHALL provide a New Card button in the toolbar for creating new cards.

系统应在工具栏中提供新建笔记按钮以创建新卡片。

### Scenario: New Card button visible
### 场景:新建笔记按钮可见

- **GIVEN**: user is on desktop home screen
- **前置条件**:用户在桌面端主屏幕上
- **WHEN**: viewing toolbar
- **操作**:查看工具栏
- **THEN**: the system SHALL display "新建笔记" button
- **预期结果**:系统应显示"新建笔记"按钮
- **AND**: button SHALL show "+" icon
- **并且**:按钮应显示"+"图标
- **AND**: button SHALL show text label
- **并且**:按钮应显示文本标签

### Scenario: Button shows hover effect
### 场景:按钮显示悬停效果

- **GIVEN**: user hovers over New Card button
- **前置条件**:用户悬停在新建笔记按钮上
- **WHEN**: mouse enters button area
- **操作**:鼠标进入按钮区域
- **THEN**: the system SHALL change background color
- **预期结果**:系统应改变背景颜色
- **AND**: change cursor to pointer
- **并且**:将光标改为指针
- **AND**: use smooth transition animation
- **并且**:使用流畅的过渡动画

### Scenario: Button shows tooltip with shortcut
### 场景:按钮显示带快捷键的工具提示

- **GIVEN**: user hovers over New Card button
- **前置条件**:用户悬停在新建笔记按钮上
- **WHEN**: mouse stays for 500ms
- **操作**:鼠标停留 500ms
- **THEN**: the system SHALL show tooltip "新建笔记 (Cmd/Ctrl+N)"
- **预期结果**:系统应显示工具提示"新建笔记 (Cmd/Ctrl+N)"
- **AND**: position tooltip below button
- **并且**:将工具提示定位在按钮下方

---

## Requirement: Provide search field
## 需求:提供搜索字段

The system SHALL provide a search field in the toolbar for searching cards.

系统应在工具栏中提供搜索字段以搜索卡片。

### Scenario: Search field visible in toolbar
### 场景:搜索字段在工具栏中可见

- **GIVEN**: user is on desktop home screen
- **前置条件**:用户在桌面端主屏幕上
- **WHEN**: viewing toolbar
- **操作**:查看工具栏
- **THEN**: the system SHALL display search field
- **预期结果**:系统应显示搜索字段
- **AND**: position field in center-right area
- **并且**:将字段定位在中右区域
- **AND**: field SHALL have 300px width
- **并且**:字段应有 300px 宽度

### Scenario: Search field shows placeholder
### 场景:搜索字段显示占位符

- **GIVEN**: search field is empty
- **前置条件**:搜索字段为空
- **WHEN**: viewing field
- **操作**:查看字段
- **THEN**: the system SHALL show placeholder "搜索笔记标题、内容或标签..."
- **预期结果**:系统应显示占位符"搜索笔记标题、内容或标签..."
- **AND**: use gray color for placeholder
- **并且**:占位符使用灰色

### Scenario: Search field shows search icon
### 场景:搜索字段显示搜索图标

- **GIVEN**: search field is displayed
- **前置条件**:搜索字段已显示
- **WHEN**: viewing field
- **操作**:查看字段
- **THEN**: the system SHALL show search icon on left side
- **预期结果**:系统应在左侧显示搜索图标
- **AND**: icon SHALL be gray color
- **并且**:图标应为灰色
- **AND**: icon SHALL be 20x20 pixels
- **并且**:图标应为 20x20 像素

---

## Requirement: Support keyboard shortcuts
## 需求:支持键盘快捷键

The system SHALL support keyboard shortcuts for toolbar actions.

系统应支持工具栏操作的键盘快捷键。

### Scenario: Cmd/Ctrl+N creates new card
### 场景:Cmd/Ctrl+N 创建新卡片

- **GIVEN**: user is on desktop home screen
- **前置条件**:用户在桌面端主屏幕上
- **WHEN**: user presses Cmd/Ctrl+N
- **操作**:用户按下 Cmd/Ctrl+N
- **THEN**: the system SHALL create new card
- **预期结果**:系统应创建新卡片
- **AND**: enter edit mode for the card
- **并且**:进入卡片的编辑模式

### Scenario: Cmd/Ctrl+F focuses search field
### 场景:Cmd/Ctrl+F 聚焦搜索字段

- **GIVEN**: user is on desktop home screen
- **前置条件**:用户在桌面端主屏幕上
- **WHEN**: user presses Cmd/Ctrl+F
- **操作**:用户按下 Cmd/Ctrl+F
- **THEN**: the system SHALL focus search field
- **预期结果**:系统应聚焦搜索字段
- **AND**: select existing text if any
- **并且**:如果有现有文本则选中

---

## Test Coverage
## 测试覆盖

**Test File**: `test/widgets/desktop_toolbar_test.dart`
**测试文件**: `test/widgets/desktop_toolbar_test.dart`

**Widget Tests**:
**组件测试**:
- `it_should_position_at_top()` - Position at top
- `it_should_position_at_top()` - 定位在顶部
- `it_should_show_app_title()` - Show app title
- `it_should_show_app_title()` - 显示应用标题
- `it_should_show_new_card_button()` - Show new card button
- `it_should_show_new_card_button()` - 显示新建笔记按钮
- `it_should_show_hover_effect()` - Show hover effect
- `it_should_show_hover_effect()` - 显示悬停效果
- `it_should_show_tooltip()` - Show tooltip
- `it_should_show_tooltip()` - 显示工具提示
- `it_should_show_search_field()` - Show search field
- `it_should_show_search_field()` - 显示搜索字段
- `it_should_show_search_placeholder()` - Show search placeholder
- `it_should_show_search_placeholder()` - 显示搜索占位符
- `it_should_show_search_icon()` - Show search icon
- `it_should_show_search_icon()` - 显示搜索图标
- `it_should_handle_cmd_n_shortcut()` - Handle Cmd/Ctrl+N
- `it_should_handle_cmd_n_shortcut()` - 处理 Cmd/Ctrl+N
- `it_should_handle_cmd_f_shortcut()` - Handle Cmd/Ctrl+F
- `it_should_handle_cmd_f_shortcut()` - 处理 Cmd/Ctrl+F

**Acceptance Criteria**:
**验收标准**:
- [ ] All widget tests pass
- [ ] 所有组件测试通过
- [ ] Toolbar layout is consistent across platforms
- [ ] 工具栏布局在各平台上一致
- [ ] Keyboard shortcuts work correctly
- [ ] 键盘快捷键正常工作
- [ ] Hover effects are smooth
- [ ] 悬停效果流畅
- [ ] Code review approved
- [ ] 代码审查通过
- [ ] Documentation updated
- [ ] 文档已更新

---

## Related Documents
## 相关文档

**Related Specs**:
**相关规格**:
- [home_screen.md](../../screens/desktop/home_screen.md) - Desktop home screen
- [home_screen.md](../../screens/desktop/home_screen.md) - 桌面端主屏幕
- [card_editor_screen.md](../../screens/desktop/card_editor_screen.md) - Desktop card editor
- [card_editor_screen.md](../../screens/desktop/card_editor_screen.md) - 桌面端卡片编辑器

---

**Last Updated**: 2026-01-24
**最后更新**: 2026-01-24

**Authors**: CardMind Team
**作者**: CardMind Team
