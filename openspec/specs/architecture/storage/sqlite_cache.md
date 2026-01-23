# SQLite Cache Architecture Specification
# SQLite 缓存架构规格

**Version**: 1.0.0
**版本**: 1.0.0

**Status**: Active
**状态**: Active

**Dependencies**: [./dual_layer.md](./dual_layer.md), [./card_store.md](./card_store.md), [./pool_store.md](./pool_store.md)
**依赖**: [./dual_layer.md](./dual_layer.md), [./card_store.md](./card_store.md), [./pool_store.md](./pool_store.md)

**Related Tests**: `rust/tests/sqlite_cache_test.rs`
**相关测试**: `rust/tests/sqlite_cache_test.rs`

---

## Overview
## 概述

This specification defines the SQLite caching layer for CardMind, which provides fast read access to card and pool data while maintaining eventual consistency with the Loro CRDT layer.

本规格定义了 CardMind 的 SQLite 缓存层，提供对卡片和池数据的快速读取访问，同时与 Loro CRDT 层保持最终一致性。

**Key Responsibilities**:
**核心职责**:
- Provide fast indexed queries for card and pool data
- 为卡片和池数据提供快速索引查询
- Maintain eventual consistency with Loro documents
- 与 Loro 文档保持最终一致性
- Support complex queries (filtering, sorting, pagination)
- 支持复杂查询（过滤、排序、分页）
- Enable full-text search capabilities
- 启用全文搜索功能

---

## Requirement: Database Schema
## 需求：数据库 Schema

The system SHALL maintain a SQLite database with optimized schema for read operations.

系统应维护具有优化 schema 的 SQLite 数据库以进行读取操作。

### Scenario: Cards table schema
### 场景：Cards 表 schema

