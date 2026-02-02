# SQLite 缓存架构规格

**版本**: 1.0.0

**状态**: 活跃

**依赖**: [./dual_layer.md](./dual_layer.md), [./card_store.md](./card_store.md), [./pool_store.md](./pool_store.md)

**相关测试**: `rust/tests/sqlite_cache_test.rs`

---

## 概述

本规格定义了 CardMind 的 SQLite 缓存层，提供对卡片和池数据的快速读取访问，同时与 Loro CRDT 层保持最终一致性。

**核心职责**:
- 为卡片和池数据提供快速索引查询
- 与 Loro 文档保持最终一致性
- 支持复杂查询（过滤、排序、分页）
- 启用全文搜索功能

---

## 需求：数据库 Schema

系统应维护具有优化 schema 的 SQLite 数据库以进行读取操作。

### 场景：Cards 表 schema


```sql
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted INTEGER NOT NULL DEFAULT 0
);

-- 常用查询的索引
```

**字段描述**:
- `id`: 卡片 ID（UUIDv7）
- `title`: 卡片标题（索引用于搜索）
- `content`: 卡片内容（Markdown）
- `created_at`: 创建时间戳（Unix 毫秒）
- `updated_at`: 最后更新时间戳（索引用于排序）
- `deleted`: 软删除标志（索引用于过滤）

### 场景：Pools 表 schema


```sql
    pool_id TEXT PRIMARY KEY,
    pool_name TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

```

### 场景：Card-Pool 绑定表 schema


```sql
    card_id TEXT NOT NULL,
    pool_id TEXT NOT NULL,
    PRIMARY KEY (card_id, pool_id),
    FOREIGN KEY (card_id) REFERENCES cards(id) ON DELETE CASCADE,
    FOREIGN KEY (pool_id) REFERENCES pools(pool_id) ON DELETE CASCADE
);

-- Indexes for relationship queries
-- 关系查询的索引
```

**理由**:
- Composite primary key ensures unique card-pool relationships
- 复合主键确保唯一的卡片-池关系
- Foreign keys maintain referential integrity
- 外键维护引用完整性
- Indexes on both columns support bidirectional queries
- 两列上的索引支持双向查询

---

## 需求：全文搜索

系统应使用 SQLite FTS5 支持对卡片标题和内容的全文搜索。

### 场景：卡片的 FTS5 虚拟表


```sql
-- FTS5 virtual table for full-text search
-- 用于全文搜索的 FTS5 虚拟表
    id UNINDEXED,
    title,
    content,
    content='cards',
    content_rowid='rowid'
);

-- Triggers to keep FTS5 in sync with cards table
-- 保持 FTS5 与 cards 表同步的触发器
    INSERT INTO cards_fts(rowid, id, title, content)
    VALUES (new.rowid, new.id, new.title, new.content);

    UPDATE cards_fts
    SET title = new.title, content = new.content
    WHERE rowid = new.rowid;

    DELETE FROM cards_fts WHERE rowid = old.rowid;
```

### 场景：按关键词搜索卡片

- **前置条件**: 多张具有不同内容的卡片
- **操作**: 用户搜索 "rust programming"
- **预期结果**: 系统应返回包含这些关键词的卡片
- **并且**: 结果应按相关性排序

**查询逻辑**:

```
function search_cards(query, pool_id, limit):
    // 步骤1：查询 FTS5 虚拟表以查找匹配的卡片
    // 设计决策：使用 FTS5 MATCH 进行全文搜索并按相关性排序
    matching_cards = query_fts_table(
        search_term: query,
        filter_by_pool: pool_id,
        exclude_deleted: true,
        order_by: relevance_rank,
        limit: limit
    )

    // 步骤2：与 cards 表连接以获取完整的卡片数据
    // 注意：FTS5 只存储索引字段，需要完整的卡片详情
    full_cards = join_with_cards_table(matching_cards)

    // 步骤3：返回排序后的结果
    return full_cards
```

