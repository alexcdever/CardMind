# Desktop Inline Editor Specification

## 📋 规格编号: SP-FLT-DSK-002
**版本**: 1.0.0
**状态**: 已完成
**依赖**: 
- SP-FLT-DSK-* (桌面端 UI 交互规格)
- SP-CARD-004 (CardStore 规格)

---

## 1. 概述

### 1.1 目标
定义桌面端内联编辑器规范，确保：
- 就地编辑，保持上下文
- 高效的键盘操作
- 自动保存机制
- 清晰的视觉反馈

### 1.2 适用平台
- macOS
- Windows
- Linux

---

## 2. 编辑器激活

### Requirement: Desktop SHALL use inline editing

桌面端 SHALL 使用内联编辑模式。

#### Scenario: Creating card enters edit mode
- **GIVEN** user clicks "新建笔记"
- **WHEN** card is created
- **THEN** card SHALL enter edit mode automatically
- **AND** title field SHALL have focus
- **AND** cursor SHALL be at beginning

#### Scenario: Clicking edit button enters edit mode
- **GIVEN** user clicks edit button on card
- **WHEN** button is clicked
- **THEN** card SHALL enter edit mode
- **AND** title field SHALL have focus
- **AND** existing content SHALL be preserved

#### Scenario: Only one card can be edited
- **GIVEN** user is editing card A
- **WHEN** user clicks edit on card B
- **THEN** card A SHALL save automatically
- **AND** card A SHALL exit edit mode
- **AND** card B SHALL enter edit mode

---

## 3. 编辑器布局

### Requirement: Inline editor SHALL show fields vertically

内联编辑器 SHALL 垂直显示字段。

#### Scenario: Title field is at top
- **GIVEN** card is in edit mode
- **WHEN** viewing card
- **THEN** title field SHALL be at top
- **AND** field SHALL be full-width within card
- **AND** field SHALL have single line

#### Scenario: Content field is below title
- **GIVEN** card is in edit mode
- **WHEN** viewing card
- **THEN** content field SHALL be below title
- **AND** field SHALL be full-width within card
- **AND** field SHALL expand to fit text

#### Scenario: Action buttons are in top-right
- **GIVEN** card is in edit mode
- **WHEN** viewing card
- **THEN** save button SHALL be in top-right
- **AND** cancel button SHALL be next to save
- **AND** buttons SHALL be clearly visible

---

## 4. 键盘导航

### Requirement: Editor SHALL support keyboard navigation

编辑器 SHALL 支持键盘导航。

#### Scenario: Tab moves to content field
- **GIVEN** cursor is in title field
- **WHEN** user presses Tab
- **THEN** focus SHALL move to content field
- **AND** cursor SHALL be at beginning

#### Scenario: Shift+Tab moves to title field
- **GIVEN** cursor is in content field
- **WHEN** user presses Shift+Tab
- **THEN** focus SHALL move to title field
- **AND** cursor SHALL be at end

#### Scenario: Cmd/Ctrl+Enter saves
- **GIVEN** user is editing
- **WHEN** user presses Cmd/Ctrl+Enter
- **THEN** card SHALL save
- **AND** edit mode SHALL exit
- **AND** saved content SHALL be shown

#### Scenario: Escape cancels
- **GIVEN** user is editing
- **WHEN** user presses Escape
- **THEN** edit mode SHALL exit
- **AND** changes SHALL be discarded (if confirmed)
- **AND** original content SHALL be restored

---

## 5. 自动保存

### Requirement: Editor SHALL auto-save

编辑器 SHALL 自动保存用户输入。

#### Scenario: Auto-save triggers after 500ms
- **GIVEN** user is typing
- **WHEN** user stops for 500ms
- **THEN** system SHALL call save API
- **AND** indicator SHALL show "保存中..."

#### Scenario: Auto-save indicator is subtle
- **GIVEN** auto-save is in progress
- **WHEN** indicator is shown
- **THEN** indicator SHALL be in card footer
- **AND** indicator SHALL be small and subtle
- **AND** indicator SHALL not block content

#### Scenario: Auto-save shows success briefly
- **GIVEN** save completes
- **WHEN** successful
- **THEN** indicator SHALL show "已保存"
- **AND** indicator SHALL fade after 1 second

---

## 6. 视觉反馈

### Requirement: Editor SHALL provide clear feedback

编辑器 SHALL 提供清晰的视觉反馈。

#### Scenario: Edit mode shows elevated card
- **GIVEN** card is in edit mode
- **WHEN** viewing card
- **THEN** card SHALL have elevated shadow
- **AND** elevation SHALL be higher than hover
- **AND** card SHALL stand out from others

#### Scenario: Save button is green
- **GIVEN** card is in edit mode
- **WHEN** viewing save button
- **THEN** button SHALL be green
- **AND** button SHALL show checkmark icon

#### Scenario: Cancel button is red
- **GIVEN** card is in edit mode
- **WHEN** viewing cancel button
- **THEN** button SHALL be red
- **AND** button SHALL show X icon

---

**最后更新**: 2026-01-19
**作者**: CardMind Team
