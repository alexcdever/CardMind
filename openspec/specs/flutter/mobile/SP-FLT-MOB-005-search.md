# Mobile Search Specification

## 📋 规格编号: SP-FLT-MOB-005
**版本**: 1.0.0
**状态**: 已完成
**依赖**: 
- SP-FLT-MOB-* (移动端 UI 交互规格)
- SP-FLT-SHR-002 (主页交互规格)

---

## 1. 概述

### 1.1 目标
定义移动端搜索功能规范，确保：
- 覆盖模式提供专注体验
- 实时搜索结果
- 流畅的键盘交互

### 1.2 适用平台
- Android
- iOS
- iPadOS（作为移动端处理）

---

## 2. 搜索入口

### Requirement: Mobile SHALL use search overlay

移动端 SHALL 使用搜索覆盖模式。

#### Scenario: Search icon in app bar
- **GIVEN** user is on home screen
- **WHEN** viewing app bar
- **THEN** search icon SHALL be visible
- **AND** icon SHALL be on right side

#### Scenario: Tapping icon opens overlay
- **GIVEN** user taps search icon
- **WHEN** icon is tapped
- **THEN** search overlay SHALL open
- **AND** search field SHALL have focus
- **AND** keyboard SHALL appear

---

## 3. 搜索覆盖层

### Requirement: Search overlay SHALL cover main content

搜索覆盖层 SHALL 覆盖主要内容。

#### Scenario: Overlay covers card list
- **GIVEN** search overlay is open
- **WHEN** viewing screen
- **THEN** overlay SHALL cover card list
- **AND** search results SHALL replace list

#### Scenario: Back button closes overlay
- **GIVEN** search overlay is open
- **WHEN** user taps back button
- **THEN** overlay SHALL close
- **AND** card list SHALL reappear

---

## 4. 实时搜索

### Requirement: Search SHALL filter in real-time

搜索 SHALL 实时过滤卡片。

#### Scenario: Results update as user types
- **GIVEN** user types in search field
- **WHEN** user enters text
- **THEN** results SHALL update immediately
- **AND** filtering SHALL be smooth

#### Scenario: No results shows message
- **GIVEN** search has no matches
- **WHEN** viewing results
- **THEN** message SHALL say "未找到相关笔记"
- **AND** icon SHALL be displayed

#### Scenario: Tapping result opens card
- **GIVEN** search results are shown
- **WHEN** user taps a result
- **THEN** overlay SHALL close
- **AND** card SHALL open in editor

---

**最后更新**: 2026-01-19
**作者**: CardMind Team
