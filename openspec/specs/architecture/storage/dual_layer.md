# Dual-Layer Storage Architecture Specification
# 双层存储架构规格

**Version**: 1.0.0
**版本**: 1.0.0

**Status**: Active
**状态**: Active

**Dependencies**: [./card_store.md](./card_store.md), [../../domain/card/model.md](../../domain/card/model.md)
**依赖**: [./card_store.md](./card_store.md), [../../domain/card/model.md](../../domain/card/model.md)

**Related Tests**: `rust/tests/dual_layer_test.rs`
**相关测试**: `rust/tests/dual_layer_test.rs`

---

## Overview
## 概述

This specification defines the dual-layer storage architecture that separates write operations (Loro CRDT) from read operations (SQLite cache), enabling conflict-free synchronization while maintaining query performance.

本规格定义了双层存储架构，将写操作（Loro CRDT）与读操作（SQLite 缓存）分离，在保持查询性能的同时实现无冲突同步。

**Architecture Pattern**:
**架构模式**:

```
┌─────────────────────────────────────────┐
│         Application Layer               │
│    (UI, Business Logic)                 │
└─────────────────────────────────────────┘
           │                    │
           │ Write              │ Read
           ▼                    ▼
┌──────────────────┐  ┌──────────────────┐
│   Write Layer    │  │   Read Layer     │
│   (Loro CRDT)    │  │   (SQLite)       │
│                  │  │                  │
│ - Source of      │  │ - Query Cache    │
│   Truth          │  │ - Indexes        │
│ - P2P Sync       │  │ - Fast Reads     │
│ - Conflict-Free  │  │                  │
└──────────────────┘  └──────────────────┘
           │                    ▲
           │ Subscription       │
           └────────────────────┘
              (Auto Update)
```

**Key Principles**:
**核心原则**:
- **Single Source of Truth**: Loro documents are authoritative
- **单一数据源**: Loro 文档是权威数据源
- **Read-Write Separation**: Optimize each layer for its purpose
- **读写分离**: 为每层优化其用途
- **Eventual Consistency**: SQLite eventually reflects Loro state
- **最终一致性**: SQLite 最终反映 Loro 状态
- **Subscription-Driven**: Updates propagate automatically
- **订阅驱动**: 更新自动传播

---

## Requirement: Write Layer - Loro CRDT
## 需求：写入层 - Loro CRDT

The system SHALL use Loro CRDT documents as the authoritative source of truth for all write operations.

系统应使用 Loro CRDT 文档作为所有写操作的权威数据源。

### Scenario: All writes go to Loro first
### 场景：所有写入首先进入 Loro

- **GIVEN**: A user modifies a card
- **前置条件**: 用户修改卡片
- **WHEN**: The modification is saved
- **操作**: 保存修改
- **THEN**: The change SHALL be written to the Loro document first
- **预期结果**: 变更应首先写入 Loro 文档
- **AND**: The Loro document SHALL be persisted to disk
- **并且**: Loro 文档应持久化到磁盘
- **AND**: The SQLite cache SHALL be updated via subscription
- **并且**: SQLite 缓存应通过订阅更新

**Rationale**:
**理由**:
- Loro provides conflict-free merging for P2P sync
- Loro 为 P2P 同步提供无冲突合并
- CRDT guarantees eventual consistency across devices
- CRDT 保证跨设备的最终一致性
- Loro documents can be synced directly between peers
- Loro 文档可以在对等设备间直接同步

### Scenario: Loro document structure for Card
### 场景：卡片的 Loro 文档结构

**Document Structure**:
**文档结构**:

```rust
// Loro document for a Card
// 卡片的 Loro 文档
{
  "card": {
    "id": "01JQXXX...",           // UUIDv7
    "title": "Card Title",        // String
    "content": "# Content",       // Markdown string
    "created_at": 1706000000000,  // Unix timestamp (ms)
    "updated_at": 1706000001000,  // Unix timestamp (ms)
    "deleted": false              // Boolean
  }
}
```

**File Location**:
**文件位置**:
- Path: `data/loro/<card_id>/snapshot.loro`
- 路径: `data/loro/<card_id>/snapshot.loro`
- Format: Loro binary snapshot
- 格式: Loro 二进制快照

### Scenario: Loro document structure for Pool
### 场景：池的 Loro 文档结构

**Document Structure**:
**文档结构**:

