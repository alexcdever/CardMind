# CardStore 架构规格

**状态**: 活跃
**依赖**: [../../domain/card/rules.md](../../domain/card/rules.md), [../../domain/pool/model.md](../../domain/pool/model.md), [./device_config.md](./device_config.md)
**相关测试**: `rust/tests/card_store_test.rs`

---

## 概述

本规格定义了单池架构下 CardStore 的技术实现，包括双层存储架构（Loro + SQLite）、订阅驱动的同步机制和数据管理操作。

**架构模式**:
- **写入层**: Loro CRDT 文档（数据源）
- **读取层**: SQLite 缓存（优化查询）
- **同步机制**: 订阅驱动更新

---

## 需求：Loro 文档管理

系统应使用 Loro CRDT 文档作为数据源管理卡片数据。

### 场景：为新卡片创建 Loro 文档

- **前置条件**: 需要创建新卡片
- **操作**: 调用 CardStore.create_card()
- **预期结果**: 应创建新的 Loro 文档
- **并且**: 文档应持久化到 `data/loro/<card_id>/snapshot.loro`

**实现逻辑**:

```
function create_card(title, content):
    // 步骤1：在 Loro CRDT 层创建卡片
    // 设计决策：生成 UUID v7 以支持时间排序
    card_id = generate_uuid_v7()
    card = create_card_in_loro(card_id, title, content)

    // 步骤2：从设备配置获取当前池
    // 注意：如果设备未加入任何池则失败
    device_config = load_device_config()
    if device_config.pool_id is null:
        return error "NOT_JOINED_POOL"

    pool_id = device_config.pool_id

    // 步骤3：将卡片添加到池的卡片列表
    // 设计决策：池拥有卡片列表，而非卡片自身
    pool = load_pool(pool_id)
    pool.add_card(card_id)
    pool.commit()  // 触发订阅回调

    // 步骤4：订阅自动更新 SQLite
    // 注意：on_pool_updated() 回调处理 SQLite 同步

    return card

function create_card_in_loro(card_id, title, content):
    // 为卡片创建 CRDT 文档
    crdt_doc = create_crdt_document()

    // 在 CRDT 映射结构中设置卡片字段
    // 设计决策：使用映射实现字段级冲突解决
    crdt_doc.set_field("id", card_id)
    crdt_doc.set_field("title", title)
    crdt_doc.set_field("content", content)
    crdt_doc.set_field("created_at", current_timestamp())
    crdt_doc.set_field("updated_at", current_timestamp())
    crdt_doc.set_field("deleted", false)

    // 持久化到文件系统
    // 文件路径：data/loro/<card_id>/snapshot.loro
    create_directory("data/loro/" + card_id)
    save_crdt_snapshot(crdt_doc, "data/loro/" + card_id + "/snapshot.loro")

    // 缓存到内存以提升性能
    memory_cache.store(card_id, crdt_doc)

    return card
```

### 场景：从磁盘加载 Loro 文档

- **前置条件**: 卡片 ID 存在
- **操作**: 调用 CardStore.load_card()
- **预期结果**: 应从 `data/loro/<card_id>/snapshot.loro` 加载 Loro 文档
- **并且**: 文档应缓存在内存中

**实现逻辑**:

