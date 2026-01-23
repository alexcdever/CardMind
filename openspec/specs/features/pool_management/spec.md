# Pool Management Feature Specification
# 池管理功能规格

**Version**: 1.0.0
**版本**: 1.0.0

**Status**: Active
**状态**: Active

**Dependencies**: [../../domain/pool/model.md](../../domain/pool/model.md), [../../architecture/storage/pool_store.md](../../architecture/storage/pool_store.md), [../../architecture/storage/device_config.md](../../architecture/storage/device_config.md)
**依赖**: [../../domain/pool/model.md](../../domain/pool/model.md), [../../architecture/storage/pool_store.md](../../architecture/storage/pool_store.md), [../../architecture/storage/device_config.md](../../architecture/storage/device_config.md)

**Related Tests**: `test/features/pool_management_test.dart`
**相关测试**: `test/features/pool_management_test.dart`

---

## Overview
## 概述

This specification defines the Pool Management feature, which enables users to create pools, join existing pools, manage pool settings, and leave pools. The feature enforces the single-pool constraint where each device can join at most one pool at a time, and all cards created on a device automatically belong to the joined pool.

本规格定义了池管理功能，使用户能够创建池、加入现有池、管理池设置和离开池。该功能强制执行单池约束，即每个设备一次最多只能加入一个池，设备上创建的所有卡片自动属于已加入的池。

**Key User Journeys**:
**核心用户旅程**:
- Create a new pool with name and password
- 创建包含名称和密码的新池
- Join an existing pool using pool ID and password
- 使用池 ID 和密码加入现有池
- View current pool information and settings
- 查看当前池信息和设置
- Update pool name and password
- 更新池名称和密码
- Leave a pool and clear all local data
- 离开池并清除所有本地数据
- View devices in the pool
- 查看池中的设备

---

## Requirement: Pool Creation
## 需求：池创建

Users SHALL be able to create a new pool with a name and password.

用户应能够创建包含名称和密码的新池。

### Scenario: Create pool with name and password
### 场景：使用名称和密码创建池

- **GIVEN**: The device has not joined any pool
- **前置条件**: 设备未加入任何池
- **WHEN**: The user creates a new pool with name "Family Notes" and password "secure123"
- **操作**: 用户创建名称为"Family Notes"、密码为"secure123"的新池
- **THEN**: The system SHALL create a pool with UUID v7 identifier
- **预期结果**: 系统应使用 UUID v7 标识符创建池
- **AND**: The pool name SHALL be set to "Family Notes"
- **并且**: 池名称应设置为"Family Notes"
- **AND**: The password SHALL be hashed using bcrypt and stored
- **并且**: 密码应使用 bcrypt 哈希并存储
- **AND**: The device SHALL automatically join the pool
- **并且**: 设备应自动加入池
- **AND**: The pool SHALL be visible to all devices that join with the correct password
- **并且**: 使用正确密码加入的所有设备应可见该池

### Scenario: Reject pool creation with empty name
### 场景：拒绝创建空名称的池

- **GIVEN**: The user attempts to create a pool
- **前置条件**: 用户尝试创建池
- **WHEN**: The user provides empty name or whitespace-only name
- **操作**: 用户提供空名称或仅包含空格的名称
- **THEN**: The system SHALL reject the creation
- **预期结果**: 系统应拒绝创建
- **AND**: The system SHALL display error message "Pool name is required"
- **并且**: 系统应显示错误消息"池名称为必填项"

### Scenario: Reject pool creation with weak password
### 场景：拒绝创建弱密码的池

- **GIVEN**: The user attempts to create a pool
- **前置条件**: 用户尝试创建池
- **WHEN**: The user provides a password shorter than 6 characters
- **操作**: 用户提供少于6个字符的密码
- **THEN**: The system SHALL reject the creation
- **预期结果**: 系统应拒绝创建
- **AND**: The system SHALL display error message "Password must be at least 6 characters"
- **并且**: 系统应显示错误消息"密码必须至少6个字符"

