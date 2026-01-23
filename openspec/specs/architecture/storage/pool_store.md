# PoolStore Architecture Specification
# PoolStore 架构规格

**Version**: 1.0.0
**版本**: 1.0.0

**Status**: Active
**状态**: Active

**Dependencies**: [../../domain/pool/model.md](../../domain/pool/model.md), [./device_config.md](./device_config.md), [./dual_layer.md](./dual_layer.md)
**依赖**: [../../domain/pool/model.md](../../domain/pool/model.md), [./device_config.md](./device_config.md), [./dual_layer.md](./dual_layer.md)

**Related Tests**: `rust/tests/pool_store_test.rs`
**相关测试**: `rust/tests/pool_store_test.rs`

---

## Overview
## 概述

This specification defines the technical implementation of PoolStore, which manages pool data using the dual-layer architecture (Loro + SQLite) and enforces the single-pool constraint.

本规格定义了 PoolStore 的技术实现，使用双层架构（Loro + SQLite）管理池数据并强制执行单池约束。

**Key Responsibilities**:
**核心职责**:
- Manage Pool Loro documents (create, load, update)
- 管理 Pool Loro 文档（创建、加载、更新）
- Enforce single-pool constraint per device
- 强制执行每设备单池约束
- Maintain pool-device relationships
- 维护池-设备关系
- Synchronize Pool data to SQLite cache
- 同步 Pool 数据到 SQLite 缓存

---

## Requirement: Pool Loro Document Management
## 需求：Pool Loro 文档管理

The system SHALL manage Pool data using Loro CRDT documents as the source of truth.

系统应使用 Loro CRDT 文档作为数据源管理 Pool 数据。

### Scenario: Create new pool
### 场景：创建新池

- **GIVEN**: A user wants to create a new pool
- **前置条件**: 用户想要创建新池
- **WHEN**: PoolStore.create_pool() is called
- **操作**: 调用 PoolStore.create_pool()
- **THEN**: A new Pool Loro document SHALL be created
- **预期结果**: 应创建新的 Pool Loro 文档
- **AND**: The document SHALL be persisted to `data/loro/<pool_id>/snapshot.loro`
- **并且**: 文档应持久化到 `data/loro/<pool_id>/snapshot.loro`
- **AND**: The pool SHALL be added to SQLite via subscription
- **并且**: 池应通过订阅添加到 SQLite

**Implementation**:
**实现**:

```
function create_pool(pool_name, password):
    // Step 1: Generate unique pool identifier
    // 步骤1：生成唯一池标识符
    // Design decision: Use UUIDv7 for time-sortable IDs
    // 设计决策：使用 UUIDv7 实现时间可排序的 ID
    pool_id = generate_uuid_v7()

    // Step 2: Hash password for security
    // 步骤2：哈希密码以确保安全
    // Security: Use bcrypt with appropriate cost factor
    // 安全：使用适当成本因子的 bcrypt
    password_hash = hash_password(password)

    // Step 3: Create CRDT document structure
    // 步骤3：创建 CRDT 文档结构
    // Design decision: Use map structure for field-level merging
    // 设计决策：使用映射结构实现字段级合并
    crdt_doc = create_crdt_document()
    crdt_doc.set_field("pool_id", pool_id)
    crdt_doc.set_field("pool_name", pool_name)
    crdt_doc.set_field("password_hash", password_hash)
    crdt_doc.set_field("card_ids", empty_list)
    crdt_doc.set_field("device_ids", empty_list)
    crdt_doc.set_field("created_at", current_timestamp)
    crdt_doc.set_field("updated_at", current_timestamp)

    // Step 4: Persist to disk
    // 步骤4：持久化到磁盘
    // Note: Store in pool-specific directory for isolation
    // 注意：存储在池特定目录中以实现隔离
    save_to_disk(crdt_doc, path: "data/loro/{pool_id}/snapshot.loro")

    // Step 5: Cache in memory for fast access
    // 步骤5：缓存到内存以实现快速访问
    cache_document(pool_id, crdt_doc)

    // Step 6: Trigger subscription to update SQLite cache
    // 步骤6：触发订阅以更新 SQLite 缓存
    // Note: Subscription pattern ensures consistency
    // 注意：订阅模式确保一致性
    notify_pool_updated(pool)

    return pool
```

