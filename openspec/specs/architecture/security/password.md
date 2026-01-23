# bcrypt Password Management Architecture Specification
# bcrypt 密码管理架构规格

**Version**: 1.0.0
**版本**: 1.0.0
**Status**: Active
**状态**: Active
**Dependencies**: [../../domain/pool/model.md](../../domain/pool/model.md)
**依赖**: [../../domain/pool/model.md](../../domain/pool/model.md)
**Related Tests**: `rust/tests/security/password_test.rs`
**相关测试**: `rust/tests/security/password_test.rs`

---

## Overview
## 概述

This specification defines the password hashing, verification, and strength validation mechanisms for data pools in CardMind. The system uses bcrypt algorithm with work factor 12 and employs memory zeroing techniques to protect sensitive data.

本规格定义了 CardMind 中数据池密码的哈希、验证和强度检查机制。系统使用 bcrypt 算法进行密码哈希，工作因子为 12，并通过内存清零技术保护敏感数据。

**Technology Stack**:
**技术栈**:
- bcrypt = "0.16" - Password hashing algorithm
- bcrypt = "0.16" - 密码哈希算法
- zeroize = "1.7" - Memory zeroing
- zeroize = "1.7" - 内存清零

---

## Requirement: Password Hashing
## 需求：密码哈希

The system SHALL hash data pool passwords using bcrypt algorithm with work factor 12 and automatically generated salt.

系统应使用 bcrypt 算法对数据池密码进行哈希，工作因子为 12，并自动生成盐值。

### Scenario: Hash password when creating pool
### 场景：创建数据池时哈希密码

- **GIVEN**: User provides plaintext password string
- **前置条件**: 用户提供明文密码字符串
- **WHEN**: Password hashing function is called
- **操作**: 调用密码哈希函数
- **THEN**: A bcrypt format hash string SHALL be returned (`$2b$12$...`)
- **预期结果**: 应返回 bcrypt 格式的哈希字符串（`$2b$12$...`）
- **AND**: Original password SHALL be automatically zeroed in memory
- **并且**: 原始密码应在内存中自动清零

**Implementation Logic**:
**实现逻辑**:

```
function hash_password(password):
    // Use bcrypt to hash password with work factor 12
    // 使用 bcrypt 哈希密码，工作因子 12
    // Design decision: Work factor 12 balances security and performance
    // 设计决策：工作因子 12 平衡安全性和性能
    hash = bcrypt.hash(password, cost=12)

    // Password automatically zeroed when leaving scope
    // 密码离开作用域时自动清零
    // Note: Using Zeroizing<String> wrapper
    // 注意：使用 Zeroizing<String> 包装器

    return hash
```

---

## Requirement: Password Verification
## 需求：密码验证

The system SHALL verify user-provided passwords against stored hashes without exposing specific error information to prevent timing attacks.

系统应验证用户输入的密码与存储的哈希值是否匹配，不暴露具体错误信息以防止时序攻击。

### Scenario: Verify password when joining pool
### 场景：加入数据池时验证密码

- **GIVEN**: User input password and stored password hash
- **前置条件**: 用户输入密码和存储的密码哈希
- **WHEN**: Password verification function is called
- **操作**: 调用密码验证函数
- **THEN**: A boolean value SHALL be returned indicating match status
- **预期结果**: 应返回布尔值表示是否匹配
- **AND**: Verification time SHALL be constant regardless of password correctness
- **并且**: 验证时间应恒定，不因密码正确性而变化

**Implementation Logic**:
**实现逻辑**:

```
function verify_password(password, hash):
    // Verify password matches hash
    // 验证密码与哈希是否匹配
    // Design decision: Constant-time comparison prevents timing attacks
    // 设计决策：恒定时间比较防止时序攻击
    is_valid = bcrypt.verify(password, hash)

    // Don't expose specific error information
    // 不暴露具体错误信息
    // Note: Return boolean only, no error details
    // 注意：仅返回布尔值，不返回错误详情

    return is_valid
```