### Scenario: Reject pool creation when already joined
### 场景：已加入池时拒绝创建池

- **GIVEN**: The device has already joined a pool
- **前置条件**: 设备已加入一个池
- **WHEN**: The user attempts to create a new pool
- **操作**: 用户尝试创建新池
- **THEN**: The system SHALL reject the creation with error "ALREADY_JOINED_POOL"
- **预期结果**: 系统应以错误"ALREADY_JOINED_POOL"拒绝创建
- **AND**: The system SHALL prompt the user to leave the current pool first
- **并且**: 系统应提示用户先离开当前池

---

## Requirement: Pool Joining
## 需求：池加入

Users SHALL be able to join an existing pool using the pool ID and password.

用户应能够使用池 ID 和密码加入现有池。

### Scenario: Join pool with valid credentials
### 场景：使用有效凭据加入池

- **GIVEN**: A pool exists with ID "pool-123" and password "secure123"
- **前置条件**: 存在 ID 为"pool-123"、密码为"secure123"的池
- **AND**: The device has not joined any pool
- **并且**: 设备未加入任何池
- **WHEN**: The user joins the pool with ID "pool-123" and password "secure123"
- **操作**: 用户使用 ID"pool-123"和密码"secure123"加入池
- **THEN**: The system SHALL verify the password against the stored hash
- **预期结果**: 系统应根据存储的哈希验证密码
- **AND**: The device SHALL be added to the pool's device list
- **并且**: 设备应添加到池的设备列表
- **AND**: The device configuration SHALL be updated with the pool ID
- **并且**: 设备配置应使用池 ID 更新
- **AND**: The system SHALL begin syncing pool data
- **并且**: 系统应开始同步池数据

### Scenario: Reject join with invalid password
### 场景：拒绝使用无效密码加入

- **GIVEN**: A pool exists with ID "pool-123" and password "secure123"
- **前置条件**: 存在 ID 为"pool-123"、密码为"secure123"的池
- **WHEN**: The user attempts to join with password "wrong-password"
- **操作**: 用户尝试使用密码"wrong-password"加入
- **THEN**: The system SHALL reject the join request
- **预期结果**: 系统应拒绝加入请求
- **AND**: The system SHALL display error message "Invalid password"
- **并且**: 系统应显示错误消息"密码无效"
- **AND**: The device SHALL NOT be added to the pool
- **并且**: 设备不应添加到池

### Scenario: Reject join with non-existent pool ID
### 场景：拒绝使用不存在的池 ID 加入

- **GIVEN**: The user attempts to join a pool
- **前置条件**: 用户尝试加入池
- **WHEN**: The user provides a pool ID that does not exist
- **操作**: 用户提供不存在的池 ID
- **THEN**: The system SHALL reject the join request
- **预期结果**: 系统应拒绝加入请求
- **AND**: The system SHALL display error message "Pool not found"
- **并且**: 系统应显示错误消息"池未找到"

### Scenario: Reject joining second pool
### 场景：拒绝加入第二个池

- **GIVEN**: The device has already joined pool "pool-A"
- **前置条件**: 设备已加入池"pool-A"
- **WHEN**: The user attempts to join pool "pool-B"
- **操作**: 用户尝试加入池"pool-B"
- **THEN**: The system SHALL reject the join request with error "ALREADY_JOINED_POOL"
- **预期结果**: 系统应以错误"ALREADY_JOINED_POOL"拒绝加入请求
- **AND**: The system SHALL display message "You can only join one pool at a time. Leave your current pool first."
- **并且**: 系统应显示消息"您一次只能加入一个池。请先离开当前池。"

---

## Requirement: Pool Information Viewing
## 需求：池信息查看

Users SHALL be able to view information about the currently joined pool.

用户应能够查看当前已加入池的信息。

### Scenario: View pool details
### 场景：查看池详情

