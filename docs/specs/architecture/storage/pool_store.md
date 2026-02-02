# PoolStore 架构规格

**版本**: 1.0.0

**状态**: 活跃

**依赖**: [../../domain/pool/model.md](../../domain/pool/model.md), [./device_config.md](./device_config.md), [./dual_layer.md](./dual_layer.md)

**相关测试**: `rust/tests/pool_store_test.rs`

---

## 概述

本规格定义了 PoolStore 的技术实现，使用双层架构（Loro + SQLite）管理池数据并强制执行单池约束。

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

**实现**:

```
function create_pool(pool_name, password):
    // 步骤1：生成唯一池标识符
    // 设计决策：使用 UUIDv7 实现时间可排序的 ID
    pool_id = generate_uuid_v7()

    // 步骤2：哈希密码以确保安全
    // 安全：使用适当成本因子的 bcrypt
    password_hash = hash_password(password)

    // 步骤3：创建 CRDT 文档结构
    // 设计决策：使用映射结构实现字段级合并
    crdt_doc = create_crdt_document()
    crdt_doc.set_field("pool_id", pool_id)
    crdt_doc.set_field("pool_name", pool_name)
    crdt_doc.set_field("password_hash", password_hash)
    crdt_doc.set_field("card_ids", empty_list)
    crdt_doc.set_field("device_ids", empty_list)
    crdt_doc.set_field("created_at", current_timestamp)
    crdt_doc.set_field("updated_at", current_timestamp)

    // 步骤4：持久化到磁盘
    // 注意：存储在池特定目录中以实现隔离
    save_to_disk(crdt_doc, path: "data/loro/{pool_id}/snapshot.loro")

    // 步骤5：缓存到内存以实现快速访问
    cache_document(pool_id, crdt_doc)

    // 步骤6：触发订阅以更新 SQLite 缓存
    // 注意：订阅模式确保一致性
    notify_pool_updated(pool)

    return pool
```

### 场景：从磁盘加载池

- **前置条件**: 池 ID 存在
- **操作**: 调用 PoolStore.load_pool()
- **预期结果**: 应从磁盘加载 Pool Loro 文档
- **并且**: 文档应缓存在内存中

**实现**:

```
function load_pool(pool_id):
    // 步骤1：首先检查内存缓存以提高性能
    // 设计决策：两级缓存（内存 + 磁盘）
    if pool_exists_in_cache(pool_id):
        crdt_doc = get_from_cache(pool_id)
        return convert_to_pool(crdt_doc)

    // 步骤2：如果不在缓存中则从磁盘加载
    file_path = "data/loro/{pool_id}/snapshot.loro"
    crdt_doc = load_crdt_from_disk(file_path)

    // 步骤3：缓存到内存以供将来访问
    cache_document(pool_id, crdt_doc)

    // 步骤4：将 CRDT 文档转换为领域模型
    return convert_to_pool(crdt_doc)

function convert_to_pool(crdt_doc):
    // 从 CRDT 文档中提取所有字段
    pool = create_pool_object()
    pool.pool_id = crdt_doc.get_field("pool_id")
    pool.pool_name = crdt_doc.get_field("pool_name")
    pool.password_hash = crdt_doc.get_field("password_hash")
    pool.card_ids = crdt_doc.get_list("card_ids")
    pool.device_ids = crdt_doc.get_list("device_ids")
    pool.created_at = crdt_doc.get_field("created_at")
    pool.updated_at = crdt_doc.get_field("updated_at")

    return pool
```

---

## 需求：单池约束强制执行

系统应强制执行设备最多只能加入一个池。

### 场景：设备成功加入第一个池

- **前置条件**: 设备未加入任何池
- **操作**: 调用 PoolStore.join_pool()
- **预期结果**: 设备应被添加到 Pool.device_ids
- **并且**: DeviceConfig.pool_id 应被设置
- **并且**: 变更应通过 P2P 同步传播到所有设备

**实现**:

```
function join_pool(pool_id, password):
    // 步骤1：强制执行单池约束
    // 设计决策：设备一次只能加入一个池
    device_config = load_device_config()
    if device_config.has_joined_pool():
        return error("AlreadyJoinedPool")

    // 步骤2：加载池并验证密码
    // 安全：使用恒定时间比较以防止时序攻击
    pool = load_pool(pool_id)
    if not verify_password(password, pool.password_hash):
        return error("InvalidPassword")

    // 步骤3：将设备添加到池的设备列表
    // 注意：幂等操作 - 可以安全地多次调用
    device_id = device_config.device_id
    if not pool.device_ids.contains(device_id):
        pool.device_ids.add(device_id)
        pool.updated_at = current_timestamp

        // 更新 CRDT 文档
        crdt_doc = get_pool_document(pool_id)
        crdt_doc.add_to_list("device_ids", device_id)
        crdt_doc.set_field("updated_at", current_timestamp)

        // 持久化变更
        save_to_disk(crdt_doc)

        // 触发订阅以更新 SQLite 并同步到其他设备
        notify_pool_updated(pool)

    // 步骤4：更新设备配置
    // 注意：这建立了设备-池关系
    device_config.pool_id = pool_id
    save_device_config(device_config)

    return success
```

### 场景：设备拒绝加入第二个池

- **前置条件**: 设备已加入 pool_A
- **操作**: 为 pool_B 调用 PoolStore.join_pool()
- **预期结果**: 系统应返回 AlreadyJoinedPool 错误
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

**实现**:

```
function leave_pool():
    // 步骤1：从设备配置获取当前池
    device_config = load_device_config()
    if not device_config.has_joined_pool():
        return error("NotJoinedPool")

    pool_id = device_config.pool_id

    // 步骤2：从池的设备列表中移除设备
    // 注意：此变更将通过 P2P 同步到其他设备
    pool = load_pool(pool_id)
    device_id = device_config.device_id
    pool.device_ids.remove(device_id)
    pool.updated_at = current_timestamp

    // 更新 CRDT 文档
    crdt_doc = get_pool_document(pool_id)
    crdt_doc.remove_from_list("device_ids", device_id)
    crdt_doc.set_field("updated_at", current_timestamp)

    // 持久化变更以同步到其他设备
    save_to_disk(crdt_doc)

    // 步骤3：删除所有本地数据
    // 设计决策：完全清理确保没有孤立数据
    delete_all_local_data(pool_id)

    // 步骤4：清除设备配置
    device_config.pool_id = null
    save_device_config(device_config)

    return success

function delete_all_local_data(pool_id):
    // 步骤1：从池获取所有卡片 ID
    pool = load_pool(pool_id)
    card_ids = pool.card_ids

    // 步骤2：删除所有卡片 CRDT 文档
    for each card_id in card_ids:
        delete_directory("data/loro/{card_id}")

    // 步骤3：删除池 CRDT 文档
    delete_directory("data/loro/{pool_id}")

    // 步骤4：清除 SQLite 缓存
    // 注意：从缓存中移除所有池相关数据
    execute_sql("DELETE FROM cards")
    execute_sql("DELETE FROM card_pool_bindings")
    execute_sql("DELETE FROM pools WHERE pool_id = ?", pool_id)

    // 步骤5：清除内存缓存
    remove_from_cache(pool_id)
```

---

## 需求：池-卡片关系管理

系统应通过 Pool.card_ids 管理池和卡片之间的关系。

### 场景：添加卡片到池

- **前置条件**: 池和卡片存在
- **操作**: 调用 PoolStore.add_card()
- **预期结果**: 卡片 ID 应被添加到 Pool.card_ids
- **并且**: 变更应传播到所有设备
- **并且**: SQLite 绑定应通过订阅更新

**实现**:

