# CardStore 架构规格

## 概述

本规格定义了单池架构下 CardStore 的技术实现，包括双层存储架构（Loro + SQLite）、订阅驱动的同步机制和数据管理操作。

**架构模式**:
- **写入层**: Loro CRDT 文档（数据源）
- **读取层**: SQLite 缓存（优化查询）
- **同步机制**: 订阅驱动更新

---

## 需求：Loro 文档管理

系统应使用 Loro CRDT 文档作为数据源管理卡片数据。

### 场景：为新卡片创建 Loro 文档

- **前置条件**: 需要创建新卡片
- **操作**: 调用 CardStore.create_card()
- **预期结果**: 应创建新的 Loro 文档
- **并且**: 文档应持久化到 `data/loro/<card_id>/snapshot.loro`

### 场景：从磁盘加载 Loro 文档

- **前置条件**: 卡片 ID 存在
- **操作**: 调用 CardStore.load_card()
- **预期结果**: 应从 `data/loro/<card_id>/snapshot.loro` 加载 Loro 文档
- **并且**: 文档应缓存在内存中

---

## 需求：SQLite 缓存层

系统应维护 SQLite 缓存以优化读取查询。

### 场景：cards 表的 SQLite schema

- **前置条件**: 需要定义卡片缓存表结构
- **操作**: 设定 cards 表字段
- **预期结果**: 表包含卡片核心字段与删除标记
- **并且**: schema 片段可用于初始化表


### 场景：card_pool_bindings 表的 SQLite schema

- **前置条件**: 需要定义卡片与池的绑定关系表
- **操作**: 设定 card_pool_bindings 表字段
- **预期结果**: 表包含 card_id 与 pool_id 组合主键
- **并且**: schema 片段可用于初始化表


---

## 需求：订阅驱动的同步

系统应使用 Loro 文档订阅在 Pool 文档变更时自动更新 SQLite 缓存。

### 场景：Pool 订阅触发 SQLite 更新

- **前置条件**: Pool Loro 文档被修改
- **操作**: 调用 Pool.commit()
- **预期结果**: 应触发订阅回调
- **并且**: card_pool_bindings 表应被更新

---

## 需求：池成员管理

系统应通过修改 Pool.card_ids（而非 Card.pool_ids）管理卡片-池关系。

### 场景：添加卡片到池

- **前置条件**: 池和卡片存在
- **操作**: 调用 CardStore.add_card_to_pool()
- **预期结果**: Pool.card_ids 应包含该卡片 ID
- **并且**: SQLite bindings 表应通过订阅更新

### 场景：从池移除卡片

- **前置条件**: 卡片已被添加到池
- **操作**: 调用 CardStore.remove_card_from_pool()
- **预期结果**: Pool.card_ids 应不再包含该卡片
- **并且**: 移除操作应通过 P2P 同步传播到所有设备

---

## 需求：退出池时的数据清理

系统应在设备退出池时清理所有本地数据。

### 场景：删除所有 Loro 文档和 SQLite 数据

- **前置条件**: 设备在 pool_A 中，有 50 张卡片
- **操作**: 调用 CardStore.leave_pool()
- **预期结果**: 所有卡片 Loro 文档应被删除
- **并且**: Pool Loro 文档应被删除
- **并且**: SQLite 应被清空

---

## 补充说明

**技术栈**:
- **Rust std::fs**: 用于 Loro 文档持久化的文件系统操作

**设计模式**:
- **双层架构**: 分离写入层（Loro）和读取层（SQLite）
- **观察者模式**: 订阅驱动的 SQLite 更新
- **旁路缓存模式**: Loro 文档的内存 HashMap 缓存

**性能考虑**:
- **内存缓存**: Loro 文档缓存在 HashMap 中以避免重复磁盘 I/O
- **SQLite 索引**: 在 updated_at、deleted、pool_id、card_id 上建立索引以加快查询
- **批量操作**: 使用 SQLite 事务进行批量更新
- **延迟加载**: Loro 文档按需加载，而非启动时全部加载

**安全考虑**:
- **文件权限**: Loro 文档以仅用户读写权限存储
- **SQLite 加密**: 考虑使用 SQLite 加密扩展保护敏感数据
- **输入验证**: 验证 card_id 和 pool_id 以防止路径遍历

---

## 相关文档

**领域规格**:
- [../../domain/card.md](../../domain/card.md) - 卡片业务规则
- [../../domain/pool.md](../../domain/pool.md) - 池领域模型

**相关架构规格**:
- [./device_config.md](./device_config.md) - 设备配置存储
- [./pool_store.md](./pool_store.md) - PoolStore 实现
- [../sync/service.md](../sync/service.md) - P2P 同步服务

**架构决策记录**:

---

## 测试覆盖

**测试文件**: `rust/tests/card_store_feature_test.rs`

**单元测试**:
- `it_creates_card_and_auto_adds_to_current_pool()` - 创建卡片自动加入池
- `it_should_fail_when_device_not_joined()` - 未加入时失败
- `it_should_trigger_subscription_to_update_bindings()` - 触发订阅
- `it_should_modify_pool_card_ids_on_add()` - 添加卡片到池
- `it_should_be_idempotent()` - 幂等添加
- `it_should_remove_card_from_pool_card_ids()` - 移除卡片
- `it_should_propagate_removal_to_all_devices()` - 传播移除
- `it_should_clean_up_all_data_when_leaving_pool()` - 退出池清理
- `it_should_update_bindings_on_pool_change()` - 更新绑定
- `it_should_clear_old_bindings_when_pool_changes()` - 清除旧绑定

**功能测试**:
- 创建卡片自动加入当前池
- 移除操作跨设备传播
- 退出池完整流程

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 功能测试通过
- [ ] 代码审查通过
- [ ] 文档已更新
