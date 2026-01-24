# CardStore Architecture Specification
# CardStore 架构规格

**Version**: 1.0.0
**版本**: 1.0.0
**Status**: Active
**状态**: Active
**Dependencies**: [../../domain/card/rules.md](../../domain/card/rules.md), [../../domain/pool/model.md](../../domain/pool/model.md), [./device_config.md](./device_config.md)
**依赖**: [../../domain/card/rules.md](../../domain/card/rules.md), [../../domain/pool/model.md](../../domain/pool/model.md), [./device_config.md](./device_config.md)
**Related Tests**: `rust/tests/card_store_test.rs`
**相关测试**: `rust/tests/card_store_test.rs`

---

## Overview
## 概述

This specification defines the technical implementation of CardStore for the single pool architecture, including the dual-layer storage architecture (Loro + SQLite), subscription-driven synchronization, and data management operations.

本规格定义了单池架构下 CardStore 的技术实现，包括双层存储架构（Loro + SQLite）、订阅驱动的同步机制和数据管理操作。

**Architecture Pattern**:
**架构模式**:
- **Write Layer**: Loro CRDT documents (source of truth)
- **写入层**: Loro CRDT 文档（数据源）
- **Read Layer**: SQLite cache (optimized queries)
- **读取层**: SQLite 缓存（优化查询）
- **Sync Mechanism**: Subscription-driven updates
- **同步机制**: 订阅驱动更新

---

## Requirement: Loro Document Management
## 需求：Loro 文档管理

The system SHALL manage Card data using Loro CRDT documents as the source of truth.

系统应使用 Loro CRDT 文档作为数据源管理卡片数据。

### Scenario: Create Loro document for new card
### 场景：为新卡片创建 Loro 文档

- **GIVEN**: A new card needs to be created
- **前置条件**: 需要创建新卡片
- **WHEN**: CardStore.create_card() is called
- **操作**: 调用 CardStore.create_card()
- **THEN**: A new Loro document SHALL be created
- **预期结果**: 应创建新的 Loro 文档
- **AND**: The document SHALL be persisted to `data/loro/<card_id>/snapshot.loro`
- **并且**: 文档应持久化到 `data/loro/<card_id>/snapshot.loro`

**Implementation Logic**:
**实现逻辑**:

```
function create_card(title, content):
    // Step 1: Create card in Loro CRDT layer
    // 步骤1：在 Loro CRDT 层创建卡片
    // Design decision: Generate UUID v7 for time-sortable IDs
    // 设计决策：生成 UUID v7 以支持时间排序
    card_id = generate_uuid_v7()
    card = create_card_in_loro(card_id, title, content)

    // Step 2: Get current pool from device configuration
    // 步骤2：从设备配置获取当前池
    // Note: Fail if device hasn't joined any pool
    // 注意：如果设备未加入任何池则失败
    device_config = load_device_config()
    if device_config.pool_id is null:
        return error "NOT_JOINED_POOL"

    pool_id = device_config.pool_id

    // Step 3: Add card to pool's card list
    // 步骤3：将卡片添加到池的卡片列表
    // Design decision: Pool owns the card list, not Card
    // 设计决策：池拥有卡片列表，而非卡片自身
    pool = load_pool(pool_id)
    pool.add_card(card_id)
    pool.commit()  // Triggers subscription callback

    // Step 4: Subscription automatically updates SQLite
    // 步骤4：订阅自动更新 SQLite
    // Note: on_pool_updated() callback handles SQLite synchronization
    // 注意：on_pool_updated() 回调处理 SQLite 同步

    return card

function create_card_in_loro(card_id, title, content):
    // Create CRDT document for the card
    // 为卡片创建 CRDT 文档
    crdt_doc = create_crdt_document()

    // Set card fields in CRDT map structure
    // 在 CRDT 映射结构中设置卡片字段
    // Design decision: Use map for field-level conflict resolution
    // 设计决策：使用映射实现字段级冲突解决
    crdt_doc.set_field("id", card_id)
    crdt_doc.set_field("title", title)
    crdt_doc.set_field("content", content)
    crdt_doc.set_field("created_at", current_timestamp())
    crdt_doc.set_field("updated_at", current_timestamp())
    crdt_doc.set_field("deleted", false)

    // Persist to file system
    // 持久化到文件系统
    // File path: data/loro/<card_id>/snapshot.loro
    // 文件路径：data/loro/<card_id>/snapshot.loro
    create_directory("data/loro/" + card_id)
    save_crdt_snapshot(crdt_doc, "data/loro/" + card_id + "/snapshot.loro")

    // Cache in memory for performance
    // 缓存到内存以提升性能
    memory_cache.store(card_id, crdt_doc)

    return card
```

