# Mobile FAB Specification

## 📋 规格编号: SP-FLT-MOB-006
**版本**: 1.0.0
**状态**: 已完成
**依赖**: 
- SP-FLT-MOB-* (移动端 UI 交互规格)
- SP-ADAPT-004 (移动端 UI 模式规格)

---

## 1. 概述

### 1.1 目标
定义移动端浮动操作按钮（FAB）规范，确保：
- 易于触达的位置
- 清晰的视觉反馈
- 符合 Material Design 规范

### 1.2 适用平台
- Android
- iOS
- iPadOS（作为移动端处理）

---

## 2. FAB 位置和样式

### Requirement: Mobile SHALL use FAB for primary action

移动端 SHALL 使用 FAB 作为主要操作入口。

#### Scenario: FAB is at bottom-right
- **GIVEN** user is on home screen
- **WHEN** viewing screen
- **THEN** FAB SHALL be at bottom-right corner
- **AND** FAB SHALL be 56x56 logical pixels
- **AND** FAB SHALL use primary color

#### Scenario: FAB shows plus icon
- **GIVEN** FAB is displayed
- **WHEN** viewing FAB
- **THEN** FAB SHALL show "+" icon
- **AND** icon SHALL be white
- **AND** icon SHALL be 24x24 logical pixels

#### Scenario: FAB has elevation
- **GIVEN** FAB is displayed
- **WHEN** viewing FAB
- **THEN** FAB SHALL have 6dp elevation
- **AND** shadow SHALL be visible

---

## 3. FAB 交互

### Requirement: FAB SHALL respond to touch

FAB SHALL 响应触摸交互。

#### Scenario: Tapping FAB opens editor
- **GIVEN** user taps FAB
- **WHEN** FAB is tapped
- **THEN** fullscreen editor SHALL open
- **AND** new card SHALL be created
- **AND** title field SHALL have focus

#### Scenario: FAB shows ripple effect
- **GIVEN** user taps FAB
- **WHEN** touch occurs
- **THEN** ripple effect SHALL appear
- **AND** ripple SHALL be white

#### Scenario: FAB is accessible within 1 second
- **GIVEN** home screen loads
- **WHEN** 1 second passes
- **THEN** FAB SHALL be interactive
- **AND** tapping SHALL work

---

## 4. FAB 可访问性

### Requirement: FAB SHALL be accessible

FAB SHALL 满足可访问性要求。

#### Scenario: FAB has minimum touch target
- **GIVEN** FAB is displayed
- **WHEN** measuring touch target
- **THEN** touch target SHALL be at least 48x48 logical pixels
- **AND** target SHALL extend beyond visual bounds

#### Scenario: FAB has semantic label
- **GIVEN** screen reader is enabled
- **WHEN** FAB is focused
- **THEN** label SHALL announce "创建新笔记"
- **AND** announcement SHALL be clear

---

**最后更新**: 2026-01-19
**作者**: CardMind Team
