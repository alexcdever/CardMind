# Keyring Password Storage Architecture Specification
# Keyring 密码存储架构规格

**Version**: 1.0.0
**版本**: 1.0.0
**Status**: Active
**状态**: Active
**Dependencies**: [../../domain/pool/model.md](../../domain/pool/model.md), [./password.md](./password.md)
**依赖**: [../../domain/pool/model.md](../../domain/pool/model.md), [./password.md](./password.md)
**Related Tests**: `rust/tests/security/keyring_test.rs`
**相关测试**: `rust/tests/security/keyring_test.rs`

---

## Overview
## 概述

This specification defines the cross-platform secure storage mechanism for data pool passwords in CardMind. The system uses system-level Keyring services (Windows Credential Manager, macOS Keychain, Linux Secret Service, Android Keystore) to store passwords, ensuring encrypted storage and no long-term memory residence.

本规格定义了 CardMind 中数据池密码的跨平台安全存储机制。系统使用系统级 Keyring 服务（Windows Credential Manager、macOS Keychain、Linux Secret Service、Android Keystore）存储密码，确保密码加密存储且不在内存中长期驻留。

**Technology Stack**:
**技术栈**:
- keyring = "3.6" - Cross-platform Keyring library
- keyring = "3.6" - 跨平台 Keyring 库
- zeroize = "1.7" - Memory zeroing
- zeroize = "1.7" - 内存清零

**Platform Support**:
**平台支持**:

| Platform | Keyring Service |
| 平台 | Keyring 服务 |
|----------|-----------------|
| Windows | Windows Credential Manager |
| Windows | Windows 凭据管理器 |
| macOS/iOS | Keychain |
| macOS/iOS | 钥匙串 |
| Linux | Secret Service API (libsecret) |
| Linux | Secret Service API (libsecret) |
| Android | Android Keystore |
| Android | Android 密钥库 |

---

## Requirement: Cross-Platform Password Storage
## 需求：跨平台密码存储

The system SHALL use platform-native Keyring services to store data pool passwords, supporting Windows, macOS, Linux, iOS, and Android.

系统应使用平台原生 Keyring 服务存储数据池密码，支持 Windows、macOS、Linux、iOS 和 Android。

### Scenario: Store password on different platforms
### 场景：在不同平台存储密码

- **GIVEN**: User creates or joins a pool on a specific platform
- **前置条件**: 用户在特定平台上创建或加入数据池
- **WHEN**: Password storage function is called
- **操作**: 调用密码存储函数
- **THEN**: Password SHALL be stored to the corresponding platform's Keyring service
- **预期结果**: 密码应存储到对应平台的 Keyring 服务
- **AND**: Windows uses Credential Manager, macOS uses Keychain, Linux uses Secret Service, Android uses Keystore
- **并且**: Windows 使用 Credential Manager，macOS 使用 Keychain，Linux 使用 Secret Service，Android 使用 Keystore

---

## Requirement: Password Storage Format
## 需求：密码存储格式

The system SHALL use a unified key format to store passwords, with service name "cardmind" and key name "pool.<pool_id>.password".

系统应使用统一的密钥格式存储密码，服务名称为 "cardmind"，密钥名称为 "pool.<pool_id>.password"。

### Scenario: Store pool password
### 场景：存储数据池密码

- **GIVEN**: Pool ID is "018c8a1b-2c3d-7e4f-8a9b-0c1d2e3f4a5b"
- **前置条件**: 数据池 ID 为 "018c8a1b-2c3d-7e4f-8a9b-0c1d2e3f4a5b"
- **WHEN**: Store password to Keyring
- **操作**: 存储密码到 Keyring
- **THEN**: Key name SHALL be "pool.018c8a1b-2c3d-7e4f-8a9b-0c1d2e3f4a5b.password"
- **预期结果**: 密钥名称应为 "pool.018c8a1b-2c3d-7e4f-8a9b-0c1d2e3f4a5b.password"
- **AND**: Service name SHALL be "cardmind"
- **并且**: 服务名称应为 "cardmind"

**Implementation Logic**:
**实现逻辑**:

```
// Keyring storage service
// Keyring 存储服务
structure KeyringStore:
    service_name: String = "cardmind"

    // Store password
    // 存储密码
    // Design decision: Use pool ID in key name for multi-pool support
    // 设计决策：在密钥名称中使用池 ID 以支持多池
    function store_pool_password(pool_id, password):
        key_name = "pool." + pool_id + ".password"
        keyring.set(service_name, key_name, password)

        // Password automatically zeroed
        // 密码自动清零
        return ok()
```

---

## Requirement: Password Retrieval
## 需求：密码读取

