# Home Screen Specification

## 📋 规格编号: SP-FLT-SHR-002
**版本**: 1.0.0
**状态**: 已完成
**依赖**: 
- SP-SPM-001 (单池模型核心规格)
- SP-FLT-SHR-001 (初始化流程规格)
- SP-CARD-004 (CardStore 规格)

---

## 1. 概述

### 1.1 目标
定义 CardMind 主页的跨平台通用规范，确保：
- 卡片列表展示符合单池模型
- 同步状态清晰可见
- 用户操作响应及时
- 跨平台一致的核心体验

### 1.2 适用平台
- Android
- iOS
- iPadOS
- macOS
- Windows
- Linux

---

## 2. 卡片显示

### Requirement: Home screen SHALL display all cards

主页 SHALL 显示所有卡片。

#### Scenario: Cards are loaded on screen open
- **GIVEN** user opens home screen
- **WHEN** screen loads
- **THEN** all cards SHALL be fetched from API
- **AND** cards SHALL be displayed

#### Scenario: Empty state is shown when no cards
- **GIVEN** user has no cards
- **WHEN** home screen loads
- **THEN** empty state SHALL be displayed
- **AND** message SHALL say "还没有笔记"

#### Scenario: Cards show title and preview
- **GIVEN** cards are displayed
- **WHEN** viewing a card
- **THEN** card SHALL show title
- **AND** card SHALL show content preview
- **AND** card SHALL show last updated time

---

## 3. 同步状态

### Requirement: Home screen SHALL show sync status

主页 SHALL 显示同步状态。

#### Scenario: Sync status indicator is visible
- **GIVEN** user is on home screen
- **WHEN** viewing screen
- **THEN** sync status indicator SHALL be visible
- **AND** indicator SHALL show current sync state

#### Scenario: Syncing shows progress
- **GIVEN** sync is in progress
- **WHEN** viewing indicator
- **THEN** indicator SHALL show "同步中..."
- **AND** progress animation SHALL be visible

#### Scenario: Synced shows success
- **GIVEN** sync completed successfully
- **WHEN** viewing indicator
- **THEN** indicator SHALL show "已同步"
- **AND** success icon SHALL be visible

---

## 4. 卡片操作

### Requirement: User SHALL interact with cards

用户 SHALL 与卡片交互。

#### Scenario: Tapping card opens it
- **GIVEN** user taps a card
- **WHEN** tap occurs
- **THEN** card SHALL open for viewing/editing
- **AND** navigation SHALL be smooth

#### Scenario: Creating new card is available
- **GIVEN** user is on home screen
- **WHEN** viewing screen
- **THEN** create card action SHALL be available
- **AND** action SHALL be easily accessible

---

## 5. 搜索功能

### Requirement: User SHALL search cards

用户 SHALL 搜索卡片。

#### Scenario: Search is available
- **GIVEN** user is on home screen
- **WHEN** viewing screen
- **THEN** search function SHALL be available
- **AND** search SHALL be easily accessible

#### Scenario: Search filters cards
- **GIVEN** user enters search query
- **WHEN** typing
- **THEN** cards SHALL be filtered in real-time
- **AND** only matching cards SHALL be visible

---

## 6. 性能要求

### Requirement: Home screen SHALL be performant

主页 SHALL 满足性能要求。

#### Scenario: Cards load within 350ms
- **GIVEN** user opens home screen
- **WHEN** loading
- **THEN** cards SHALL appear within 350ms
- **AND** loading indicator SHALL be shown

#### Scenario: Scrolling is smooth
- **GIVEN** user scrolls card list
- **WHEN** scrolling
- **THEN** scrolling SHALL maintain 60fps
- **AND** no frame drops SHALL occur

---

**最后更新**: 2026-01-19
**作者**: CardMind Team