```rust
// Loro document for a Pool
// 池的 Loro 文档
{
  "pool": {
    "pool_id": "01JQYYY...",      // UUIDv7
    "pool_name": "My Pool",       // String
    "card_ids": [                 // Array of card IDs
      "01JQXXX...",
      "01JQZZZ..."
    ],
    "device_ids": [               // Array of device IDs
      "device_A",
      "device_B"
    ],
    "created_at": 1706000000000,  // Unix timestamp (ms)
    "updated_at": 1706000001000   // Unix timestamp (ms)
  }
}
```

**File Location**:
**文件位置**:
- Path: `data/loro/<pool_id>/snapshot.loro`
- 路径: `data/loro/<pool_id>/snapshot.loro`

---

## Requirement: Read Layer - SQLite Cache
## 需求：读取层 - SQLite 缓存

The system SHALL maintain a SQLite cache for optimized read queries.

系统应维护 SQLite 缓存以优化读取查询。

### Scenario: All reads come from SQLite
### 场景：所有读取来自 SQLite

- **GIVEN**: A user requests a list of cards
- **前置条件**: 用户请求卡片列表
- **WHEN**: The query is executed
- **操作**: 执行查询
- **THEN**: The data SHALL be read from SQLite
- **预期结果**: 数据应从 SQLite 读取
- **AND**: Loro documents SHALL NOT be accessed for reads
- **并且**: 读取时不应访问 Loro 文档

**Rationale**:
**理由**:
- SQLite provides fast indexed queries
- SQLite 提供快速索引查询
- Avoid deserializing Loro documents for every read
- 避免为每次读取反序列化 Loro 文档
- Support complex queries (filtering, sorting, pagination)
- 支持复杂查询（过滤、排序、分页）

### Scenario: SQLite schema design
### 场景：SQLite schema 设计

**Cards Table**:
**卡片表**:

```sql
CREATE TABLE IF NOT EXISTS cards (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted INTEGER NOT NULL DEFAULT 0
);

-- Indexes for common queries
-- 常用查询的索引
CREATE INDEX idx_cards_updated_at ON cards(updated_at DESC);
CREATE INDEX idx_cards_deleted ON cards(deleted);
CREATE INDEX idx_cards_title ON cards(title);
```

**Card-Pool Bindings Table**:
**卡片-池绑定表**:

```sql
CREATE TABLE IF NOT EXISTS card_pool_bindings (
    card_id TEXT NOT NULL,
    pool_id TEXT NOT NULL,
    PRIMARY KEY (card_id, pool_id)
);

-- Indexes for relationship queries
-- 关系查询的索引
CREATE INDEX idx_bindings_pool_id ON card_pool_bindings(pool_id);
CREATE INDEX idx_bindings_card_id ON card_pool_bindings(card_id);
```

**Pools Table**:
**池表**:

```sql
CREATE TABLE IF NOT EXISTS pools (
    pool_id TEXT PRIMARY KEY,
    pool_name TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);
```

### Scenario: Query optimization examples
### 场景：查询优化示例

**Example 1: Get all cards in current pool**
**示例 1：获取当前池中的所有卡片**

```sql
-- Fast query using indexes
-- 使用索引的快速查询
SELECT c.*
FROM cards c
JOIN card_pool_bindings b ON c.id = b.card_id
WHERE b.pool_id = ?
  AND c.deleted = 0
ORDER BY c.updated_at DESC
LIMIT 50;
```

**Example 2: Search cards by title**
**示例 2：按标题搜索卡片**

```sql
-- Full-text search (can be optimized with FTS5)
-- 全文搜索（可使用 FTS5 优化）
SELECT c.*
FROM cards c
JOIN card_pool_bindings b ON c.id = b.card_id
WHERE b.pool_id = ?
  AND c.deleted = 0
  AND c.title LIKE ?
ORDER BY c.updated_at DESC;
```

---

## Requirement: Subscription-Driven Synchronization
## 需求：订阅驱动的同步

The system SHALL use Loro document subscriptions to automatically propagate changes from write layer to read layer.

系统应使用 Loro 文档订阅自动将变更从写入层传播到读取层。

### Scenario: Pool update triggers SQLite update
### 场景：池更新触发 SQLite 更新

- **GIVEN**: A Pool Loro document is modified
- **前置条件**: Pool Loro 文档被修改
- **WHEN**: Pool.commit() is called
- **操作**: 调用 Pool.commit()
- **THEN**: The subscription callback SHALL be triggered
- **预期结果**: 应触发订阅回调
- **AND**: The card_pool_bindings table SHALL be updated
- **并且**: card_pool_bindings 表应被更新
- **AND**: The update SHALL be idempotent
- **并且**: 更新应是幂等的

**Implementation**:
**实现**:

```
// Pool Loro document subscription callback
// Pool Loro 文档订阅回调
//
// Triggered when: Pool.commit() is called
// 触发时机：调用 Pool.commit()
//
// Responsibility: Sync Pool.card_ids to card_pool_bindings table
// 职责：同步 Pool.card_ids 到 card_pool_bindings 表

function on_pool_updated(pool):
    // Step 1: Get SQLite connection
    // 步骤1：获取 SQLite 连接
    sqlite = get_sqlite_connection()

    // Step 2: Clear old bindings for this pool (ensures idempotency)
    // 步骤2：清除该池的旧绑定（确保幂等性）
    // Design decision: Delete-then-insert pattern ensures consistency
    // 设计决策：先删除后插入模式确保一致性
    delete_bindings_for_pool(sqlite, pool.pool_id)

    // Step 3: Insert new bindings from current pool state
    // 步骤3：从当前池状态插入新绑定
    for each card_id in pool.card_ids:
        insert_binding(sqlite, card_id, pool.pool_id)

    return success
```

### Scenario: Card update triggers SQLite update
### 场景：卡片更新触发 SQLite 更新

- **GIVEN**: A Card Loro document is modified
- **前置条件**: Card Loro 文档被修改
- **WHEN**: Card.commit() is called
- **操作**: 调用 Card.commit()
- **THEN**: The subscription callback SHALL be triggered
- **预期结果**: 应触发订阅回调
- **AND**: The cards table SHALL be updated
- **并且**: cards 表应被更新

**Implementation**:
**实现**:

```
// Card Loro document subscription callback
// Card Loro 文档订阅回调

function on_card_updated(card):
    // Step 1: Get SQLite connection
    // 步骤1：获取 SQLite 连接
    sqlite = get_sqlite_connection()

    // Step 2: Upsert card data to SQLite cache
    // 步骤2：将卡片数据更新插入到 SQLite 缓存
    // Design decision: Use upsert to handle both create and update cases
    // 设计决策：使用 upsert 同时处理创建和更新情况
    upsert_card(sqlite, {
        id: card.id,
        title: card.title,
        content: card.content,
        created_at: card.created_at,
        updated_at: card.updated_at,
        deleted: card.deleted
    })

    return success
```

---

## Requirement: Data Consistency Guarantees
## 需求：数据一致性保证

The system SHALL maintain eventual consistency between Loro and SQLite layers.

系统应在 Loro 和 SQLite 层之间维护最终一致性。

### Scenario: SQLite reflects Loro state eventually
### 场景：SQLite 最终反映 Loro 状态

- **GIVEN**: A Loro document is modified
- **前置条件**: Loro 文档被修改
- **WHEN**: The subscription callback completes
- **操作**: 订阅回调完成
- **THEN**: SQLite SHALL reflect the same data as Loro
- **预期结果**: SQLite 应反映与 Loro 相同的数据
- **AND**: Any subsequent reads SHALL see the updated data
- **并且**: 任何后续读取应看到更新的数据

### Scenario: Handle subscription callback failures
### 场景：处理订阅回调失败

- **GIVEN**: A Loro document is modified
- **前置条件**: Loro 文档被修改
- **WHEN**: The subscription callback fails
- **操作**: 订阅回调失败
- **THEN**: The error SHALL be logged
- **预期结果**: 错误应被记录
- **AND**: The system SHALL retry the update
- **并且**: 系统应重试更新
- **AND**: Loro SHALL remain the source of truth
- **并且**: Loro 应保持为数据源

**Error Handling**:
**错误处理**:

```
// Subscription callback with error handling
// 带错误处理的订阅回调

function on_pool_updated_safe(pool):
    // Attempt to update SQLite cache
    // 尝试更新 SQLite 缓存
    result = on_pool_updated(pool)

    if result is success:
        // Log successful update
        // 记录成功更新
        log_debug("SQLite updated for pool", pool.pool_id)
    else:
        // Log error and queue for retry
        // 记录错误并加入重试队列
        // Design decision: Use retry queue to ensure eventual consistency
        // 设计决策：使用重试队列确保最终一致性
        log_error("Failed to update SQLite for pool", pool.pool_id, result.error)
        add_to_retry_queue(UpdatePoolTask(pool))
```

---

## Requirement: Rebuild SQLite from Loro
## 需求：从 Loro 重建 SQLite

The system SHALL support rebuilding the entire SQLite cache from Loro documents.

系统应支持从 Loro 文档重建整个 SQLite 缓存。

### Scenario: Rebuild SQLite on corruption
### 场景：损坏时重建 SQLite