### Scenario: Load pool from disk
### 场景：从磁盘加载池

- **GIVEN**: A pool ID exists
- **前置条件**: 池 ID 存在
- **WHEN**: PoolStore.load_pool() is called
- **操作**: 调用 PoolStore.load_pool()
- **THEN**: The Pool Loro document SHALL be loaded from disk
- **预期结果**: 应从磁盘加载 Pool Loro 文档
- **AND**: The document SHALL be cached in memory
- **并且**: 文档应缓存在内存中

**Implementation**:
**实现**:

```
function load_pool(pool_id):
    // Step 1: Check memory cache first for performance
    // 步骤1：首先检查内存缓存以提高性能
    // Design decision: Two-level caching (memory + disk)
    // 设计决策：两级缓存（内存 + 磁盘）
    if pool_exists_in_cache(pool_id):
        crdt_doc = get_from_cache(pool_id)
        return convert_to_pool(crdt_doc)

    // Step 2: Load from disk if not in cache
    // 步骤2：如果不在缓存中则从磁盘加载
    file_path = "data/loro/{pool_id}/snapshot.loro"
    crdt_doc = load_crdt_from_disk(file_path)

    // Step 3: Cache in memory for future access
    // 步骤3：缓存到内存以供将来访问
    cache_document(pool_id, crdt_doc)

    // Step 4: Convert CRDT document to domain model
    // 步骤4：将 CRDT 文档转换为领域模型
    return convert_to_pool(crdt_doc)

function convert_to_pool(crdt_doc):
    // Extract all fields from CRDT document
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

## Requirement: Single-Pool Constraint Enforcement
## 需求：单池约束强制执行

The system SHALL enforce that a device can join at most one pool.

系统应强制执行设备最多只能加入一个池。

### Scenario: Device joins first pool successfully
### 场景：设备成功加入第一个池

- **GIVEN**: A device has not joined any pool
- **前置条件**: 设备未加入任何池
- **WHEN**: PoolStore.join_pool() is called
- **操作**: 调用 PoolStore.join_pool()
- **THEN**: The device SHALL be added to Pool.device_ids
- **预期结果**: 设备应被添加到 Pool.device_ids
- **AND**: DeviceConfig.pool_id SHALL be set
- **并且**: DeviceConfig.pool_id 应被设置
- **AND**: The change SHALL propagate to all devices via P2P sync
- **并且**: 变更应通过 P2P 同步传播到所有设备

**Implementation**:
**实现**:

```
function join_pool(pool_id, password):
    // Step 1: Enforce single-pool constraint
    // 步骤1：强制执行单池约束
    // Design decision: Device can only join one pool at a time
    // 设计决策：设备一次只能加入一个池
    device_config = load_device_config()
    if device_config.has_joined_pool():
        return error("AlreadyJoinedPool")

    // Step 2: Load pool and verify password
    // 步骤2：加载池并验证密码
    // Security: Use constant-time comparison to prevent timing attacks
    // 安全：使用恒定时间比较以防止时序攻击
    pool = load_pool(pool_id)
    if not verify_password(password, pool.password_hash):
        return error("InvalidPassword")

    // Step 3: Add device to pool's device list
    // 步骤3：将设备添加到池的设备列表
    // Note: Idempotent operation - safe to call multiple times
    // 注意：幂等操作 - 可以安全地多次调用
    device_id = device_config.device_id
    if not pool.device_ids.contains(device_id):
        pool.device_ids.add(device_id)
        pool.updated_at = current_timestamp

        // Update CRDT document
        // 更新 CRDT 文档
        crdt_doc = get_pool_document(pool_id)
        crdt_doc.add_to_list("device_ids", device_id)
        crdt_doc.set_field("updated_at", current_timestamp)

        // Persist changes
        // 持久化变更
        save_to_disk(crdt_doc)

        // Trigger subscription to update SQLite and sync to other devices
        // 触发订阅以更新 SQLite 并同步到其他设备
        notify_pool_updated(pool)

    // Step 4: Update device configuration
    // 步骤4：更新设备配置
    // Note: This establishes the device-pool relationship
    // 注意：这建立了设备-池关系
    device_config.pool_id = pool_id
    save_device_config(device_config)

    return success