---

## 需求：查询优化


系统应使用索引和查询规划优化常见查询。

### 场景：获取当前池中的所有卡片（按更新时间排序）

**查询逻辑**:

```
function get_cards_in_pool(pool_id, limit, offset):
    // 步骤1：使用池绑定过滤查询 cards 表
    // 设计决策：使用 JOIN 按池成员资格过滤
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

    // 步骤2：返回分页结果
    return cards
```

### 场景：统计池中的卡片数量

**查询逻辑**:

```
function count_cards_in_pool(pool_id):
    // 步骤1：使用池绑定过滤统计卡片
    // 设计决策：使用 COUNT 聚合与 JOIN 实现精确统计
    // 注意：pool_id 和 deleted 上的索引实现高效统计
    count = count_records(
        table: "cards",
        join_with: "card_pool_bindings",
        filter: {
            pool_id: pool_id,
            deleted: false
        }
    )

    // 步骤2：返回统计结果
    return count
```

---

## 需求：数据库配置


系统应配置 SQLite 以获得最佳性能和持久性。

### 场景：SQLite 性能配置

**配置逻辑**:

```
function initialize_database():
    // 步骤1：打开数据库连接
    connection = open_database("data/cardmind.db")

    // 步骤2：配置性能设置
    // 设计决策：使用 WAL 模式以提高并发性
    // 理由：允许写入期间的并发读取
    set_journal_mode(connection, "WAL")

    // 设计决策：将缓存大小设置为 10MB
    // 理由：减少频繁访问数据的磁盘 I/O
    set_cache_size(connection, 10_megabytes)

    // 设计决策：使用 NORMAL 同步模式
    // 理由：平衡持久性和性能
    set_synchronous_mode(connection, "NORMAL")

    // 步骤3：启用完整性功能
    enable_foreign_keys(connection)

    // 步骤4：优化内存使用
    // 注意：使用内存进行临时操作以提高性能
    set_temp_store(connection, "MEMORY")

    // 设计决策：启用内存映射 I/O（256MB）
    // 理由：提高大型数据库的读取性能
    set_mmap_size(connection, 256_megabytes)

    // 步骤5：分析数据库以优化查询
    analyze_database(connection)

    return connection
```

**配置理由**:
- **WAL 模式**: 允许写入期间的并发读取
- **缓存大小**: 减少频繁访问数据的磁盘 I/O
- **同步 NORMAL**: 平衡持久性和性能
- **外键**: 维护引用完整性
- **内存临时存储**: 更快的临时操作

---

## 需求：连接池


系统应使用连接池高效管理数据库连接。

### 场景：并发访问的连接池

**连接池逻辑**:

```
// 连接池的数据结构
structure SqliteCache:
    connection_pool: ConnectionPool

// 初始化连接池
function create_connection_pool(max_connections):
    // 步骤1：创建连接池管理器
    // 设计决策：使用连接池实现并发访问
    // 理由：重用连接，减少开销
    pool = create_pool(
        database_path: "data/cardmind.db",
        max_size: max_connections
    )

    // 步骤2：在第一个连接上初始化 schema
    first_connection = pool.get_connection()
    initialize_schema(first_connection)
    initialize_performance_settings(first_connection)

    return SqliteCache { connection_pool: pool }

// 从池中获取连接
function get_connection():
    // 注意：如果所有连接都在使用中则阻塞
    connection = connection_pool.acquire()
    return connection

// 初始化数据库 schema
function initialize_schema(connection):
    // 步骤1：配置 SQLite 设置
    configure_performance_settings(connection)

    // 步骤2：创建表和索引
    // 注意：从外部 SQL 文件加载 schema
    execute_schema_script(connection, "schema.sql")

    return success
```

---

## 需求：事务管理


系统应使用事务进行原子更新以维护一致性。

### 场景：使用事务批量更新

**事务逻辑**:

