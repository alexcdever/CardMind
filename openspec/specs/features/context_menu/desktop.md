# Desktop Context Menu Specification | 桌面端右键菜单规格

**Version** | **版本**: 1.0.0
**Status** | **状态**: Active | 已完成
**Dependencies** | **依赖**: [adaptive_ui_components.md](../../ui_system/adaptive_ui_components.md)

---

## 1. Overview | 概述

### 1.1 Goals | 目标

Define desktop right-click context menu specifications to ensure:

定义桌面端右键菜单规范，确保：

- Aligned with desktop application conventions | 符合桌面应用习惯
- Provide quick access to common actions | 提供快速操作入口
- Clear menu hierarchy | 清晰的菜单层次

### 1.2 Applicable Platforms | 适用平台

- macOS
- Windows
- Linux

---

## 2. Menu Trigger | 菜单触发

### Requirement: Desktop SHALL support right-click menu | 需求：桌面端应支持右键菜单

Desktop SHALL support right-click context menu.

桌面端应支持右键菜单。

#### Scenario: Right-clicking card shows menu | 场景：右键点击卡片显示菜单

- **GIVEN** user views card grid
- **前置条件**：用户查看卡片网格
- **WHEN** user right-clicks on card
- **操作**：用户右键点击卡片
- **THEN** context menu SHALL appear
- **预期结果**：右键菜单应出现
- **AND** menu SHALL be near mouse cursor
- **并且**：菜单应靠近鼠标光标
- **AND** menu SHALL not extend off screen
- **并且**：菜单不应超出屏幕

#### Scenario: Menu appears within 100ms | 场景：菜单在 100ms 内出现

- **GIVEN** user right-clicks card
- **前置条件**：用户右键点击卡片
- **WHEN** right-click occurs
- **操作**：右键点击发生
- **THEN** menu SHALL appear within 100ms
- **预期结果**：菜单应在 100ms 内出现
- **AND** appearance SHALL be smooth
- **并且**：出现应平滑

---

## 3. Menu Content | 菜单内容

### Requirement: Context menu SHALL show card actions | 需求：右键菜单应显示卡片操作

Context menu SHALL show card actions.

右键菜单应显示卡片操作。

#### Scenario: Menu includes Edit option | 场景：菜单包含编辑选项

- **GIVEN** context menu is shown
- **前置条件**：右键菜单已显示
- **WHEN** viewing menu
- **操作**：查看菜单
- **THEN** "编辑" option SHALL be first
- **预期结果**："编辑"选项应排在第一位
- **AND** option SHALL show edit icon
- **并且**：选项应显示编辑图标
- **AND** option SHALL show keyboard shortcut
- **并且**：选项应显示键盘快捷键

#### Scenario: Menu includes Delete option | 场景：菜单包含删除选项

- **GIVEN** context menu is shown
- **前置条件**：右键菜单已显示
- **WHEN** viewing menu
- **操作**：查看菜单
- **THEN** "删除" option SHALL be included
- **预期结果**："删除"选项应包含在内
- **AND** option SHALL show delete icon
- **并且**：选项应显示删除图标
- **AND** option SHALL be red
- **并且**：选项应为红色

#### Scenario: Menu includes Copy option | 场景：菜单包含复制选项

- **GIVEN** context menu is shown
- **前置条件**：右键菜单已显示
- **WHEN** viewing menu
- **操作**：查看菜单
- **THEN** "复制" option SHALL be included
- **预期结果**："复制"选项应包含在内
- **AND** option SHALL show copy icon
- **并且**：选项应显示复制图标

#### Scenario: Menu includes Share option | 场景：菜单包含分享选项

- **GIVEN** context menu is shown
- **前置条件**：右键菜单已显示
- **WHEN** viewing menu
- **操作**：查看菜单
- **THEN** "分享" option SHALL be included
- **预期结果**："分享"选项应包含在内
- **AND** option SHALL show share icon
- **并且**：选项应显示分享图标

---

## 4. Menu Interaction | 菜单交互

### Requirement: Menu options SHALL be clickable | 需求：菜单选项应可点击

Menu options SHALL be clickable.

菜单选项应可点击。

#### Scenario: Clicking Edit enters edit mode | 场景：点击编辑进入编辑模式

- **GIVEN** context menu is shown
- **前置条件**：右键菜单已显示
- **WHEN** user clicks "编辑"
- **操作**：用户点击"编辑"
- **THEN** menu SHALL close
- **预期结果**：菜单应关闭
- **AND** card SHALL enter edit mode
- **并且**：卡片应进入编辑模式
- **AND** title field SHALL have focus
- **并且**：标题字段应获得焦点

#### Scenario: Clicking Delete shows confirmation | 场景：点击删除显示确认

- **GIVEN** context menu is shown
- **前置条件**：右键菜单已显示
- **WHEN** user clicks "删除"
- **操作**：用户点击"删除"
- **THEN** menu SHALL close
- **预期结果**：菜单应关闭
- **AND** confirmation dialog SHALL appear
- **并且**：确认对话框应出现
- **AND** dialog SHALL ask "确定删除这张笔记？"
- **并且**：对话框应询问"确定删除这张笔记？"

#### Scenario: Clicking outside dismisses menu | 场景：点击外部关闭菜单

- **GIVEN** context menu is shown
- **前置条件**：右键菜单已显示
- **WHEN** user clicks outside menu
- **操作**：用户点击菜单外部
- **THEN** menu SHALL close
- **预期结果**：菜单应关闭
- **AND** no action SHALL occur
- **并且**：不应发生任何操作

---

## 5. Menu Styling | 菜单样式

### Requirement: Menu SHALL follow platform conventions | 需求：菜单应遵循平台规范

Menu SHALL follow platform conventions.

菜单应遵循平台规范。

#### Scenario: Menu has proper styling | 场景：菜单有适当的样式

- **GIVEN** context menu is shown
- **前置条件**：右键菜单已显示
- **WHEN** viewing menu
- **操作**：查看菜单
- **THEN** menu SHALL have white background
- **预期结果**：菜单应有白色背景
- **AND** menu SHALL have subtle shadow
- **并且**：菜单应有微妙的阴影
- **AND** menu SHALL have rounded corners
- **并且**：菜单应有圆角

#### Scenario: Menu items have hover effect | 场景：菜单项有悬停效果

- **GIVEN** context menu is shown
- **前置条件**：右键菜单已显示
- **WHEN** user hovers over item
- **操作**：用户悬停在项上
- **THEN** item SHALL highlight
- **预期结果**：项应高亮
- **AND** background SHALL change color
- **并且**：背景应改变颜色
- **AND** cursor SHALL change to pointer
- **并且**：光标应变为指针

---

**Last Updated** | **最后更新**: 2026-01-21
**Authors** | **作者**: CardMind Team
