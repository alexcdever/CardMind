# Desktop Inline Editor Specification | 桌面端内联编辑器规格

**Version** | **版本**: 1.0.0
**Status** | **状态**: Active | 已完成
**Dependencies** | **依赖**: [card_store.md](../../architecture/storage/card_store.md), [adaptive_ui_components.md](../../ui_system/adaptive_ui_components.md)

---

## 1. Overview | 概述

### 1.1 Goals | 目标

Define desktop inline editor specifications to ensure:

定义桌面端内联编辑器规范，确保：

- In-place editing, maintaining context | 就地编辑，保持上下文
- Efficient keyboard operations | 高效的键盘操作
- Auto-save mechanism | 自动保存机制
- Clear visual feedback | 清晰的视觉反馈

### 1.2 Applicable Platforms | 适用平台

- macOS
- Windows
- Linux

---

## 2. Editor Activation | 编辑器激活

### Requirement: Desktop SHALL use inline editing | 需求：桌面端应使用内联编辑

Desktop SHALL use inline editing mode.

桌面端应使用内联编辑模式。

#### Scenario: Creating card enters edit mode | 场景：创建卡片进入编辑模式

- **GIVEN** user clicks "新建笔记"
- **前置条件**：用户点击"新建笔记"
- **WHEN** card is created
- **操作**：创建卡片
- **THEN** card SHALL enter edit mode automatically
- **预期结果**：卡片应自动进入编辑模式
- **AND** title field SHALL have focus
- **并且**：标题字段应获得焦点
- **AND** cursor SHALL be at beginning
- **并且**：光标应在开头

#### Scenario: Clicking edit button enters edit mode | 场景：点击编辑按钮进入编辑模式

- **GIVEN** user clicks edit button on card
- **前置条件**：用户点击卡片上的编辑按钮
- **WHEN** button is clicked
- **操作**：点击按钮
- **THEN** card SHALL enter edit mode
- **预期结果**：卡片应进入编辑模式
- **AND** title field SHALL have focus
- **并且**：标题字段应获得焦点
- **AND** existing content SHALL be preserved
- **并且**：现有内容应保留

#### Scenario: Only one card can be edited | 场景：只能编辑一张卡片

- **GIVEN** user is editing card A
- **前置条件**：用户正在编辑卡片 A
- **WHEN** user clicks edit on card B
- **操作**：用户点击卡片 B 的编辑
- **THEN** card A SHALL save automatically
- **预期结果**：卡片 A 应自动保存
- **AND** card A SHALL exit edit mode
- **并且**：卡片 A 应退出编辑模式
- **AND** card B SHALL enter edit mode
- **并且**：卡片 B 应进入编辑模式

---

## 3. Editor Layout | 编辑器布局

### Requirement: Inline editor SHALL show fields vertically | 需求：内联编辑器应垂直显示字段

Inline editor SHALL show fields vertically.

内联编辑器应垂直显示字段。

#### Scenario: Title field is at top | 场景：标题字段在顶部

- **GIVEN** card is in edit mode
- **前置条件**：卡片处于编辑模式
- **WHEN** viewing card
- **操作**：查看卡片
- **THEN** title field SHALL be at top
- **预期结果**：标题字段应在顶部
- **AND** field SHALL be full-width within card
- **并且**：字段应在卡片内全宽
- **AND** field SHALL have single line
- **并且**：字段应为单行

#### Scenario: Content field is below title | 场景：内容字段在标题下方

- **GIVEN** card is in edit mode
- **前置条件**：卡片处于编辑模式
- **WHEN** viewing card
- **操作**：查看卡片
- **THEN** content field SHALL be below title
- **预期结果**：内容字段应在标题下方
- **AND** field SHALL be full-width within card
- **并且**：字段应在卡片内全宽
- **AND** field SHALL expand to fit text
- **并且**：字段应扩展以适应文本

#### Scenario: Action buttons are in top-right | 场景：操作按钮在右上角

- **GIVEN** card is in edit mode
- **前置条件**：卡片处于编辑模式
- **WHEN** viewing card
- **操作**：查看卡片
- **THEN** save button SHALL be in top-right
- **预期结果**：保存按钮应在右上角
- **AND** cancel button SHALL be next to save
- **并且**：取消按钮应在保存按钮旁边
- **AND** buttons SHALL be clearly visible
- **并且**：按钮应清晰可见

---

## 4. Keyboard Navigation | 键盘导航

### Requirement: Editor SHALL support keyboard navigation | 需求：编辑器应支持键盘导航

Editor SHALL support keyboard navigation.

编辑器应支持键盘导航。

#### Scenario: Tab moves to content field | 场景：Tab 移动到内容字段

- **GIVEN** cursor is in title field
- **前置条件**：光标在标题字段
- **WHEN** user presses Tab
- **操作**：用户按下 Tab
- **THEN** focus SHALL move to content field
- **预期结果**：焦点应移动到内容字段
- **AND** cursor SHALL be at beginning
- **并且**：光标应在开头