### Scenario: Load Loro document from disk
### 场景：从磁盘加载 Loro 文档

- **GIVEN**: A card ID exists
- **前置条件**: 卡片 ID 存在
- **WHEN**: CardStore.load_card() is called
- **操作**: 调用 CardStore.load_card()
- **THEN**: The Loro document SHALL be loaded from `data/loro/<card_id>/snapshot.loro`
- **预期结果**: 应从 `data/loro/<card_id>/snapshot.loro` 加载 Loro 文档
- **AND**: The document SHALL be cached in memory
- **并且**: 文档应缓存在内存中

**Implementation Logic**:
**实现逻辑**:

```
function load_card(card_id):
    // Step 1: Check memory cache first for performance
    // 步骤1：首先检查内存缓存以提升性能
    if memory_cache.contains(card_id):
        crdt_doc = memory_cache.get(card_id)
        return convert_crdt_to_card(crdt_doc)

    // Step 2: Load from disk if not in cache
    // 步骤2：如果不在缓存中则从磁盘加载
    // File path: data/loro/<card_id>/snapshot.loro
    // 文件路径：data/loro/<card_id>/snapshot.loro
    file_path = "data/loro/" + card_id + "/snapshot.loro"
    snapshot_bytes = read_file(file_path)

    // Step 3: Import CRDT snapshot
    // 步骤3：导入 CRDT 快照
    crdt_doc = create_crdt_document()
    crdt_doc.import_snapshot(snapshot_bytes)

    // Step 4: Cache in memory for future access
    // 步骤4：缓存到内存以供未来访问
    memory_cache.store(card_id, crdt_doc)

    // Step 5: Convert CRDT document to Card structure
    // 步骤5：将 CRDT 文档转换为 Card 结构
    return convert_crdt_to_card(crdt_doc)

function convert_crdt_to_card(crdt_doc):
    // Extract fields from CRDT map structure
    // 从 CRDT 映射结构提取字段
    card.id = crdt_doc.get_field("id")
    card.title = crdt_doc.get_field("title")
    card.content = crdt_doc.get_field("content")
    card.created_at = crdt_doc.get_field("created_at")
    card.updated_at = crdt_doc.get_field("updated_at")
    card.deleted = crdt_doc.get_field("deleted")

    return card
```

---

## Requirement: SQLite Caching Layer
## 需求：SQLite 缓存层

The system SHALL maintain a SQLite cache for optimized read queries.

系统应维护 SQLite 缓存以优化读取查询。

### Scenario: SQLite schema for cards table
### 场景：cards 表的 SQLite schema

**Schema**:

```sql
CREATE TABLE IF NOT EXISTS cards (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX idx_cards_updated_at ON cards(updated_at DESC);
CREATE INDEX idx_cards_deleted ON cards(deleted);
```

### Scenario: SQLite schema for card_pool_bindings table
### 场景：card_pool_bindings 表的 SQLite schema

**Schema**:

```sql
CREATE TABLE IF NOT EXISTS card_pool_bindings (
    card_id TEXT NOT NULL,
    pool_id TEXT NOT NULL,
    PRIMARY KEY (card_id, pool_id)
);

CREATE INDEX idx_bindings_pool_id ON card_pool_bindings(pool_id);
CREATE INDEX idx_bindings_card_id ON card_pool_bindings(card_id);
```

---

## Requirement: Subscription-Driven Synchronization
## 需求：订阅驱动的同步

The system SHALL use Loro document subscriptions to automatically update SQLite cache when Pool documents change.

系统应使用 Loro 文档订阅在 Pool 文档变更时自动更新 SQLite 缓存。

### Scenario: Pool subscription triggers SQLite update
### 场景：Pool 订阅触发 SQLite 更新

