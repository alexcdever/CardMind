# Onboarding Flow Specification (Shared) | 应用引导流程规格（通用）

**Version** | **版本**: 1.0.0
**Status** | **状态**: Active | 已完成
**Dependencies** | **依赖**: [card_store.md](../../architecture/storage/card_store.md), [pool_model.md](../../domain/pool/model.md)

---

## 1. Overview | 概述

### 1.1 Goals | 目标

Define CardMind application initialization flow specifications to ensure:

定义 CardMind 应用初始化流程规范，确保：

- Proper guidance for first-time users | 用户首次使用时正确引导
- Seamless integration with DeviceConfig's join_pool mechanism | 与 DeviceConfig 的 join_pool 机制无缝集成
- Correct initialization of local storage and sync services | 本地存储和同步服务正确初始化
- Consistent initialization experience across platforms | 跨平台一致的初始化体验

### 1.2 Applicable Platforms | 适用平台

- Android
- iOS
- iPadOS
- macOS
- Windows
- Linux

---

## 2. Initialization Flow | 初始化流程

### Requirement: App SHALL detect first launch | 需求：应用应检测首次启动

App SHALL detect first launch.

应用应检测首次启动。

#### Scenario: First launch shows welcome screen | 场景：首次启动显示欢迎页

- **GIVEN** user opens app for first time
- **前置条件**：用户首次打开应用
- **WHEN** app starts
- **操作**：应用启动
- **THEN** welcome screen SHALL be displayed
- **预期结果**：欢迎页应显示
- **AND** device config SHALL not exist
- **并且**：设备配置不应存在

#### Scenario: Subsequent launch shows home screen | 场景：后续启动显示主屏幕

- **GIVEN** user has completed onboarding
- **前置条件**：用户已完成引导
- **WHEN** app starts
- **操作**：应用启动
- **THEN** home screen SHALL be displayed
- **预期结果**：主屏幕应显示
- **AND** device config SHALL exist
- **并且**：设备配置应存在

---

## 3. Welcome Screen | 欢迎页

### Requirement: Welcome screen SHALL introduce app | 需求：欢迎页应介绍应用

Welcome screen SHALL introduce app.

欢迎页应介绍应用。

#### Scenario: Welcome screen shows app name | 场景：欢迎页显示应用名称

- **GIVEN** welcome screen is displayed
- **前置条件**：欢迎页已显示
- **WHEN** viewing screen
- **操作**：查看屏幕
- **THEN** app name "CardMind" SHALL be shown
- **预期结果**：应用名称 "CardMind" 应显示
- **AND** app description SHALL be shown
- **并且**：应用描述应显示

#### Scenario: Get Started button is available | 场景：开始使用按钮可用

- **GIVEN** welcome screen is displayed
- **前置条件**：欢迎页已显示
- **WHEN** viewing screen
- **操作**：查看屏幕
- **THEN** "开始使用" button SHALL be visible
- **预期结果**："开始使用"按钮应可见
- **AND** button SHALL be enabled
- **并且**：按钮应启用

---

## 4. Pool Creation Flow | 池创建流程

### Requirement: User SHALL create or join pool | 需求：用户应创建或加入池

User SHALL create or join pool.

用户应创建或加入池。

#### Scenario: User can create new pool | 场景：用户可以创建新池

- **GIVEN** user taps "开始使用"
- **前置条件**：用户点击"开始使用"
- **WHEN** action selection screen appears
- **操作**：操作选择屏幕出现
- **THEN** "创建新池" option SHALL be available
- **预期结果**："创建新池"选项应可用
- **AND** tapping option SHALL show pool creation form
- **并且**：点击选项应显示池创建表单

#### Scenario: Pool creation requires name | 场景：池创建需要名称

- **GIVEN** pool creation form is shown
- **前置条件**：池创建表单已显示
- **WHEN** user enters pool name
- **操作**：用户输入池名称
- **THEN** name SHALL be validated
- **预期结果**：名称应验证
- **AND** empty name SHALL be rejected
- **并且**：空名称应被拒绝

#### Scenario: Pool creation succeeds | 场景：池创建成功

- **GIVEN** user enters valid pool name
- **前置条件**：用户输入有效的池名称
- **WHEN** user confirms creation
- **操作**：用户确认创建
- **THEN** pool SHALL be created
- **预期结果**：池应被创建
- **AND** device SHALL join pool
- **并且**：设备应加入池
- **AND** app SHALL navigate to home screen
- **并且**：应用应导航到主屏幕

---

## 5. Initialization Complete | 初始化完成

### Requirement: Initialization SHALL complete successfully | 需求：初始化应成功完成

Initialization SHALL complete successfully.

初始化应成功完成。

#### Scenario: Device config is saved | 场景：设备配置已保存

- **GIVEN** pool creation succeeds
- **前置条件**：池创建成功
- **WHEN** initialization completes
- **操作**：初始化完成
- **THEN** device config SHALL be saved
- **预期结果**：设备配置应保存
- **AND** pool ID SHALL be stored
- **并且**：池 ID 应存储

#### Scenario: Card store is initialized | 场景：卡片存储已初始化

- **GIVEN** pool creation succeeds
- **前置条件**：池创建成功
- **WHEN** initialization completes
- **操作**：初始化完成
- **THEN** card store SHALL be initialized
- **预期结果**：卡片存储应初始化
- **AND** ready to accept cards
- **并且**：准备接受卡片

---

**Last Updated** | **最后更新**: 2026-01-21
**Authors** | **作者**: CardMind Team