- **GIVEN**: The device has joined a pool
- **前置条件**: 设备已加入池
- **WHEN**: The user opens the pool settings
- **操作**: 用户打开池设置
- **THEN**: The system SHALL display the pool name
- **预期结果**: 系统应显示池名称
- **AND**: The system SHALL display the pool ID
- **并且**: 系统应显示池 ID
- **AND**: The system SHALL display the creation timestamp
- **并且**: 系统应显示创建时间戳
- **AND**: The system SHALL display the number of devices in the pool
- **并且**: 系统应显示池中的设备数量
- **AND**: The system SHALL display the number of cards in the pool
- **并且**: 系统应显示池中的卡片数量

### Scenario: View devices in pool
### 场景：查看池中的设备

- **GIVEN**: The device has joined a pool with multiple devices
- **前置条件**: 设备已加入包含多个设备的池
- **WHEN**: The user views the pool devices list
- **操作**: 用户查看池设备列表
- **THEN**: The system SHALL display all devices in the pool
- **预期结果**: 系统应显示池中的所有设备
- **AND**: Each device SHALL show its name, type, and online status
- **并且**: 每个设备应显示其名称、类型和在线状态
- **AND**: The current device SHALL be marked as "This Device"
- **并且**: 当前设备应标记为"此设备"

### Scenario: Copy pool ID for sharing
### 场景：复制池 ID 以供分享

- **GIVEN**: The device has joined a pool
- **前置条件**: 设备已加入池
- **WHEN**: The user taps "Copy Pool ID"
- **操作**: 用户点击"复制池 ID"
- **THEN**: The system SHALL copy the pool ID to clipboard
- **预期结果**: 系统应将池 ID 复制到剪贴板
- **AND**: The system SHALL display confirmation message "Pool ID copied"
- **并且**: 系统应显示确认消息"池 ID 已复制"

---

## Requirement: Pool Settings Management
## 需求：池设置管理

Users SHALL be able to update pool settings including name and password.

用户应能够更新池设置，包括名称和密码。

### Scenario: Update pool name
### 场景：更新池名称

- **GIVEN**: The device has joined a pool with name "Old Name"
- **前置条件**: 设备已加入名称为"Old Name"的池
- **WHEN**: The user updates the pool name to "New Name"
- **操作**: 用户将池名称更新为"New Name"
- **THEN**: The system SHALL update the pool name
- **预期结果**: 系统应更新池名称
- **AND**: The change SHALL sync to all devices in the pool
- **并且**: 更改应同步到池中的所有设备
- **AND**: The system SHALL display confirmation message "Pool name updated"
- **并且**: 系统应显示确认消息"池名称已更新"

### Scenario: Reject empty pool name update
### 场景：拒绝空池名称更新

- **GIVEN**: The user attempts to update the pool name
- **前置条件**: 用户尝试更新池名称
- **WHEN**: The user provides empty name or whitespace-only name
- **操作**: 用户提供空名称或仅包含空格的名称
- **THEN**: The system SHALL reject the update
- **预期结果**: 系统应拒绝更新
- **AND**: The system SHALL display error message "Pool name cannot be empty"
- **并且**: 系统应显示错误消息"池名称不能为空"

### Scenario: Update pool password
### 场景：更新池密码

- **GIVEN**: The device has joined a pool
- **前置条件**: 设备已加入池
- **WHEN**: The user updates the pool password to "new-password"
- **操作**: 用户将池密码更新为"new-password"
- **THEN**: The system SHALL verify the current password first
- **预期结果**: 系统应首先验证当前密码
- **AND**: The system SHALL hash the new password using bcrypt
- **并且**: 系统应使用 bcrypt 哈希新密码
- **AND**: The system SHALL update the password hash
- **并且**: 系统应更新密码哈希
- **AND**: The change SHALL sync to all devices in the pool
- **并且**: 更改应同步到池中的所有设备
- **AND**: The system SHALL display confirmation message "Pool password updated"
- **并且**: 系统应显示确认消息"池密码已更新"

