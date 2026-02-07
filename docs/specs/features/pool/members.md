# 池成员规格

**状态**: 生效中
**依赖**: [../../domain/pool.md](../../domain/pool.md), [../../architecture/storage/pool_store.md](../../architecture/storage/pool_store.md), [../../architecture/storage/device_config.md](../../architecture/storage/device_config.md), [../../architecture/sync/service.md](../../architecture/sync/service.md), [../../architecture/sync/peer_discovery.md](../../architecture/sync/peer_discovery.md)
**相关测试**: `test/feature/features/pool_management_feature_test.dart`, `test/feature/features/p2p_sync_feature_test.dart`

---

## 概述

定义池成员的业务查询与变更：设备列表包含在线状态与当前设备标记；成员增删应通过同步机制保持一致。

---

## GIVEN-WHEN-THEN 场景

### 场景：获取成员列表

- **GIVEN**: 设备已加入某个池
- **WHEN**: 请求成员列表
- **THEN**: 返回池内所有设备标识
- **并且**: 返回每个设备的在线状态
- **并且**: 标记当前设备为“当前设备”

### 场景：新设备加入后成员列表更新

- **GIVEN**: 池中已有设备列表
- **WHEN**: 新设备成功加入该池
- **THEN**: 设备被加入成员列表
- **并且**: 成员变更通过同步传播

### 场景：设备离开后成员列表更新

- **GIVEN**: 设备属于某个池
- **WHEN**: 设备离开该池
- **THEN**: 设备从成员列表移除
- **并且**: 成员变更通过同步传播