```
function add_card(pool_id, card_id):
    // 从存储加载池
    pool = load_pool(pool_id)

    // 如果尚未存在则添加卡片（幂等操作）
    // 设计决策：幂等以安全处理重复请求
    if not pool.card_ids.contains(card_id):
        pool.card_ids.add(card_id)
        pool.updated_at = current_timestamp

        // 更新 CRDT 文档
        crdt_doc = get_pool_document(pool_id)
        crdt_doc.add_to_list("card_ids", card_id)
        crdt_doc.set_field("updated_at", current_timestamp)

        // 持久化变更
        save_to_disk(crdt_doc)

        // 触发订阅以更新 SQLite 绑定
        // 注意：这确保卡片-池关系被缓存
        notify_pool_updated(pool)

    return success

function remove_card(pool_id, card_id):
    // 从存储加载池
    pool = load_pool(pool_id)

    // 从池的卡片列表中移除卡片
    pool.card_ids.remove(card_id)
    pool.updated_at = current_timestamp

    // 更新 CRDT 文档
    crdt_doc = get_pool_document(pool_id)
    crdt_doc.remove_from_list("card_ids", card_id)
    crdt_doc.set_field("updated_at", current_timestamp)

    // 持久化变更
    save_to_disk(crdt_doc)

    // 触发订阅以更新 SQLite 绑定
    notify_pool_updated(pool)

    return success
```

---

## 需求：SQLite 同步

系统应通过订阅回调将 Pool 数据同步到 SQLite。

### 场景：池更新触发 SQLite 更新

- **前置条件**: Pool Loro 文档被修改
- **操作**: 触发订阅回调
- **预期结果**: pools 表应被更新
- **并且**: card_pool_bindings 表应被更新

**实现**:

```
function on_pool_updated(pool):
    // 当池 CRDT 文档变更时触发的订阅回调
    // 设计决策：观察者模式实现自动缓存同步

    // 步骤1：更新 SQLite 缓存中的 pools 表
    // 注意：使用 INSERT OR REPLACE 实现幂等更新
    execute_sql(
        "INSERT OR REPLACE INTO pools (pool_id, pool_name, created_at, updated_at)
         VALUES (?, ?, ?, ?)",
        pool.pool_id, pool.pool_name, pool.created_at, pool.updated_at
    )

    // 步骤2：更新卡片-池绑定
    // 设计决策：清除并重建以确保一致性

    // 清除此池的旧绑定
    execute_sql(
        "DELETE FROM card_pool_bindings WHERE pool_id = ?",
        pool.pool_id
    )

    // 为池中所有卡片插入新绑定
    for each card_id in pool.card_ids:
        execute_sql(
            "INSERT OR REPLACE INTO card_pool_bindings (card_id, pool_id)
             VALUES (?, ?)",
            card_id, pool.pool_id
        )

    return success
```

---

## 实现细节

**技术栈**:
- **bcrypt**: 池安全的密码哈希

**设计模式**:
- **仓储模式**: PoolStore 作为数据访问层
- **观察者模式**: 订阅驱动的 SQLite 更新
- **约束强制**: 应用层的单池约束

**安全考虑**:
- **密码哈希**: 使用成本因子 12 的 bcrypt
- **密码验证**: 通过 bcrypt 的恒定时间比较
- **访问控制**: 只有 Pool.device_ids 中的设备可以访问池数据

---

## 测试覆盖

**测试文件**: `rust/tests/pool_store_test.rs`

**单元测试**:
- `test_create_pool()` - 创建池
- `test_join_pool_success()` - 成功加入池
- `test_join_pool_rejects_second()` - 拒绝第二个池
- `test_leave_pool()` - 离开池
- `test_add_card_to_pool()` - 添加卡片
- `test_remove_card_from_pool()` - 移除卡片
- `test_sqlite_sync()` - SQLite 同步

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 单池约束强制执行
- [ ] 密码验证工作正常
- [ ] 离开池时数据清理
- [ ] 代码审查通过

---

## 相关文档

**领域规格**:
- [../../domain/pool/model.md](../../domain/pool/model.md) - 池领域模型

**架构规格**:
- [./dual_layer.md](./dual_layer.md) - 双层架构
- [./card_store.md](./card_store.md) - CardStore 实现
- [./device_config.md](./device_config.md) - 设备配置
- [../sync/service.md](../sync/service.md) - P2P 同步服务

**架构决策记录**:
- [../../../docs/adr/0001-single-pool-model.md](../../../docs/adr/0001-single-pool-model.md) - 单池模型决策

---

**最后更新**: 2026-01-23
**作者**: CardMind Team