### Scenario: Reject weak password update
### 场景：拒绝弱密码更新

- **GIVEN**: The user attempts to update the pool password
- **前置条件**: 用户尝试更新池密码
- **WHEN**: The user provides a password shorter than 6 characters
- **操作**: 用户提供少于6个字符的密码
- **THEN**: The system SHALL reject the update
- **预期结果**: 系统应拒绝更新
- **AND**: The system SHALL display error message "Password must be at least 6 characters"
- **并且**: 系统应显示错误消息"密码必须至少6个字符"

---

## Requirement: Pool Leaving
## 需求：池离开

Users SHALL be able to leave a pool, which clears all local pool and card data.

用户应能够离开池，这将清除所有本地池和卡片数据。

### Scenario: Leave pool with confirmation
### 场景：确认后离开池

- **GIVEN**: The device has joined a pool with cards
- **前置条件**: 设备已加入包含卡片的池
- **WHEN**: The user selects "Leave Pool" action
- **操作**: 用户选择"离开池"操作
- **THEN**: The system SHALL display confirmation dialog "Leave pool? All local data will be deleted."
- **预期结果**: 系统应显示确认对话框"离开池？所有本地数据将被删除。"
- **AND**: If user confirms, the system SHALL remove the device from the pool's device list
- **并且**: 如果用户确认，系统应从池的设备列表中移除设备
- **AND**: The system SHALL delete all local pool data
- **并且**: 系统应删除所有本地池数据
- **AND**: The system SHALL delete all local card data
- **并且**: 系统应删除所有本地卡片数据
- **AND**: The system SHALL clear the device configuration pool ID
- **并且**: 系统应清除设备配置池 ID
- **AND**: The removal SHALL sync to other devices in the pool
- **并且**: 移除操作应同步到池中的其他设备

### Scenario: Cancel pool leaving
### 场景：取消离开池

- **GIVEN**: The device has joined a pool
- **前置条件**: 设备已加入池
- **WHEN**: The user selects "Leave Pool" action
- **操作**: 用户选择"离开池"操作
- **AND**: The user clicks "Cancel" in the confirmation dialog
- **并且**: 用户在确认对话框中点击"取消"
- **THEN**: The system SHALL not leave the pool
- **预期结果**: 系统应不离开池
- **AND**: All data SHALL remain intact
- **并且**: 所有数据应保持完整

### Scenario: Data cleanup after leaving pool
### 场景：离开池后数据清理

- **GIVEN**: The device has left a pool
- **前置条件**: 设备已离开池
- **WHEN**: The user checks local storage
- **操作**: 用户检查本地存储
- **THEN**: No pool data SHALL exist locally
- **预期结果**: 本地不应存在池数据
- **AND**: No card data SHALL exist locally
- **并且**: 本地不应存在卡片数据
- **AND**: The device SHALL be able to create or join a new pool
- **并且**: 设备应能够创建或加入新池

---

## Requirement: Pool Discovery
## 需求：池发现

Users SHALL be able to discover pools through pool ID sharing.

用户应能够通过池 ID 分享发现池。

### Scenario: Share pool ID with others
### 场景：与他人分享池 ID

- **GIVEN**: The device has joined a pool
- **前置条件**: 设备已加入池
- **WHEN**: The user selects "Share Pool"
- **操作**: 用户选择"分享池"
- **THEN**: The system SHALL format sharing text with pool ID and instructions
- **预期结果**: 系统应格式化包含池 ID 和说明的分享文本
- **AND**: The format SHALL be: "Join my CardMind pool!\nPool ID: [pool-id]\nPassword: [ask me for password]"
- **并且**: 格式应为："加入我的 CardMind 池！\n池 ID：[pool-id]\n密码：[向我索取密码]"
- **AND**: The system SHALL open the platform share dialog
- **并且**: 系统应打开平台分享对话框

### Scenario: Join pool from shared link
### 场景：从分享链接加入池