```

### Scenario: Device rejects joining second pool
### 场景：设备拒绝加入第二个池

- **GIVEN**: A device has already joined pool_A
- **前置条件**: 设备已加入 pool_A
- **WHEN**: PoolStore.join_pool() is called for pool_B
- **操作**: 为 pool_B 调用 PoolStore.join_pool()
- **THEN**: The system SHALL return AlreadyJoinedPool error
- **预期结果**: 系统应返回 AlreadyJoinedPool 错误
- **AND**: DeviceConfig.pool_id SHALL remain pool_A
- **并且**: DeviceConfig.pool_id 应保持为 pool_A

---

## Requirement: Leave Pool and Data Cleanup
## 需求：离开池和数据清理

The system SHALL clean up all pool-related data when a device leaves a pool.

系统应在设备离开池时清理所有池相关数据。

### Scenario: Device leaves pool
### 场景：设备离开池

- **GIVEN**: A device has joined a pool
- **前置条件**: 设备已加入池
- **WHEN**: PoolStore.leave_pool() is called
- **操作**: 调用 PoolStore.leave_pool()
- **THEN**: The device SHALL be removed from Pool.device_ids
- **预期结果**: 设备应从 Pool.device_ids 中移除
- **AND**: DeviceConfig.pool_id SHALL be cleared
- **并且**: DeviceConfig.pool_id 应被清除
- **AND**: All local Pool and Card data SHALL be deleted
- **并且**: 所有本地 Pool 和 Card 数据应被删除
- **AND**: The removal SHALL propagate to other devices
- **并且**: 移除操作应传播到其他设备

**Implementation**:
**实现**:

```
function leave_pool():
    // Step 1: Get current pool from device configuration
    // 步骤1：从设备配置获取当前池
    device_config = load_device_config()
    if not device_config.has_joined_pool():
        return error("NotJoinedPool")

    pool_id = device_config.pool_id

    // Step 2: Remove device from pool's device list
    // 步骤2：从池的设备列表中移除设备
    // Note: This change will sync to other devices via P2P
    // 注意：此变更将通过 P2P 同步到其他设备
    pool = load_pool(pool_id)
    device_id = device_config.device_id
    pool.device_ids.remove(device_id)
    pool.updated_at = current_timestamp

    // Update CRDT document
    // 更新 CRDT 文档
    crdt_doc = get_pool_document(pool_id)
    crdt_doc.remove_from_list("device_ids", device_id)
    crdt_doc.set_field("updated_at", current_timestamp)

    // Persist changes to sync to other devices
    // 持久化变更以同步到其他设备
    save_to_disk(crdt_doc)

    // Step 3: Delete all local data
    // 步骤3：删除所有本地数据
    // Design decision: Complete cleanup ensures no orphaned data
    // 设计决策：完全清理确保没有孤立数据
    delete_all_local_data(pool_id)

    // Step 4: Clear device configuration
    // 步骤4：清除设备配置
    device_config.pool_id = null
    save_device_config(device_config)

    return success

function delete_all_local_data(pool_id):
    // Step 1: Get all card IDs from pool
    // 步骤1：从池获取所有卡片 ID
    pool = load_pool(pool_id)
    card_ids = pool.card_ids

    // Step 2: Delete all card CRDT documents
    // 步骤2：删除所有卡片 CRDT 文档
    for each card_id in card_ids:
        delete_directory("data/loro/{card_id}")

    // Step 3: Delete pool CRDT document
    // 步骤3：删除池 CRDT 文档
    delete_directory("data/loro/{pool_id}")

    // Step 4: Clear SQLite cache
    // 步骤4：清除 SQLite 缓存
    // Note: Remove all pool-related data from cache
    // 注意：从缓存中移除所有池相关数据
    execute_sql("DELETE FROM cards")
    execute_sql("DELETE FROM card_pool_bindings")
    execute_sql("DELETE FROM pools WHERE pool_id = ?", pool_id)

    // Step 5: Clear memory cache
    // 步骤5：清除内存缓存
    remove_from_cache(pool_id)
