# SQLite 缓存架构规格

**状态**: 活跃
**依赖**: [./dual_layer.md](./dual_layer.md), [./card_store.md](./card_store.md), [./pool_store.md](./pool_store.md)
**相关测试**: `rust/tests/sqlite_cache_test.rs`

---

## 概述

本规格定义了 CardMind 的 SQLite 缓存层，提供对卡片和池数据的快速读取访问，同时与 Loro CRDT 层保持最终一致性。

**技术栈**:
- **rusqlite** = "0.31" - SQLite Rust 绑定
- **r2d2** = "0.8" - 连接池管理
- **r2d2_sqlite** = "0.24" - SQLite 连接池适配器
- **tokio** - 异步运行时

**核心职责**:
- 为卡片和池数据提供快速索引查询
- 与 Loro 文档保持最终一致性
- 支持复杂查询（过滤、排序、分页）
- 启用全文搜索功能

---

## 需求：数据库 Schema

系统应维护具有优化 schema 的 SQLite 数据库以进行读取操作。

### 场景：Cards 表 schema

- **前置条件**: 数据库初始化
- **操作**: 创建 cards 表
- **预期结果**: 应创建包含所有必需字段的表
- **并且**: 应创建优化查询的索引

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

-- 常用查询的索引
CREATE INDEX IF NOT EXISTS idx_cards_updated_at ON cards(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_cards_deleted ON cards(deleted);
CREATE INDEX IF NOT EXISTS idx_cards_created_at ON cards(created_at DESC);
```

**字段描述**:
- `id`: 卡片 ID（UUIDv7）
- `title`: 卡片标题（索引用于搜索）
- `content`: 卡片内容（Markdown）
- `created_at`: 创建时间戳（Unix 毫秒）
- `updated_at`: 最后更新时间戳（索引用于排序）
- `deleted`: 软删除标志（索引用于过滤）

### 场景：Pools 表 schema

- **前置条件**: 数据库初始化
- **操作**: 创建 pools 表
- **预期结果**: 应创建池元数据表

**Schema 定义**:

```sql
CREATE TABLE IF NOT EXISTS pools (
    pool_id TEXT PRIMARY KEY,
    pool_name TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);
```

### 场景：Card-Pool 绑定表 schema

- **前置条件**: 数据库初始化
- **操作**: 创建 card_pool_bindings 表
- **预期结果**: 应创建关系表
- **并且**: 应设置外键约束

**Schema 定义**:

```sql
CREATE TABLE IF NOT EXISTS card_pool_bindings (
    card_id TEXT NOT NULL,
    pool_id TEXT NOT NULL,
    PRIMARY KEY (card_id, pool_id),
    FOREIGN KEY (card_id) REFERENCES cards(id) ON DELETE CASCADE,
    FOREIGN KEY (pool_id) REFERENCES pools(pool_id) ON DELETE CASCADE
);

-- 关系查询的索引
CREATE INDEX IF NOT EXISTS idx_bindings_pool_id ON card_pool_bindings(pool_id);
CREATE INDEX IF NOT EXISTS idx_bindings_card_id ON card_pool_bindings(card_id);
```

**理由**:
- 复合主键确保唯一的卡片-池关系
- 外键维护引用完整性
- 两列上的索引支持双向查询

**实现逻辑**:

```
function initialize_schema(connection):
    // 步骤1：创建 cards 表
    connection.execute("
        CREATE TABLE IF NOT EXISTS cards (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            deleted INTEGER NOT NULL DEFAULT 0
        )
    ")
    
    // 步骤2：创建 cards 表索引
    connection.execute("CREATE INDEX IF NOT EXISTS idx_cards_updated_at ON cards(updated_at DESC)")
    connection.execute("CREATE INDEX IF NOT EXISTS idx_cards_deleted ON cards(deleted)")
    connection.execute("CREATE INDEX IF NOT EXISTS idx_cards_created_at ON cards(created_at DESC)")
    
    // 步骤3：创建 pools 表
    connection.execute("
        CREATE TABLE IF NOT EXISTS pools (
            pool_id TEXT PRIMARY KEY,
            pool_name TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        )
    ")
    
    // 步骤4：创建 card_pool_bindings 表
    connection.execute("
        CREATE TABLE IF NOT EXISTS card_pool_bindings (
            card_id TEXT NOT NULL,
            pool_id TEXT NOT NULL,
            PRIMARY KEY (card_id, pool_id),
            FOREIGN KEY (card_id) REFERENCES cards(id) ON DELETE CASCADE,
            FOREIGN KEY (pool_id) REFERENCES pools(pool_id) ON DELETE CASCADE
        )
    ")
    
    // 步骤5：创建 bindings 表索引
    connection.execute("CREATE INDEX IF NOT EXISTS idx_bindings_pool_id ON card_pool_bindings(pool_id)")
    connection.execute("CREATE INDEX IF NOT EXISTS idx_bindings_card_id ON card_pool_bindings(card_id)")
    
    log_info("Database schema initialized")
    return success
```

---

## 需求：全文搜索

系统应使用 SQLite FTS5 支持对卡片标题和内容的全文搜索。

### 场景：卡片的 FTS5 虚拟表

- **前置条件**: cards 表已创建
- **操作**: 创建 FTS5 虚拟表和触发器
- **预期结果**: 应创建全文搜索索引
- **并且**: 应自动与 cards 表保持同步

**Schema 定义**:

```sql
-- FTS5 虚拟表用于全文搜索
CREATE VIRTUAL TABLE IF NOT EXISTS cards_fts USING fts5(
    id UNINDEXED,
    title,
    content,
    content='cards',
    content_rowid='rowid'
);

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

**实现逻辑**:

```
function initialize_fts5(connection):
    // 步骤1：创建 FTS5 虚拟表
    connection.execute("
        CREATE VIRTUAL TABLE IF NOT EXISTS cards_fts USING fts5(
            id UNINDEXED,
            title,
            content,
            content='cards',
            content_rowid='rowid'
        )
    ")
    
    // 步骤2：创建插入触发器
    connection.execute("
        CREATE TRIGGER IF NOT EXISTS cards_fts_insert AFTER INSERT ON cards BEGIN
            INSERT INTO cards_fts(rowid, id, title, content)
            VALUES (new.rowid, new.id, new.title, new.content);
        END
    ")
    
    // 步骤3：创建更新触发器
    connection.execute("
        CREATE TRIGGER IF NOT EXISTS cards_fts_update AFTER UPDATE ON cards BEGIN
            UPDATE cards_fts
            SET title = new.title, content = new.content
            WHERE rowid = new.rowid;
        END
    ")
    
    // 步骤4：创建删除触发器
    connection.execute("
        CREATE TRIGGER IF NOT EXISTS cards_fts_delete AFTER DELETE ON cards BEGIN
            DELETE FROM cards_fts WHERE rowid = old.rowid;
        END
    ")
    
    log_info("FTS5 full-text search initialized")
    return success
```

### 场景：按关键词搜索卡片

- **前置条件**: 多张具有不同内容的卡片
- **操作**: 用户搜索 "rust programming"
- **预期结果**: 系统应返回包含这些关键词的卡片
- **并且**: 结果应按相关性排序

**实现逻辑**:

```
function search_cards(query, pool_id, limit):
    // 步骤1：构建 FTS5 查询
    // 设计决策：使用 FTS5 MATCH 进行全文搜索并按相关性排序
    db = get_sqlite_connection()
    
    // 步骤2：执行全文搜索查询
    // 注意：FTS5 rank 函数提供相关性评分
    sql = "
        SELECT c.id, c.title, c.content, c.created_at, c.updated_at,
               cards_fts.rank AS relevance
        FROM cards_fts
        INNER JOIN cards c ON cards_fts.id = c.id
        INNER JOIN card_pool_bindings b ON c.id = b.card_id
        WHERE cards_fts MATCH ?
          AND b.pool_id = ?
          AND c.deleted = 0
        ORDER BY cards_fts.rank
        LIMIT ?
    "
    
    results = db.query(sql, [query, pool_id, limit])
    
    log_debug("Found " + results.length + " cards matching: " + query)
    return results
```

---

## 需求：查询优化

系统应使用索引和查询规划优化常见查询。

### 场景：获取当前池中的所有卡片（按更新时间排序）

- **前置条件**: 池中有多张卡片
- **操作**: 查询池中的卡片
- **预期结果**: 应返回按更新时间排序的卡片
- **并且**: 查询应使用索引优化

**实现逻辑**:

```
function get_cards_in_pool(pool_id, limit, offset):
    // 步骤1：获取数据库连接
    db = get_sqlite_connection()
    
    // 步骤2：使用池绑定过滤查询 cards 表
    // 设计决策：使用 JOIN 按池成员资格过滤
    // 注意：pool_id 和 updated_at 上的索引实现高效查询
    sql = "
        SELECT c.id, c.title, c.content, c.created_at, c.updated_at
        FROM cards c
        INNER JOIN card_pool_bindings b ON c.id = b.card_id
        WHERE b.pool_id = ?
          AND c.deleted = 0
        ORDER BY c.updated_at DESC
        LIMIT ? OFFSET ?
    "
    
    cards = db.query(sql, [pool_id, limit, offset])
    
    log_debug("Retrieved " + cards.length + " cards from pool")
    return cards
```

### 场景：统计池中的卡片数量

- **前置条件**: 池存在
- **操作**: 统计池中的卡片
- **预期结果**: 应返回准确的卡片数量

**实现逻辑**:

```
function count_cards_in_pool(pool_id):
    // 步骤1：获取数据库连接
    db = get_sqlite_connection()
    
    // 步骤2：使用池绑定过滤统计卡片
    // 设计决策：使用 COUNT 聚合与 JOIN 实现精确统计
    // 注意：pool_id 和 deleted 上的索引实现高效统计
    sql = "
        SELECT COUNT(*) as count
        FROM cards c
        INNER JOIN card_pool_bindings b ON c.id = b.card_id
        WHERE b.pool_id = ?
          AND c.deleted = 0
    "
    
    result = db.query_one(sql, [pool_id])
    count = result.count
    
    return count
```

### 场景：按创建时间获取最新卡片

- **前置条件**: 池中有多张卡片
- **操作**: 获取最新创建的卡片
- **预期结果**: 应返回按创建时间排序的卡片

**实现逻辑**:

```
function get_recent_cards(pool_id, limit):
    // 获取最近创建的卡片
    db = get_sqlite_connection()
    
    sql = "
        SELECT c.id, c.title, c.content, c.created_at, c.updated_at
        FROM cards c
        INNER JOIN card_pool_bindings b ON c.id = b.card_id
        WHERE b.pool_id = ?
          AND c.deleted = 0
        ORDER BY c.created_at DESC
        LIMIT ?
    "
    
    cards = db.query(sql, [pool_id, limit])
    return cards
```

---

## 需求：数据库配置

系统应配置 SQLite 以获得最佳性能和持久性。

### 场景：SQLite 性能配置

- **前置条件**: 数据库连接已建立
- **操作**: 配置性能参数
- **预期结果**: 应优化数据库性能

**实现逻辑**:

```
function initialize_database():
    // 步骤1：打开数据库连接
    connection = open_database("data/cardmind.db")

    // 步骤2：配置性能设置
    // 设计决策：使用 WAL 模式以提高并发性
    // 理由：允许写入期间的并发读取
    connection.execute("PRAGMA journal_mode = WAL")

    // 设计决策：将缓存大小设置为 10MB
    // 理由：减少频繁访问数据的磁盘 I/O
    connection.execute("PRAGMA cache_size = -10000")  // 负数表示 KB

    // 设计决策：使用 NORMAL 同步模式
    // 理由：平衡持久性和性能
    connection.execute("PRAGMA synchronous = NORMAL")

    // 步骤3：启用完整性功能
    connection.execute("PRAGMA foreign_keys = ON")

    // 步骤4：优化内存使用
    // 注意：使用内存进行临时操作以提高性能
    connection.execute("PRAGMA temp_store = MEMORY")

    // 设计决策：启用内存映射 I/O（256MB）
    // 理由：提高大型数据库的读取性能
    connection.execute("PRAGMA mmap_size = 268435456")  // 256MB

    // 步骤5：分析数据库以优化查询
    connection.execute("ANALYZE")

    log_info("Database configured for optimal performance")
    return connection
```

**配置理由**:
- **WAL 模式**: 允许写入期间的并发读取
- **缓存大小**: 减少频繁访问数据的磁盘 I/O
- **同步 NORMAL**: 平衡持久性和性能
- **外键**: 维护引用完整性
- **内存临时存储**: 更快的临时操作
- **内存映射 I/O**: 提高大型数据库的读取性能

---

## 需求：连接池

系统应使用连接池高效管理数据库连接。

### 场景：并发访问的连接池

- **前置条件**: 应用启动
- **操作**: 初始化连接池
- **预期结果**: 应创建可复用的连接池
- **并且**: 应支持并发访问

**实现逻辑**:

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
        max_size: max_connections,
        min_idle: 2,
        connection_timeout: 30_seconds
    )

    // 步骤2：在第一个连接上初始化 schema
    first_connection = pool.get_connection()
    initialize_schema(first_connection)
    initialize_fts5(first_connection)
    configure_performance_settings(first_connection)
    first_connection.release()

    log_info("Connection pool initialized with max size: " + max_connections)
    return SqliteCache { connection_pool: pool }

// 从池中获取连接
function get_connection():
    // 注意：如果所有连接都在使用中则阻塞
    // 设计决策：使用超时防止无限等待
    connection = connection_pool.acquire(timeout: 30_seconds)
    
    if connection is None:
        return error "ConnectionPoolTimeout"
    
    return connection

// 释放连接回池
function release_connection(connection):
    // 将连接返回到池中以供重用
    connection_pool.release(connection)
```

---

## 需求：事务管理

系统应使用事务进行原子更新以维护一致性。

### 场景：使用事务批量更新

- **前置条件**: 需要更新多张卡片
- **操作**: 批量更新
- **预期结果**: 应原子地更新所有卡片
- **并且**: 失败时应回滚

**实现逻辑**:

```
// 原子性地批量更新多张卡片
function batch_update_cards(cards):
    // 步骤1：获取连接
    connection = get_connection()
    
    // 步骤2：开始事务
    // 设计决策：使用事务实现原子批量更新
    // 理由：确保全有或全无的语义
    transaction = connection.begin_transaction()

    try:
        // 步骤3：更新每张卡片
        for each card in cards:
            transaction.execute("
                INSERT OR REPLACE INTO cards
                (id, title, content, created_at, updated_at, deleted)
                VALUES (?, ?, ?, ?, ?, ?)
            ", [
                card.id,
                card.title,
                card.content,
                card.created_at,
                card.updated_at,
                card.deleted
            ])

        // 步骤4：提交事务
        transaction.commit()
        
        log_debug("Batch updated " + cards.length + " cards")
        return success

    catch error:
        // 步骤5：出错时回滚
        transaction.rollback()
        log_error("Batch update failed: " + error)
        return error
    finally:
        // 步骤6：释放连接
        release_connection(connection)

// 原子性地更新池绑定
function update_pool_bindings(pool_id, card_ids):
    // 步骤1：获取连接
    connection = get_connection()
    
    // 步骤2：开始事务
    transaction = connection.begin_transaction()

    try:
        // 步骤3：清除此池的旧绑定
        // 设计决策：删除并重新插入以简化逻辑
        transaction.execute("
            DELETE FROM card_pool_bindings 
            WHERE pool_id = ?
        ", [pool_id])

        // 步骤4：插入新绑定
        for each card_id in card_ids:
            transaction.execute("
                INSERT OR REPLACE INTO card_pool_bindings
                (card_id, pool_id)
                VALUES (?, ?)
            ", [card_id, pool_id])

        // 步骤5：提交事务
        transaction.commit()
        
        log_debug("Updated bindings for pool: " + pool_id)
        return success

    catch error:
        // 步骤6：出错时回滚
        transaction.rollback()
        log_error("Failed to update pool bindings: " + error)
        return error
    finally:
        // 步骤7：释放连接
        release_connection(connection)
```

---

## 需求：数据库维护

系统应提供数据库维护操作以保持数据库健康。

### 场景：清理数据库以回收空间

- **前置条件**: 数据库有已删除的数据
- **操作**: 运行 VACUUM
- **预期结果**: 应回收磁盘空间

### 场景：优化查询性能

- **前置条件**: 数据库有大量数据
- **操作**: 运行 ANALYZE
- **预期结果**: 应更新查询统计信息

**实现逻辑**:

```
// 清理数据库以回收空间
function vacuum_database():
    // 设计决策：运行 VACUUM 回收已删除的空间
    // 注意：应定期运行（例如，每周）
    // 理由：减少数据库文件大小并提高性能
    
    connection = get_connection()
    
    try:
        // VACUUM 会锁定整个数据库
        log_info("Starting database vacuum...")
        connection.execute("VACUUM")
        log_info("Database vacuumed successfully")
        return success
    catch error:
        log_error("Vacuum failed: " + error)
        return error
    finally:
        release_connection(connection)

// 分析数据库以优化查询
function analyze_database():
    // 设计决策：运行 ANALYZE 更新查询统计信息
    // 注意：应在重大数据变更后运行
    // 理由：帮助查询规划器选择最优执行计划
    
    connection = get_connection()
    
    try:
        connection.execute("ANALYZE")
        log_info("Database analyzed successfully")
        return success
    catch error:
        log_error("Analyze failed: " + error)
        return error
    finally:
        release_connection(connection)

// 检查数据库完整性
function check_database_integrity():
    // 步骤1：获取连接
    connection = get_connection()
    
    try:
        // 步骤2：运行完整性检查
        result = connection.query_one("PRAGMA integrity_check")

        // 步骤3：验证结果
        if result == "ok":
            log_info("Database integrity check passed")
            return true
        else:
            log_error("Database integrity check failed: " + result)
            return false
    catch error:
        log_error("Integrity check failed: " + error)
        return false
    finally:
        release_connection(connection)

// 优化数据库（组合操作）
function optimize_database():
    // 执行完整的数据库优化
    // 步骤1：分析统计信息
    analyze_database()
    
    // 步骤2：清理空间
    vacuum_database()
    
    // 步骤3：检查完整性
    is_healthy = check_database_integrity()
    
    if is_healthy:
        log_info("Database optimization completed successfully")
        return success
    else:
        log_error("Database optimization completed with errors")
        return error
```

---

## 补充说明

**技术栈**:
- **rusqlite** = "0.31" - SQLite Rust 绑定
- **r2d2** = "0.8" - 连接池管理
- **r2d2_sqlite** = "0.24" - SQLite 连接池适配器
- **tokio** - 异步运行时

**设计模式**:
- **仓储模式**: SqliteCache 作为数据访问层
- **连接池模式**: 高效的连接管理
- **事务模式**: 原子批量更新
- **索引策略**: 优化常见查询路径

**性能特征**:
- **读取性能**: 1000 张卡片 < 10ms
- **写入性能**: 每张卡片 < 50ms
- **搜索性能**: 全文搜索 < 100ms
- **并发读取**: WAL 模式下无限制
- **连接池大小**: 默认 10 个连接

**内存使用**:
- **缓存大小**: 10MB
- **内存映射**: 256MB
- **连接池**: ~1MB per connection

---

## 相关文档

**架构规格**:
- [./dual_layer.md](./dual_layer.md) - 双层架构
- [./card_store.md](./card_store.md) - CardStore 实现
- [./pool_store.md](./pool_store.md) - PoolStore 实现
- [./loro_integration.md](./loro_integration.md) - Loro 集成
- [../sync/subscription.md](../sync/subscription.md) - 订阅机制

**领域规格**:
- [../../domain/card/model.md](../../domain/card/model.md) - 卡片模型
- [../../domain/pool/model.md](../../domain/pool/model.md) - 池模型

---

## 测试覆盖

**测试文件**: `rust/tests/sqlite_cache_test.rs`

**单元测试**:
- `test_schema_creation()` - Schema 初始化
- `test_insert_and_query_card()` - 基本 CRUD 操作
- `test_full_text_search()` - FTS5 搜索
- `test_fts5_triggers()` - FTS5 触发器同步
- `test_pagination()` - 分页查询
- `test_count_cards()` - 卡片统计
- `test_recent_cards()` - 最新卡片查询
- `test_transaction_commit()` - 事务提交
- `test_transaction_rollback()` - 事务回滚
- `test_batch_update()` - 批量更新
- `test_connection_pool()` - 连接池
- `test_connection_timeout()` - 连接超时
- `test_vacuum()` - 数据库清理
- `test_analyze()` - 数据库分析
- `test_integrity_check()` - 完整性检查
- `test_foreign_key_constraints()` - 外键约束

**性能测试**:
- `bench_query_1000_cards()` - 10ms 内查询 1000 张卡片
- `bench_full_text_search()` - 100ms 内全文搜索
- `bench_concurrent_reads()` - 并发读取压力测试
- `bench_batch_insert()` - 批量插入性能

**验收标准**:
- [x] 所有单元测试通过
- [x] 性能基准达标
- [x] FTS5 搜索正确工作
- [x] 连接池高效
- [x] 事务正确处理
- [x] 代码审查通过
