# Desktop Context Menu Specification

## 📋 规格编号: SP-FLT-DSK-004
**版本**: 1.0.0
**状态**: 已完成
**依赖**: 
- SP-FLT-DSK-* (桌面端 UI 交互规格)
- SP-ADAPT-005 (桌面端 UI 模式规格)

---

## 1. 概述

### 1.1 目标
定义桌面端右键菜单规范，确保：
- 符合桌面应用习惯
- 提供快速操作入口
- 清晰的菜单层次

### 1.2 适用平台
- macOS
- Windows
- Linux

---

## 2. 菜单触发

### Requirement: Desktop SHALL support right-click menu

桌面端 SHALL 支持右键菜单。

#### Scenario: Right-clicking card shows menu
- **GIVEN** user views card grid
- **WHEN** user right-clicks on card
- **THEN** context menu SHALL appear
- **AND** menu SHALL be near mouse cursor
- **AND** menu SHALL not extend off screen

#### Scenario: Menu appears within 100ms
- **GIVEN** user right-clicks card
- **WHEN** right-click occurs
- **THEN** menu SHALL appear within 100ms
- **AND** appearance SHALL be smooth

---

## 3. 菜单内容

### Requirement: Context menu SHALL show card actions

上下文菜单 SHALL 显示卡片操作。

#### Scenario: Menu includes Edit option
- **GIVEN** context menu is shown
- **WHEN** viewing menu
- **THEN** "编辑" option SHALL be first
- **AND** option SHALL show edit icon
- **AND** option SHALL show keyboard shortcut

#### Scenario: Menu includes Delete option
- **GIVEN** context menu is shown
- **WHEN** viewing menu
- **THEN** "删除" option SHALL be included
- **AND** option SHALL show delete icon
- **AND** option SHALL be red

#### Scenario: Menu includes Copy option
- **GIVEN** context menu is shown
- **WHEN** viewing menu
- **THEN** "复制" option SHALL be included
- **AND** option SHALL show copy icon

#### Scenario: Menu includes Share option
- **GIVEN** context menu is shown
- **WHEN** viewing menu
- **THEN** "分享" option SHALL be included
- **AND** option SHALL show share icon

---

## 4. 菜单交互

### Requirement: Menu options SHALL be clickable

菜单选项 SHALL 可点击。

#### Scenario: Clicking Edit enters edit mode
- **GIVEN** context menu is shown
- **WHEN** user clicks "编辑"
- **THEN** menu SHALL close
- **AND** card SHALL enter edit mode
- **AND** title field SHALL have focus

#### Scenario: Clicking Delete shows confirmation
- **GIVEN** context menu is shown
- **WHEN** user clicks "删除"
- **THEN** menu SHALL close
- **AND** confirmation dialog SHALL appear
- **AND** dialog SHALL ask "确定删除这张笔记？"

#### Scenario: Clicking outside dismisses menu
- **GIVEN** context menu is shown
- **WHEN** user clicks outside menu
- **THEN** menu SHALL close
- **AND** no action SHALL occur

---

## 5. 菜单样式

### Requirement: Menu SHALL follow platform conventions

菜单 SHALL 遵循平台规范。

#### Scenario: Menu has proper styling
- **GIVEN** context menu is shown
- **WHEN** viewing menu
- **THEN** menu SHALL have white background
- **AND** menu SHALL have subtle shadow
- **AND** menu SHALL have rounded corners

#### Scenario: Menu items have hover effect
- **GIVEN** context menu is shown
- **WHEN** user hovers over item
- **THEN** item SHALL highlight
- **AND** background SHALL change color
- **AND** cursor SHALL change to pointer

---

**最后更新**: 2026-01-19
**作者**: CardMind Team