- **GIVEN**: A Pool Loro document is modified
- **前置条件**: Pool Loro 文档被修改
- **WHEN**: Pool.commit() is called
- **操作**: 调用 Pool.commit()
- **THEN**: The subscription callback SHALL be triggered
- **预期结果**: 应触发订阅回调
- **AND**: The card_pool_bindings table SHALL be updated
- **并且**: card_pool_bindings 表应被更新

**Implementation Logic**:
**实现逻辑**:

```
// Subscription callback triggered when Pool CRDT document changes
// 当 Pool CRDT 文档变更时触发的订阅回调
// Design decision: Use observer pattern for automatic cache synchronization
// 设计决策：使用观察者模式实现自动缓存同步

function on_pool_updated(pool):
    // Step 1: Clear old bindings for this pool (idempotent operation)
    // 步骤1：清除此池的旧绑定（幂等操作）
    // Note: Delete-then-insert ensures consistency
    // 注意：先删除后插入确保一致性
    sqlite.execute("DELETE FROM card_pool_bindings WHERE pool_id = ?", pool.pool_id)

    // Step 2: Insert new bindings from Pool.card_ids
    // 步骤2：从 Pool.card_ids 插入新绑定
    // Design decision: Pool is source of truth for card membership
    // 设计决策：池是卡片成员关系的数据源
    for each card_id in pool.card_ids:
        sqlite.execute(
            "INSERT OR REPLACE INTO card_pool_bindings VALUES (?, ?)",
            card_id, pool.pool_id
        )

    return success
```

---

## Requirement: Pool Membership Management
## 需求：池成员管理

The system SHALL manage card-pool relationships by modifying Pool.card_ids (not Card.pool_ids).

系统应通过修改 Pool.card_ids（而非 Card.pool_ids）管理卡片-池关系。

### Scenario: Add card to pool
### 场景：添加卡片到池

- **GIVEN**: A pool and a card exist
- **前置条件**: 池和卡片存在
- **WHEN**: CardStore.add_card_to_pool() is called
- **操作**: 调用 CardStore.add_card_to_pool()
- **THEN**: Pool.card_ids SHALL contain the card ID
- **预期结果**: Pool.card_ids 应包含该卡片 ID
- **AND**: SQLite bindings table SHALL be updated via subscription
- **并且**: SQLite bindings 表应通过订阅更新

**Implementation Logic**:
**实现逻辑**:

```
function add_card_to_pool(card_id, pool_id):
    // Design decision: Modify Pool CRDT, not Card
    // 设计决策：修改 Pool CRDT，而非 Card
    // Rationale: Pool owns the membership relationship
    // 理由：池拥有成员关系

    // Step 1: Load pool CRDT document
    // 步骤1：加载池 CRDT 文档
    pool = load_pool(pool_id)

    // Step 2: Add card ID to pool's card list
    // 步骤2：将卡片 ID 添加到池的卡片列表
    pool.add_card(card_id)

    // Step 3: Commit changes (triggers subscription)
    // 步骤3：提交变更（触发订阅）
    // Note: This automatically updates SQLite via on_pool_updated() callback
    // 注意：这会通过 on_pool_updated() 回调自动更新 SQLite
    pool.commit()

    return success
```

### Scenario: Remove card from pool
### 场景：从池移除卡片

- **GIVEN**: A card has been added to a pool
- **前置条件**: 卡片已被添加到池
- **WHEN**: CardStore.remove_card_from_pool() is called
- **操作**: 调用 CardStore.remove_card_from_pool()
- **THEN**: Pool.card_ids SHALL no longer contain the card
- **预期结果**: Pool.card_ids 应不再包含该卡片
- **AND**: The removal SHALL propagate to all devices via P2P sync
- **并且**: 移除操作应通过 P2P 同步传播到所有设备

**Implementation Logic**:
**实现逻辑**:

