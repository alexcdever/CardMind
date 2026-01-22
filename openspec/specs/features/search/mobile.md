# Mobile Search Specification | 移动端搜索规格

**Version** | **版本**: 1.0.0
**Status** | **状态**: Active | 已完成
**Dependencies** | **依赖**: [home_screen/shared.md](../home_screen/shared.md)

---

## 1. Overview | 概述

### 1.1 Goals | 目标

Define mobile search feature specifications to ensure:

定义移动端搜索功能规范，确保：

- Overlay mode providing focused experience | 覆盖模式提供专注体验
- Real-time search results | 实时搜索结果
- Smooth keyboard interaction | 流畅的键盘交互

### 1.2 Applicable Platforms | 适用平台

- Android
- iOS
- iPadOS (treated as mobile | 作为移动端处理)

---

## 2. Search Entry | 搜索入口

### Requirement: Mobile SHALL use search overlay | 需求：移动端应使用搜索覆盖模式

Mobile SHALL use search overlay mode.

移动端应使用搜索覆盖模式。

#### Scenario: Search icon in app bar | 场景：搜索图标在应用栏中

- **GIVEN** user is on home screen
- **前置条件**：用户在主屏幕上
- **WHEN** viewing app bar
- **操作**：查看应用栏
- **THEN** search icon SHALL be visible
- **预期结果**：搜索图标应可见
- **AND** icon SHALL be on right side
- **并且**：图标应在右侧

#### Scenario: Tapping icon opens overlay | 场景：点击图标打开覆盖层

- **GIVEN** user taps search icon
- **前置条件**：用户点击搜索图标
- **WHEN** icon is tapped
- **操作**：图标被点击
- **THEN** search overlay SHALL open
- **预期结果**：搜索覆盖层应打开
- **AND** search field SHALL have focus
- **并且**：搜索字段应获得焦点
- **AND** keyboard SHALL appear
- **并且**：键盘应出现

---

## 3. Search Overlay | 搜索覆盖层

### Requirement: Search overlay SHALL cover main content
### 需求：搜索覆盖层应覆盖主要内容

Search overlay SHALL cover main content.

搜索覆盖层应覆盖主要内容。

#### Scenario: Overlay covers card list
#### 场景：覆盖层覆盖卡片列表

- **GIVEN** search overlay is open
- **前置条件**：搜索覆盖层已打开
- **WHEN** viewing screen
- **操作**：查看屏幕
- **THEN** overlay SHALL cover card list
- **预期结果**：覆盖层应覆盖卡片列表
- **AND** search results SHALL replace list
- **并且**：搜索结果应替换列表

#### Scenario: Back button closes overlay
#### 场景：返回按钮关闭覆盖层

- **GIVEN** search overlay is open
- **前置条件**：搜索覆盖层已打开
- **WHEN** user taps back button
- **操作**：用户点击返回按钮
- **THEN** overlay SHALL close
- **预期结果**：覆盖层应关闭
- **AND** card list SHALL reappear
- **并且**：卡片列表应重新出现

---

## 4. Real-Time Search | 实时搜索

### Requirement: Search SHALL filter in real-time
### 需求：搜索应实时过滤

Search SHALL filter cards in real-time.

搜索应实时过滤卡片。

#### Scenario: Results update as user types
#### 场景：用户输入时结果更新

- **GIVEN** user types in search field
- **前置条件**：用户在搜索字段中输入
- **WHEN** user enters text
- **操作**：用户输入文本
- **THEN** results SHALL update immediately
- **预期结果**：结果应立即更新
- **AND** filtering SHALL be smooth
- **并且**：过滤应平滑

#### Scenario: No results shows message
#### 场景：无结果显示消息

- **GIVEN** search has no matches
- **前置条件**：搜索无匹配
- **WHEN** viewing results
- **操作**：查看结果
- **THEN** message SHALL say "未找到相关笔记"
- **预期结果**：消息应显示"未找到相关笔记"
- **AND** icon SHALL be displayed
- **并且**：图标应显示

#### Scenario: Tapping result opens card
#### 场景：点击结果打开卡片

- **GIVEN** search results are shown
- **前置条件**：搜索结果已显示
- **WHEN** user taps a result
- **操作**：用户点击结果
- **THEN** overlay SHALL close
- **预期结果**：覆盖层应关闭
- **AND** card SHALL open in editor
- **并且**：卡片应在编辑器中打开

---

**Last Updated** | **最后更新**: 2026-01-21
**Authors** | **作者**: CardMind Team