- **GIVEN**: The SQLite database is corrupted
- **前置条件**: SQLite 数据库损坏
- **WHEN**: The system detects corruption
- **操作**: 系统检测到损坏
- **THEN**: The system SHALL delete the SQLite database
- **预期结果**: 系统应删除 SQLite 数据库
- **AND**: The system SHALL rebuild it from all Loro documents
- **并且**: 系统应从所有 Loro 文档重建
- **AND**: All data SHALL be recovered
- **并且**: 所有数据应被恢复

**Implementation**:
**实现**:

```
// Rebuild SQLite cache from Loro documents
// 从 Loro 文档重建 SQLite 缓存
//
// Use cases:
// 用例：
// - SQLite corruption / SQLite 损坏
// - Schema migration / Schema 迁移
// - Data verification / 数据验证

function rebuild_sqlite_from_loro():
    // Step 1: Get SQLite connection
    // 步骤1：获取 SQLite 连接
    sqlite = get_sqlite_connection()

    // Step 2: Clear all existing cache data
    // 步骤2：清除所有现有缓存数据
    // Design decision: Full clear ensures clean rebuild
    // 设计决策：完全清除确保干净重建
    clear_table(sqlite, "cards")
    clear_table(sqlite, "card_pool_bindings")
    clear_table(sqlite, "pools")

    // Step 3: Scan Loro document directory
    // 步骤3：扫描 Loro 文档目录
    loro_directory = "data/loro"
    for each subdirectory in loro_directory:
        snapshot_file = subdirectory + "/snapshot.loro"

        if snapshot_file exists:
            // Step 4: Load Loro document snapshot
            // 步骤4：加载 Loro 文档快照
            loro_doc = load_loro_snapshot(snapshot_file)

            // Step 5: Parse document and update SQLite
            // 步骤5：解析文档并更新 SQLite
            // Note: Document type determines which callback to use
            // 注意：文档类型决定使用哪个回调
            if loro_doc is Card:
                card = parse_card_from_loro(loro_doc)
                on_card_updated(card)
            else if loro_doc is Pool:
                pool = parse_pool_from_loro(loro_doc)
                on_pool_updated(pool)

    log_info("SQLite cache rebuilt from Loro documents")
    return success
```

---

## Requirement: Performance Optimization
## 需求：性能优化

The system SHALL optimize both layers for their specific use cases.

系统应为每层的特定用例优化性能。

### Scenario: Write performance - Loro
### 场景：写性能 - Loro

**Optimizations**:
**优化**:
- **In-Memory Cache**: Keep frequently accessed Loro documents in memory
- **内存缓存**: 将频繁访问的 Loro 文档保存在内存中
- **Lazy Persistence**: Batch writes to disk
- **延迟持久化**: 批量写入磁盘
- **Incremental Snapshots**: Only save changed documents
- **增量快照**: 仅保存变更的文档

### Scenario: Read performance - SQLite
### 场景：读性能 - SQLite

**Optimizations**:
**优化**:
- **Indexes**: Create indexes on frequently queried columns
- **索引**: 在频繁查询的列上创建索引
- **Query Planning**: Use EXPLAIN QUERY PLAN to optimize queries
- **查询规划**: 使用 EXPLAIN QUERY PLAN 优化查询
- **Connection Pooling**: Reuse SQLite connections
- **连接池**: 复用 SQLite 连接
- **WAL Mode**: Enable Write-Ahead Logging for better concurrency
- **WAL 模式**: 启用预写日志以提高并发性

**SQLite Configuration**:
**SQLite 配置**:

```
// Configure SQLite for optimal performance
// 配置 SQLite 以获得最佳性能

function configure_sqlite(connection):
    // Step 1: Enable WAL mode for better concurrency
    // 步骤1：启用 WAL 模式以提高并发性
    // Design decision: WAL allows concurrent reads during writes
    // 设计决策：WAL 允许写入时并发读取
    set_journal_mode(connection, "WAL")

    // Step 2: Increase cache size for better performance
    // 步骤2：增加缓存大小以提高性能
    // Note: 10MB cache reduces disk I/O
    // 注意：10MB 缓存减少磁盘 I/O
    set_cache_size(connection, 10_megabytes)

    // Step 3: Set synchronous mode for durability
    // 步骤3：设置同步模式以保证持久性
    // Design decision: NORMAL balances performance and safety
    // 设计决策：NORMAL 平衡性能和安全性
    set_synchronous_mode(connection, "NORMAL")

    // Step 4: Enable foreign key constraints
    // 步骤4：启用外键约束
    enable_foreign_keys(connection)

    return success
```

---

## Implementation Details
## 实现细节