```

---

## Requirement: Pool-Card Relationship Management
## 需求：池-卡片关系管理

The system SHALL manage the relationship between pools and cards through Pool.card_ids.

系统应通过 Pool.card_ids 管理池和卡片之间的关系。

### Scenario: Add card to pool
### 场景：添加卡片到池

- **GIVEN**: A pool and a card exist
- **前置条件**: 池和卡片存在
- **WHEN**: PoolStore.add_card() is called
- **操作**: 调用 PoolStore.add_card()
- **THEN**: The card ID SHALL be added to Pool.card_ids
- **预期结果**: 卡片 ID 应被添加到 Pool.card_ids
- **AND**: The change SHALL propagate to all devices
- **并且**: 变更应传播到所有设备
- **AND**: SQLite bindings SHALL be updated via subscription
- **并且**: SQLite 绑定应通过订阅更新

**Implementation**:
**实现**:

```
function add_card(pool_id, card_id):
    // Load pool from storage
    // 从存储加载池
    pool = load_pool(pool_id)

    // Add card if not already present (idempotent operation)
    // 如果尚未存在则添加卡片（幂等操作）
    // Design decision: Idempotent to handle duplicate requests safely
    // 设计决策：幂等以安全处理重复请求
    if not pool.card_ids.contains(card_id):
        pool.card_ids.add(card_id)
        pool.updated_at = current_timestamp

        // Update CRDT document
        // 更新 CRDT 文档
        crdt_doc = get_pool_document(pool_id)
        crdt_doc.add_to_list("card_ids", card_id)
        crdt_doc.set_field("updated_at", current_timestamp)

        // Persist changes
        // 持久化变更
        save_to_disk(crdt_doc)

        // Trigger subscription to update SQLite bindings
        // 触发订阅以更新 SQLite 绑定
        // Note: This ensures card-pool relationship is cached
        // 注意：这确保卡片-池关系被缓存
        notify_pool_updated(pool)

    return success

function remove_card(pool_id, card_id):
    // Load pool from storage
    // 从存储加载池
    pool = load_pool(pool_id)

    // Remove card from pool's card list
    // 从池的卡片列表中移除卡片
    pool.card_ids.remove(card_id)
    pool.updated_at = current_timestamp

    // Update CRDT document
    // 更新 CRDT 文档
    crdt_doc = get_pool_document(pool_id)
    crdt_doc.remove_from_list("card_ids", card_id)
    crdt_doc.set_field("updated_at", current_timestamp)

    // Persist changes
    // 持久化变更
    save_to_disk(crdt_doc)

    // Trigger subscription to update SQLite bindings
    // 触发订阅以更新 SQLite 绑定
    notify_pool_updated(pool)

    return success
```

---

## Requirement: SQLite Synchronization
## 需求：SQLite 同步

The system SHALL synchronize Pool data to SQLite via subscription callbacks.

系统应通过订阅回调将 Pool 数据同步到 SQLite。

### Scenario: Pool update triggers SQLite update
### 场景：池更新触发 SQLite 更新

- **GIVEN**: A Pool Loro document is modified
- **前置条件**: Pool Loro 文档被修改
- **WHEN**: The subscription callback is triggered
- **操作**: 触发订阅回调
- **THEN**: The pools table SHALL be updated
- **预期结果**: pools 表应被更新
- **AND**: The card_pool_bindings table SHALL be updated
- **并且**: card_pool_bindings 表应被更新

**Implementation**:
**实现**:

```
function on_pool_updated(pool):
    // Subscription callback triggered when pool CRDT document changes
    // 当池 CRDT 文档变更时触发的订阅回调
    // Design decision: Observer pattern for automatic cache synchronization
    // 设计决策：观察者模式实现自动缓存同步

    // Step 1: Update pools table in SQLite cache
    // 步骤1：更新 SQLite 缓存中的 pools 表
    // Note: Use INSERT OR REPLACE for idempotent updates
    // 注意：使用 INSERT OR REPLACE 实现幂等更新
    execute_sql(
        "INSERT OR REPLACE INTO pools (pool_id, pool_name, created_at, updated_at)
         VALUES (?, ?, ?, ?)",
        pool.pool_id, pool.pool_name, pool.created_at, pool.updated_at
    )

    // Step 2: Update card-pool bindings
    // 步骤2：更新卡片-池绑定
    // Design decision: Clear and rebuild to ensure consistency
    // 设计决策：清除并重建以确保一致性

    // Clear old bindings for this pool
    // 清除此池的旧绑定
    execute_sql(
        "DELETE FROM card_pool_bindings WHERE pool_id = ?",
        pool.pool_id
    )

    // Insert new bindings for all cards in pool
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

