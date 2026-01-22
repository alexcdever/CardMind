# Mobile Gestures Specification

## 📋 规格编号: SP-FLT-MOB-003
**版本**: 1.0.0
**状态**: 已完成
**依赖**: 
- SP-FLT-MOB-* (移动端 UI 交互规格)
- SP-ADAPT-004 (移动端 UI 模式规格)

---

## 1. 概述

### 1.1 目标
定义移动端手势交互规范，确保：
- 流畅的滑动手势
- 直观的长按操作
- 符合平台习惯的手势行为

### 1.2 适用平台
- Android
- iOS
- iPadOS（作为移动端处理）

---

## 2. 滑动手势

### Requirement: Mobile SHALL support swipe gestures

移动端 SHALL 支持滑动手势进行快速操作。

#### Scenario: Swipe left reveals delete
- **GIVEN** user views card list
- **WHEN** user swipes left on card
- **THEN** delete button SHALL be revealed
- **AND** card SHALL slide left smoothly
- **AND** button SHALL be red

#### Scenario: Swipe right dismisses action
- **GIVEN** delete button is revealed
- **WHEN** user swipes right
- **THEN** button SHALL be hidden
- **AND** card SHALL slide back

#### Scenario: Tapping delete removes card
- **GIVEN** delete button is revealed
- **WHEN** user taps delete
- **THEN** card SHALL be soft-deleted
- **AND** card SHALL animate out
- **AND** snackbar SHALL show "已删除"

---

## 3. 长按手势

### Requirement: Mobile SHALL support long-press

移动端 SHALL 支持长按手势打开上下文菜单。

#### Scenario: Long-press shows context menu
- **GIVEN** user views card list
- **WHEN** user long-presses card
- **THEN** context menu SHALL appear
- **AND** menu SHALL include: "编辑", "删除", "分享"

#### Scenario: Context menu positioned near touch
- **GIVEN** context menu is shown
- **WHEN** viewing menu
- **THEN** menu SHALL appear near touch point
- **AND** menu SHALL not extend off screen

#### Scenario: Tapping outside dismisses menu
- **GIVEN** context menu is shown
- **WHEN** user taps outside
- **THEN** menu SHALL close
- **AND** no action SHALL occur

---

## 4. 下拉刷新

### Requirement: Mobile SHALL support pull-to-refresh

移动端 SHALL 支持下拉刷新手势。

#### Scenario: Pull down shows indicator
- **GIVEN** user is at top of list
- **WHEN** user pulls down
- **THEN** refresh indicator SHALL appear
- **AND** indicator SHALL follow pull distance

#### Scenario: Release triggers refresh
- **GIVEN** user pulled past threshold
- **WHEN** user releases
- **THEN** system SHALL reload cards
- **AND** indicator SHALL show loading

---

**最后更新**: 2026-01-19
**作者**: CardMind Team
