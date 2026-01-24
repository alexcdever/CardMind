# Desktop Toolbar Specification | 桌面端工具栏规格

**Version** | **版本**: 1.0.0
**Status** | **状态**: Active | 已完成
**Dependencies** | **依赖**: [adaptive_ui_components.md](../../ui_system/adaptive_ui_components.md)

---

## 1. Overview | 概述

### 1.1 Goals | 目标

Define desktop toolbar specifications to ensure:

定义桌面端工具栏规范，确保：

- Primary actions easily accessible | 主要操作易于访问
- Clear visual hierarchy | 清晰的视觉层次
- Aligned with desktop application conventions | 符合桌面应用习惯

### 1.2 Applicable Platforms | 适用平台

- macOS
- Windows
- Linux

---

## 2. Toolbar Layout | 工具栏布局

### Requirement: Desktop SHALL use toolbar for actions | 需求：桌面端应使用工具栏放置主要操作

Desktop SHALL use toolbar for primary actions.

桌面端应使用工具栏放置主要操作。

#### Scenario: Toolbar is at top of screen | 场景：工具栏在屏幕顶部

- **GIVEN** user is on home screen
- **前置条件**：用户在主屏幕上
- **WHEN** viewing screen
- **操作**：查看屏幕
- **THEN** toolbar SHALL be at top
- **预期结果**：工具栏应在顶部
- **AND** toolbar SHALL span full width
- **并且**：工具栏应占满宽度
- **AND** toolbar SHALL have 64px height
- **并且**：工具栏应有 64px 高度

#### Scenario: App title is on left | 场景：应用标题在左侧

- **GIVEN** toolbar is displayed
- **前置条件**：工具栏已显示
- **WHEN** viewing toolbar
- **操作**：查看工具栏
- **THEN** app title "CardMind" SHALL be on left
- **预期结果**：应用标题 "CardMind" 应在左侧
- **AND** title SHALL use 24px font size
- **并且**：标题应使用 24px 字号
- **AND** title SHALL be bold
- **并且**：标题应加粗

#### Scenario: Actions are on right | 场景：操作在右侧

- **GIVEN** toolbar is displayed
- **前置条件**：工具栏已显示
- **WHEN** viewing toolbar
- **操作**：查看工具栏
- **THEN** action buttons SHALL be on right
- **预期结果**：操作按钮应在右侧
- **AND** buttons SHALL be horizontally aligned
- **并且**：按钮应水平对齐
- **AND** spacing SHALL be 8px
- **并且**：间距应为 8px

---

## 3. New Card Button | 新建笔记按钮

### Requirement: Toolbar SHALL have New Card button | 需求：工具栏应包含新建笔记按钮

Toolbar SHALL have New Card button.

工具栏应包含新建笔记按钮。

#### Scenario: New Card button is visible | 场景：新建笔记按钮可见

- **GIVEN** user is on home screen
- **前置条件**：用户在主屏幕上
- **WHEN** viewing toolbar
- **操作**：查看工具栏
- **THEN** "新建笔记" button SHALL be visible
- **预期结果**："新建笔记"按钮应可见
- **AND** button SHALL show "+" icon
- **并且**：按钮应显示"+"图标
- **AND** button SHALL show text label
- **并且**：按钮应显示文本标签

#### Scenario: Button has hover effect | 场景：按钮有悬停效果

- **GIVEN** user hovers over button
- **前置条件**：用户悬停在按钮上
- **WHEN** mouse enters button
- **操作**：鼠标进入按钮
- **THEN** background SHALL change color
- **预期结果**：背景应改变颜色
- **AND** cursor SHALL change to pointer
- **并且**：光标应变为指针
- **AND** transition SHALL be smooth
- **并且**：过渡应平滑

#### Scenario: Button shows tooltip | 场景：按钮显示工具提示

- **GIVEN** user hovers over button
- **前置条件**：用户悬停在按钮上
- **WHEN** mouse stays for 500ms
- **操作**：鼠标停留 500ms
- **THEN** tooltip SHALL show "新建笔记 (Cmd/Ctrl+N)"
- **预期结果**：工具提示应显示"新建笔记（Cmd/Ctrl+N）"
- **AND** tooltip SHALL appear below button
- **并且**：工具提示应出现在按钮下方

---

## 4. Search Field | 搜索字段

### Requirement: Toolbar SHALL have search field | 需求：工具栏应包含搜索字段

Toolbar SHALL have search field.

工具栏应包含搜索字段。

#### Scenario: Search field is visible | 场景：搜索字段可见

- **GIVEN** user is on home screen
- **前置条件**：用户在主屏幕上
- **WHEN** viewing toolbar
- **操作**：查看工具栏
- **THEN** search field SHALL be visible
- **预期结果**：搜索字段应可见
- **AND** field SHALL be in center-right area
- **并且**：字段应在中右区域
- **AND** field SHALL have 300px width
- **并且**：字段应有 300px 宽度

#### Scenario: Search field has placeholder | 场景：搜索字段有占位符

- **GIVEN** search field is empty
- **前置条件**：搜索字段为空
- **WHEN** viewing field
- **操作**：查看字段
- **THEN** placeholder SHALL say "搜索笔记标题、内容或标签..."
- **预期结果**：占位符应显示"搜索笔记标题、内容或标签..."
- **AND** placeholder SHALL be gray
- **并且**：占位符应为灰色

#### Scenario: Search field has icon | 场景：搜索字段有图标

- **GIVEN** search field is displayed
- **前置条件**：搜索字段已显示
- **WHEN** viewing field
- **操作**：查看字段
- **THEN** search icon SHALL be on left side
- **预期结果**：搜索图标应在左侧
- **AND** icon SHALL be gray
- **并且**：图标应为灰色
- **AND** icon SHALL be 20x20 pixels
- **并且**：图标应为 20x20 像素

---

## 5. Keyboard Shortcuts | 键盘快捷键

### Requirement: Toolbar actions SHALL support shortcuts | 需求：工具栏操作应支持键盘快捷键

Toolbar actions SHALL support keyboard shortcuts.

工具栏操作应支持键盘快捷键。

#### Scenario: Cmd/Ctrl+N creates card | 场景：Cmd/Ctrl+N 创建卡片

- **GIVEN** user is on home screen
- **前置条件**：用户在主屏幕上
- **WHEN** user presses Cmd/Ctrl+N
- **操作**：用户按下 Cmd/Ctrl+N
- **THEN** new card SHALL be created
- **预期结果**：新卡片应被创建
- **AND** card SHALL enter edit mode
- **并且**：卡片应进入编辑模式

#### Scenario: Cmd/Ctrl+F focuses search | 场景：Cmd/Ctrl+F 聚焦搜索

- **GIVEN** user is on home screen
- **前置条件**：用户在主屏幕上
- **WHEN** user presses Cmd/Ctrl+F
- **操作**：用户按下 Cmd/Ctrl+F
- **THEN** search field SHALL receive focus
- **预期结果**：搜索字段应获得焦点
- **AND** existing text SHALL be selected
- **并且**：现有文本应被选中

---

**Last Updated** | **最后更新**: 2026-01-21
**Authors** | **作者**: CardMind Team
