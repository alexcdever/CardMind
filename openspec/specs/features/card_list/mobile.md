# Mobile Card List Specification
# 移动端卡片列表规格

**Version** | **版本**: 1.0.0
**Status** | **状态**: Active | 已完成
**Dependencies** | **依赖**: [card_store.md](../../domain/card_store.md), [adaptive_ui_components.md](../../ui_system/adaptive_ui_components.md)

---

## 1. Overview | 概述

### 1.1 Goals | 目标

Define mobile card list display and interaction specifications to ensure:

定义移动端卡片列表的显示和交互规范，确保：

- Vertical scrolling list optimized for one-handed operation | 垂直滚动列表，优化单手操作
- Full-width card display maximizing content visibility | 全宽卡片显示，最大化内容可见性
- Smooth scrolling and loading experience | 流畅的滚动和加载体验
- Pull-to-refresh support | 下拉刷新支持

### 1.2 Applicable Platforms | 适用平台

- Android
- iOS
- iPadOS (treated as mobile | 作为移动端处理)

---

## 2. List Layout | 列表布局

### Requirement: Mobile SHALL use vertical list layout
### 需求：移动端应使用垂直列表布局

Mobile SHALL use vertical list layout to display cards.

移动端应使用垂直列表布局显示卡片。

#### Scenario: Cards are displayed in vertical list
#### 场景：卡片在垂直列表中显示

- **GIVEN** user has multiple cards
- **前置条件**：用户有多张卡片
- **WHEN** viewing home screen
- **操作**：查看主屏幕
- **THEN** cards SHALL be displayed in vertical list
- **预期结果**：卡片应在垂直列表中显示
- **AND** each card SHALL be full-width
- **并且**：每张卡片应全宽显示
- **AND** cards SHALL have 8px vertical spacing
- **并且**：卡片应有 8px 垂直间距

#### Scenario: List scrolls vertically
#### 场景：列表垂直滚动

- **GIVEN** user has many cards
- **前置条件**：用户有很多卡片
- **WHEN** user scrolls
- **操作**：用户滚动
- **THEN** list SHALL scroll vertically
- **预期结果**：列表应垂直滚动
- **AND** scrolling SHALL be smooth (60fps)
- **并且**：滚动应流畅（60fps）
- **AND** scroll physics SHALL feel natural
- **并且**：滚动物理效果应自然

#### Scenario: List supports infinite scroll
#### 场景：列表支持无限滚动

- **GIVEN** user has many cards
- **前置条件**：用户有很多卡片
- **WHEN** user scrolls to bottom
- **操作**：用户滚动到底部
- **THEN** system SHALL load more cards
- **预期结果**：系统应加载更多卡片
- **AND** loading SHALL be seamless
- **并且**：加载应无缝衔接
- **AND** loading indicator SHALL appear at bottom
- **并且**：加载指示器应出现在底部

---

## 3. Card Display | 卡片显示

### Requirement: Mobile cards SHALL show title and preview
### 需求：移动端卡片应显示标题和预览

Mobile cards SHALL show title and content preview.

移动端卡片应显示标题和内容预览。

#### Scenario: Card shows title
#### 场景：卡片显示标题

- **GIVEN** card is displayed in list
- **前置条件**：卡片在列表中显示
- **WHEN** viewing card
- **操作**：查看卡片
- **THEN** card SHALL show title in bold
- **预期结果**：卡片应以粗体显示标题
- **AND** title SHALL be truncated if too long
- **并且**：标题过长应截断
- **AND** title SHALL use 18sp font size
- **并且**：标题应使用 18sp 字号

#### Scenario: Card shows content preview
#### 场景：卡片显示内容预览

- **GIVEN** card is displayed in list
- **前置条件**：卡片在列表中显示
- **WHEN** viewing card
- **操作**：查看卡片
- **THEN** card SHALL show first 3 lines of content
- **预期结果**：卡片应显示内容的前 3 行
- **AND** content SHALL be truncated with "..."
- **并且**：内容应以"..."截断
- **AND** content SHALL use 14sp font size
- **并且**：内容应使用 14sp 字号

#### Scenario: Card shows metadata
#### 场景：卡片显示元数据

