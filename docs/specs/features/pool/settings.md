# 池设置规格

**依赖**: [../../domain/pool.md](../../domain/pool.md), [../../architecture/storage/pool_store.md](../../architecture/storage/pool_store.md), [../../architecture/security/password.md](../../architecture/security/password.md), [../../architecture/sync/service.md](../../architecture/sync/service.md)
**相关测试**: `test/feature/features/pool_management_feature_test.dart`, `rust/tests/pool_model_feature_test.rs`

---

## 概述

定义池设置变更的业务规则：可更新名称与密钥；更新密钥需验证旧密钥；任何变更必须同步到池内所有设备。

---

## GIVEN-WHEN-THEN 场景

### 场景：更新池名称

- **GIVEN**: 设备已加入某个池且新名称非空
- **WHEN**: 请求更新池名称
- **THEN**: 系统更新池名称并持久化
- **并且**: 变更同步到所有设备

### 场景：更新池名称失败

- **GIVEN**: 新名称为空或仅包含空白字符
- **WHEN**: 请求更新池名称
- **THEN**: 系统拒绝并返回错误 `INVALID_NAME`

### 场景：更新池密钥成功

- **GIVEN**: 设备已加入某个池且提供正确旧密钥
- **WHEN**: 请求设置新密钥且长度不少于 6
- **THEN**: 系统使用 bcrypt 哈希保存新密钥
- **并且**: 变更同步到所有设备

### 场景：旧密钥验证失败

- **GIVEN**: 提供的旧密钥错误
- **WHEN**: 请求更新池密钥
- **THEN**: 系统拒绝并返回错误 `INVALID_PASSWORD`

### 场景：新密钥过短

- **GIVEN**: 新密钥长度少于 6
- **WHEN**: 请求更新池密钥
- **THEN**: 系统拒绝并返回错误 `WEAK_PASSWORD`
