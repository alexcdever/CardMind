# 双层存储架构规格

**状态**: 活跃
**依赖**: [./card_store.md](./card_store.md), [../../domain/card.md](../../domain/card.md)
**相关测试**: `rust/tests/dual_layer_test.rs`

---

## 概述

本规格定义了双层存储架构，将写操作（Loro CRDT）与读操作（SQLite 缓存）分离，在保持查询性能的同时实现无冲突同步。

**技术栈**:
- **loro** = "1.0" - CRDT 文档存储
- **rusqlite** = "0.31" - SQLite 数据库
- **tokio** - 异步运行时
- **serde** = "1.0" - 序列化/反序列化

**架构模式**:

```
┌─────────────────────────────────────────┐
│              应用层                      │
│         (UI, 业务逻辑)                   │
└─────────────────────────────────────────┘
           │                    │
           │      写入          │ 读取
           ▼                    ▼
┌──────────────────┐  ┌──────────────────┐
│      写入层      │  │      读取层      │
│   (Loro CRDT)    │  │   (SQLite)       │
│                  │  │                  │
│ - 单一数据源     │  │ - 查询缓存       │
│ - P2P 同步       │  │ - 索引           │
│ - 无冲突         │  │ - 快速读取       │
└──────────────────┘  └──────────────────┘
           │                    ▲
           │      订阅          │
           └────────────────────┘
              (自动更新)
```

**核心原则**:
- **单一数据源**: Loro 文档是权威数据源
- **读写分离**: 为每层优化其用途
- **最终一致性**: SQLite 最终反映 Loro 状态
- **订阅驱动**: 更新自动传播

---

## 需求：写入层 - Loro CRDT

系统应使用 Loro CRDT 文档作为所有写操作的权威数据源。

### 场景：所有写入首先进入 Loro

- **前置条件**: 用户修改卡片
- **操作**: 保存修改
- **预期结果**: 变更应首先写入 Loro 文档
- **并且**: Loro 文档应持久化到磁盘
- **并且**: SQLite 缓存应通过订阅更新

**理由**:
- Loro 为 P2P 同步提供无冲突合并
- CRDT 保证跨设备的最终一致性
- Loro 文档可以在对等设备间直接同步

**实现逻辑**:

```
function update_card(card_id, title, content):
    // 步骤1：加载 Loro 文档
    // 设计决策：Loro 是单一数据源
    loro_doc = load_loro_document(card_id)
    
    if loro_doc is None:
        return error "CardNotFound"
    
    // 步骤2：更新 Loro 文档字段
    card_map = loro_doc.get_map("card")
    card_map.set("title", title)
    card_map.set("content", content)
    card_map.set("updated_at", current_timestamp())
    
    // 步骤3：提交变更
    // 注意：commit() 触发订阅回调
    loro_doc.commit()
    
    // 步骤4：持久化到磁盘
    // 设计决策：异步持久化以提高性能
    save_loro_snapshot_async(card_id, loro_doc)
    
    log_debug("Card updated in Loro: " + card_id)
    return success
```

### 场景：卡片的 Loro 文档结构

- **前置条件**: 系统需要定义卡片的 CRDT 文档结构
- **操作**: 设定卡片的 Loro 文档字段
- **预期结果**: 文档包含卡片核心字段
- **并且**: 字段使用 UUIDv7 与毫秒级时间戳

**文档结构**:

```rust
// 卡片的 Loro 文档
{
  "card": {
    "id": "01JQXXX...",           // UUIDv7
    "title": "卡片标题",
    "content": "# 内容",
    "created_at": 1706000000000,  // Unix 时间戳 (毫秒)
    "updated_at": 1706000001000,  // Unix 时间戳 (毫秒)
    "deleted": false
  }
}
```

**文件位置**:
- 路径: `data/loro/<card_id>/snapshot.loro`
- 格式: Loro 二进制快照

**实现逻辑**:

```
function create_card_loro_document(card_id, title, content):
    // 步骤1：创建新的 Loro 文档
    loro_doc = create_loro_document()
    
    // 步骤2：初始化卡片结构
    card_map = loro_doc.get_map("card")
    card_map.set("id", card_id)
    card_map.set("title", title)
    card_map.set("content", content)
    card_map.set("created_at", current_timestamp())
    card_map.set("updated_at", current_timestamp())
    card_map.set("deleted", false)
    
    // 步骤3：提交初始状态
    loro_doc.commit()
    
    // 步骤4：持久化到磁盘
    save_loro_snapshot(card_id, loro_doc)
    
    return loro_doc
```

### 场景：池的 Loro 文档结构

- **前置条件**: 系统需要定义池的 CRDT 文档结构
- **操作**: 设定池的 Loro 文档字段
- **预期结果**: 文档包含池与成员列表信息
- **并且**: 列表字段使用 Loro List CRDT

**文档结构**:

```rust
// 池的 Loro 文档
{
  "pool": {
    "pool_id": "01JQYYY...",      // UUIDv7
    "pool_name": "我的池",
    "card_ids": [                 // 卡片 ID 列表
      "01JQXXX...",
      "01JQZZZ..."
    ],
    "device_ids": [               // 设备 ID 列表
      "device_A",
      "device_B"
    ],
    "created_at": 1706000000000,  // Unix 时间戳 (毫秒)
    "updated_at": 1706000001000   // Unix 时间戳 (毫秒)
  }
}
```

**文件位置**:
- 路径: `data/loro/<pool_id>/snapshot.loro`

**实现逻辑**:

```
function create_pool_loro_document(pool_id, pool_name):
    // 步骤1：创建新的 Loro 文档
    loro_doc = create_loro_document()
    
    // 步骤2：初始化池结构
    pool_map = loro_doc.get_map("pool")
    pool_map.set("pool_id", pool_id)
    pool_map.set("pool_name", pool_name)
    
    // 步骤3：初始化列表字段
    // 设计决策：使用 Loro List CRDT 支持并发添加
    card_ids_list = loro_doc.get_list("card_ids")
    device_ids_list = loro_doc.get_list("device_ids")
    
    pool_map.set("created_at", current_timestamp())
    pool_map.set("updated_at", current_timestamp())
    
    // 步骤4：提交初始状态
    loro_doc.commit()
    
    // 步骤5：持久化到磁盘
    save_loro_snapshot(pool_id, loro_doc)
    
    return loro_doc
```

---

## 需求：读取层 - SQLite 缓存

系统应维护 SQLite 缓存以优化读取查询。

### 场景：所有读取来自 SQLite

- **前置条件**: 用户请求卡片列表
- **操作**: 执行查询
- **预期结果**: 数据应从 SQLite 读取
- **并且**: 读取时不应访问 Loro 文档

**理由**:
- SQLite 提供快速索引查询
- 避免为每次读取反序列化 Loro 文档
- 支持复杂查询（过滤、排序、分页）

**实现逻辑**:

```
function get_cards_in_pool(pool_id, limit, offset):
    // 步骤1：获取 SQLite 连接
    db = get_sqlite_connection()
    
    // 步骤2：执行查询
    // 设计决策：使用索引优化查询性能
    query = "
        SELECT c.id, c.title, c.content, c.created_at, c.updated_at
        FROM cards c
        INNER JOIN card_pool_bindings b ON c.id = b.card_id
        WHERE b.pool_id = ?
          AND c.deleted = 0
        ORDER BY c.updated_at DESC
        LIMIT ? OFFSET ?
    "
    
    // 步骤3：执行查询并返回结果
    cards = db.query(query, [pool_id, limit, offset])
    
    log_debug("Retrieved " + cards.length + " cards from SQLite")
    return cards
```

### 场景：SQLite schema 设计

- **前置条件**: 系统需要定义缓存层的表结构
- **操作**: 建立卡片、池及绑定关系的表
- **预期结果**: 支持常用查询并具备索引
- **并且**: schema 可被重复初始化

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