**Technology Stack**:
**技术栈**:
- **Loro**: v0.16+ for CRDT functionality
- **Loro**: v0.16+ 用于 CRDT 功能
- **SQLite**: v3.40+ with WAL mode
- **SQLite**: v3.40+ 带 WAL 模式
- **Rust rusqlite**: v0.30+ for SQLite bindings
- **Rust rusqlite**: v0.30+ 用于 SQLite 绑定

**Design Patterns**:
**设计模式**:
- **CQRS (Command Query Responsibility Segregation)**: Separate write and read models
- **CQRS（命令查询职责分离）**: 分离写入和读取模型
- **Observer Pattern**: Subscription-driven updates
- **观察者模式**: 订阅驱动更新
- **Cache-Aside Pattern**: SQLite as cache for Loro
- **旁路缓存模式**: SQLite 作为 Loro 的缓存

**Trade-offs**:
**权衡**:
- **Pros**: Conflict-free sync, fast reads, eventual consistency
- **优点**: 无冲突同步、快速读取、最终一致性
- **Cons**: Eventual consistency (not immediate), storage overhead (two copies)
- **缺点**: 最终一致性（非即时）、存储开销（两份副本）

---

## Test Coverage
## 测试覆盖

**Test File**: `rust/tests/dual_layer_test.rs`
**测试文件**: `rust/tests/dual_layer_test.rs`

**Unit Tests**:
**单元测试**:
- `test_write_to_loro_updates_sqlite()` - Write propagation
- `test_write_to_loro_updates_sqlite()` - 写入传播
- `test_read_from_sqlite_not_loro()` - Read from cache
- `test_read_from_sqlite_not_loro()` - 从缓存读取
- `test_subscription_callback_updates_sqlite()` - Subscription mechanism
- `test_subscription_callback_updates_sqlite()` - 订阅机制
- `test_rebuild_sqlite_from_loro()` - Rebuild functionality
- `test_rebuild_sqlite_from_loro()` - 重建功能
- `test_eventual_consistency()` - Consistency guarantee
- `test_eventual_consistency()` - 一致性保证

**Integration Tests**:
**集成测试**:
- End-to-end write-read flow
- 端到端写读流程
- SQLite corruption recovery
- SQLite 损坏恢复
- Performance benchmarks
- 性能基准测试

**Acceptance Criteria**:
**验收标准**:
- [ ] All unit tests pass
- [ ] 所有单元测试通过
- [ ] Integration tests pass
- [ ] 集成测试通过
- [ ] Read performance < 10ms for 1000 cards
- [ ] 1000 张卡片的读取性能 < 10ms
- [ ] Write performance < 50ms per card
- [ ] 每张卡片的写入性能 < 50ms
- [ ] SQLite rebuild completes in < 5s for 10000 cards
- [ ] 10000 张卡片的 SQLite 重建在 5 秒内完成

---

## Related Documents
## 相关文档

**Architecture Specs**:
**架构规格**:
- [./card_store.md](./card_store.md) - CardStore implementation
- [./card_store.md](./card_store.md) - CardStore 实现
- [./pool_store.md](./pool_store.md) - PoolStore implementation
- [./pool_store.md](./pool_store.md) - PoolStore 实现
- [./sqlite_cache.md](./sqlite_cache.md) - SQLite caching details
- [./sqlite_cache.md](./sqlite_cache.md) - SQLite 缓存细节
- [./loro_integration.md](./loro_integration.md) - Loro integration
- [./loro_integration.md](./loro_integration.md) - Loro 集成

**Domain Specs**:
**领域规格**:
- [../../domain/card/model.md](../../domain/card/model.md) - Card domain model
- [../../domain/card/model.md](../../domain/card/model.md) - 卡片领域模型
- [../../domain/pool/model.md](../../domain/pool/model.md) - Pool domain model
- [../../domain/pool/model.md](../../domain/pool/model.md) - 池领域模型

**ADRs**:
**架构决策记录**:
- [../../../docs/adr/0002-dual-layer-architecture.md](../../../docs/adr/0002-dual-layer-architecture.md) - Dual-layer architecture decision
- [../../../docs/adr/0002-dual-layer-architecture.md](../../../docs/adr/0002-dual-layer-architecture.md) - 双层架构决策
- [../../../docs/adr/0003-loro-crdt.md](../../../docs/adr/0003-loro-crdt.md) - Loro CRDT selection
- [../../../docs/adr/0003-loro-crdt.md](../../../docs/adr/0003-loro-crdt.md) - Loro CRDT 选择

---

**Last Updated**: 2026-01-23
**最后更新**: 2026-01-23

**Authors**: CardMind Team
**作者**: CardMind Team
