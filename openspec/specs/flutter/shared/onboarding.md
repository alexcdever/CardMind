# Onboarding Flow Specification

## 📋 规格编号: SP-FLT-SHR-001
**版本**: 1.0.0
**状态**: 已完成
**依赖**: 
- SP-SPM-001 (单池模型核心规格)
- SP-DEV-002 (DeviceConfig 规格)
- SP-CARD-004 (CardStore 规格)

---

## 1. 概述

### 1.1 目标
定义 CardMind 应用初始化流程规范，确保：
- 用户首次使用时正确引导
- 与 DeviceConfig 的 join_pool 机制无缝集成
- 本地存储和同步服务正确初始化
- 跨平台一致的初始化体验

### 1.2 适用平台
- Android
- iOS
- iPadOS
- macOS
- Windows
- Linux

---

## 2. 初始化流程

### Requirement: App SHALL detect first launch

应用 SHALL 检测首次启动。

#### Scenario: First launch shows welcome screen
- **GIVEN** user opens app for first time
- **WHEN** app starts
- **THEN** welcome screen SHALL be displayed
- **AND** device config SHALL not exist

#### Scenario: Subsequent launch shows home screen
- **GIVEN** user has completed onboarding
- **WHEN** app starts
- **THEN** home screen SHALL be displayed
- **AND** device config SHALL exist

---

## 3. 欢迎页

### Requirement: Welcome screen SHALL introduce app

欢迎页 SHALL 介绍应用。

#### Scenario: Welcome screen shows app name
- **GIVEN** welcome screen is displayed
- **WHEN** viewing screen
- **THEN** app name "CardMind" SHALL be shown
- **AND** app description SHALL be shown

#### Scenario: Get Started button is available
- **GIVEN** welcome screen is displayed
- **WHEN** viewing screen
- **THEN** "开始使用" button SHALL be visible
- **AND** button SHALL be enabled

---

## 4. 池创建流程

### Requirement: User SHALL create or join pool

用户 SHALL 创建或加入池。

#### Scenario: User can create new pool
- **GIVEN** user taps "开始使用"
- **WHEN** action selection screen appears
- **THEN** "创建新池" option SHALL be available
- **AND** tapping option SHALL show pool creation form

#### Scenario: Pool creation requires name
- **GIVEN** pool creation form is shown
- **WHEN** user enters pool name
- **THEN** name SHALL be validated
- **AND** empty name SHALL be rejected

#### Scenario: Pool creation succeeds
- **GIVEN** user enters valid pool name
- **WHEN** user confirms creation
- **THEN** pool SHALL be created
- **AND** device SHALL join pool
- **AND** app SHALL navigate to home screen

---

## 5. 初始化完成

### Requirement: Initialization SHALL complete successfully

初始化 SHALL 成功完成。

#### Scenario: Device config is saved
- **GIVEN** pool creation succeeds
- **WHEN** initialization completes
- **THEN** device config SHALL be saved
- **AND** pool ID SHALL be stored

#### Scenario: Card store is initialized
- **GIVEN** pool creation succeeds
- **WHEN** initialization completes
- **THEN** card store SHALL be initialized
- **AND** ready to accept cards

---

**最后更新**: 2026-01-19
**作者**: CardMind Team
