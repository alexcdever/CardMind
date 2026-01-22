# Mobile Navigation Specification | 移动端导航规格

**Version** | **版本**: 1.0.0
**Status** | **状态**: Completed | 已完成
**Dependencies** | **依赖**: [adaptive_ui_components.md](../../ui_system/adaptive_ui_components.md)

---

## 1. Overview | 概述

### 1.1 Goals | 目标

Define mobile navigation system specifications to ensure:

定义移动端导航系统规范，确保：

- Bottom navigation bar is easy to reach | 底部导航栏易于触达
- Tab switching is smooth | 标签切换流畅
- Conforms to mobile navigation habits | 符合移动端导航习惯

### 1.2 Applicable Platforms | 适用平台
- Android
- iOS
- iPadOS (treated as mobile) | iPadOS（作为移动端处理）

---

## 2. Bottom Navigation Bar | 底部导航栏

### Requirement: Mobile SHALL use bottom navigation | 需求：移动端应使用底部导航栏

Mobile SHALL use bottom navigation bar for main function switching.

移动端应使用底部导航栏进行主要功能切换。

#### Scenario: Bottom navigation has 3 tabs | 场景：底部导航栏有 3 个标签
- **GIVEN** user is on home screen
- **前置条件**：用户在主屏幕
- **WHEN** viewing screen
- **操作**：查看屏幕
- **THEN** bottom navigation SHALL have 3 tabs
- **预期结果**：底部导航栏应有 3 个标签
- **AND** tabs SHALL be: "笔记", "设备", "设置"
- **并且**：标签应为："笔记"、"设备"、"设置"

#### Scenario: Active tab is highlighted | 场景：活动标签高亮显示
- **GIVEN** user is on a tab
- **前置条件**：用户在某个标签上
- **WHEN** viewing navigation
- **操作**：查看导航
- **THEN** active tab SHALL use primary color
- **预期结果**：活动标签应使用主色
- **AND** inactive tabs SHALL use gray
- **并且**：非活动标签应使用灰色

#### Scenario: Tapping tab switches content | 场景：点击标签切换内容
- **GIVEN** user is on "笔记" tab
- **前置条件**：用户在"笔记"标签
- **WHEN** user taps "设备" tab
- **操作**：用户点击"设备"标签
- **THEN** content SHALL switch to device view
- **预期结果**：内容应切换到设备视图
- **AND** transition SHALL be smooth
- **并且**：过渡应流畅

---

## 3. Tab Content | 标签内容

### Requirement: Each tab SHALL show appropriate content | 需求：每个标签应显示对应的内容

Each tab SHALL display corresponding content.

每个标签应显示对应的内容。

#### Scenario: Notes tab shows card list | 场景：笔记标签显示卡片列表
- **GIVEN** user taps "笔记" tab
- **前置条件**：用户点击"笔记"标签
- **WHEN** tab loads
- **操作**：标签加载
- **THEN** card list SHALL be displayed
- **预期结果**：卡片列表应显示
- **AND** FAB SHALL be visible
- **并且**：FAB 应可见

#### Scenario: Devices tab shows device manager | 场景：设备标签显示设备管理器
- **GIVEN** user taps "设备" tab
- **前置条件**：用户点击"设备"标签
- **WHEN** tab loads
- **操作**：标签加载
- **THEN** device manager SHALL be displayed
- **预期结果**：设备管理器应显示
- **AND** current device SHALL be shown
- **并且**：当前设备应显示

#### Scenario: Settings tab shows settings | 场景：设置标签显示设置
- **GIVEN** user taps "设置" tab
- **前置条件**：用户点击"设置"标签
- **WHEN** tab loads
- **操作**：标签加载
- **THEN** settings list SHALL be displayed
- **预期结果**：设置列表应显示
- **AND** theme toggle SHALL be visible
- **并且**：主题切换应可见

---

## 4. Navigation State | 导航状态

### Requirement: Navigation state SHALL be preserved | 需求：导航状态应保持

Navigation state SHALL be preserved when switching tabs.

导航状态应在标签切换时保持。

#### Scenario: Switching tabs preserves scroll position | 场景：切换标签保持滚动位置
- **GIVEN** user scrolled in "笔记" tab
- **前置条件**：用户在"笔记"标签中滚动
- **WHEN** user switches to "设备" and back
- **操作**：用户切换到"设备"再返回
- **THEN** scroll position SHALL be preserved
- **预期结果**：滚动位置应保持
- **AND** list SHALL not reload
- **并且**：列表不应重新加载

#### Scenario: Tab badge shows notifications | 场景：标签徽章显示通知
- **GIVEN** there are unsynced cards
- **前置条件**：有未同步的卡片
- **WHEN** viewing navigation
- **操作**：查看导航
- **THEN** "笔记" tab MAY show badge
- **预期结果**："笔记"标签可显示徽章
- **AND** badge SHALL show count
- **并且**：徽章应显示数量

---

**Last Updated** | **最后更新**: 2026-01-19
**Authors** | **作者**: CardMind Team