```
function remove_card_from_pool(card_id, pool_id):
    // Design decision: Modify Pool CRDT to remove card
    // 设计决策：修改 Pool CRDT 以移除卡片
    // Important: This operation syncs to all devices via P2P
    // 重要：此操作通过 P2P 同步到所有设备

    // Step 1: Load pool CRDT document
    // 步骤1：加载池 CRDT 文档
    pool = load_pool(pool_id)

    // Step 2: Remove card ID from pool's card list
    // 步骤2：从池的卡片列表移除卡片 ID
    pool.remove_card(card_id)

    // Step 3: Commit changes (triggers subscription and P2P sync)
    // 步骤3：提交变更（触发订阅和 P2P 同步）
    // Note: Subscription updates local SQLite
    // 注意：订阅更新本地 SQLite
    // Note: P2P sync propagates to all devices in pool
    // 注意：P2P 同步传播到池中所有设备
    pool.commit()

    return success
```

---

## Requirement: Data Cleanup on Leave Pool
## 需求：退出池时的数据清理

The system SHALL clean up all local data when a device leaves a pool.

系统应在设备退出池时清理所有本地数据。

### Scenario: Delete all Loro documents and SQLite data
### 场景：删除所有 Loro 文档和 SQLite 数据

- **GIVEN**: The device is in pool_A with 50 cards
- **前置条件**: 设备在 pool_A 中，有 50 张卡片
- **WHEN**: CardStore.leave_pool() is called
- **操作**: 调用 CardStore.leave_pool()
- **THEN**: All card Loro documents SHALL be deleted
- **预期结果**: 所有卡片 Loro 文档应被删除
- **AND**: The Pool Loro document SHALL be deleted
- **并且**: Pool Loro 文档应被删除
- **AND**: SQLite SHALL be cleared
- **并且**: SQLite 应被清空

**Implementation Logic**:
**实现逻辑**:

```
function leave_pool():
    // Complete cleanup of all local data when leaving pool
    // 离开池时完整清理所有本地数据

    // Step 1: Get current pool ID from device configuration
    // 步骤1：从设备配置获取当前池 ID
    device_config = load_device_config()
    if device_config.pool_id is null:
        return error "NOT_JOINED_POOL"

    pool_id = device_config.pool_id

    // Step 2: Get list of all cards in the pool
    // 步骤2：获取池中所有卡片的列表
    pool = load_pool(pool_id)
    card_ids_to_delete = pool.card_ids

    // Step 3: Delete all card CRDT documents
    // 步骤3：删除所有卡片 CRDT 文档
    for each card_id in card_ids_to_delete:
        delete_card_crdt(card_id)

    // Step 4: Delete pool CRDT document
    // 步骤4：删除池 CRDT 文档
    delete_pool_crdt(pool_id)

    // Step 5: Clear SQLite cache
    // 步骤5：清空 SQLite 缓存
    clear_sqlite_database()

    return success

function delete_card_crdt(card_id):
    // Remove from memory cache
    // 从内存缓存移除
    memory_cache.remove(card_id)

    // Delete from file system
    // 从文件系统删除
    // Directory path: data/loro/<card_id>/
    // 目录路径：data/loro/<card_id>/
    directory_path = "data/loro/" + card_id
    if directory_exists(directory_path):
        delete_directory_recursive(directory_path)

    return success

function clear_sqlite_database():
    // Clear all tables
    // 清空所有表
    sqlite.execute("DELETE FROM cards")
    sqlite.execute("DELETE FROM card_pool_bindings")

    return success
```

---

## Implementation Details
## 实现细节

**Technology Stack**:
**技术栈**:
- **Loro**: CRDT library for conflict-free data synchronization
- **Loro**: 用于无冲突数据同步的 CRDT 库
- **SQLite**: Embedded database for read-optimized caching
- **SQLite**: 用于读取优化缓存的嵌入式数据库
- **Rust std::fs**: File system operations for Loro document persistence
- **Rust std::fs**: 用于 Loro 文档持久化的文件系统操作

**Design Patterns**:
**设计模式**:
- **Dual-Layer Architecture**: Separate write layer (Loro) and read layer (SQLite)
- **双层架构**: 分离写入层（Loro）和读取层（SQLite）
- **Observer Pattern**: Subscription-driven SQLite updates
- **观察者模式**: 订阅驱动的 SQLite 更新
- **Cache-Aside Pattern**: In-memory HashMap cache for Loro documents
- **旁路缓存模式**: Loro 文档的内存 HashMap 缓存

