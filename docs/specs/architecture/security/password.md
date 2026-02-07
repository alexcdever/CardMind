# bcrypt 密码管理架构规格

## 概述

本规格定义了 CardMind 中数据池密码的哈希、验证和强度检查机制。系统使用 bcrypt 算法进行密码哈希，工作因子为 12，并通过内存清零技术保护敏感数据。

**技术栈**:
- bcrypt = "0.16" - 密码哈希算法
- zeroize = "1.7" - 内存清零

---

## 需求：密码哈希

系统应使用 bcrypt 算法对数据池密码进行哈希，工作因子为 12，并自动生成盐值。

### 场景：创建数据池时哈希密码

- **前置条件**: 用户提供明文密码字符串
- **操作**: 调用密码哈希函数
- **预期结果**: 应返回 bcrypt 格式的哈希字符串（`$2b$12$...`）
- **并且**: 原始密码应在内存中自动清零

**实现逻辑**:

```
function hash_password(password):
    // 使用 bcrypt 哈希密码，工作因子 12
    // 设计决策：工作因子 12 平衡安全性和性能
    hash = bcrypt.hash(password, cost=12)

    // 密码离开作用域时自动清零
    // 注意：使用 Zeroizing<String> 包装器

    return hash
```

---

## 需求：密码验证

系统应验证用户输入的密码与存储的哈希值是否匹配，不暴露具体错误信息以防止时序攻击。

### 场景：加入数据池时验证密码

- **前置条件**: 用户输入密码和存储的密码哈希
- **操作**: 调用密码验证函数
- **预期结果**: 应返回布尔值表示是否匹配
- **并且**: 验证时间应恒定，不因密码正确性而变化

**实现逻辑**:

```
function verify_password(password, hash):
    // 验证密码与哈希是否匹配
    // 设计决策：恒定时间比较防止时序攻击
    is_valid = bcrypt.verify(password, hash)

    // 不暴露具体错误信息
    // 注意：仅返回布尔值，不返回错误详情

    return is_valid
```

---

## 需求：密码强度验证

系统应验证密码强度，要求最少 8 位字符，并根据字符类型评估强度等级。

### 场景：创建数据池时检查密码强度

- **前置条件**: 用户提供密码字符串
- **操作**: 调用强度验证函数
- **预期结果**: 应返回强度等级（弱/中/强）
- **并且**: 弱密码（0-1 种字符类型）、中密码（2 种）、强密码（3 种+）

**字符类型**:
- 字母（大小写）
- 数字
- 特殊字符

**实现逻辑**:

```
function validate_strength(password):
    // 检查最小长度
    if length(password) < 8:
        return "too_short"

    // 统计字符类型
    // 设计决策：基于多样性评估，而非复杂性规则
    has_letter = contains_letter(password)
    has_number = contains_number(password)
    has_special = contains_special(password)

    type_count = count(has_letter, has_number, has_special)

    // 评估强度
    if type_count <= 1:
        return "weak"
    else if type_count == 2:
        return "medium"
    else:
        return "strong"
```

---

## 需求：时间戳验证

系统应验证加入请求的时间戳，防止重放攻击，有效期为 5 分钟，容忍 ±30 秒时钟偏差。

### 场景：处理加入请求时验证时间戳

- **前置条件**: 收到包含时间戳的加入请求
- **操作**: 调用时间戳验证函数
- **预期结果**: 时间戳应在有效期内（当前时间 ±5 分钟 ±30 秒）
- **并且**: 过期请求应被拒绝

**实现逻辑**:

```
function validate_timestamp(timestamp):
    // 获取当前时间
    now = current_time()

    // 计算时间差
    diff = abs(now - timestamp)

    // 检查有效期（5 分钟 + 30 秒容差）
    // 设计决策：容差考虑设备间的时钟偏差
    max_age = 5 * 60 * 1000 + 30 * 1000  // milliseconds

    if diff > max_age:
        return error("timestamp_expired")

    return ok()
```

**数据结构**:

```
// 包含时间戳的加入请求
structure JoinRequest:
    pool_id: String
    device_id: String
    password: ZeroizingString
    timestamp: i64  // Unix timestamp in milliseconds

    // 验证时间戳
    function validate_timestamp():
        return validate_timestamp(this.timestamp)
```

---

## 需求：内存安全

系统应在密码离开作用域时自动清零内存，防止敏感数据泄露。

### 场景：密码处理完成后清零内存

- **前置条件**: 密码存储在 Zeroizing 包装器中
- **操作**: 密码变量离开作用域
- **预期结果**: 内存中的密码数据应自动清零
- **并且**: 密码不应参与序列化，防止意外泄露

**实现逻辑**:

```
// 自动清零的密码包装器
structure ZeroizingString:
    data: String

    // 离开作用域时自动清零
    // 设计决策：使用 RAII 模式实现自动清理
    on_drop():
        zero_memory(data)
```

---

## 相关文档

**相关规格**:
- [../../domain/pool.md](../../domain/pool.md) - 数据池领域模型
- [../storage/pool_store.md](../storage/pool_store.md) - 数据池存储实现

**架构决策记录**:

---

## 测试覆盖

**测试文件**: `rust/tests/security_password_feature_test.rs`

**单元测试**:
- `test_hash_password()` - 测试密码哈希生成
- `test_verify_password_success()` - 测试密码验证成功
- `test_verify_password_failure()` - 测试密码验证失败
- `test_validate_strength_weak()` - 测试弱密码检测
- `test_validate_strength_medium()` - 测试中等密码检测
- `test_validate_strength_strong()` - 测试强密码检测
- `test_validate_timestamp_valid()` - 测试有效时间戳
- `test_validate_timestamp_expired()` - 测试过期时间戳
- `test_memory_zeroing()` - 测试内存清零

**功能测试**:
- `test_pool_creation_with_password()` - 测试创建数据池时的密码哈希
- `test_pool_join_with_password()` - 测试加入数据池时的密码验证

**验收标准**:
- [x] 所有单元测试通过
- [x] 密码哈希格式正确（`$2b$12$...`）
- [x] 密码验证时间恒定
- [x] 内存清零功能正常
- [x] 时间戳验证防止重放攻击
- [x] 代码审查通过
- [x] 文档已更新
