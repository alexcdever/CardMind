# Desktop Search Specification

## 📋 规格编号: SP-FLT-DSK-005
**版本**: 1.0.0
**状态**: 已完成
**依赖**: 
- SP-FLT-DSK-* (桌面端 UI 交互规格)
- SP-FLT-SHR-002 (主页交互规格)

---

## 1. 概述

### 1.1 目标
定义桌面端搜索功能规范，确保：
- 内联过滤，保持上下文
- 实时搜索结果
- 高亮匹配文本
- 键盘快捷键支持

### 1.2 适用平台
- macOS
- Windows
- Linux

---

## 2. 搜索字段

### Requirement: Desktop SHALL use inline search

桌面端 SHALL 使用内联搜索。

#### Scenario: Search field is in toolbar
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

#### Scenario: Cmd/Ctrl+F focuses search
- **GIVEN** user is on home screen
- **WHEN** user presses Cmd/Ctrl+F
- **THEN** search field SHALL receive focus
- **AND** existing text SHALL be selected

---

## 3. 实时过滤

### Requirement: Search SHALL filter in real-time

搜索 SHALL 实时过滤卡片。

#### Scenario: Results update as user types
- **GIVEN** user types in search field
- **WHEN** user enters text
- **THEN** card grid SHALL filter immediately
- **AND** only matching cards SHALL be visible
- **AND** filtering SHALL be smooth (no flicker)

#### Scenario: Filtering completes within 200ms
- **GIVEN** user types character
- **WHEN** filtering occurs
- **THEN** filtering SHALL complete within 200ms
- **AND** UI SHALL remain responsive

#### Scenario: Clearing search shows all cards
- **GIVEN** search is active
- **WHEN** user clears search field
- **THEN** all cards SHALL be visible again
- **AND** transition SHALL be smooth

---

## 4. 匹配高亮

### Requirement: Search SHALL highlight matches

搜索 SHALL 高亮匹配文本。

#### Scenario: Matching text is highlighted
- **GIVEN** search results are shown
- **WHEN** viewing cards
- **THEN** matching text SHALL be highlighted
- **AND** highlight SHALL use primary color
- **AND** highlight SHALL be visible

#### Scenario: Multiple matches are highlighted
- **GIVEN** card has multiple matches
- **WHEN** viewing card
- **THEN** all matches SHALL be highlighted
- **AND** highlights SHALL be consistent

---

## 5. 空结果

### Requirement: Search SHALL show empty state

搜索 SHALL 在无结果时显示空状态。

#### Scenario: No results shows message
- **GIVEN** search has no matches
- **WHEN** viewing grid
- **THEN** message SHALL say "未找到相关笔记"
- **AND** icon SHALL be displayed
- **AND** search term SHALL be shown

#### Scenario: Empty state suggests clearing
- **GIVEN** no results are shown
- **WHEN** viewing message
- **THEN** suggestion SHALL say "尝试其他关键词"
- **AND** clear button SHALL be visible

---

**最后更新**: 2026-01-19
**作者**: CardMind Team
