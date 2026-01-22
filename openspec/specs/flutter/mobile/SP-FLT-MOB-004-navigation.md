# Mobile Navigation Specification

## 📋 规格编号: SP-FLT-MOB-004
**版本**: 1.0.0
**状态**: 已完成
**依赖**: 
- SP-FLT-MOB-* (移动端 UI 交互规格)
- SP-ADAPT-004 (移动端 UI 模式规格)

---

## 1. 概述

### 1.1 目标
定义移动端导航系统规范，确保：
- 底部导航栏易于触达
- 标签切换流畅
- 符合移动端导航习惯

### 1.2 适用平台
- Android
- iOS
- iPadOS（作为移动端处理）

---

## 2. 底部导航栏

### Requirement: Mobile SHALL use bottom navigation

移动端 SHALL 使用底部导航栏进行主要功能切换。

#### Scenario: Bottom navigation has 3 tabs
- **GIVEN** user is on home screen
- **WHEN** viewing screen
- **THEN** bottom navigation SHALL have 3 tabs
- **AND** tabs SHALL be: "笔记", "设备", "设置"

#### Scenario: Active tab is highlighted
- **GIVEN** user is on a tab
- **WHEN** viewing navigation
- **THEN** active tab SHALL use primary color
- **AND** inactive tabs SHALL use gray

#### Scenario: Tapping tab switches content
- **GIVEN** user is on "笔记" tab
- **WHEN** user taps "设备" tab
- **THEN** content SHALL switch to device view
- **AND** transition SHALL be smooth

---

## 3. 标签内容

### Requirement: Each tab SHALL show appropriate content

每个标签 SHALL 显示对应的内容。

#### Scenario: Notes tab shows card list
- **GIVEN** user taps "笔记" tab
- **WHEN** tab loads
- **THEN** card list SHALL be displayed
- **AND** FAB SHALL be visible

#### Scenario: Devices tab shows device manager
- **GIVEN** user taps "设备" tab
- **WHEN** tab loads
- **THEN** device manager SHALL be displayed
- **AND** current device SHALL be shown

#### Scenario: Settings tab shows settings
- **GIVEN** user taps "设置" tab
- **WHEN** tab loads
- **THEN** settings list SHALL be displayed
- **AND** theme toggle SHALL be visible

---

## 4. 导航状态

### Requirement: Navigation state SHALL be preserved

导航状态 SHALL 在标签切换时保持。

#### Scenario: Switching tabs preserves scroll position
- **GIVEN** user scrolled in "笔记" tab
- **WHEN** user switches to "设备" and back
- **THEN** scroll position SHALL be preserved
- **AND** list SHALL not reload

#### Scenario: Tab badge shows notifications
- **GIVEN** there are unsynced cards
- **WHEN** viewing navigation
- **THEN** "笔记" tab MAY show badge
- **AND** badge SHALL show count

---

**最后更新**: 2026-01-19
**作者**: CardMind Team
