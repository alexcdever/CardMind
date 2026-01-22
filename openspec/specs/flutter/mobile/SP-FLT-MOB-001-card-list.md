# Mobile Card List Specification

## 📋 规格编号: SP-FLT-MOB-001
**版本**: 1.0.0
**状态**: 已完成
**依赖**: 
- SP-FLT-SHR-002 (主页交互规格)
- SP-ADAPT-004 (移动端 UI 模式规格)
- SP-CARD-004 (CardStore 规格)

---

## 1. 概述

### 1.1 目标
定义移动端卡片列表的显示和交互规范，确保：
- 垂直滚动列表，优化单手操作
- 全宽卡片显示，最大化内容可见性
- 流畅的滚动和加载体验
- 下拉刷新支持

### 1.2 适用平台
- Android
- iOS
- iPadOS（作为移动端处理）

---

## 2. 列表布局

### Requirement: Mobile SHALL use vertical list layout

移动端 SHALL 使用垂直列表布局显示卡片。

#### Scenario: Cards are displayed in vertical list
- **GIVEN** user has multiple cards
- **WHEN** viewing home screen
- **THEN** cards SHALL be displayed in vertical list
- **AND** each card SHALL be full-width
- **AND** cards SHALL have 8px vertical spacing

#### Scenario: List scrolls vertically
- **GIVEN** user has many cards
- **WHEN** user scrolls
- **THEN** list SHALL scroll vertically
- **AND** scrolling SHALL be smooth (60fps)
- **AND** scroll physics SHALL feel natural

#### Scenario: List supports infinite scroll
- **GIVEN** user has many cards
- **WHEN** user scrolls to bottom
- **THEN** system SHALL load more cards
- **AND** loading SHALL be seamless
- **AND** loading indicator SHALL appear at bottom

---

## 3. 卡片显示

### Requirement: Mobile cards SHALL show title and preview

移动端卡片 SHALL 显示标题和内容预览。

#### Scenario: Card shows title
- **GIVEN** card is displayed in list
- **WHEN** viewing card
- **THEN** card SHALL show title in bold
- **AND** title SHALL be truncated if too long
- **AND** title SHALL use 18sp font size

#### Scenario: Card shows content preview
- **GIVEN** card is displayed in list
- **WHEN** viewing card
- **THEN** card SHALL show first 3 lines of content
- **AND** content SHALL be truncated with "..."
- **AND** content SHALL use 14sp font size

#### Scenario: Card shows metadata
- **GIVEN** card is displayed in list
- **WHEN** viewing card
- **THEN** card SHALL show last updated time
- **AND** time SHALL use relative format ("2小时前")
- **AND** metadata SHALL use 12sp font size

---

## 4. 下拉刷新

### Requirement: Mobile SHALL support pull-to-refresh

移动端 SHALL 支持下拉刷新卡片列表。

#### Scenario: Pull down shows refresh indicator
- **GIVEN** user is at top of list
- **WHEN** user pulls down
- **THEN** refresh indicator SHALL appear
- **AND** indicator SHALL follow pull distance

#### Scenario: Release triggers refresh
- **GIVEN** user pulled down past threshold
- **WHEN** user releases
- **THEN** system SHALL reload cards from API
- **AND** indicator SHALL show loading animation
- **AND** list SHALL update with new data

#### Scenario: Refresh completes within 2 seconds
- **GIVEN** refresh is triggered
- **WHEN** loading
- **THEN** refresh SHALL complete within 2 seconds
- **AND** indicator SHALL disappear smoothly

---

## 5. 空状态

### Requirement: Mobile SHALL show empty state when no cards

移动端 SHALL 在无卡片时显示空状态。

#### Scenario: Empty state shows message
- **GIVEN** user has no cards
- **WHEN** viewing home screen
- **THEN** system SHALL show empty state
- **AND** message SHALL say "还没有笔记"
- **AND** icon SHALL be displayed

#### Scenario: Empty state shows create button
- **GIVEN** empty state is shown
- **WHEN** viewing screen
- **THEN** system SHALL show "创建第一张笔记" button
- **AND** tapping button SHALL open editor

---

## 6. 性能要求

### Requirement: Mobile list SHALL be performant

移动端列表 SHALL 满足性能要求。

#### Scenario: List scrolling maintains 60fps
- **GIVEN** user scrolls list
- **WHEN** scrolling
- **THEN** frame rate SHALL be 60fps
- **AND** no frame drops SHALL occur

#### Scenario: Cards load within 350ms
- **GIVEN** user opens home screen
- **WHEN** loading cards
- **THEN** cards SHALL appear within 350ms
- **AND** loading indicator SHALL be shown

---

**最后更新**: 2026-01-19
**作者**: CardMind Team