---

## Requirement: Password Strength Validation
## 需求：密码强度验证

The system SHALL validate password strength, requiring minimum 8 characters and evaluating strength level based on character types.

系统应验证密码强度，要求最少 8 位字符，并根据字符类型评估强度等级。

### Scenario: Check password strength when creating pool
### 场景：创建数据池时检查密码强度

- **GIVEN**: User provides password string
- **前置条件**: 用户提供密码字符串
- **WHEN**: Strength validation function is called
- **操作**: 调用强度验证函数
- **THEN**: Strength level SHALL be returned (weak/medium/strong)
- **预期结果**: 应返回强度等级（弱/中/强）
- **AND**: Weak passwords (0-1 character types), medium (2 types), strong (3+ types)
- **并且**: 弱密码（0-1 种字符类型）、中密码（2 种）、强密码（3 种+）

**Character Types**:
**字符类型**:
- Letters (uppercase/lowercase)
- 字母（大小写）
- Numbers
- 数字
- Special characters
- 特殊字符

**Implementation Logic**:
**实现逻辑**:

```
function validate_strength(password):
    // Check minimum length
    // 检查最小长度
    if length(password) < 8:
        return "too_short"

    // Count character types
    // 统计字符类型
    // Design decision: Evaluate based on diversity, not complexity rules
    // 设计决策：基于多样性评估，而非复杂性规则
    has_letter = contains_letter(password)
    has_number = contains_number(password)
    has_special = contains_special(password)

    type_count = count(has_letter, has_number, has_special)

    // Evaluate strength
    // 评估强度
    if type_count <= 1:
        return "weak"
    else if type_count == 2:
        return "medium"
    else:
        return "strong"
```

---

## Requirement: Timestamp Validation
## 需求：时间戳验证

The system SHALL validate join request timestamps to prevent replay attacks, with 5-minute validity period and ±30 seconds clock skew tolerance.

系统应验证加入请求的时间戳，防止重放攻击，有效期为 5 分钟，容忍 ±30 秒时钟偏差。

### Scenario: Validate timestamp when processing join request
### 场景：处理加入请求时验证时间戳

- **GIVEN**: Received join request with timestamp
- **前置条件**: 收到包含时间戳的加入请求
- **WHEN**: Timestamp validation function is called
- **操作**: 调用时间戳验证函数
- **THEN**: Timestamp SHALL be within validity period (current time ±5 minutes ±30 seconds)
- **预期结果**: 时间戳应在有效期内（当前时间 ±5 分钟 ±30 秒）
- **AND**: Expired requests SHALL be rejected
- **并且**: 过期请求应被拒绝

**Implementation Logic**:
**实现逻辑**:

```
function validate_timestamp(timestamp):
    // Get current time
    // 获取当前时间
    now = current_time()

    // Calculate time difference
    // 计算时间差
    diff = abs(now - timestamp)

    // Check validity (5 minutes + 30 seconds tolerance)
    // 检查有效期（5 分钟 + 30 秒容差）
    // Design decision: Tolerance accounts for clock skew between devices
    // 设计决策：容差考虑设备间的时钟偏差
    max_age = 5 * 60 * 1000 + 30 * 1000  // milliseconds

    if diff > max_age:
        return error("timestamp_expired")

    return ok()
```

**Data Structure**:
**数据结构**:

```
// Join request with timestamp
// 包含时间戳的加入请求
structure JoinRequest:
    pool_id: String
    device_id: String
    password: ZeroizingString
    timestamp: i64  // Unix timestamp in milliseconds

    // Validate timestamp
    // 验证时间戳
    function validate_timestamp():
        return validate_timestamp(this.timestamp)
```

---

## Requirement: Memory Safety
## 需求：内存安全

The system SHALL automatically zero memory when passwords leave scope to prevent sensitive data leakage.