- **GIVEN** card is displayed in list
- **前置条件**：卡片在列表中显示
- **WHEN** viewing card
- **操作**：查看卡片
- **THEN** card SHALL show last updated time
- **预期结果**：卡片应显示最后更新时间
- **AND** time SHALL use relative format ("2小时前")
- **并且**：时间应使用相对格式（"2小时前"）
- **AND** metadata SHALL use 12sp font size
- **并且**：元数据应使用 12sp 字号

---

## 4. Pull-to-Refresh | 下拉刷新

### Requirement: Mobile SHALL support pull-to-refresh
### 需求：移动端应支持下拉刷新

Mobile SHALL support pull-to-refresh for card list.

移动端应支持下拉刷新卡片列表。

#### Scenario: Pull down shows refresh indicator
#### 场景：下拉显示刷新指示器

- **GIVEN** user is at top of list
- **前置条件**：用户在列表顶部
- **WHEN** user pulls down
- **操作**：用户下拉
- **THEN** refresh indicator SHALL appear
- **预期结果**：刷新指示器应出现
- **AND** indicator SHALL follow pull distance
- **并且**：指示器应跟随下拉距离

#### Scenario: Release triggers refresh
#### 场景：释放触发刷新

- **GIVEN** user pulled down past threshold
- **前置条件**：用户下拉超过阈值
- **WHEN** user releases
- **操作**：用户释放
- **THEN** system SHALL reload cards from API
- **预期结果**：系统应从 API 重新加载卡片
- **AND** indicator SHALL show loading animation
- **并且**：指示器应显示加载动画
- **AND** list SHALL update with new data
- **并且**：列表应更新为新数据

#### Scenario: Refresh completes within 2 seconds
#### 场景：刷新在 2 秒内完成

- **GIVEN** refresh is triggered
- **前置条件**：刷新已触发
- **WHEN** loading
- **操作**：加载中
- **THEN** refresh SHALL complete within 2 seconds
- **预期结果**：刷新应在 2 秒内完成
- **AND** indicator SHALL disappear smoothly
- **并且**：指示器应平滑消失

---

## 5. Empty State | 空状态

### Requirement: Mobile SHALL show empty state when no cards
### 需求：移动端应在无卡片时显示空状态

Mobile SHALL show empty state when user has no cards.

移动端应在用户无卡片时显示空状态。

#### Scenario: Empty state shows message
#### 场景：空状态显示消息

- **GIVEN** user has no cards
- **前置条件**：用户没有卡片
- **WHEN** viewing home screen
- **操作**：查看主屏幕
- **THEN** system SHALL show empty state
- **预期结果**：系统应显示空状态
- **AND** message SHALL say "还没有笔记"
- **并且**：消息应显示"还没有笔记"
- **AND** icon SHALL be displayed
- **并且**：应显示图标

#### Scenario: Empty state shows create button
#### 场景：空状态显示创建按钮

- **GIVEN** empty state is shown
- **前置条件**：空状态已显示
- **WHEN** viewing screen
- **操作**：查看屏幕
- **THEN** system SHALL show "创建第一张笔记" button
- **预期结果**：系统应显示"创建第一张笔记"按钮
- **AND** tapping button SHALL open editor
- **并且**：点击按钮应打开编辑器

---

## 6. Performance Requirements | 性能要求

### Requirement: Mobile list SHALL be performant
### 需求：移动端列表应满足性能要求

Mobile list SHALL meet performance requirements.

移动端列表应满足性能要求。

#### Scenario: List scrolling maintains 60fps
#### 场景：列表滚动保持 60fps

- **GIVEN** user scrolls list
- **前置条件**：用户滚动列表
- **WHEN** scrolling
- **操作**：滚动中
- **THEN** frame rate SHALL be 60fps
- **预期结果**：帧率应为 60fps
- **AND** no frame drops SHALL occur
- **并且**：不应有掉帧

#### Scenario: Cards load within 350ms
#### 场景：卡片在 350ms 内加载

- **GIVEN** user opens home screen
- **前置条件**：用户打开主屏幕
- **WHEN** loading cards
- **操作**：加载卡片
- **THEN** cards SHALL appear within 350ms
- **预期结果**：卡片应在 350ms 内出现
- **AND** loading indicator SHALL be shown
- **并且**：应显示加载指示器

---

**Last Updated** | **最后更新**: 2026-01-21
**Authors** | **作者**: CardMind Team