#### Scenario: Shift+Tab moves to title field | 场景：Shift+Tab 移动到标题字段

- **GIVEN** cursor is in content field
- **前置条件**：光标在内容字段
- **WHEN** user presses Shift+Tab
- **操作**：用户按下 Shift+Tab
- **THEN** focus SHALL move to title field
- **预期结果**：焦点应移动到标题字段
- **AND** cursor SHALL be at end
- **并且**：光标应在末尾

#### Scenario: Cmd/Ctrl+Enter saves | 场景：Cmd/Ctrl+Enter 保存

- **GIVEN** user is editing
- **前置条件**：用户正在编辑
- **WHEN** user presses Cmd/Ctrl+Enter
- **操作**：用户按下 Cmd/Ctrl+Enter
- **THEN** card SHALL save
- **预期结果**：卡片应保存
- **AND** edit mode SHALL exit
- **并且**：编辑模式应退出
- **AND** saved content SHALL be shown
- **并且**：保存的内容应显示

#### Scenario: Escape cancels | 场景：Escape 取消

- **GIVEN** user is editing
- **前置条件**：用户正在编辑
- **WHEN** user presses Escape
- **操作**：用户按下 Escape
- **THEN** edit mode SHALL exit
- **预期结果**：编辑模式应退出
- **AND** changes SHALL be discarded (if confirmed)
- **并且**：更改应被丢弃（如果确认）
- **AND** original content SHALL be restored
- **并且**：原始内容应恢复

---

## 5. Auto-save | 自动保存

### Requirement: Editor SHALL auto-save | 需求：编辑器应自动保存

Editor SHALL auto-save user input.

编辑器应自动保存用户输入。

#### Scenario: Auto-save triggers after 500ms | 场景：500ms 后触发自动保存

- **GIVEN** user is typing
- **前置条件**：用户正在输入
- **WHEN** user stops for 500ms
- **操作**：用户停止输入 500ms
- **THEN** system SHALL call save API
- **预期结果**：系统应调用保存 API
- **AND** indicator SHALL show "保存中..."
- **并且**：指示器应显示"保存中..."

#### Scenario: Auto-save indicator is subtle | 场景：自动保存指示器很微妙

- **GIVEN** auto-save is in progress
- **前置条件**：自动保存正在进行
- **WHEN** indicator is shown
- **操作**：显示指示器
- **THEN** indicator SHALL be in card footer
- **预期结果**：指示器应在卡片页脚
- **AND** indicator SHALL be small and subtle
- **并且**：指示器应小而微妙
- **AND** indicator SHALL not block content
- **并且**：指示器不应阻挡内容

#### Scenario: Auto-save shows success briefly | 场景：自动保存短暂显示成功

- **GIVEN** save completes
- **前置条件**：保存完成
- **WHEN** successful
- **操作**：成功
- **THEN** indicator SHALL show "已保存"
- **预期结果**：指示器应显示"已保存"
- **AND** indicator SHALL fade after 1 second
- **并且**：指示器应在 1 秒后淡出

---

## 6. Visual Feedback | 视觉反馈

### Requirement: Editor SHALL provide clear feedback | 需求：编辑器应提供清晰的反馈

Editor SHALL provide clear visual feedback.

编辑器应提供清晰的视觉反馈。

#### Scenario: Edit mode shows elevated card | 场景：编辑模式显示提升的卡片

- **GIVEN** card is in edit mode
- **前置条件**：卡片处于编辑模式
- **WHEN** viewing card
- **操作**：查看卡片
- **THEN** card SHALL have elevated shadow
- **预期结果**：卡片应有提升的阴影
- **AND** elevation SHALL be higher than hover
- **并且**：提升应高于悬停
- **AND** card SHALL stand out from others
- **并且**：卡片应从其他卡片中脱颖而出

#### Scenario: Save button is green | 场景：保存按钮为绿色

- **GIVEN** card is in edit mode
- **前置条件**：卡片处于编辑模式
- **WHEN** viewing save button
- **操作**：查看保存按钮
- **THEN** button SHALL be green
- **预期结果**：按钮应为绿色
- **AND** button SHALL show checkmark icon
- **并且**：按钮应显示对勾图标

#### Scenario: Cancel button is red | 场景：取消按钮为红色

- **GIVEN** card is in edit mode
- **前置条件**：卡片处于编辑模式
- **WHEN** viewing cancel button
- **操作**：查看取消按钮
- **THEN** button SHALL be red
- **预期结果**：按钮应为红色
- **AND** button SHALL show X icon
- **并且**：按钮应显示 X 图标

---

**Last Updated** | **最后更新**: 2026-01-21
**Authors** | **作者**: CardMind Team