- **GIVEN**: The user receives a pool ID from another user
- **前置条件**: 用户从其他用户接收池 ID
- **WHEN**: The user enters the pool ID in the join pool form
- **操作**: 用户在加入池表单中输入池 ID
- **THEN**: The system SHALL validate the pool ID format
- **预期结果**: 系统应验证池 ID 格式
- **AND**: The system SHALL prompt for the pool password
- **并且**: 系统应提示输入池密码
- **AND**: The system SHALL attempt to join the pool
- **并且**: 系统应尝试加入池

---

## Business Rules
## 业务规则

### Single Pool Constraint
### 单池约束

A device SHALL join at most one pool at any time. To join a different pool, the device MUST leave the current pool first.

设备在任何时候最多只能加入一个池。要加入不同的池，设备必须先离开当前池。

**Rationale**: Simplifies data management and sync logic by ensuring clear pool ownership.

**理由**：通过确保清晰的池所有权简化数据管理和同步逻辑。

### Automatic Pool Association
### 自动池关联

All newly created cards SHALL be automatically associated with the device's currently joined pool.

所有新创建的卡片应自动关联到设备当前加入的池。

**Rationale**: Eliminates manual pool selection and ensures cards are always in the correct pool.

**理由**：消除手动池选择，确保卡片始终在正确的池中。

### Password Security
### 密码安全

Pool passwords SHALL be hashed using bcrypt with cost factor 12 before storage. Password verification SHALL use constant-time comparison.

池密码应在存储前使用成本因子12的 bcrypt 哈希。密码验证应使用恒定时间比较。

**Rationale**: Protects pool access from unauthorized users and prevents timing attacks.

**理由**：保护池访问免受未授权用户攻击，防止时序攻击。

### Password Minimum Length
### 密码最小长度

Pool passwords SHALL be at least 6 characters long.

池密码应至少6个字符长。

**Rationale**: Ensures basic password strength while remaining user-friendly.

**理由**：确保基本密码强度，同时保持用户友好。

### Pool Name Validation
### 池名称验证

Pool names SHALL NOT be empty or contain only whitespace. Leading and trailing whitespace SHALL be trimmed.

池名称不应为空或仅包含空格。前导和尾随空格应被修剪。

**Rationale**: Ensures all pools have meaningful identifiers for user navigation.

**理由**：确保所有池都有有意义的标识符供用户导航。

### Data Cleanup on Leave
### 离开时数据清理

When a device leaves a pool, ALL local pool and card data SHALL be deleted from the device.

当设备离开池时，所有本地池和卡片数据应从设备删除。

**Rationale**: Prevents orphaned data and ensures clean state for joining new pools.

**理由**：防止孤立数据，确保加入新池时状态清洁。

### Pool ID Format
### 池 ID 格式

Pool IDs SHALL use UUID v7 format for time-sortable, globally unique identifiers.

池 ID 应使用 UUID v7 格式以实现时间可排序的全局唯一标识符。

**Rationale**: Ensures unique pool identification and enables chronological sorting.

**理由**：确保唯一的池标识，支持按时间顺序排序。

### Sync Propagation
### 同步传播

All pool changes (name updates, password updates, device additions/removals) SHALL propagate to all devices in the pool via P2P sync.

所有池变更（名称更新、密码更新、设备添加/移除）应通过 P2P 同步传播到池中的所有设备。

**Rationale**: Ensures consistency across all devices in the pool.

**理由**：确保池中所有设备的一致性。

---

## Test Coverage
## 测试覆盖

**Test File**: `test/features/pool_management_test.dart`
**测试文件**: `test/features/pool_management_test.dart`