## Implementation Details
## 实现细节

**Technology Stack**:
**技术栈**:
- **Loro**: CRDT library for Pool documents
- **Loro**: 用于 Pool 文档的 CRDT 库
- **SQLite**: Cache for pool metadata and relationships
- **SQLite**: 池元数据和关系的缓存
- **bcrypt**: Password hashing for pool security
- **bcrypt**: 池安全的密码哈希

**Design Patterns**:
**设计模式**:
- **Repository Pattern**: PoolStore as data access layer
- **仓储模式**: PoolStore 作为数据访问层
- **Observer Pattern**: Subscription-driven SQLite updates
- **观察者模式**: 订阅驱动的 SQLite 更新
- **Constraint Enforcement**: Single-pool constraint at application layer
- **约束强制**: 应用层的单池约束

**Security Considerations**:
**安全考虑**:
- **Password Hashing**: Use bcrypt with cost factor 12
- **密码哈希**: 使用成本因子 12 的 bcrypt
- **Password Verification**: Constant-time comparison via bcrypt
- **密码验证**: 通过 bcrypt 的恒定时间比较
- **Access Control**: Only devices in Pool.device_ids can access pool data
- **访问控制**: 只有 Pool.device_ids 中的设备可以访问池数据

---

## Test Coverage
## 测试覆盖

**Test File**: `rust/tests/pool_store_test.rs`
**测试文件**: `rust/tests/pool_store_test.rs`

**Unit Tests**:
**单元测试**:
- `test_create_pool()` - Create pool
- `test_create_pool()` - 创建池
- `test_join_pool_success()` - Join pool successfully
- `test_join_pool_success()` - 成功加入池
- `test_join_pool_rejects_second()` - Reject second pool
- `test_join_pool_rejects_second()` - 拒绝第二个池
- `test_leave_pool()` - Leave pool
- `test_leave_pool()` - 离开池
- `test_add_card_to_pool()` - Add card
- `test_add_card_to_pool()` - 添加卡片
- `test_remove_card_from_pool()` - Remove card
- `test_remove_card_from_pool()` - 移除卡片
- `test_sqlite_sync()` - SQLite synchronization
- `test_sqlite_sync()` - SQLite 同步

**Acceptance Criteria**:
**验收标准**:
- [ ] All unit tests pass
- [ ] 所有单元测试通过
- [ ] Single-pool constraint enforced
- [ ] 单池约束强制执行
- [ ] Password verification works
- [ ] 密码验证工作正常
- [ ] Data cleanup on leave pool
- [ ] 离开池时数据清理
- [ ] Code review approved
- [ ] 代码审查通过

---

## Related Documents
## 相关文档

**Domain Specs**:
**领域规格**:
- [../../domain/pool/model.md](../../domain/pool/model.md) - Pool domain model
- [../../domain/pool/model.md](../../domain/pool/model.md) - 池领域模型

**Architecture Specs**:
**架构规格**:
- [./dual_layer.md](./dual_layer.md) - Dual-layer architecture
- [./dual_layer.md](./dual_layer.md) - 双层架构
- [./card_store.md](./card_store.md) - CardStore implementation
- [./card_store.md](./card_store.md) - CardStore 实现
- [./device_config.md](./device_config.md) - Device configuration
- [./device_config.md](./device_config.md) - 设备配置
- [../sync/service.md](../sync/service.md) - P2P sync service
- [../sync/service.md](../sync/service.md) - P2P 同步服务

**ADRs**:
**架构决策记录**:
- [../../../docs/adr/0001-single-pool-model.md](../../../docs/adr/0001-single-pool-model.md) - Single pool model decision
- [../../../docs/adr/0001-single-pool-model.md](../../../docs/adr/0001-single-pool-model.md) - 单池模型决策

---

**Last Updated**: 2026-01-23
**最后更新**: 2026-01-23

**Authors**: CardMind Team
**作者**: CardMind Team