The system SHALL retrieve passwords from Keyring and return auto-zeroing strings to ensure memory safety.

系统应从 Keyring 读取密码并返回自动清零的字符串，确保内存安全。

### Scenario: Retrieve pool password
### 场景：读取数据池密码

- **GIVEN**: Pool password is stored in Keyring
- **前置条件**: 数据池密码已存储在 Keyring
- **WHEN**: Password retrieval function is called
- **操作**: 调用密码读取函数
- **THEN**: Password SHALL be returned wrapped in Zeroizing<String>
- **预期结果**: 应返回 Zeroizing<String> 包装的密码
- **AND**: Password SHALL be automatically zeroed when leaving scope
- **并且**: 密码离开作用域时应自动清零内存

**Implementation Logic**:
**实现逻辑**:

```
function get_pool_password(pool_id):
    // Retrieve password from Keyring
    // 从 Keyring 读取密码
    key_name = "pool." + pool_id + ".password"
    password = keyring.get(service_name, key_name)

    // Return auto-zeroing string
    // 返回自动清零的字符串
    // Design decision: Wrap in Zeroizing to prevent memory leakage
    // 设计决策：使用 Zeroizing 包装以防止内存泄露
    return Zeroizing(password)
```

---

## Requirement: Password Deletion
## 需求：密码删除

The system SHALL support deleting pool passwords from Keyring, for scenarios like leaving a pool or clearing cache.

系统应支持从 Keyring 删除数据池密码，用于用户退出数据池或清除缓存场景。

### Scenario: Delete password when leaving pool
### 场景：退出数据池时删除密码

- **GIVEN**: User chooses to leave a pool
- **前置条件**: 用户选择退出数据池
- **WHEN**: Password deletion function is called
- **操作**: 调用密码删除函数
- **THEN**: Password SHALL be deleted from Keyring
- **预期结果**: 密码应从 Keyring 中删除
- **AND**: Subsequent retrieval operations SHALL return "not found" error
- **并且**: 后续读取操作应返回"未找到"错误

**Implementation Logic**:
**实现逻辑**:

```
function delete_pool_password(pool_id):
    // Delete password from Keyring
    // 从 Keyring 删除密码
    key_name = "pool." + pool_id + ".password"
    keyring.delete(service_name, key_name)
    return ok()
```

---

## Requirement: Password Existence Check
## 需求：密码存在性检查

The system SHALL support checking if a pool password is stored in Keyring, for auto-login determination.

系统应支持检查数据池密码是否存储在 Keyring，用于自动登录判断。

### Scenario: Check password cache on startup
### 场景：启动时检查密码缓存

- **GIVEN**: Application starts and needs to determine auto-login
- **前置条件**: 应用启动，需要判断是否自动加入数据池
- **WHEN**: Password existence check function is called
- **操作**: 调用密码存在性检查函数
- **THEN**: A boolean value SHALL be returned indicating password storage status
- **预期结果**: 应返回布尔值表示密码是否存储
- **AND**: Actual password content SHALL NOT be read, only existence checked
- **并且**: 不应读取实际密码内容，仅检查存在性

**Implementation Logic**:
**实现逻辑**:

```
function has_pool_password(pool_id):
    // Check if password exists in Keyring
    // 检查密码是否存在于 Keyring
    // Design decision: Don't read password, only check existence
    // 设计决策：不读取密码，仅检查存在性
    key_name = "pool." + pool_id + ".password"
    return keyring.exists(service_name, key_name)
```

---

## Requirement: Multiple Pool Support
## 需求：多数据池支持

The system SHALL support storing passwords for multiple pools simultaneously, with each pool using an independent key.

系统应支持同时存储多个数据池的密码，每个数据池使用独立的密钥。

### Scenario: User joins multiple pools
### 场景：用户加入多个数据池

- **GIVEN**: User has joined pool A and pool B
- **前置条件**: 用户已加入数据池 A 和数据池 B
- **WHEN**: Store passwords for both pools
- **操作**: 分别存储两个数据池的密码
- **THEN**: Both passwords SHALL be stored independently without interference
- **预期结果**: 两个密码应独立存储，互不影响
- **AND**: Each pool's password can be independently retrieved and deleted
- **并且**: 可以独立读取、删除每个数据池的密码

---

## Requirement: Flutter Integration
## 需求：Flutter 集成

The system SHALL provide Flutter API through Flutter Rust Bridge for password storage operations.

系统应通过 Flutter Rust Bridge 提供 Flutter API 用于密码存储操作。

### Scenario: Flutter calls Keyring API
### 场景：Flutter 调用 Keyring API

