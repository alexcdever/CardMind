# Mobile Navigation Specification | 移动端导航规格

**版本**: 1.0.0
**状态**: 已完成
**依赖**: [adaptive_ui_components.md](../../ui_system/adaptive_ui_components.md)

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

### Requirement: Mobile SHALL use bottom navigation | 需求：移动端应使用底部导航栏

移动端 SHALL 使用底部导航栏进行主要功能切换。

#### Scenario: Bottom navigation has 3 tabs | 场景：底部导航栏有 3 个标签
- **GIVEN** user is on home screen
- **WHEN** viewing screen
- **THEN** bottom navigation SHALL have 3 tabs
- **AND** tabs SHALL be: "笔记", "设备", "设置"

#### Scenario: Active tab is highlighted | 场景：活动标签高亮显示
- **GIVEN** user is on a tab
- **WHEN** viewing navigation
- **THEN** active tab SHALL use primary color
- **AND** inactive tabs SHALL use gray

#### Scenario: Tapping tab switches content | 场景：点击标签切换内容
- **GIVEN** user is on "笔记" tab
- **WHEN** user taps "设备" tab
- **THEN** content SHALL switch to device view
- **AND** transition SHALL be smooth

---

## 3. 标签内容

### Requirement: Each tab SHALL show appropriate content | 需求：每个标签应显示对应的内容

每个标签 SHALL 显示对应的内容。

#### Scenario: Notes tab shows card list | 场景：笔记标签显示卡片列表
- **GIVEN** user taps "笔记" tab
- **WHEN** tab loads
- **THEN** card list SHALL be displayed
- **AND** FAB SHALL be visible

#### Scenario: Devices tab shows device manager | 场景：设备标签显示设备管理器
- **GIVEN** user taps "设备" tab
- **WHEN** tab loads
- **THEN** device manager SHALL be displayed
- **AND** current device SHALL be shown

#### Scenario: Settings tab shows settings | 场景：设置标签显示设置
- **GIVEN** user taps "设置" tab
- **WHEN** tab loads
- **THEN** settings list SHALL be displayed
- **AND** theme toggle SHALL be visible

---

## 4. 导航状态

### Requirement: Navigation state SHALL be preserved | 需求：导航状态应保持

导航状态 SHALL 在标签切换时保持。

#### Scenario: Switching tabs preserves scroll position | 场景：切换标签保持滚动位置
- **GIVEN** user scrolled in "笔记" tab
- **WHEN** user switches to "设备" and back
- **THEN** scroll position SHALL be preserved
- **AND** list SHALL not reload

#### Scenario: Tab badge shows notifications | 场景：标签徽章显示通知
- **GIVEN** there are unsynced cards
- **WHEN** viewing navigation
- **THEN** "笔记" tab MAY show badge
- **AND** badge SHALL show count

---

**最后更新**: 2026-01-19
**作者**: CardMind Team
