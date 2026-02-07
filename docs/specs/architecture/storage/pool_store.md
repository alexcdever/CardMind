# PoolStore 架构规格

## 概述

本规格定义了 PoolStore 的技术实现，使用双层架构（Loro + SQLite）管理池数据并强制执行单池约束。

**技术栈**:
- **loro** = "1.0" - CRDT 文档存储
- **bcrypt** = "0.15" - 密码哈希
- **rusqlite** = "0.31" - SQLite 数据库
- **uuid** = "1.6" - UUID v7 生成

**核心职责**:
- 管理 Pool Loro 文档（创建、加载、更新）
- 强制执行每设备单池约束
- 维护池-设备关系
- 同步 Pool 数据到 SQLite 缓存

---

## 需求：Pool Loro 文档管理

系统应使用 Loro CRDT 文档作为数据源管理 Pool 数据。

### 场景：创建新池

- **前置条件**: 用户想要创建新池
- **操作**: 调用 PoolStore.create_pool()
- **预期结果**: 应创建新的 Pool Loro 文档
- **并且**: 文档应持久化到 `data/loro/<pool_id>/snapshot.loro`
- **并且**: 池应通过订阅添加到 SQLite

### 场景：从磁盘加载池

- **前置条件**: 池 ID 存在
- **操作**: 调用 PoolStore.load_pool()
- **预期结果**: 应从磁盘加载 Pool Loro 文档
- **并且**: 文档应缓存在内存中

### 场景：更新池名称

- **前置条件**: 池存在
- **操作**: 调用 PoolStore.update_pool_name()
- **预期结果**: 池名称应被更新
- **并且**: 变更应传播到所有设备

---

## 需求：单池约束强制执行

系统应强制执行设备最多只能加入一个池。

### 场景：设备成功加入第一个池

- **前置条件**: 设备未加入任何池
- **操作**: 调用 PoolStore.join_pool()
- **预期结果**: 设备应被添加到 Pool.device_ids
- **并且**: DeviceConfig.pool_id 应被设置
- **并且**: 变更应通过 P2P 同步传播到所有设备

### 场景：设备拒绝加入第二个池

- **前置条件**: 设备已加入 pool_A
- **操作**: 为 pool_B 调用 PoolStore.join_pool()
- **预期结果**: 系统应返回 ALREADY_JOINED_POOL 错误
- **并且**: DeviceConfig.pool_id 应保持为 pool_A

---

## 需求：离开池和数据清理

系统应在设备离开池时清理所有池相关数据。

### 场景：设备离开池

- **前置条件**: 设备已加入池
- **操作**: 调用 PoolStore.leave_pool()
- **预期结果**: 设备应从 Pool.device_ids 中移除
- **并且**: DeviceConfig.pool_id 应被清除
- **并且**: 所有本地 Pool 和 Card 数据应被删除
- **并且**: 移除操作应传播到其他设备

---

## 需求：池-卡片关系管理

系统应通过 Pool.card_ids 管理池和卡片之间的关系。

### 场景：添加卡片到池

- **前置条件**: 池和卡片存在
- **操作**: 调用 PoolStore.add_card()
- **预期结果**: 卡片 ID 应被添加到 Pool.card_ids
- **并且**: 变更应传播到所有设备
- **并且**: SQLite 绑定应通过订阅更新

### 场景：获取池中的所有卡片

- **前置条件**: 池存在
- **操作**: 调用 PoolStore.get_pool_cards()
- **预期结果**: 应返回池中所有卡片 ID 列表

---

## 需求：SQLite 同步

系统应通过订阅回调将 Pool 数据同步到 SQLite。

### 场景：池更新触发 SQLite 更新

- **前置条件**: Pool Loro 文档被修改
- **操作**: 触发订阅回调
- **预期结果**: pools 表应被更新
- **并且**: card_pool_bindings 表应被更新

---

## 需求：密码管理

系统应安全地管理池密码。

### 场景：验证池密码

- **前置条件**: 用户尝试加入池
- **操作**: 验证提供的密码
- **预期结果**: 应使用恒定时间比较
- **并且**: 应防止时序攻击

---

## 补充说明

**技术栈**:
- **loro** = "1.0" - CRDT 文档存储
- **bcrypt** = "0.15" - 密码哈希（成本因子 12）
- **rusqlite** = "0.31" - SQLite 数据库
- **uuid** = "1.6" - UUID v7 生成
- **tokio** - 异步运行时

**设计模式**:
- **仓储模式**: PoolStore 作为数据访问层
- **观察者模式**: 订阅驱动的 SQLite 更新
- **约束强制**: 应用层的单池约束
- **缓存模式**: 两级缓存（内存 + 磁盘）

**安全考虑**:
- **密码哈希**: 使用成本因子 12 的 bcrypt
- **密码验证**: 通过 bcrypt 的恒定时间比较
- **访问控制**: 只有 Pool.device_ids 中的设备可以访问池数据
- **密码长度**: 最小 8 字符，最大 72 字符（bcrypt 限制）

---

## 相关文档

**领域规格**:
- [../../domain/pool.md](../../domain/pool.md) - 池领域模型

**架构规格**:
- [./dual_layer.md](./dual_layer.md) - 双层架构
- [./card_store.md](./card_store.md) - CardStore 实现
- [./device_config.md](./device_config.md) - 设备配置
- [./loro_integration.md](./loro_integration.md) - Loro 集成
- [../sync/service.md](../sync/service.md) - P2P 同步服务
- [../security/password.md](../security/password.md) - 密码管理

**架构决策记录**:
- ADR-0001: 单池模型 - 每设备单池设计决策

---

## 测试覆盖

**测试文件**: `rust/tests/pool_store_feature_test.rs`

**单元测试**:
- `test_create_pool()` - 创建池
- `test_create_pool_with_weak_password()` - 弱密码验证
- `test_load_pool()` - 加载池
- `test_load_nonexistent_pool()` - 加载不存在的池
- `test_update_pool_name()` - 更新池名称
- `test_join_pool_success()` - 成功加入池
- `test_join_pool_invalid_password()` - 无效密码
- `test_join_pool_rejects_second()` - 拒绝第二个池
- `test_leave_pool()` - 离开池
- `test_leave_pool_not_joined()` - 未加入时离开
- `test_add_card_to_pool()` - 添加卡片
- `test_add_card_idempotent()` - 幂等添加
- `test_remove_card_from_pool()` - 移除卡片
- `test_get_pool_cards()` - 获取池卡片
- `test_sqlite_sync()` - SQLite 同步
- `test_password_hashing()` - 密码哈希
- `test_password_verification()` - 密码验证
- `test_cache_hit()` - 缓存命中
- `test_cache_miss()` - 缓存未命中

**功能测试**:
- `test_pool_lifecycle()` - 池生命周期
- `test_multi_device_pool()` - 多设备池
- `test_pool_sync_across_devices()` - 跨设备同步
- `test_data_cleanup_on_leave()` - 离开时数据清理

**验收标准**:
- [x] 所有单元测试通过
- [x] 单池约束强制执行
- [x] 密码验证工作正常
- [x] 离开池时数据清理
- [x] 缓存提高性能
- [x] 代码审查通过