- **GIVEN**: Flutter needs to store or retrieve password
- **前置条件**: Flutter 需要存储或读取密码
- **WHEN**: Flutter calls Keyring API through bridge
- **操作**: Flutter 通过桥接调用 Keyring API
- **THEN**: Rust backend SHALL execute Keyring operations
- **预期结果**: Rust 后端应执行 Keyring 操作
- **AND**: Results SHALL be returned to Flutter
- **并且**: 结果应返回给 Flutter

**Flutter API**:
**Flutter API**:

```
// Store password
// 存储密码
async function storePoolPasswordInKeyring(poolId, password):
    await rust_bridge.store_pool_password(poolId, password)

// Retrieve password
// 读取密码
async function getPoolPasswordFromKeyring(poolId):
    password = await rust_bridge.get_pool_password(poolId)
    return password

// Delete password
// 删除密码
async function deletePoolPasswordFromKeyring(poolId):
    await rust_bridge.delete_pool_password(poolId)

// Check if password exists
// 检查密码是否存在
async function hasPoolPasswordInKeyring(poolId):
    exists = await rust_bridge.has_pool_password(poolId)
    return exists
```

---

## Test Coverage
## 测试覆盖

**Test File**: `rust/tests/security/keyring_test.rs`
**测试文件**: `rust/tests/security/keyring_test.rs`

**Unit Tests**:
**单元测试**:
- `test_store_password()` - Test storing password
- `test_store_password()` - 测试存储密码
- `test_get_password()` - Test retrieving password
- `test_get_password()` - 测试读取密码
- `test_delete_password()` - Test deleting password
- `test_delete_password()` - 测试删除密码
- `test_has_password()` - Test checking password existence
- `test_has_password()` - 测试检查密码存在性
- `test_multiple_pools()` - Test multiple pool support
- `test_multiple_pools()` - 测试多数据池支持
- `test_memory_zeroing()` - Test memory zeroing
- `test_memory_zeroing()` - 测试内存清零
- `test_error_not_found()` - Test not found error
- `test_error_not_found()` - 测试未找到错误

**Integration Tests**:
**集成测试**:
- `test_pool_join_with_keyring()` - Test Keyring integration during pool join
- `test_pool_join_with_keyring()` - 测试加入数据池时的 Keyring 集成
- `test_auto_login_with_keyring()` - Test auto-login with Keyring
- `test_auto_login_with_keyring()` - 测试使用 Keyring 自动登录

**Platform Tests**:
**平台测试**:
- `test_windows_credential_manager()` - Test Windows Credential Manager
- `test_windows_credential_manager()` - 测试 Windows 凭据管理器
- `test_macos_keychain()` - Test macOS Keychain
- `test_macos_keychain()` - 测试 macOS 钥匙串
- `test_linux_secret_service()` - Test Linux Secret Service
- `test_linux_secret_service()` - 测试 Linux Secret Service
- `test_android_keystore()` - Test Android Keystore
- `test_android_keystore()` - 测试 Android 密钥库

**Acceptance Criteria**:
**验收标准**:
- [x] All unit tests pass
- [x] 所有单元测试通过
- [x] All platform tests pass
- [x] 所有平台测试通过
- [x] Passwords stored encrypted
- [x] 密码加密存储
- [x] Memory zeroing works correctly
- [x] 内存清零功能正常
- [x] Multiple pool support works correctly
- [x] 多数据池支持正常
- [x] Code review approved
- [x] 代码审查通过
- [x] Documentation updated
- [x] 文档已更新

---

## Related Documents
## 相关文档

**Related Specs**:
**相关规格**:
- [../../domain/pool/model.md](../../domain/pool/model.md) - Pool domain model
- [../../domain/pool/model.md](../../domain/pool/model.md) - 数据池领域模型
- [./password.md](./password.md) - bcrypt password management
- [./password.md](./password.md) - bcrypt 密码管理
- [../storage/pool_store.md](../storage/pool_store.md) - Pool store implementation
- [../storage/pool_store.md](../storage/pool_store.md) - 数据池存储实现
- [../bridge/flutter_rust_bridge.md](../bridge/flutter_rust_bridge.md) - Flutter-Rust bridge
- [../bridge/flutter_rust_bridge.md](../bridge/flutter_rust_bridge.md) - Flutter-Rust 桥接

**ADRs**:
**架构决策记录**:
- [../../../docs/adr/0001-single-pool-constraint.md](../../../docs/adr/0001-single-pool-constraint.md) - Single pool constraint
- [../../../docs/adr/0001-single-pool-constraint.md](../../../docs/adr/0001-single-pool-constraint.md) - 单池约束

---

**Last Updated**: 2026-01-23
**最后更新**: 2026-01-23
**Authors**: CardMind Team
**作者**: CardMind Team
