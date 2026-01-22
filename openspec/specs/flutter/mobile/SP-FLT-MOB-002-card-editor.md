# Mobile Card Editor Specification

## 📋 规格编号: SP-FLT-MOB-002
**版本**: 1.0.0
**状态**: 已完成
**依赖**: 
- SP-FLT-MOB-* (移动端 UI 交互规格)
- SP-CARD-004 (CardStore 规格)

---

## 1. 概述

### 1.1 目标
定义移动端全屏卡片编辑器的详细规范，确保：
- 沉浸式全屏编辑体验
- 自动保存机制
- 输入验证和错误处理
- 流畅的键盘交互

### 1.2 适用平台
- Android
- iOS
- iPadOS（作为移动端处理）

---

## 2. 编辑器布局

### Requirement: Mobile editor SHALL use fullscreen layout

移动端编辑器 SHALL 使用全屏布局。

#### Scenario: Editor occupies full screen
- **GIVEN** user opens editor
- **WHEN** editor loads
- **THEN** editor SHALL occupy entire screen
- **AND** bottom navigation SHALL be hidden
- **AND** only app bar SHALL be visible

#### Scenario: Title field is at top
- **GIVEN** editor is open
- **WHEN** viewing layout
- **THEN** title field SHALL be at top
- **AND** field SHALL be full-width
- **AND** field SHALL have single line

#### Scenario: Content field is below title
- **GIVEN** editor is open
- **WHEN** viewing layout
- **THEN** content field SHALL be below title
- **AND** field SHALL be full-width
- **AND** field SHALL expand to fill space

---

## 3. 自动保存

### Requirement: Mobile editor SHALL auto-save

移动端编辑器 SHALL 自动保存用户输入。

#### Scenario: Auto-save triggers after 500ms
- **GIVEN** user is typing
- **WHEN** user stops for 500ms
- **THEN** system SHALL call save API
- **AND** indicator SHALL show "自动保存中..."

#### Scenario: Auto-save debounces typing
- **GIVEN** user types continuously
- **WHEN** typing
- **THEN** save SHALL NOT be called
- **AND** timer SHALL reset on each keystroke

#### Scenario: Auto-save shows success
- **GIVEN** save completes
- **WHEN** successful
- **THEN** indicator SHALL show "已保存"
- **AND** indicator SHALL fade after 2 seconds

---

## 4. 键盘交互

### Requirement: Mobile editor SHALL handle keyboard

移动端编辑器 SHALL 优雅处理键盘显示和隐藏。

#### Scenario: Keyboard appears on editor open
- **GIVEN** user opens editor
- **WHEN** editor loads
- **THEN** keyboard SHALL appear within 200ms
- **AND** title field SHALL have focus

#### Scenario: Layout adjusts for keyboard
- **GIVEN** keyboard is shown
- **WHEN** keyboard appears
- **THEN** layout SHALL adjust smoothly
- **AND** content SHALL remain visible
- **AND** no content SHALL be hidden

#### Scenario: Tapping outside dismisses keyboard
- **GIVEN** keyboard is shown
- **WHEN** user taps outside fields
- **THEN** keyboard SHALL dismiss
- **AND** fields SHALL remain editable

---

## 5. 输入验证

### Requirement: Mobile editor SHALL validate input

移动端编辑器 SHALL 验证用户输入。

#### Scenario: Empty title prevents save
- **GIVEN** title is empty
- **WHEN** user taps "完成"
- **THEN** button SHALL be disabled
- **AND** no save SHALL occur

#### Scenario: Title with whitespace is invalid
- **GIVEN** title has only spaces
- **WHEN** validating
- **THEN** title SHALL be considered empty
- **AND** system SHALL trim whitespace

#### Scenario: Empty content is allowed
- **GIVEN** content is empty
- **WHEN** saving
- **THEN** save SHALL succeed
- **AND** card SHALL be created

---

**最后更新**: 2026-01-19
**作者**: CardMind Team
