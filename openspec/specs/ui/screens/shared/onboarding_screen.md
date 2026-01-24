# Onboarding Screen Specification (Shared)
# 应用引导屏幕规格（通用）

**Version**: 1.0.0
**版本**: 1.0.0

**Status**: Active
**状态**: 生效中

**Dependencies**: [pool/model.md](../../domain/pool/model.md), [device_config.md](../../architecture/storage/device_config.md)
**依赖**: [pool/model.md](../../domain/pool/model.md), [device_config.md](../../architecture/storage/device_config.md)

**Related Tests**: `test/screens/onboarding_screen_test.dart`
**相关测试**: `test/screens/onboarding_screen_test.dart`

---

## Overview
## 概述

This specification defines the onboarding flow that guides first-time users through application initialization. The onboarding experience is shared across all platforms (mobile and desktop) with platform-specific UI adaptations.

本规格定义了引导首次用户完成应用初始化的引导流程。引导体验在所有平台（移动端和桌面端）之间共享，并具有平台特定的 UI 适配。

---

## Requirement: Detect first launch
## 需求：检测首次启动

The system SHALL detect whether this is the user's first launch of the application.

系统应检测这是否是用户首次启动应用程序。

### Scenario: First launch shows welcome screen
### 场景：首次启动显示欢迎屏幕

- **GIVEN**: user opens app for the first time
- **前置条件**：用户首次打开应用
- **WHEN**: app starts
- **操作**：应用启动
- **THEN**: the system SHALL check if device config exists
- **预期结果**：系统应检查设备配置是否存在
- **AND**: display welcome screen if config does not exist
- **并且**：如果配置不存在则显示欢迎屏幕

### Scenario: Subsequent launch shows home screen
### 场景：后续启动显示主屏幕

- **GIVEN**: user has completed onboarding
- **前置条件**：用户已完成引导
- **WHEN**: app starts
- **操作**：应用启动
- **THEN**: the system SHALL find existing device config
- **预期结果**：系统应找到现有的设备配置
- **AND**: navigate directly to home screen
- **并且**：直接导航到主屏幕

---

## Requirement: Display welcome screen
## 需求：显示欢迎屏幕

The system SHALL display a welcome screen introducing the application.

系统应显示介绍应用程序的欢迎屏幕。

### Scenario: Show app introduction
### 场景：显示应用介绍

- **GIVEN**: welcome screen is displayed
- **前置条件**：欢迎屏幕已显示
- **WHEN**: user views screen
- **操作**：用户查看屏幕
- **THEN**: the system SHALL show app name "CardMind"
- **预期结果**：系统应显示应用名称 "CardMind"
- **AND**: display app logo or illustration
- **并且**：显示应用徽标或插图
- **AND**: show brief description of app purpose
- **并且**：显示应用目的的简要描述

### Scenario: Provide get started action
### 场景：提供开始使用操作

- **GIVEN**: welcome screen is displayed
- **前置条件**：欢迎屏幕已显示
- **WHEN**: user views screen
- **操作**：用户查看屏幕
- **THEN**: the system SHALL show "开始使用" button
- **预期结果**：系统应显示"开始使用"按钮
- **AND**: button SHALL be prominently placed
- **并且**：按钮应放置在显眼位置
- **AND**: button SHALL be enabled
- **并且**：按钮应启用

---

## Requirement: Guide pool creation
## 需求：引导池创建

The system SHALL guide users through creating their first pool.

系统应引导用户创建他们的第一个池。

### Scenario: Show pool creation options
### 场景：显示池创建选项

- **GIVEN**: user taps "开始使用" button
- **前置条件**：用户点击"开始使用"按钮
- **WHEN**: button is tapped
- **操作**：按钮被点击
- **THEN**: the system SHALL show pool creation screen
- **预期结果**：系统应显示池创建屏幕
- **AND**: explain what a pool is
- **并且**：解释什么是池
- **AND**: show "创建新池" option
- **并且**：显示"创建新池"选项

### Scenario: Create new pool
### 场景：创建新池

- **GIVEN**: user selects "创建新池"
- **前置条件**：用户选择"创建新池"
- **WHEN**: option is selected
- **操作**：选项被选择
- **THEN**: the system SHALL show pool creation form
- **预期结果**：系统应显示池创建表单
- **AND**: provide input field for pool name
- **并且**：提供池名称输入框
- **AND**: suggest default name based on device name
- **并且**：根据设备名称建议默认名称

### Scenario: Validate pool name
### 场景：验证池名称

- **GIVEN**: user enters pool name
- **前置条件**：用户输入池名称
- **WHEN**: name is entered
- **操作**：名称被输入
- **THEN**: the system SHALL validate the name
- **预期结果**：系统应验证名称
- **AND**: reject empty names
- **并且**：拒绝空名称
- **AND**: show validation error if invalid
- **并且**：如果无效则显示验证错误

### Scenario: Complete pool creation
### 场景：完成池创建

- **GIVEN**: user enters valid pool name and confirms
- **前置条件**：用户输入有效的池名称并确认
- **WHEN**: creation is confirmed
- **操作**：创建被确认
- **THEN**: the system SHALL create the pool
- **预期结果**：系统应创建池
- **AND**: join the device to the pool
- **并且**：将设备加入池
- **AND**: save device configuration
- **并且**：保存设备配置
- **AND**: initialize card store
- **并且**：初始化卡片存储
- **AND**: navigate to home screen
- **并且**：导航到主屏幕
- **AND**: show success message "池已创建"
- **并且**：显示成功消息"池已创建"