**Feature Tests**:
**功能测试**:
- `it_should_create_pool_with_name_and_password()` - Create pool with valid data
- 使用有效数据创建池
- `it_should_reject_pool_with_empty_name()` - Reject empty name
- 拒绝空名称
- `it_should_reject_pool_with_weak_password()` - Reject weak password
- 拒绝弱密码
- `it_should_reject_creation_when_already_joined()` - Reject when already joined
- 已加入时拒绝创建
- `it_should_join_pool_with_valid_credentials()` - Join with valid credentials
- 使用有效凭据加入
- `it_should_reject_join_with_invalid_password()` - Reject invalid password
- 拒绝无效密码
- `it_should_reject_join_with_nonexistent_pool()` - Reject non-existent pool
- 拒绝不存在的池
- `it_should_reject_joining_second_pool()` - Reject second pool
- 拒绝第二个池
- `it_should_display_pool_details()` - Display pool details
- 显示池详情
- `it_should_display_devices_in_pool()` - Display devices
- 显示设备
- `it_should_copy_pool_id()` - Copy pool ID
- 复制池 ID
- `it_should_update_pool_name()` - Update pool name
- 更新池名称
- `it_should_reject_empty_name_update()` - Reject empty name update
- 拒绝空名称更新
- `it_should_update_pool_password()` - Update pool password
- 更新池密码
- `it_should_reject_weak_password_update()` - Reject weak password update
- 拒绝弱密码更新
- `it_should_leave_pool_with_confirmation()` - Leave with confirmation
- 确认后离开
- `it_should_cancel_pool_leaving()` - Cancel leaving
- 取消离开
- `it_should_cleanup_data_after_leaving()` - Cleanup after leaving
- 离开后清理
- `it_should_share_pool_id()` - Share pool ID
- 分享池 ID
- `it_should_join_from_shared_link()` - Join from shared link
- 从分享链接加入

**Acceptance Criteria**:
**验收标准**:
- [ ] All feature tests pass
- [ ] 所有功能测试通过
- [ ] Pool creation works on all platforms
- [ ] 池创建在所有平台上工作
- [ ] Single-pool constraint is enforced
- [ ] 单池约束被强制执行
- [ ] Password security is implemented correctly
- [ ] 密码安全正确实现
- [ ] Data cleanup on leave is complete
- [ ] 离开时数据清理完整
- [ ] Pool sharing works smoothly
- [ ] 池分享流畅工作
- [ ] Code review approved
- [ ] 代码审查通过
- [ ] Documentation updated
- [ ] 文档已更新

---

## Related Documents
## 相关文档

**Domain Specs**:
**领域规格**:
- [../../domain/pool/model.md](../../domain/pool/model.md) - Pool domain model
- 池领域模型

**Architecture Specs**:
**架构规格**:
- [../../architecture/storage/pool_store.md](../../architecture/storage/pool_store.md) - PoolStore implementation
- PoolStore 实现
- [../../architecture/storage/device_config.md](../../architecture/storage/device_config.md) - Device configuration
- 设备配置
- [../../architecture/sync/service.md](../../architecture/sync/service.md) - P2P sync service
- P2P 同步服务

**Feature Specs**:
**功能规格**:
- [../card_management/spec.md](../card_management/spec.md) - Card management feature
- 卡片管理功能
- [../onboarding/shared.md](../onboarding/shared.md) - Onboarding flow
- 应用引导流程
- [../settings/settings_screen.md](../settings/settings_screen.md) - Settings screen
- 设置屏幕

**ADRs**:
**架构决策记录**:
- [../../../docs/adr/0001-single-pool-ownership.md](../../../docs/adr/0001-single-pool-ownership.md) - Single pool model decision
- 单池模型决策

**UI Specs** (to be created):
**UI规格**（待创建）:
- `../../ui/screens/mobile/pool_creation_screen.md` - Pool creation screen UI
- 池创建屏幕UI
- `../../ui/screens/mobile/pool_join_screen.md` - Pool join screen UI
- 池加入屏幕UI
- `../../ui/screens/mobile/pool_settings_screen.md` - Pool settings screen UI
- 池设置屏幕UI

---

**Last Updated**: 2026-01-23
**最后更新**: 2026-01-23

**Authors**: CardMind Team
**作者**: CardMind Team