系统应在密码离开作用域时自动清零内存，防止敏感数据泄露。

### Scenario: Zero memory after password processing
### 场景：密码处理完成后清零内存

- **GIVEN**: Password stored in Zeroizing wrapper
- **前置条件**: 密码存储在 Zeroizing 包装器中
- **WHEN**: Password variable leaves scope
- **操作**: 密码变量离开作用域
- **THEN**: Password data in memory SHALL be automatically zeroed
- **预期结果**: 内存中的密码数据应自动清零
- **AND**: Password SHALL NOT participate in serialization to prevent accidental leakage
- **并且**: 密码不应参与序列化，防止意外泄露

**Implementation Logic**:
**实现逻辑**:

```
// Password wrapper with automatic zeroing
// 自动清零的密码包装器
structure ZeroizingString:
    data: String

    // Automatically zero on drop
    // 离开作用域时自动清零
    // Design decision: Use RAII pattern for automatic cleanup
    // 设计决策：使用 RAII 模式实现自动清理
    on_drop():
        zero_memory(data)
```

---

## Test Coverage
## 测试覆盖

**Test File**: `rust/tests/security/password_test.rs`
**测试文件**: `rust/tests/security/password_test.rs`

**Unit Tests**:
**单元测试**:
- `test_hash_password()` - Test password hash generation
- `test_hash_password()` - 测试密码哈希生成
- `test_verify_password_success()` - Test password verification success
- `test_verify_password_success()` - 测试密码验证成功
- `test_verify_password_failure()` - Test password verification failure
- `test_verify_password_failure()` - 测试密码验证失败
- `test_validate_strength_weak()` - Test weak password detection
- `test_validate_strength_weak()` - 测试弱密码检测
- `test_validate_strength_medium()` - Test medium password detection
- `test_validate_strength_medium()` - 测试中等密码检测
- `test_validate_strength_strong()` - Test strong password detection
- `test_validate_strength_strong()` - 测试强密码检测
- `test_validate_timestamp_valid()` - Test valid timestamp
- `test_validate_timestamp_valid()` - 测试有效时间戳
- `test_validate_timestamp_expired()` - Test expired timestamp
- `test_validate_timestamp_expired()` - 测试过期时间戳
- `test_memory_zeroing()` - Test memory zeroing
- `test_memory_zeroing()` - 测试内存清零

**Integration Tests**:
**集成测试**:
- `test_pool_creation_with_password()` - Test password hashing during pool creation
- `test_pool_creation_with_password()` - 测试创建数据池时的密码哈希
- `test_pool_join_with_password()` - Test password verification during pool join
- `test_pool_join_with_password()` - 测试加入数据池时的密码验证

**Acceptance Criteria**:
**验收标准**:
- [x] All unit tests pass
- [x] 所有单元测试通过
- [x] Password hash format correct (`$2b$12$...`)
- [x] 密码哈希格式正确（`$2b$12$...`）
- [x] Password verification time constant
- [x] 密码验证时间恒定
- [x] Memory zeroing works correctly
- [x] 内存清零功能正常
- [x] Timestamp validation prevents replay attacks
- [x] 时间戳验证防止重放攻击
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
- [./keyring.md](./keyring.md) - Keyring password storage
- [./keyring.md](./keyring.md) - Keyring 密码存储
- [../storage/pool_store.md](../storage/pool_store.md) - Pool store implementation
- [../storage/pool_store.md](../storage/pool_store.md) - 数据池存储实现

**ADRs**:
**架构决策记录**:
- [../../../docs/adr/0001-single-pool-constraint.md](../../../docs/adr/0001-single-pool-constraint.md) - Single pool constraint
- [../../../docs/adr/0001-single-pool-constraint.md](../../../docs/adr/0001-single-pool-constraint.md) - 单池约束

---

**Last Updated**: 2026-01-23
**最后更新**: 2026-01-23
**Authors**: CardMind Team
**作者**: CardMind Team
