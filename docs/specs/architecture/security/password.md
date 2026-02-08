# secretkey 管理架构规格（临时方案）

## 概述

当前阶段仅定义最小可用的 secretkey 处理规则。secretkey 明文保存在数据池元数据中；加入与同步只做哈希校验，不提供强度、时间戳或内存安全等能力。

---

## 需求：明文保存 secretkey

系统在创建数据池时应保存用户提供的 secretkey 明文到数据池元数据。

### 场景：创建数据池时保存 secretkey

- **前置条件**: 用户提供 secretkey
- **操作**: 保存到数据池元数据
- **预期结果**: 元数据中保存明文 secretkey
- **并且**: 不进行强度检查或其他安全处理

---

## 需求：加入时携带 secretkey 哈希

系统在加入数据池请求中携带 secretkey 的 SHA-256 哈希值，用于与目标数据池的 secretkey 校验匹配。

### 场景：加入数据池时发送哈希

- **前置条件**: 用户输入 secretkey，目标数据池已保存 secretkey
- **操作**: 发送 secretkey 的 SHA-256 哈希
- **预期结果**: 目标设备使用一致的哈希方式进行匹配
- **并且**: 哈希仅用于匹配，不作为安全防护

---

## 需求：同步请求携带 secretkey 哈希

每次同步请求必须携带 `pool_id` 与 secretkey 的 SHA-256 哈希，用于同步前校验。

### 场景：同步请求校验

- **前置条件**: 设备已加入数据池
- **操作**: 发起同步请求
- **预期结果**: 请求携带 `pool_id` 与 secretkey 哈希
- **并且**: 校验不通过时拒绝同步

---

## 需求：不提供安全性能力

系统不提供 secretkey 强度、时间戳防重放、内存清零等安全能力，待安全性功能完成后再完善。

### 场景：当前阶段安全能力缺失

- **前置条件**: 系统处于临时方案阶段
- **操作**: 使用明文 secretkey 与简化匹配流程
- **预期结果**: 不包含强度、时间戳、防重放等能力
- **并且**: 后续安全功能完成后再补充

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
- `it_should_hash_secretkey_with_sha256()` - 测试 secretkey 哈希生成
- `it_should_verify_secretkey_hash_successfully()` - 测试 secretkey 哈希验证成功
- `it_should_verify_secretkey_hash_failure()` - 测试 secretkey 哈希验证失败

**功能测试**:
- `it_should_create_pool_with_secretkey()` - 测试创建数据池时 secretkey 处理
- `it_should_join_pool_with_secretkey_hash_verification()` - 测试加入数据池时哈希验证

**验收标准**:
- [x] 所有单元测试通过
- [x] secretkey 哈希为 SHA-256
- [x] 加入与同步使用哈希匹配
- [x] 文档已更新