```
// 原子性地批量更新多张卡片
function batch_update_cards(cards):
    // 步骤1：开始事务
    // 设计决策：使用事务实现原子批量更新
    // 理由：确保全有或全无的语义
    transaction = begin_transaction()

    try:
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

        // 步骤3：提交事务
        commit(transaction)
        return success

    catch error:
        // 步骤4：出错时回滚
        rollback(transaction)
        return failure

// 原子性地更新池绑定
function update_pool_bindings(pool_id, card_ids):
    // 步骤1：开始事务
    transaction = begin_transaction()

    try:
        // 步骤2：清除此池的旧绑定
        // 设计决策：删除并重新插入以简化逻辑
        delete_bindings_for_pool(transaction, pool_id)

        // 步骤3：插入新绑定
        for each card_id in card_ids:
            insert_binding(
                transaction,
                card_id: card_id,
                pool_id: pool_id
            )

        // 步骤4：提交事务
        commit(transaction)
        return success

    catch error:
        // 步骤5：出错时回滚
        rollback(transaction)
        return failure
```

---

## 需求：数据库维护


系统应提供数据库维护操作以保持数据库健康。

### 场景：清理数据库以回收空间

**维护逻辑**:

```
// 清理数据库以回收空间
function vacuum_database():
    // 设计决策：运行 VACUUM 回收已删除的空间
    // 注意：应定期运行（例如，每周）
    // 理由：减少数据库文件大小并提高性能
    connection = get_connection()
    execute_vacuum(connection)
    log("Database vacuumed successfully")
    return success

// 分析数据库以优化查询
function analyze_database():
    // 设计决策：运行 ANALYZE 更新查询统计信息
    // 注意：应在重大数据变更后运行
    // 理由：帮助查询规划器选择最优执行计划
    connection = get_connection()
    execute_analyze(connection)
    log("Database analyzed successfully")
    return success

// 检查数据库完整性
function check_database_integrity():
    // 步骤1：运行完整性检查
    connection = get_connection()
    result = execute_integrity_check(connection)

    // 步骤2：验证结果
    if result == "ok":
        return true
    else:
        log_error("Database integrity check failed: " + result)
        return false
```

---

## 实现细节

**技术栈**:
- **rusqlite**: v0.30+ 用于 Rust 绑定
- **r2d2**: 连接池

**设计模式**:
- **仓储模式**: SqliteCache 作为数据访问层
- **连接池**: 高效的连接管理
- **事务模式**: 原子批量更新

**性能特征**:
- **读取性能**: 1000 张卡片 < 10ms
- **写入性能**: 每张卡片 < 50ms
- **搜索性能**: 全文搜索 < 100ms
- **并发读取**: WAL 模式下无限制

---

## 测试覆盖

**测试文件**: `rust/tests/sqlite_cache_test.rs`

**单元测试**:
- `test_schema_creation()` - Schema 初始化
- `test_insert_and_query_card()` - 基本 CRUD 操作
- `test_full_text_search()` - FTS5 搜索
- `test_pagination()` - 分页查询
- `test_transaction_rollback()` - 事务处理
- `test_connection_pool()` - 连接池
- `test_vacuum()` - 数据库维护

**性能测试**:
- 10ms 内查询 1000 张卡片
- 100ms 内全文搜索
- 并发读取压力测试

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 性能基准达标
- [ ] FTS5 搜索正确工作
- [ ] 连接池高效
- [ ] 代码审查通过

---

## 相关文档

**架构规格**:
- [./dual_layer.md](./dual_layer.md) - 双层架构
- [./card_store.md](./card_store.md) - CardStore 实现
- [./pool_store.md](./pool_store.md) - PoolStore 实现

**领域规格**:
- [../../domain/card/model.md](../../domain/card/model.md) - 卡片模型
- [../../domain/pool/model.md](../../domain/pool/model.md) - 池模型

---

**最后更新**: 2026-01-23
**作者**: CardMind Team
