# 离开池规格

**状态**: 生效中
**依赖**: [../../domain/pool.md](../../domain/pool.md), [../../architecture/storage/device_config.md](../../architecture/storage/device_config.md), [../../architecture/storage/pool_store.md](../../architecture/storage/pool_store.md), [../../architecture/storage/card_store.md](../../architecture/storage/card_store.md), [../../architecture/storage/sqlite_cache.md](../../architecture/storage/sqlite_cache.md), [../../architecture/sync/service.md](../../architecture/sync/service.md), [../../architecture/sync/subscription.md](../../architecture/sync/subscription.md)
**相关测试**: `test/feature/features/pool_management_feature_test.dart`, `rust/tests/pool_model_feature_test.rs`

---

## 概述

定义离开池的业务规则：确认后移除设备与池的关系；仅清理本地属于该池的数据（卡片、池与同步元数据），保留本地独立数据；清除设备配置中的池 ID。

---

## GIVEN-WHEN-THEN 场景

### 场景：确认离开池并完成清理

- **GIVEN**: 设备已加入某个池且用户确认离开
- **WHEN**: 触发离开池流程
- **THEN**: 系统从池成员列表移除该设备
- **并且**: 清除本地属于该池的卡片数据
- **并且**: 清除本地池数据与同步元数据
- **并且**: 清除设备配置中的池 ID
- **并且**: 不属于该池的本地独立数据保持不变

### 场景：未确认离开池不做变更

- **GIVEN**: 设备已加入某个池且未确认离开
- **WHEN**: 触发离开池流程
- **THEN**: 不移除设备关系且本地数据不变
