# 双层存储架构规格

**版本**: 1.0.0

**状态**: 活跃

**依赖**: [./card_store.md](./card_store.md), [../../domain/card/model.md](../../domain/card/model.md)

**相关测试**: `rust/tests/dual_layer_test.rs`

---

## 概述

本规格定义了双层存储架构，将写操作（Loro CRDT）与读操作（SQLite 缓存）分离，在保持查询性能的同时实现无冲突同步。

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

### 场景：卡片的 Loro 文档结构

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

### 场景：池的 Loro 文档结构

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

### 场景：SQLite schema 设计

**卡片表**:

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

**卡片-池绑定表**:

```sql
    card_id TEXT NOT NULL,
    pool_id TEXT NOT NULL,
    PRIMARY KEY (card_id, pool_id)
);

-- 关系查询的索引
```

**池表**:

```sql
    pool_id TEXT PRIMARY KEY,
    pool_name TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);
```

### 场景：查询优化示例

**示例 1：获取当前池中的所有卡片**

```sql
-- 使用索引的快速查询
  AND c.deleted = 0
```

**示例 2：按标题搜索卡片**

```sql
-- 全文搜索（可使用 FTS5 优化）
  AND c.deleted = 0
  AND c.title LIKE ?
```

---

## 需求：订阅驱动的同步

系统应使用 Loro 文档订阅自动将变更从写入层传播到读取层。

### 场景：池更新触发 SQLite 更新

- **前置条件**: Pool Loro 文档被修改
- **操作**: 调用 Pool.commit()
- **预期结果**: 应触发订阅回调
- **并且**: card_pool_bindings 表应被更新
- **并且**: 更新应是幂等的

**实现**:

```
//
// 触发时机：调用 Pool.commit()
//
// 职责：同步 Pool.card_ids 到 card_pool_bindings 表

function on_pool_updated(pool):
    // 步骤1：获取 SQLite 连接
    sqlite = get_sqlite_connection()

    // 步骤2：清除该池的旧绑定（确保幂等性）
    // 设计决策：先删除后插入模式确保一致性
    delete_bindings_for_pool(sqlite, pool.pool_id)

    // 步骤3：从当前池状态插入新绑定
    for each card_id in pool.card_ids:
        insert_binding(sqlite, card_id, pool.pool_id)

    return success
```

### 场景：卡片更新触发 SQLite 更新

- **前置条件**: Card Loro 文档被修改
- **操作**: 调用 Card.commit()
- **预期结果**: 应触发订阅回调
- **并且**: cards 表应被更新

**实现**:

```

function on_card_updated(card):
    // 步骤1：获取 SQLite 连接
    sqlite = get_sqlite_connection()

    // 步骤2：将卡片数据更新插入到 SQLite 缓存
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

**错误处理**:

```
// 带错误处理的订阅回调

function on_pool_updated_safe(pool):
    // 尝试更新 SQLite 缓存
    result = on_pool_updated(pool)

    if result is success:
        // 记录成功更新
        log_debug("SQLite updated for pool", pool.pool_id)
    else:
        // 记录错误并加入重试队列
        // 设计决策：使用重试队列确保最终一致性
        log_error("Failed to update SQLite for pool", pool.pool_id, result.error)
        add_to_retry_queue(UpdatePoolTask(pool))
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

**实现**:

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
    clear_table(sqlite, "cards")
    clear_table(sqlite, "card_pool_bindings")
    clear_table(sqlite, "pools")

    // 步骤3：扫描 Loro 文档目录
    loro_directory = "data/loro"
    for each subdirectory in loro_directory:
        snapshot_file = subdirectory + "/snapshot.loro"

        if snapshot_file exists:
            // 步骤4：加载 Loro 文档快照
            loro_doc = load_loro_snapshot(snapshot_file)

            // 步骤5：解析文档并更新 SQLite
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

## 需求：性能优化

系统应为每层的特定用例优化性能。

### 场景：写性能 - Loro

**优化**:
- **内存缓存**: 将频繁访问的 Loro 文档保存在内存中
- **延迟持久化**: 批量写入磁盘
- **增量快照**: 仅保存变更的文档

### 场景：读性能 - SQLite

**优化**:
- **索引**: 在频繁查询的列上创建索引
- **查询规划**: 使用 EXPLAIN QUERY PLAN 优化查询
- **连接池**: 复用 SQLite 连接
- **WAL 模式**: 启用预写日志以提高并发性


```
// 配置 SQLite 以获得最佳性能

function configure_sqlite(connection):
    // 步骤1：启用 WAL 模式以提高并发性
    // 设计决策：WAL 允许写入时并发读取
    set_journal_mode(connection, "WAL")

    // 步骤2：增加缓存大小以提高性能
    // 注意：10MB 缓存减少磁盘 I/O
    set_cache_size(connection, 10_megabytes)

    // 步骤3：设置同步模式以保证持久性
    // 设计决策：NORMAL 平衡性能和安全性
    set_synchronous_mode(connection, "NORMAL")

    // 步骤4：启用外键约束
    enable_foreign_keys(connection)

    return success
```

---

## 实现细节

**技术栈**:

**设计模式**:
- **CQRS（命令查询职责分离）**: 分离写入和读取模型
- **观察者模式**: 订阅驱动更新
- **旁路缓存模式**: SQLite 作为 Loro 的缓存

**权衡**:
- **优点**: 无冲突同步、快速读取、最终一致性
- **缺点**: 最终一致性（非即时）、存储开销（两份副本）

---

## 测试覆盖

**测试文件**: `rust/tests/dual_layer_test.rs`

**单元测试**:
- `test_write_to_loro_updates_sqlite()` - 写入传播
- `test_read_from_sqlite_not_loro()` - 从缓存读取
- `test_subscription_callback_updates_sqlite()` - 订阅机制
- `test_rebuild_sqlite_from_loro()` - 重建功能
- `test_eventual_consistency()` - 一致性保证

**集成测试**:
- 端到端写读流程
- SQLite 损坏恢复
- 性能基准测试

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 集成测试通过
- [ ] 1000 张卡片的读取性能 < 10ms
- [ ] 每张卡片的写入性能 < 50ms
- [ ] 10000 张卡片的 SQLite 重建在 5 秒内完成

---

## 相关文档

**架构规格**:
- [./card_store.md](./card_store.md) - CardStore 实现
- [./pool_store.md](./pool_store.md) - PoolStore 实现
- [./sqlite_cache.md](./sqlite_cache.md) - SQLite 缓存细节
- [./loro_integration.md](./loro_integration.md) - Loro 集成

**领域规格**:
- [../../domain/card/model.md](../../domain/card/model.md) - 卡片领域模型
- [../../domain/pool/model.md](../../domain/pool/model.md) - 池领域模型

**架构决策记录**:
- [../../../docs/adr/0002-dual-layer-architecture.md](../../../docs/adr/0002-dual-layer-architecture.md) - 双层架构决策
- [../../../docs/adr/0003-loro-crdt.md](../../../docs/adr/0003-loro-crdt.md) - Loro CRDT 选择

---

**最后更新**: 2026-01-23
**作者**: CardMind Team