**Performance Considerations**:
**性能考虑**:
- **Memory Caching**: Loro documents cached in HashMap to avoid repeated disk I/O
- **内存缓存**: Loro 文档缓存在 HashMap 中以避免重复磁盘 I/O
- **SQLite Indexes**: Indexes on updated_at, deleted, pool_id, card_id for fast queries
- **SQLite 索引**: 在 updated_at、deleted、pool_id、card_id 上建立索引以加快查询
- **Batch Operations**: Use SQLite transactions for bulk updates
- **批量操作**: 使用 SQLite 事务进行批量更新
- **Lazy Loading**: Loro documents loaded on demand, not all at startup
- **延迟加载**: Loro 文档按需加载，而非启动时全部加载

**Security Considerations**:
**安全考虑**:
- **File Permissions**: Loro documents stored with user-only read/write permissions
- **文件权限**: Loro 文档以仅用户读写权限存储
- **SQLite Encryption**: Consider SQLite encryption extension for sensitive data
- **SQLite 加密**: 考虑使用 SQLite 加密扩展保护敏感数据
- **Input Validation**: Validate card_id and pool_id to prevent path traversal
- **输入验证**: 验证 card_id 和 pool_id 以防止路径遍历

---

## Test Coverage
## 测试覆盖

**Test File**: `rust/tests/card_store_test.rs`
**测试文件**: `rust/tests/card_store_test.rs`

**Unit Tests**:
**单元测试**:
- `it_creates_card_and_auto_adds_to_current_pool()` - Create card auto-join pool
- 创建卡片自动加入池
- `it_should_fail_when_device_not_joined()` - Fail when not joined
- 未加入时失败
- `it_should_trigger_subscription_to_update_bindings()` - Trigger subscription
- 触发订阅
- `it_should_modify_pool_card_ids_on_add()` - Add card to pool
- 添加卡片到池
- `it_should_be_idempotent()` - Idempotent add
- 幂等添加
- `it_should_remove_card_from_pool_card_ids()` - Remove card
- 移除卡片
- `it_should_propagate_removal_to_all_devices()` - Propagate removal
- 传播移除
- `it_should_clean_up_all_data_when_leaving_pool()` - Leave pool cleanup
- 退出池清理
- `it_should_update_bindings_on_pool_change()` - Update bindings
- 更新绑定
- `it_should_clear_old_bindings_when_pool_changes()` - Clear old bindings
- 清除旧绑定

**Integration Tests**:
**集成测试**:
- Create card automatically joins current pool
- 创建卡片自动加入当前池
- Removal operation propagates across devices
- 移除操作跨设备传播
- Leave pool complete flow
- 退出池完整流程

**Acceptance Criteria**:
**验收标准**:
- [ ] All unit tests pass
- [ ] 所有单元测试通过
- [ ] Integration tests pass
- [ ] 集成测试通过
- [ ] Performance benchmarks meet requirements
- [ ] 性能基准满足要求
- [ ] Code review approved
- [ ] 代码审查通过
- [ ] Documentation updated
- [ ] 文档已更新

---

## Related Documents
## 相关文档

**Domain Specs**:
**领域规格**:
- [../../domain/card/rules.md](../../domain/card/rules.md) - Card business rules
- 卡片业务规则
- [../../domain/pool/model.md](../../domain/pool/model.md) - Pool domain model
- 池领域模型

**Related Architecture Specs**:
**相关架构规格**:
- [./device_config.md](./device_config.md) - Device configuration storage
- 设备配置存储
- [./pool_store.md](./pool_store.md) - PoolStore implementation
- PoolStore 实现
- [../sync/service.md](../sync/service.md) - P2P sync service
- P2P 同步服务

**ADRs**:
**架构决策记录**:
- [../../../docs/adr/0002-dual-layer-architecture.md](../../../docs/adr/0002-dual-layer-architecture.md) - Dual-layer architecture
- 双层架构
- [../../../docs/adr/0003-loro-crdt.md](../../../docs/adr/0003-loro-crdt.md) - Loro CRDT for conflict-free sync
- Loro CRDT 用于无冲突同步

---

**Last Updated**: 2026-01-23
**最后更新**: 2026-01-23
**Authors**: CardMind Team
**作者**: CardMind Team
