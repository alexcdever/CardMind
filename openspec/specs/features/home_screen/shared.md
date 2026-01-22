# Home Screen Specification (Shared)
# 主屏幕规格（通用）

**Version** | **版本**: 1.0.0
**Status** | **状态**: Active | 已完成
**Dependencies** | **依赖**: [card_store.md](../../domain/card_store.md), [pool_model.md](../../domain/pool_model.md)

---

## 1. Overview | 概述

### 1.1 Goals | 目标

Define cross-platform common specifications for CardMind home screen to ensure:

定义 CardMind 主页的跨平台通用规范，确保：

- Card list display aligned with single pool model | 卡片列表展示符合单池模型
- Sync status clearly visible | 同步状态清晰可见
- Responsive user actions | 用户操作响应及时
- Consistent core experience across platforms | 跨平台一致的核心体验

### 1.2 Applicable Platforms | 适用平台

- Android
- iOS
- iPadOS
- macOS
- Windows
- Linux

---

## 2. Card Display | 卡片显示

### Requirement: Home screen SHALL display all cards
### 需求：主页应显示所有卡片

Home screen SHALL display all cards.

主页应显示所有卡片。

#### Scenario: Cards are loaded on screen open
#### 场景：打开屏幕时加载卡片

- **GIVEN** user opens home screen
- **前置条件**：用户打开主屏幕
- **WHEN** screen loads
- **操作**：屏幕加载
- **THEN** all cards SHALL be fetched from API
- **预期结果**：应从 API 获取所有卡片
- **AND** cards SHALL be displayed
- **并且**：卡片应显示

#### Scenario: Empty state is shown when no cards
#### 场景：无卡片时显示空状态

- **GIVEN** user has no cards
- **前置条件**：用户没有卡片
- **WHEN** home screen loads
- **操作**：主屏幕加载
- **THEN** empty state SHALL be displayed
- **预期结果**：应显示空状态
- **AND** message SHALL say "还没有笔记"
- **并且**：消息应显示"还没有笔记"

#### Scenario: Cards show title and preview
#### 场景：卡片显示标题和预览

- **GIVEN** cards are displayed
- **前置条件**：卡片已显示
- **WHEN** viewing a card
- **操作**：查看卡片
- **THEN** card SHALL show title
- **预期结果**：卡片应显示标题
- **AND** card SHALL show content preview
- **并且**：卡片应显示内容预览
- **AND** card SHALL show last updated time
- **并且**：卡片应显示最后更新时间

---

## 3. Sync Status | 同步状态

### Requirement: Home screen SHALL show sync status
### 需求：主页应显示同步状态

Home screen SHALL show sync status.

主页应显示同步状态。

#### Scenario: Sync status indicator is visible
#### 场景：同步状态指示器可见

- **GIVEN** user is on home screen
- **前置条件**：用户在主屏幕上
- **WHEN** viewing screen
- **操作**：查看屏幕
- **THEN** sync status indicator SHALL be visible
- **预期结果**：同步状态指示器应可见
- **AND** indicator SHALL show current sync state
- **并且**：指示器应显示当前同步状态

#### Scenario: Syncing shows progress
#### 场景：同步中显示进度

- **GIVEN** sync is in progress
- **前置条件**：同步正在进行
- **WHEN** viewing indicator
- **操作**：查看指示器
- **THEN** indicator SHALL show "同步中..."
- **预期结果**：指示器应显示"同步中..."
- **AND** progress animation SHALL be visible
- **并且**：进度动画应可见

#### Scenario: Synced shows success
#### 场景：已同步显示成功

- **GIVEN** sync completed successfully
- **前置条件**：同步已成功完成
- **WHEN** viewing indicator
- **操作**：查看指示器
- **THEN** indicator SHALL show "已同步"
- **预期结果**：指示器应显示"已同步"
- **AND** success icon SHALL be visible
- **并且**：成功图标应可见

---

## 4. Card Actions | 卡片操作

### Requirement: User SHALL interact with cards
### 需求：用户应与卡片交互

User SHALL interact with cards.

用户应与卡片交互。

#### Scenario: Tapping card opens it
#### 场景：点击卡片打开它

- **GIVEN** user taps a card
- **前置条件**：用户点击卡片
- **WHEN** tap occurs
- **操作**：点击发生
- **THEN** card SHALL open for viewing/editing
- **预期结果**：卡片应打开以查看/编辑
- **AND** navigation SHALL be smooth
- **并且**：导航应流畅

#### Scenario: Creating new card is available
#### 场景：创建新卡片可用

- **GIVEN** user is on home screen
- **前置条件**：用户在主屏幕上
- **WHEN** viewing screen
- **操作**：查看屏幕
- **THEN** create card action SHALL be available
- **预期结果**：创建卡片操作应可用
- **AND** action SHALL be easily accessible
- **并且**：操作应易于访问

---

## 5. Search Function | 搜索功能

### Requirement: User SHALL search cards
### 需求：用户应搜索卡片

User SHALL search cards.

用户应搜索卡片。

#### Scenario: Search is available
#### 场景：搜索可用

- **GIVEN** user is on home screen
- **前置条件**：用户在主屏幕上
- **WHEN** viewing screen
- **操作**：查看屏幕
- **THEN** search function SHALL be available
- **预期结果**：搜索功能应可用
- **AND** search SHALL be easily accessible
- **并且**：搜索应易于访问

#### Scenario: Search filters cards
#### 场景：搜索过滤卡片

- **GIVEN** user enters search query
- **前置条件**：用户输入搜索查询
- **WHEN** typing
- **操作**：输入中
- **THEN** cards SHALL be filtered in real-time
- **预期结果**：卡片应实时过滤
- **AND** only matching cards SHALL be visible
- **并且**：只有匹配的卡片应可见

---

## 6. Performance Requirements | 性能要求

### Requirement: Home screen SHALL be performant
### 需求：主页应满足性能要求

Home screen SHALL meet performance requirements.

主页应满足性能要求。

#### Scenario: Cards load within 350ms
#### 场景：卡片在 350ms 内加载

- **GIVEN** user opens home screen
- **前置条件**：用户打开主屏幕
- **WHEN** loading
- **操作**：加载中
- **THEN** cards SHALL appear within 350ms
- **预期结果**：卡片应在 350ms 内出现
- **AND** loading indicator SHALL be shown
- **并且**：加载指示器应显示

#### Scenario: Scrolling is smooth
#### 场景：滚动流畅

- **GIVEN** user scrolls card list
- **前置条件**：用户滚动卡片列表
- **WHEN** scrolling
- **操作**：滚动中
- **THEN** scrolling SHALL maintain 60fps
- **预期结果**：滚动应保持 60fps
- **AND** no frame drops SHALL occur
- **并且**：不应有掉帧

---

**Last Updated** | **最后更新**: 2026-01-21
**Authors** | **作者**: CardMind Team