-- 常用查询的索引
CREATE INDEX IF NOT EXISTS idx_cards_updated_at ON cards(updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_cards_deleted ON cards(deleted);
```

**卡片-池绑定表**:

```sql
CREATE TABLE IF NOT EXISTS card_pool_bindings (
    card_id TEXT NOT NULL,
    pool_id TEXT NOT NULL,
    PRIMARY KEY (card_id, pool_id),
    FOREIGN KEY (card_id) REFERENCES cards(id) ON DELETE CASCADE
);

-- 关系查询的索引
CREATE INDEX IF NOT EXISTS idx_bindings_pool_id ON card_pool_bindings(pool_id);
CREATE INDEX IF NOT EXISTS idx_bindings_card_id ON card_pool_bindings(card_id);
```

**池表**:

```sql
CREATE TABLE IF NOT EXISTS pools (
    pool_id TEXT PRIMARY KEY,
    pool_name TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);
```

**实现逻辑**:

```
function initialize_sqlite_schema():
    // 步骤1：获取 SQLite 连接
    db = get_sqlite_connection()
    
    // 步骤2：创建表
    db.execute("CREATE TABLE IF NOT EXISTS cards (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted INTEGER NOT NULL DEFAULT 0
    )")
    
    db.execute("CREATE TABLE IF NOT EXISTS card_pool_bindings (
        card_id TEXT NOT NULL,
        pool_id TEXT NOT NULL,
        PRIMARY KEY (card_id, pool_id),
        FOREIGN KEY (card_id) REFERENCES cards(id) ON DELETE CASCADE
    )")
    
    db.execute("CREATE TABLE IF NOT EXISTS pools (
        pool_id TEXT PRIMARY KEY,
        pool_name TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
    )")
    
    // 步骤3：创建索引
    db.execute("CREATE INDEX IF NOT EXISTS idx_cards_updated_at ON cards(updated_at DESC)")
    db.execute("CREATE INDEX IF NOT EXISTS idx_cards_deleted ON cards(deleted)")
    db.execute("CREATE INDEX IF NOT EXISTS idx_bindings_pool_id ON card_pool_bindings(pool_id)")
    db.execute("CREATE INDEX IF NOT EXISTS idx_bindings_card_id ON card_pool_bindings(card_id)")
    
    log_info("SQLite schema initialized")
    return success
```

### 场景：查询优化示例

- **前置条件**: 需要验证常用查询的可读性与索引使用
- **操作**: 列出典型查询语句
- **预期结果**: 查询语句覆盖列表、搜索与计数
- **并且**: 可用于性能调优

**示例 1：获取当前池中的所有卡片**

```sql
-- 使用索引的快速查询
SELECT c.id, c.title, c.content, c.created_at, c.updated_at
FROM cards c
INNER JOIN card_pool_bindings b ON c.id = b.card_id
WHERE b.pool_id = ?
  AND c.deleted = 0
ORDER BY c.updated_at DESC;
```

**示例 2：按标题搜索卡片**

```sql
-- 全文搜索（可使用 FTS5 优化）
SELECT c.id, c.title, c.content, c.created_at, c.updated_at
FROM cards c
INNER JOIN card_pool_bindings b ON c.id = b.card_id
WHERE b.pool_id = ?
  AND c.deleted = 0
  AND c.title LIKE ?
ORDER BY c.updated_at DESC;
```

**示例 3：统计池中的卡片数量**

```sql
-- 使用索引的快速计数
SELECT COUNT(*)
FROM card_pool_bindings b
INNER JOIN cards c ON b.card_id = c.id
WHERE b.pool_id = ?
  AND c.deleted = 0;
```

---

## 需求：订阅驱动的同步

系统应使用 Loro 文档订阅自动将变更从写入层传播到读取层。

### 场景：卡片更新触发 SQLite 更新

- **前置条件**: Card Loro 文档被修改
- **操作**: 调用 Card.commit()
- **预期结果**: 应触发订阅回调
- **并且**: cards 表应被更新

**实现逻辑**:

```
function on_card_updated(card):
    // 步骤1：获取 SQLite 连接
    sqlite = get_sqlite_connection()

    // 步骤2：将卡片数据更新插入到 SQLite 缓存
    // 设计决策：使用 INSERT OR REPLACE 实现幂等更新
    sqlite.execute("
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

    log_debug("SQLite updated for card: " + card.id)
    return success
```

### 场景：池更新触发 SQLite 更新

- **前置条件**: Pool Loro 文档被修改
- **操作**: 调用 Pool.commit()
- **预期结果**: 应触发订阅回调
- **并且**: card_pool_bindings 表应被更新
- **并且**: 更新应是幂等的

**实现逻辑**:

```
function on_pool_updated(pool):
    // 步骤1：获取 SQLite 连接
    sqlite = get_sqlite_connection()

    // 步骤2：开始事务
    // 设计决策：使用事务确保原子性
    transaction = sqlite.begin_transaction()

    try:
        // 步骤3：清除该池的旧绑定（确保幂等性）
        // 设计决策：先删除后插入模式确保一致性
        transaction.execute("
            DELETE FROM card_pool_bindings
            WHERE pool_id = ?
        ", [pool.pool_id])

        // 步骤4：从当前池状态插入新绑定
        for each card_id in pool.card_ids:
            transaction.execute("
                INSERT OR REPLACE INTO card_pool_bindings
                (card_id, pool_id)
                VALUES (?, ?)
            ", [card_id, pool.pool_id])

        // 步骤5：更新池元数据
        transaction.execute("
            INSERT OR REPLACE INTO pools
            (pool_id, pool_name, created_at, updated_at)
            VALUES (?, ?, ?, ?)
        ", [
            pool.pool_id,
            pool.pool_name,
            pool.created_at,
            pool.updated_at
        ])

        // 步骤6：提交事务
        transaction.commit()

        log_debug("SQLite updated for pool: " + pool.pool_id)
        return success
    catch error:
        // 回滚事务
        transaction.rollback()
        log_error("Failed to update SQLite for pool: " + error)
        return error
```

---

## 需求：数据一致性保证

系统应在 Loro 和 SQLite 层之间维护最终一致性。

### 场景：SQLite 最终反映 Loro 状态

- **前置条件**: Loro 文档被修改
- **操作**: 订阅回调完成
- **预期结果**: SQLite 应反映与 Loro 相同的数据
- **并且**: 任何后续读取应看到更新的数据

### 场景：处理订阅回调失败

- **前置条件**: Loro 文档被修改
- **操作**: 订阅回调失败
- **预期结果**: 错误应被记录
- **并且**: 系统应重试更新
- **并且**: Loro 应保持为数据源

**实现逻辑**:

```
// 带错误处理的订阅回调

function on_pool_updated_safe(pool):
    // 尝试更新 SQLite 缓存
    result = on_pool_updated(pool)

    if result is success:
        // 记录成功更新
        log_debug("SQLite updated for pool: " + pool.pool_id)
    else:
        // 记录错误并加入重试队列
        // 设计决策：使用重试队列确保最终一致性
        log_error("Failed to update SQLite for pool: " + pool.pool_id + ", error: " + result.error)
        add_to_retry_queue(UpdatePoolTask {
            pool: pool,
            retry_count: 0,
            max_retries: 5
        })

function process_retry_queue():
    // 后台任务处理重试队列
    loop forever:
        task = retry_queue.pop()
        
        if task exists:
            if task.retry_count < task.max_retries:
                // 重试更新
                result = on_pool_updated(task.pool)
                
                if result is success:
                    log_info("Retry successful for pool: " + task.pool.pool_id)
                else:
                    // 增加重试计数并重新加入队列
                    task.retry_count = task.retry_count + 1
                    delay = calculate_exponential_backoff(task.retry_count)
                    sleep(delay)
                    retry_queue.push(task)
            else:
                log_error("Max retries exceeded for pool: " + task.pool.pool_id)
        else:
            sleep(1_second)
```

---

## 需求：从 Loro 重建 SQLite

系统应支持从 Loro 文档重建整个 SQLite 缓存。

### 场景：损坏时重建 SQLite

- **前置条件**: SQLite 数据库损坏
- **操作**: 系统检测到损坏
- **预期结果**: 系统应删除 SQLite 数据库
- **并且**: 系统应从所有 Loro 文档重建
- **并且**: 所有数据应被恢复

**实现逻辑**:

```
// 从 Loro 文档重建 SQLite 缓存
//
// 用例：
// - SQLite 损坏
// - Schema 迁移
// - 数据验证

function rebuild_sqlite_from_loro():
    // 步骤1：获取 SQLite 连接
    sqlite = get_sqlite_connection()

    // 步骤2：清除所有现有缓存数据
    // 设计决策：完全清除确保干净重建
    sqlite.execute("DELETE FROM card_pool_bindings")
    sqlite.execute("DELETE FROM cards")
    sqlite.execute("DELETE FROM pools")

    // 步骤3：扫描 Loro 文档目录
    loro_directory = get_loro_directory()
    subdirectories = list_directories(loro_directory)
    
    log_info("Rebuilding SQLite from " + subdirectories.length + " Loro documents")

    // 步骤4：遍历所有 Loro 文档
    for each subdirectory in subdirectories:
        snapshot_file = subdirectory + "/snapshot.loro"

        if file_exists(snapshot_file):
            // 步骤5：加载 Loro 文档快照
            loro_doc = load_loro_snapshot(snapshot_file)

            // 步骤6：解析文档并更新 SQLite
            // 注意：文档类型决定使用哪个回调
            if loro_doc.has_map("card"):
                card = parse_card_from_loro(loro_doc)
                on_card_updated(card)
            else if loro_doc.has_map("pool"):
                pool = parse_pool_from_loro(loro_doc)
                on_pool_updated(pool)

    log_info("SQLite cache rebuilt from Loro documents")
    return success

function parse_card_from_loro(loro_doc):
    // 从 Loro 文档中提取卡片数据
    card_map = loro_doc.get_map("card")
    
    return Card {
        id: card_map.get("id"),
        title: card_map.get("title"),
        content: card_map.get("content"),
        created_at: card_map.get("created_at"),
        updated_at: card_map.get("updated_at"),
        deleted: card_map.get("deleted")
    }

function parse_pool_from_loro(loro_doc):
    // 从 Loro 文档中提取池数据
    pool_map = loro_doc.get_map("pool")
    card_ids_list = loro_doc.get_list("card_ids")
    device_ids_list = loro_doc.get_list("device_ids")
    
    return Pool {
        pool_id: pool_map.get("pool_id"),
        pool_name: pool_map.get("pool_name"),
        card_ids: card_ids_list.to_array(),
        device_ids: device_ids_list.to_array(),
        created_at: pool_map.get("created_at"),
        updated_at: pool_map.get("updated_at")
    }
```

---

## 需求：性能优化

系统应为每层的特定用例优化性能。

### 场景：写性能 - Loro

- **前置条件**: 高频写入导致响应延迟上升
- **操作**: 引入缓存与延迟持久化策略
- **预期结果**: 写入延迟保持可控
- **并且**: 不影响最终一致性

**优化**:
- **内存缓存**: 将频繁访问的 Loro 文档保存在内存中
- **延迟持久化**: 批量写入磁盘
- **增量快照**: 仅保存变更的文档

**实现逻辑**:

```
structure LoroDocumentCache:
    documents: map of document_id to loro_doc
    max_size: 100
    
    function get_or_load(document_id):
        // 步骤1：检查内存缓存
        if documents.has(document_id):
            return documents[document_id]
        
        // 步骤2：从磁盘加载
        loro_doc = load_loro_snapshot(document_id)
        
        // 步骤3：添加到缓存
        if documents.size >= max_size:
            // 驱逐最少使用的文档
            evict_lru_document()
        
        documents[document_id] = loro_doc
        return loro_doc
```

### 场景：读性能 - SQLite

- **前置条件**: 读取查询成为性能瓶颈
- **操作**: 配置 SQLite 并优化索引
- **预期结果**: 读取延迟降低
- **并且**: 读写并发能力提升

**优化**:
- **索引**: 在频繁查询的列上创建索引
- **查询规划**: 使用 EXPLAIN QUERY PLAN 优化查询
- **连接池**: 复用 SQLite 连接
- **WAL 模式**: 启用预写日志以提高并发性

**实现逻辑**:

```
// 配置 SQLite 以获得最佳性能

function configure_sqlite(connection):
    // 步骤1：启用 WAL 模式以提高并发性
    // 设计决策：WAL 允许写入时并发读取
    connection.execute("PRAGMA journal_mode = WAL")

    // 步骤2：增加缓存大小以提高性能
    // 注意：10MB 缓存减少磁盘 I/O
    connection.execute("PRAGMA cache_size = -10000")  // 负数表示 KB

    // 步骤3：设置同步模式以保证持久性
    // 设计决策：NORMAL 平衡性能和安全性
    connection.execute("PRAGMA synchronous = NORMAL")

    // 步骤4：启用外键约束
    connection.execute("PRAGMA foreign_keys = ON")
    
    // 步骤5：设置临时存储为内存
    connection.execute("PRAGMA temp_store = MEMORY")

    log_info("SQLite configured for optimal performance")
    return success
```

---

## 补充说明

**设计模式**:
- **CQRS（命令查询职责分离）**: 分离写入和读取模型
- **观察者模式**: 订阅驱动更新
- **旁路缓存模式**: SQLite 作为 Loro 的缓存

**权衡**:
- **优点**: 无冲突同步、快速读取、最终一致性
- **缺点**: 最终一致性（非即时）、存储开销（两份副本）

**性能特征**:
- **写入延迟**: < 50ms（包括 Loro commit）
- **读取延迟**: < 10ms（SQLite 索引查询）
- **同步延迟**: < 100ms（订阅回调）
- **重建时间**: < 5s（10000 张卡片）

---

## 相关文档

**架构规格**:
- [./card_store.md](./card_store.md) - CardStore 实现
- [./pool_store.md](./pool_store.md) - PoolStore 实现
- [./sqlite_cache.md](./sqlite_cache.md) - SQLite 缓存细节
- [./loro_integration.md](./loro_integration.md) - Loro 集成
- [../sync/subscription.md](../sync/subscription.md) - 订阅机制

**领域规格**:
- [../../domain/card.md](../../domain/card.md) - 卡片领域模型
- [../../domain/pool.md](../../domain/pool.md) - 池领域模型

**架构决策记录**:
- ADR-0002: 双层架构 - 读写分离设计决策
- ADR-0003: Loro CRDT - CRDT 选择理由

---

## 测试覆盖

**测试文件**: `rust/tests/dual_layer_test.rs`

**单元测试**:
- `test_write_to_loro_updates_sqlite()` - 写入传播
- `test_read_from_sqlite_not_loro()` - 从缓存读取
- `test_subscription_callback_updates_sqlite()` - 订阅机制
- `test_rebuild_sqlite_from_loro()` - 重建功能
- `test_eventual_consistency()` - 一致性保证
- `test_loro_document_cache()` - 文档缓存
- `test_sqlite_configuration()` - SQLite 配置
- `test_retry_mechanism()` - 重试机制
- `test_transaction_atomicity()` - 事务原子性

**集成测试**:
- `test_end_to_end_write_read_flow()` - 端到端写读流程
- `test_sqlite_corruption_recovery()` - SQLite 损坏恢复
- `test_concurrent_writes()` - 并发写入
- `test_performance_benchmarks()` - 性能基准测试

**验收标准**:
- [x] 所有单元测试通过
- [x] 集成测试通过
- [x] 1000 张卡片的读取性能 < 10ms
- [x] 每张卡片的写入性能 < 50ms
- [x] 10000 张卡片的 SQLite 重建在 5 秒内完成
- [x] 订阅回调延迟 < 100ms
- [x] 代码审查通过
