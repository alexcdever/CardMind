# Desktop Toolbar Specification

## 📋 规格编号: SP-FLT-DSK-003
**版本**: 1.0.0
**状态**: 已完成
**依赖**: 
- SP-FLT-DSK-* (桌面端 UI 交互规格)
- SP-ADAPT-005 (桌面端 UI 模式规格)

---

## 1. 概述

### 1.1 目标
定义桌面端工具栏规范，确保：
- 主要操作易于访问
- 清晰的视觉层次
- 符合桌面应用习惯

### 1.2 适用平台
- macOS
- Windows
- Linux

---

## 2. 工具栏布局

### Requirement: Desktop SHALL use toolbar for actions

桌面端 SHALL 使用工具栏放置主要操作。

#### Scenario: Toolbar is at top of screen
- **GIVEN** user is on home screen
- **WHEN** viewing screen
- **THEN** toolbar SHALL be at top
- **AND** toolbar SHALL span full width
- **AND** toolbar SHALL have 64px height

#### Scenario: App title is on left
- **GIVEN** toolbar is displayed
- **WHEN** viewing toolbar
- **THEN** app title "CardMind" SHALL be on left
- **AND** title SHALL use 24px font size
- **AND** title SHALL be bold

#### Scenario: Actions are on right
- **GIVEN** toolbar is displayed
- **WHEN** viewing toolbar
- **THEN** action buttons SHALL be on right
- **AND** buttons SHALL be horizontally aligned
- **AND** spacing SHALL be 8px

---

## 3. 新建笔记按钮

### Requirement: Toolbar SHALL have New Card button

工具栏 SHALL 包含新建笔记按钮。

#### Scenario: New Card button is visible
- **GIVEN** user is on home screen
- **WHEN** viewing toolbar
- **THEN** "新建笔记" button SHALL be visible
- **AND** button SHALL show "+" icon
- **AND** button SHALL show text label

#### Scenario: Button has hover effect
- **GIVEN** user hovers over button
- **WHEN** mouse enters button
- **THEN** background SHALL change color
- **AND** cursor SHALL change to pointer
- **AND** transition SHALL be smooth

#### Scenario: Button shows tooltip
- **GIVEN** user hovers over button
- **WHEN** mouse stays for 500ms
- **THEN** tooltip SHALL show "新建笔记 (Cmd/Ctrl+N)"
- **AND** tooltip SHALL appear below button

---

## 4. 搜索字段

### Requirement: Toolbar SHALL have search field

工具栏 SHALL 包含搜索字段。

#### Scenario: Search field is visible
- **GIVEN** user is on home screen
- **WHEN** viewing toolbar
- **THEN** search field SHALL be visible
- **AND** field SHALL be in center-right area
- **AND** field SHALL have 300px width

#### Scenario: Search field has placeholder
- **GIVEN** search field is empty
- **WHEN** viewing field
- **THEN** placeholder SHALL say "搜索笔记标题、内容或标签..."
- **AND** placeholder SHALL be gray

#### Scenario: Search field has icon
- **GIVEN** search field is displayed
- **WHEN** viewing field
- **THEN** search icon SHALL be on left side
- **AND** icon SHALL be gray
- **AND** icon SHALL be 20x20 pixels

---

## 5. 键盘快捷键

### Requirement: Toolbar actions SHALL support shortcuts

工具栏操作 SHALL 支持键盘快捷键。

#### Scenario: Cmd/Ctrl+N creates card
- **GIVEN** user is on home screen
- **WHEN** user presses Cmd/Ctrl+N
- **THEN** new card SHALL be created
- **AND** card SHALL enter edit mode

#### Scenario: Cmd/Ctrl+F focuses search
- **GIVEN** user is on home screen
- **WHEN** user presses Cmd/Ctrl+F
- **THEN** search field SHALL receive focus
- **AND** existing text SHALL be selected

---

**最后更新**: 2026-01-19
**作者**: CardMind Team
