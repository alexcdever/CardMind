# 池创建规格

**状态**: 生效中
**依赖**: [../../domain/pool.md](../../domain/pool.md), [../../domain/types.md](../../domain/types.md), [../../architecture/security/password.md](../../architecture/security/password.md), [../../architecture/storage/pool_store.md](../../architecture/storage/pool_store.md), [../../architecture/storage/device_config.md](../../architecture/storage/device_config.md), [../../architecture/sync/service.md](../../architecture/sync/service.md)
**相关测试**: `test/feature/features/pool_management_feature_test.dart`, `rust/tests/pool_model_feature_test.rs`

---

## 概述

定义池创建的业务规则：名称必填、密钥长度不少于 6、池 ID 使用 UUID v7、密钥以 bcrypt 哈希存储；创建成功后设备自动加入并触发同步。

---

## GIVEN-WHEN-THEN 场景

### 场景：使用有效名称与密钥创建池

- **GIVEN**: 设备未加入任何池，名称非空且密钥长度不少于 6
- **WHEN**: 用户发起创建池请求
- **THEN**: 系统生成 UUID v7 作为池 ID
- **并且**: 系统使用 bcrypt 哈希存储池密钥
- **并且**: 设备自动加入该池
- **并且**: 同步服务对该池立即启动

### 场景：拒绝空名称创建

- **GIVEN**: 名称为空或仅包含空白字符
- **WHEN**: 用户发起创建池请求
- **THEN**: 系统拒绝创建并返回错误 `INVALID_NAME`

### 场景：拒绝弱密钥创建

- **GIVEN**: 密钥长度少于 6
- **WHEN**: 用户发起创建池请求
- **THEN**: 系统拒绝创建并返回错误 `WEAK_PASSWORD`