```
function load_card(card_id):
    // 步骤1：首先检查内存缓存以提升性能
    if memory_cache.contains(card_id):
        crdt_doc = memory_cache.get(card_id)
        return convert_crdt_to_card(crdt_doc)

    // 步骤2：如果不在缓存中则从磁盘加载
    // 文件路径：data/loro/<card_id>/snapshot.loro
    file_path = "data/loro/" + card_id + "/snapshot.loro"
    snapshot_bytes = read_file(file_path)

    // 步骤3：导入 CRDT 快照
    crdt_doc = create_crdt_document()
    crdt_doc.import_snapshot(snapshot_bytes)

    // 步骤4：缓存到内存以供未来访问
    memory_cache.store(card_id, crdt_doc)

    // 步骤5：将 CRDT 文档转换为 Card 结构
    return convert_crdt_to_card(crdt_doc)

function convert_crdt_to_card(crdt_doc):
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

## 需求：SQLite 缓存层

系统应维护 SQLite 缓存以优化读取查询。

### 场景：cards 表的 SQLite schema

- **前置条件**: 需要定义卡片缓存表结构
- **操作**: 设定 cards 表字段
- **预期结果**: 表包含卡片核心字段与删除标记
- **并且**: schema 片段可用于初始化表

```sql
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted INTEGER NOT NULL DEFAULT 0
);
```

### 场景：card_pool_bindings 表的 SQLite schema

- **前置条件**: 需要定义卡片与池的绑定关系表
- **操作**: 设定 card_pool_bindings 表字段
- **预期结果**: 表包含 card_id 与 pool_id 组合主键
- **并且**: schema 片段可用于初始化表

```sql
    card_id TEXT NOT NULL,
    pool_id TEXT NOT NULL,
    PRIMARY KEY (card_id, pool_id)
);
```

---

## 需求：订阅驱动的同步

系统应使用 Loro 文档订阅在 Pool 文档变更时自动更新 SQLite 缓存。

### 场景：Pool 订阅触发 SQLite 更新

- **前置条件**: Pool Loro 文档被修改
- **操作**: 调用 Pool.commit()
- **预期结果**: 应触发订阅回调
- **并且**: card_pool_bindings 表应被更新

**实现逻辑**:

```
// 当 Pool CRDT 文档变更时触发的订阅回调
// 设计决策：使用观察者模式实现自动缓存同步

function on_pool_updated(pool):
    // 步骤1：清除此池的旧绑定（幂等操作）
    // 注意：先删除后插入确保一致性
    sqlite.execute("DELETE FROM card_pool_bindings WHERE pool_id = ?", pool.pool_id)

    // 步骤2：从 Pool.card_ids 插入新绑定
    // 设计决策：池是卡片成员关系的数据源
    for each card_id in pool.card_ids:
        sqlite.execute(
            "INSERT OR REPLACE INTO card_pool_bindings VALUES (?, ?)",
            card_id, pool.pool_id
        )

    return success
```

---

## 需求：池成员管理

系统应通过修改 Pool.card_ids（而非 Card.pool_ids）管理卡片-池关系。

### 场景：添加卡片到池

- **前置条件**: 池和卡片存在
- **操作**: 调用 CardStore.add_card_to_pool()
- **预期结果**: Pool.card_ids 应包含该卡片 ID
- **并且**: SQLite bindings 表应通过订阅更新

**实现逻辑**:

```
function add_card_to_pool(card_id, pool_id):
    // 设计决策：修改 Pool CRDT，而非 Card
    // 理由：池拥有成员关系

    // 步骤1：加载池 CRDT 文档
    pool = load_pool(pool_id)

    // 步骤2：将卡片 ID 添加到池的卡片列表
    pool.add_card(card_id)

    // 步骤3：提交变更（触发订阅）
    // 注意：这会通过 on_pool_updated() 回调自动更新 SQLite
    pool.commit()

    return success
```

### 场景：从池移除卡片

- **前置条件**: 卡片已被添加到池
- **操作**: 调用 CardStore.remove_card_from_pool()
- **预期结果**: Pool.card_ids 应不再包含该卡片
- **并且**: 移除操作应通过 P2P 同步传播到所有设备

**实现逻辑**:

```
function remove_card_from_pool(card_id, pool_id):
    // 设计决策：修改 Pool CRDT 以移除卡片
    // 重要：此操作通过 P2P 同步到所有设备

    // 步骤1：加载池 CRDT 文档
    pool = load_pool(pool_id)

    // 步骤2：从池的卡片列表移除卡片 ID
    pool.remove_card(card_id)

    // 步骤3：提交变更（触发订阅和 P2P 同步）
    // 注意：订阅更新本地 SQLite
    // 注意：P2P 同步传播到池中所有设备
    pool.commit()

    return success