**Schema Definition**:
**Schema 定义**:

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
CREATE INDEX IF NOT EXISTS idx_cards_updated_at ON cards(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_cards_deleted ON cards(deleted);
CREATE INDEX IF NOT EXISTS idx_cards_title ON cards(title COLLATE NOCASE);
CREATE INDEX IF NOT EXISTS idx_cards_created_at ON cards(created_at DESC);
```

**Field Descriptions**:
**字段描述**:
- `id`: Card ID (UUIDv7)
- `id`: 卡片 ID（UUIDv7）
- `title`: Card title (indexed for search)
- `title`: 卡片标题（索引用于搜索）
- `content`: Card content (Markdown)
- `content`: 卡片内容（Markdown）
- `created_at`: Creation timestamp (Unix milliseconds)
- `created_at`: 创建时间戳（Unix 毫秒）
- `updated_at`: Last update timestamp (indexed for sorting)
- `updated_at`: 最后更新时间戳（索引用于排序）
- `deleted`: Soft delete flag (indexed for filtering)
- `deleted`: 软删除标志（索引用于过滤）

### Scenario: Pools table schema
### 场景：Pools 表 schema

**Schema Definition**:
**Schema 定义**:

```sql
CREATE TABLE IF NOT EXISTS pools (
    pool_id TEXT PRIMARY KEY,
    pool_name TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_pools_updated_at ON pools(updated_at DESC);
```

### Scenario: Card-Pool bindings table schema
### 场景：Card-Pool 绑定表 schema

**Schema Definition**:
**Schema 定义**:

```sql
CREATE TABLE IF NOT EXISTS card_pool_bindings (
    card_id TEXT NOT NULL,
    pool_id TEXT NOT NULL,
    PRIMARY KEY (card_id, pool_id),
    FOREIGN KEY (card_id) REFERENCES cards(id) ON DELETE CASCADE,
    FOREIGN KEY (pool_id) REFERENCES pools(pool_id) ON DELETE CASCADE
);

-- Indexes for relationship queries
-- 关系查询的索引
CREATE INDEX IF NOT EXISTS idx_bindings_pool_id ON card_pool_bindings(pool_id);
CREATE INDEX IF NOT EXISTS idx_bindings_card_id ON card_pool_bindings(card_id);
```

**Rationale**:
**理由**:
- Composite primary key ensures unique card-pool relationships
- 复合主键确保唯一的卡片-池关系
- Foreign keys maintain referential integrity
- 外键维护引用完整性
- Indexes on both columns support bidirectional queries
- 两列上的索引支持双向查询

---

## Requirement: Full-Text Search
## 需求：全文搜索

The system SHALL support full-text search on card titles and content using SQLite FTS5.

系统应使用 SQLite FTS5 支持对卡片标题和内容的全文搜索。

### Scenario: FTS5 virtual table for cards
### 场景：卡片的 FTS5 虚拟表

**Schema Definition**:
**Schema 定义**:

```sql
-- FTS5 virtual table for full-text search
-- 用于全文搜索的 FTS5 虚拟表
CREATE VIRTUAL TABLE IF NOT EXISTS cards_fts USING fts5(
    id UNINDEXED,
    title,
    content,
    content='cards',
    content_rowid='rowid'
);

-- Triggers to keep FTS5 in sync with cards table
-- 保持 FTS5 与 cards 表同步的触发器
CREATE TRIGGER IF NOT EXISTS cards_fts_insert AFTER INSERT ON cards BEGIN
    INSERT INTO cards_fts(rowid, id, title, content)
    VALUES (new.rowid, new.id, new.title, new.content);
END;

CREATE TRIGGER IF NOT EXISTS cards_fts_update AFTER UPDATE ON cards BEGIN
    UPDATE cards_fts
    SET title = new.title, content = new.content
    WHERE rowid = new.rowid;
END;

CREATE TRIGGER IF NOT EXISTS cards_fts_delete AFTER DELETE ON cards BEGIN
    DELETE FROM cards_fts WHERE rowid = old.rowid;
END;
```

### Scenario: Search cards by keyword
### 场景：按关键词搜索卡片

- **GIVEN**: Multiple cards with different content
- **前置条件**: 多张具有不同内容的卡片
- **WHEN**: User searches for "rust programming"
- **操作**: 用户搜索 "rust programming"
- **THEN**: The system SHALL return cards containing those keywords
- **预期结果**: 系统应返回包含这些关键词的卡片
- **AND**: Results SHALL be ranked by relevance
- **并且**: 结果应按相关性排序

**Query Logic**:
**查询逻辑**:

```
function search_cards(query, pool_id, limit):
    // Step 1: Query FTS5 virtual table for matching cards
    // 步骤1：查询 FTS5 虚拟表以查找匹配的卡片
    // Design decision: Use FTS5 MATCH for full-text search with relevance ranking
    // 设计决策：使用 FTS5 MATCH 进行全文搜索并按相关性排序
    matching_cards = query_fts_table(
        search_term: query,
        filter_by_pool: pool_id,
        exclude_deleted: true,
        order_by: relevance_rank,
        limit: limit
    )

    // Step 2: Join with cards table to get full card data
    // 步骤2：与 cards 表连接以获取完整的卡片数据
    // Note: FTS5 only stores indexed fields, need full card details
    // 注意：FTS5 只存储索引字段，需要完整的卡片详情
    full_cards = join_with_cards_table(matching_cards)

    // Step 3: Return ranked results
    // 步骤3：返回排序后的结果
    return full_cards
```

---

## Requirement: Query Optimization
## 需求：查询优化

The system SHALL optimize common queries using indexes and query planning.

系统应使用索引和查询规划优化常见查询。

### Scenario: Get all cards in current pool (sorted by update time)
### 场景：获取当前池中的所有卡片（按更新时间排序）

**Query Logic**:
**查询逻辑**:

```
function get_cards_in_pool(pool_id, limit, offset):
    // Step 1: Query cards table with pool binding filter
    // 步骤1：使用池绑定过滤查询 cards 表
    // Design decision: Use JOIN to filter by pool membership
    // 设计决策：使用 JOIN 按池成员资格过滤
    // Note: Indexes on pool_id and updated_at enable efficient query
    // 注意：pool_id 和 updated_at 上的索引实现高效查询
    cards = query_database(
        table: "cards",
        join_with: "card_pool_bindings",
        filter: {
            pool_id: pool_id,
            deleted: false
        },
        order_by: "updated_at DESC",
        limit: limit,
        offset: offset
    )

    // Step 2: Return paginated results
    // 步骤2：返回分页结果
    return cards
```

### Scenario: Count cards in pool
### 场景：统计池中的卡片数量

**Query Logic**:
**查询逻辑**:

```
function count_cards_in_pool(pool_id):
    // Step 1: Count cards with pool binding filter
    // 步骤1：使用池绑定过滤统计卡片
    // Design decision: Use COUNT aggregate with JOIN for accurate count
    // 设计决策：使用 COUNT 聚合与 JOIN 实现精确统计
    // Note: Indexes on pool_id and deleted enable efficient counting
    // 注意：pool_id 和 deleted 上的索引实现高效统计
    count = count_records(
        table: "cards",
        join_with: "card_pool_bindings",
        filter: {
            pool_id: pool_id,
            deleted: false
        }
    )

    // Step 2: Return count
    // 步骤2：返回统计结果
    return count
```

---

## Requirement: Database Configuration
## 需求：数据库配置

The system SHALL configure SQLite for optimal performance and durability.

系统应配置 SQLite 以获得最佳性能和持久性。

### Scenario: SQLite performance configuration
### 场景：SQLite 性能配置

**Configuration Logic**:
**配置逻辑**:

```
function initialize_database():
    // Step 1: Open database connection
    // 步骤1：打开数据库连接
    connection = open_database("data/cardmind.db")

    // Step 2: Configure performance settings
    // 步骤2：配置性能设置
    // Design decision: Use WAL mode for better concurrency
    // 设计决策：使用 WAL 模式以提高并发性
    // Rationale: Allows concurrent reads during writes
    // 理由：允许写入期间的并发读取
    set_journal_mode(connection, "WAL")

    // Design decision: Set cache size to 10MB
    // 设计决策：将缓存大小设置为 10MB
    // Rationale: Reduces disk I/O for frequently accessed data
    // 理由：减少频繁访问数据的磁盘 I/O
    set_cache_size(connection, 10_megabytes)

    // Design decision: Use NORMAL synchronous mode
    // 设计决策：使用 NORMAL 同步模式
    // Rationale: Balances durability and performance
    // 理由：平衡持久性和性能
    set_synchronous_mode(connection, "NORMAL")

    // Step 3: Enable integrity features
    // 步骤3：启用完整性功能
    enable_foreign_keys(connection)

    // Step 4: Optimize memory usage
    // 步骤4：优化内存使用
    // Note: Use memory for temporary operations for better performance
    // 注意：使用内存进行临时操作以提高性能
    set_temp_store(connection, "MEMORY")

    // Design decision: Enable memory-mapped I/O (256MB)
    // 设计决策：启用内存映射 I/O（256MB）
    // Rationale: Improves read performance for large databases
    // 理由：提高大型数据库的读取性能
    set_mmap_size(connection, 256_megabytes)

    // Step 5: Analyze database for query optimization
    // 步骤5：分析数据库以优化查询
    analyze_database(connection)

    return connection
```

**Configuration Rationale**:
**配置理由**:
- **WAL Mode**: Allows concurrent reads during writes
- **WAL 模式**: 允许写入期间的并发读取
- **Cache Size**: Reduces disk I/O for frequently accessed data
- **缓存大小**: 减少频繁访问数据的磁盘 I/O
- **Synchronous NORMAL**: Balances durability and performance
- **同步 NORMAL**: 平衡持久性和性能
- **Foreign Keys**: Maintains referential integrity
- **外键**: 维护引用完整性
- **Memory Temp Store**: Faster temporary operations
- **内存临时存储**: 更快的临时操作
- **MMAP**: Memory-mapped I/O for better performance
- **MMAP**: 内存映射 I/O 以提高性能

---

## Requirement: Connection Pooling
## 需求：连接池

The system SHALL use connection pooling to efficiently manage database connections.

系统应使用连接池高效管理数据库连接。

### Scenario: Connection pool for concurrent access
### 场景：并发访问的连接池

**Connection Pool Logic**:
**连接池逻辑**:

```
// Data structure for connection pool
// 连接池的数据结构
structure SqliteCache:
    connection_pool: ConnectionPool

// Initialize connection pool
// 初始化连接池
function create_connection_pool(max_connections):
    // Step 1: Create connection pool manager
    // 步骤1：创建连接池管理器
    // Design decision: Use connection pooling for concurrent access
    // 设计决策：使用连接池实现并发访问
    // Rationale: Reuses connections, reduces overhead
    // 理由：重用连接，减少开销
    pool = create_pool(
        database_path: "data/cardmind.db",
        max_size: max_connections
    )

    // Step 2: Initialize schema on first connection
    // 步骤2：在第一个连接上初始化 schema
    first_connection = pool.get_connection()
    initialize_schema(first_connection)
    initialize_performance_settings(first_connection)

    return SqliteCache { connection_pool: pool }

// Get connection from pool
// 从池中获取连接
function get_connection():
    // Note: Blocks if all connections are in use
    // 注意：如果所有连接都在使用中则阻塞
    connection = connection_pool.acquire()
    return connection

// Initialize database schema
// 初始化数据库 schema
function initialize_schema(connection):
    // Step 1: Configure SQLite settings
    // 步骤1：配置 SQLite 设置
    configure_performance_settings(connection)

    // Step 2: Create tables and indexes
    // 步骤2：创建表和索引
    // Note: Load schema from external SQL file
    // 注意：从外部 SQL 文件加载 schema
    execute_schema_script(connection, "schema.sql")

    return success
```

---

## Requirement: Transaction Management
## 需求：事务管理

The system SHALL use transactions for atomic updates to maintain consistency.

系统应使用事务进行原子更新以维护一致性。

### Scenario: Batch update with transaction
### 场景：使用事务批量更新

**Transaction Logic**:
**事务逻辑**:

```
// Batch update multiple cards atomically
// 原子性地批量更新多张卡片
function batch_update_cards(cards):
    // Step 1: Begin transaction
    // 步骤1：开始事务
    // Design decision: Use transaction for atomic batch updates
    // 设计决策：使用事务实现原子批量更新
    // Rationale: Ensures all-or-nothing semantics
    // 理由：确保全有或全无的语义
    transaction = begin_transaction()

    try:
        // Step 2: Update each card
        // 步骤2：更新每张卡片
        for each card in cards:
            upsert_card(
                transaction,
                card_id: card.id,
                title: card.title,
                content: card.content,
                created_at: card.created_at,
                updated_at: card.updated_at,
                deleted: card.deleted
            )

        // Step 3: Commit transaction
        // 步骤3：提交事务
        commit(transaction)
        return success

    catch error:
        // Step 4: Rollback on error
        // 步骤4：出错时回滚
        rollback(transaction)
        return failure

// Update pool bindings atomically
// 原子性地更新池绑定
function update_pool_bindings(pool_id, card_ids):
    // Step 1: Begin transaction
    // 步骤1：开始事务
    transaction = begin_transaction()

    try:
        // Step 2: Clear old bindings for this pool
        // 步骤2：清除此池的旧绑定
        // Design decision: Delete and re-insert for simplicity
        // 设计决策：删除并重新插入以简化逻辑
        delete_bindings_for_pool(transaction, pool_id)

        // Step 3: Insert new bindings
        // 步骤3：插入新绑定
        for each card_id in card_ids:
            insert_binding(
                transaction,
                card_id: card_id,
                pool_id: pool_id
            )

        // Step 4: Commit transaction
        // 步骤4：提交事务
        commit(transaction)
        return success

    catch error:
        // Step 5: Rollback on error
        // 步骤5：出错时回滚
        rollback(transaction)
        return failure
```

---

## Requirement: Database Maintenance
## 需求：数据库维护

The system SHALL provide maintenance operations for database health.

系统应提供数据库维护操作以保持数据库健康。

### Scenario: Vacuum database to reclaim space
### 场景：清理数据库以回收空间

**Maintenance Logic**:
**维护逻辑**:

```
// Vacuum database to reclaim space
// 清理数据库以回收空间
function vacuum_database():
    // Design decision: Run VACUUM to reclaim deleted space
    // 设计决策：运行 VACUUM 回收已删除的空间
    // Note: Should be run periodically (e.g., weekly)
    // 注意：应定期运行（例如，每周）
    // Rationale: Reduces database file size and improves performance
    // 理由：减少数据库文件大小并提高性能
    connection = get_connection()
    execute_vacuum(connection)
    log("Database vacuumed successfully")
    return success

// Analyze database for query optimization
// 分析数据库以优化查询
function analyze_database():
    // Design decision: Run ANALYZE to update query statistics
    // 设计决策：运行 ANALYZE 更新查询统计信息
    // Note: Should be run after significant data changes
    // 注意：应在重大数据变更后运行
    // Rationale: Helps query planner choose optimal execution plans
    // 理由：帮助查询规划器选择最优执行计划
    connection = get_connection()
    execute_analyze(connection)
    log("Database analyzed successfully")
    return success

// Check database integrity
// 检查数据库完整性
function check_database_integrity():
    // Step 1: Run integrity check
    // 步骤1：运行完整性检查
    connection = get_connection()
    result = execute_integrity_check(connection)

    // Step 2: Verify result
    // 步骤2：验证结果
    if result == "ok":
        return true
    else:
        log_error("Database integrity check failed: " + result)
        return false
```

---

## Implementation Details
## 实现细节

**Technology Stack**:
**技术栈**:
- **SQLite**: v3.40+ with FTS5 extension
- **SQLite**: v3.40+ 带 FTS5 扩展
- **rusqlite**: v0.30+ for Rust bindings
- **rusqlite**: v0.30+ 用于 Rust 绑定
- **r2d2**: Connection pooling
- **r2d2**: 连接池

**Design Patterns**:
**设计模式**:
- **Repository Pattern**: SqliteCache as data access layer
- **仓储模式**: SqliteCache 作为数据访问层
- **Connection Pooling**: Efficient connection management
- **连接池**: 高效的连接管理
- **Transaction Pattern**: Atomic batch updates
- **事务模式**: 原子批量更新

**Performance Characteristics**:
**性能特征**:
- **Read Performance**: < 10ms for 1000 cards
- **读取性能**: 1000 张卡片 < 10ms
- **Write Performance**: < 50ms per card
- **写入性能**: 每张卡片 < 50ms
- **Search Performance**: < 100ms for full-text search
- **搜索性能**: 全文搜索 < 100ms
- **Concurrent Reads**: Unlimited with WAL mode
- **并发读取**: WAL 模式下无限制

---

## Test Coverage
## 测试覆盖

**Test File**: `rust/tests/sqlite_cache_test.rs`
**测试文件**: `rust/tests/sqlite_cache_test.rs`

**Unit Tests**:
**单元测试**:
- `test_schema_creation()` - Schema initialization
- `test_schema_creation()` - Schema 初始化
- `test_insert_and_query_card()` - Basic CRUD operations
- `test_insert_and_query_card()` - 基本 CRUD 操作
- `test_full_text_search()` - FTS5 search
- `test_full_text_search()` - FTS5 搜索
- `test_pagination()` - Pagination queries
- `test_pagination()` - 分页查询
- `test_transaction_rollback()` - Transaction handling
- `test_transaction_rollback()` - 事务处理
- `test_connection_pool()` - Connection pooling
- `test_connection_pool()` - 连接池
- `test_vacuum()` - Database maintenance
- `test_vacuum()` - 数据库维护

**Performance Tests**:
**性能测试**:
- Query 1000 cards in < 10ms
- 10ms 内查询 1000 张卡片
- Full-text search in < 100ms
- 100ms 内全文搜索
- Concurrent read stress test
- 并发读取压力测试

**Acceptance Criteria**:
**验收标准**:
- [ ] All unit tests pass
- [ ] 所有单元测试通过
- [ ] Performance benchmarks met
- [ ] 性能基准达标
- [ ] FTS5 search works correctly
- [ ] FTS5 搜索正确工作
- [ ] Connection pooling efficient
- [ ] 连接池高效
- [ ] Code review approved
- [ ] 代码审查通过

---

## Related Documents
## 相关文档

**Architecture Specs**:
**架构规格**:
- [./dual_layer.md](./dual_layer.md) - Dual-layer architecture
- [./dual_layer.md](./dual_layer.md) - 双层架构
- [./card_store.md](./card_store.md) - CardStore implementation
- [./card_store.md](./card_store.md) - CardStore 实现
- [./pool_store.md](./pool_store.md) - PoolStore implementation
- [./pool_store.md](./pool_store.md) - PoolStore 实现

**Domain Specs**:
**领域规格**:
- [../../domain/card/model.md](../../domain/card/model.md) - Card model
- [../../domain/card/model.md](../../domain/card/model.md) - 卡片模型
- [../../domain/pool/model.md](../../domain/pool/model.md) - Pool model
- [../../domain/pool/model.md](../../domain/pool/model.md) - 池模型

---

**Last Updated**: 2026-01-23
**最后更新**: 2026-01-23

**Authors**: CardMind Team
**作者**: CardMind Team