---

## Requirement: Handle onboarding errors
## 需求：处理引导错误

The system SHALL handle errors during onboarding gracefully.

系统应优雅地处理引导期间的错误。

### Scenario: Show error on pool creation failure
### 场景：池创建失败时显示错误

- **GIVEN**: pool creation fails
- **前置条件**：池创建失败
- **WHEN**: error occurs
- **操作**：错误发生
- **THEN**: the system SHALL show error message
- **预期结果**：系统应显示错误消息
- **AND**: allow user to retry
- **并且**：允许用户重试
- **AND**: keep user on creation screen
- **并且**：保持用户在创建屏幕上

---

## Requirement: Support platform-specific UI
## 需求：支持平台特定的 UI

The system SHALL adapt onboarding UI to platform conventions.

系统应使引导 UI 适应平台约定。

### Scenario: Mobile onboarding uses full-screen flow
### 场景：移动端引导使用全屏流程

- **GIVEN**: user is on mobile device
- **前置条件**：用户在移动设备上
- **WHEN**: onboarding starts
- **操作**：引导开始
- **THEN**: the system SHALL use full-screen pages
- **预期结果**：系统应使用全屏页面
- **AND**: use bottom buttons for navigation
- **并且**：使用底部按钮进行导航
- **AND**: support swipe gestures between steps
- **并且**：支持步骤之间的滑动手势

### Scenario: Desktop onboarding uses centered dialog
### 场景：桌面端引导使用居中对话框

- **GIVEN**: user is on desktop device
- **前置条件**：用户在桌面设备上
- **WHEN**: onboarding starts
- **操作**：引导开始
- **THEN**: the system SHALL use centered dialog or window
- **预期结果**：系统应使用居中对话框或窗口
- **AND**: use standard dialog buttons
- **并且**：使用标准对话框按钮
- **AND**: support keyboard navigation
- **并且**：支持键盘导航

---

## Test Coverage
## 测试覆盖

**Test File**: `test/screens/onboarding_screen_test.dart`
**测试文件**: `test/screens/onboarding_screen_test.dart`

**Widget Tests**:
**组件测试**:
- `it_should_detect_first_launch()` - Detect first launch
- `it_should_detect_first_launch()` - 检测首次启动
- `it_should_show_welcome_screen()` - Show welcome screen
- `it_should_show_welcome_screen()` - 显示欢迎屏幕
- `it_should_navigate_to_home_on_subsequent_launch()` - Navigate to home on subsequent launch
- `it_should_navigate_to_home_on_subsequent_launch()` - 后续启动导航到主屏幕
- `it_should_show_app_introduction()` - Show app introduction
- `it_should_show_app_introduction()` - 显示应用介绍
- `it_should_provide_get_started_button()` - Provide get started button
- `it_should_provide_get_started_button()` - 提供开始使用按钮
- `it_should_show_pool_creation_options()` - Show pool creation options
- `it_should_show_pool_creation_options()` - 显示池创建选项
- `it_should_create_new_pool()` - Create new pool
- `it_should_create_new_pool()` - 创建新池
- `it_should_validate_pool_name()` - Validate pool name
- `it_should_validate_pool_name()` - 验证池名称
- `it_should_complete_pool_creation()` - Complete pool creation
- `it_should_complete_pool_creation()` - 完成池创建
- `it_should_handle_creation_error()` - Handle creation error
- `it_should_handle_creation_error()` - 处理创建错误
- `it_should_adapt_to_mobile()` - Adapt UI to mobile
- `it_should_adapt_to_mobile()` - 适配移动端 UI
- `it_should_adapt_to_desktop()` - Adapt UI to desktop
- `it_should_adapt_to_desktop()` - 适配桌面端 UI

**Acceptance Criteria**:
**验收标准**:
- [ ] All widget tests pass
- [ ] 所有组件测试通过
- [ ] First launch detection works correctly
- [ ] 首次启动检测正常工作
- [ ] Pool creation flow is intuitive
- [ ] 池创建流程直观
- [ ] Error handling is graceful
- [ ] 错误处理优雅
- [ ] Platform-specific UI adapts correctly
- [ ] 平台特定 UI 正确适配
- [ ] Code review approved
- [ ] 代码审查通过
- [ ] Documentation updated
- [ ] 文档已更新

---

## Related Documents
## 相关文档

**Related Specs**:
**相关规格**:
- [pool/model.md](../../domain/pool/model.md) - Pool domain model
- [pool/model.md](../../domain/pool/model.md) - 池领域模型
- [device_config.md](../../architecture/storage/device_config.md) - Device configuration
- [device_config.md](../../architecture/storage/device_config.md) - 设备配置
- [home_screen.md](../mobile/home_screen.md) - Mobile home screen
- [home_screen.md](../mobile/home_screen.md) - 移动端主屏幕
- [home_screen.md](../desktop/home_screen.md) - Desktop home screen
- [home_screen.md](../desktop/home_screen.md) - 桌面端主屏幕

---

**Last Updated**: 2026-01-23
**最后更新**: 2026-01-23

**Authors**: CardMind Team
**作者**: CardMind Team