```

---

## 需求：退出池时的数据清理

系统应在设备退出池时清理所有本地数据。

### 场景：删除所有 Loro 文档和 SQLite 数据

- **前置条件**: 设备在 pool_A 中，有 50 张卡片
- **操作**: 调用 CardStore.leave_pool()
- **预期结果**: 所有卡片 Loro 文档应被删除
- **并且**: Pool Loro 文档应被删除
- **并且**: SQLite 应被清空

**实现逻辑**:

```
function leave_pool():
    // 离开池时完整清理所有本地数据

    // 步骤1：从设备配置获取当前池 ID
    device_config = load_device_config()
    if device_config.pool_id is null:
        return error "NOT_JOINED_POOL"

    pool_id = device_config.pool_id

    // 步骤2：获取池中所有卡片的列表
    pool = load_pool(pool_id)
    card_ids_to_delete = pool.card_ids

    // 步骤3：删除所有卡片 CRDT 文档
    for each card_id in card_ids_to_delete:
        delete_card_crdt(card_id)

    // 步骤4：删除池 CRDT 文档
    delete_pool_crdt(pool_id)

    // 步骤5：清空 SQLite 缓存
    clear_sqlite_database()

    return success

function delete_card_crdt(card_id):
    // 从内存缓存移除
    memory_cache.remove(card_id)

    // 从文件系统删除
    // 目录路径：data/loro/<card_id>/
    directory_path = "data/loro/" + card_id
    if directory_exists(directory_path):
        delete_directory_recursive(directory_path)

    return success

function clear_sqlite_database():
    // 清空所有表
    sqlite.execute("DELETE FROM cards")
    sqlite.execute("DELETE FROM card_pool_bindings")

    return success
```

---

## 补充说明

**技术栈**:
- **Rust std::fs**: 用于 Loro 文档持久化的文件系统操作

**设计模式**:
- **双层架构**: 分离写入层（Loro）和读取层（SQLite）
- **观察者模式**: 订阅驱动的 SQLite 更新
- **旁路缓存模式**: Loro 文档的内存 HashMap 缓存

**性能考虑**:
- **内存缓存**: Loro 文档缓存在 HashMap 中以避免重复磁盘 I/O
- **SQLite 索引**: 在 updated_at、deleted、pool_id、card_id 上建立索引以加快查询
- **批量操作**: 使用 SQLite 事务进行批量更新
- **延迟加载**: Loro 文档按需加载，而非启动时全部加载

**安全考虑**:
- **文件权限**: Loro 文档以仅用户读写权限存储
- **SQLite 加密**: 考虑使用 SQLite 加密扩展保护敏感数据
- **输入验证**: 验证 card_id 和 pool_id 以防止路径遍历

---

## 相关文档

**领域规格**:
- [../../domain/card/rules.md](../../domain/card/rules.md) - 卡片业务规则
- [../../domain/pool/model.md](../../domain/pool/model.md) - 池领域模型

**相关架构规格**:
- [./device_config.md](./device_config.md) - 设备配置存储
- [./pool_store.md](./pool_store.md) - PoolStore 实现
- [../sync/service.md](../sync/service.md) - P2P 同步服务

**架构决策记录**:
- [../../../docs/adr/0002-dual-layer-architecture.md](../../../docs/adr/0002-dual-layer-architecture.md) - 双层架构
- [../../../docs/adr/0003-loro-crdt.md](../../../docs/adr/0003-loro-crdt.md) - Loro CRDT 用于无冲突同步

---

## 测试覆盖

**测试文件**: `rust/tests/card_store_test.rs`

**单元测试**:
- `it_creates_card_and_auto_adds_to_current_pool()` - 创建卡片自动加入池
- `it_should_fail_when_device_not_joined()` - 未加入时失败
- `it_should_trigger_subscription_to_update_bindings()` - 触发订阅
- `it_should_modify_pool_card_ids_on_add()` - 添加卡片到池
- `it_should_be_idempotent()` - 幂等添加
- `it_should_remove_card_from_pool_card_ids()` - 移除卡片
- `it_should_propagate_removal_to_all_devices()` - 传播移除
- `it_should_clean_up_all_data_when_leaving_pool()` - 退出池清理
- `it_should_update_bindings_on_pool_change()` - 更新绑定
- `it_should_clear_old_bindings_when_pool_changes()` - 清除旧绑定

**集成测试**:
- 创建卡片自动加入当前池
- 移除操作跨设备传播
- 退出池完整流程

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 集成测试通过
- [ ] 性能基准满足要求
- [ ] 代码审查通过
- [ ] 文档已更新
