# Keyring 密码存储架构规格

## 概述

本规格定义了 CardMind 中数据池密码的跨平台安全存储机制。系统使用系统级 Keyring 服务（Windows 凭据管理器、macOS 钥匙串、Linux Secret Service、Android 密钥库）存储密码，确保密码加密存储且不在内存中长期驻留。

**技术栈**:
- keyring = "3.6" - 跨平台 Keyring 库
- zeroize = "1.7" - 内存清零

**平台支持**:

| 平台 | 存储服务 |
|------|-------------|
| Windows | Windows Credential Manager |
| macOS/iOS | Keychain |
| Linux | Secret Service |
| Android | Keystore |

---

## 需求：跨平台密码存储


系统应使用平台原生 Keyring 服务存储数据池密码，支持 Windows、macOS、Linux、iOS 和 Android。

### 场景：在不同平台存储密码

- **前置条件**: 用户在特定平台上创建或加入数据池
- **操作**: 调用密码存储函数
- **预期结果**: 密码应存储到对应平台的 Keyring 服务
- **并且**: Windows 使用 Credential Manager，macOS 使用 Keychain，Linux 使用 Secret Service，Android 使用 Keystore

---

## 需求：密码存储格式


系统应使用统一的密钥格式存储密码，服务名称为 "cardmind"，密钥名称为 "pool.<pool_id>.password"。

### 场景：存储数据池密码

- **前置条件**: 数据池 ID 为 "018c8a1b-2c3d-7e4f-8a9b-0c1d2e3f4a5b"
- **操作**: 存储密码到 Keyring
- **预期结果**: 密钥名称应为 "pool.018c8a1b-2c3d-7e4f-8a9b-0c1d2e3f4a5b.password"
- **并且**: 服务名称应为 "cardmind"

---

## 需求：密码读取


系统应从 Keyring 读取密码并返回自动清零的字符串，确保内存安全。

### 场景：读取数据池密码

- **前置条件**: 数据池密码已存储在 Keyring
- **操作**: 调用密码读取函数
- **预期结果**: 应返回 Zeroizing<String> 包装的密码
- **并且**: 密码离开作用域时应自动清零内存

---

## 需求：密码删除


系统应支持从 Keyring 删除数据池密码，用于用户退出数据池或清除缓存场景。

### 场景：退出数据池时删除密码

- **前置条件**: 用户选择退出数据池
- **操作**: 调用密码删除函数
- **预期结果**: 密码应从 Keyring 中删除
- **并且**: 后续读取操作应返回"未找到"错误

---

## 需求：密码存在性检查


系统应支持检查数据池密码是否存储在 Keyring，用于自动登录判断。

### 场景：启动时检查密码缓存

- **前置条件**: 应用启动，需要判断是否自动加入数据池
- **操作**: 调用密码存在性检查函数
- **预期结果**: 应返回布尔值表示密码是否存储
- **并且**: 不应读取实际密码内容，仅检查存在性

---

## 需求：多数据池支持


系统应支持同时存储多个数据池的密码，每个数据池使用独立的密钥。

### 场景：用户加入多个数据池

- **前置条件**: 用户已加入数据池 A 和数据池 B
- **操作**: 分别存储两个数据池的密码
- **预期结果**: 两个密码应独立存储，互不影响
- **并且**: 可以独立读取、删除每个数据池的密码

---

## 需求：Flutter 集成


系统应通过 Flutter Rust Bridge 提供 Flutter API 用于密码存储操作。

### 场景：Flutter 调用 Keyring API

- **前置条件**: Flutter 需要存储或读取密码
- **操作**: Flutter 通过桥接调用 Keyring API
- **预期结果**: Rust 后端应执行 Keyring 操作
- **并且**: 结果应返回给 Flutter


```
// 存储密码
async function storePoolPasswordInKeyring(poolId, password):
    await rust_bridge.store_pool_password(poolId, password)

// 读取密码
async function getPoolPasswordFromKeyring(poolId):
    password = await rust_bridge.get_pool_password(poolId)
    return password

// 删除密码
async function deletePoolPasswordFromKeyring(poolId):
    await rust_bridge.delete_pool_password(poolId)

// 检查密码是否存在
async function hasPoolPasswordInKeyring(poolId):
    exists = await rust_bridge.has_pool_password(poolId)
    return exists
```

---

## 测试覆盖

**测试文件**: `rust/tests/security_keyring_feature_test.rs`

**单元测试**:
- `test_store_password()` - 测试存储密码
- `test_get_password()` - 测试读取密码
- `test_delete_password()` - 测试删除密码
- `test_has_password()` - 测试检查密码存在性
- `test_multiple_pools()` - 测试多数据池支持
- `test_memory_zeroing()` - 测试内存清零
- `test_error_not_found()` - 测试未找到错误

**功能测试**:
- `test_pool_join_with_keyring()` - 测试加入数据池时的 Keyring 集成
- `test_auto_login_with_keyring()` - 测试使用 Keyring 自动登录

**平台测试**:
- `test_windows_credential_manager()` - 测试 Windows 凭据管理器
- `test_macos_keychain()` - 测试 macOS 钥匙串
- `test_linux_secret_service()` - 测试 Linux Secret Service
- `test_android_keystore()` - 测试 Android 密钥库

**验收标准**:
- [x] 所有单元测试通过
- [x] 所有平台测试通过
- [x] 密码加密存储
- [x] 内存清零功能正常
- [x] 多数据池支持正常
- [x] 代码审查通过
- [x] 文档已更新

---

## 相关文档

**相关规格**:
- [../../domain/pool.md](../../domain/pool.md) - 数据池领域模型
- [./password.md](./password.md) - bcrypt 密码管理
- [../storage/pool_store.md](../storage/pool_store.md) - 数据池存储实现

**架构决策记录**:

---

**最后更新**: 2026-01-23
**作者**: CardMind Team
