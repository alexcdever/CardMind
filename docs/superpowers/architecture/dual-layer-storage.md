# 双层存储架构行为指南

## 🎯 核心思想：读写分离，各司其职

CardMind采用一种聪明的双层存储设计：
- **写入层（Loro CRDT）**：专门负责保存数据变更，确保多设备同步时不会冲突
- **读取层（SQLite）**：专门负责快速查询，支持搜索和排序功能

就像图书馆有**藏书库**（写入层）和**阅览室**（读取层）一样，两个空间分工合作，提供最佳体验。

## 📋 架构行为

### 数据写入行为
当用户创建或修改笔记时：

**立即发生的事情**：
```
用户操作 → 写入Loro CRDT → 生成唯一变更记录 → 触发订阅更新
```

**为什么这样做**：
- Loro CRDT会记录每一次变更，就像记账一样详细
- 这些记录可以在不同设备间安全地合并，不会冲突
- 即使网络断开，数据也安全保存在本地文件中

**开发者视角**：
```rust
// 用户创建笔记时
fn create_card(title: String, content: String) -> Result<Card, Error> {
    // 1. 生成基于时间戳的UUID v7
    let card_id = Uuid::new_v7();
    
    // 2. 写入Loro文档（源数据层）
    let card_doc = LoroDoc::new();
    card_doc.get_map("cards").insert(&card_id.to_string(), json!({
        "title": title,
        "content": content,
        "created_at": timestamp(),
        "updated_at": timestamp()
    }));
    
    // 3. 提交变更（这会触发订阅回调）
    card_doc.commit();
    
    Ok(Card { id: card_id, title, content })
}
```

### 数据读取行为
当用户查看笔记列表或搜索时：

**快速响应过程**：
```
用户查询 → SQLite快速响应 → 毫秒级返回结果
```

**背后的同步机制**：
```
Loro变更 → 订阅回调 → 更新SQLite → 保持数据一致
```

**性能表现**：
- 查询1000张笔记：< 10毫秒
- 全文搜索：< 100毫秒  
- 单张笔记查找：< 1毫秒

**实现代码**：
```rust
// 订阅机制保持同步
fn setup_subscription(loro_doc: &LoroDoc, sqlite_pool: &SqlitePool) {
    loro_doc.subscribe(move |event| {
        match event {
            LoroEvent::Insert { path, value } => {
                // 有新增数据，更新SQLite
                sqlite_pool.execute(
                    "INSERT INTO cards (id, title, content, updated_at) VALUES (?, ?, ?, ?)",
                    &[&path, &value["title"], &value["content"], &timestamp()]
                ).unwrap();
            },
            LoroEvent::Update { path, value } => {
                // 有更新数据，同步到SQLite
                sqlite_pool.execute(
                    "UPDATE cards SET title = ?, content = ?, updated_at = ? WHERE id = ?",
                    &[&value["title"], &value["content"], &timestamp(), &path]
                ).unwrap();
            }
        }
    });
}
```

### 离线使用行为
当设备没有网络连接时：

**用户无感知**：
- 所有操作都像在线一样正常工作
- 数据变更保存在本地的Loro文件中
- SQLite缓存继续提供快速查询

**重新连网后**：
```
网络恢复 → 自动发现其他设备 → 交换变更记录 → 自动合并数据
```

**冲突处理**：
- 如果同一笔记在不同设备上被修改，CRDT会自动合并
- 用户的修改不会丢失，系统会保留所有变更的历史
- 最终所有设备都会达到一致的状态

## 💡 实现架构详解

### 存储层架构
```
┌─────────────────────────────────────────┐
│         应用层（UI/业务逻辑）             │
└─────────────────────────────────────────┘
           │                    │
           │ 写入操作             │ 读取操作
           ▼                    ▼
┌──────────────────┐  ┌──────────────────┐
│   写入层          │  │   读取层          │
│   Loro CRDT      │  │   SQLite         │
│                  │  │                  │
│ • 数据的真实来源   │  │ • 查询缓存        │
│ • P2P同步能力     │  │ • 快速读取        │
│ • 无冲突合并      │  │ • 搜索排序        │
└──────────────────┘  └──────────────────┘
           │                    ▲
           │ 订阅自动更新         │
           └────────────────────┘
```

### 为什么选择这种架构？

**1. 性能优化**：
- 写入操作：虽然Loro稍慢（~50ms），但可以接受，因为不是频繁操作
- 读取操作：SQLite极快（<10ms），用户体验流畅
- 搜索功能：SQLite的FTS5提供专业的全文搜索能力

**2. 可靠性保证**：
- Loro文件是"金标准"，即使SQLite损坏也能重建
- 双层保险，数据永不丢失
- 支持从任意一层恢复整个系统状态

**3. 同步简化**：
- 只需要同步Loro层的变更记录
- SQLite层可以自动重建，减少同步数据量
- 支持增量同步，只传改变的部分

## 🧪 技术实现细节

### Loro文档结构
```rust
// 每个笔记空间的Loro文档结构
{
  "space_info": {
    "id": "space_uuid",
    "name": "我的工作笔记",
    "created_at": "2026-01-20T10:00:00Z"
  },
  "cards": {
    "card_uuid_1": {
      "title": "项目想法",
      "content": "# 新项目\n一些详细内容...",
      "created_at": "2026-01-20T10:30:00Z",
      "updated_at": "2026-01-20T14:20:00Z"
    },
    "card_uuid_2": { ... }
  },
  "sync_state": {
    "last_sync": "2026-01-20T15:00:00Z",
    "peers": ["device_1", "device_2"]
  }
}
```

### SQLite表结构
```sql
-- 主表：快速查询
CREATE TABLE cards (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    space_id TEXT NOT NULL
);

-- 全文搜索虚拟表
CREATE VIRTUAL TABLE cards_fts USING fts5(
    title, 
    content,
    content='cards',
    content_rowid='id'
);

-- 触发器：自动维护FTS索引
CREATE TRIGGER cards_fts_insert AFTER INSERT ON cards BEGIN
    INSERT INTO cards_fts(rowid, title, content) 
    VALUES (new.id, new.title, new.content);
END;
```

### 错误处理行为
```rust
// 优雅的降级处理
fn handle_storage_error(error: StorageError) -> Result<(), UserFriendlyError> {
    match error {
        StorageError::LoroCorrupted => {
            // 尝试从SQLite恢复
            restore_from_sqlite()?;
            log::warn!("Loro文档损坏，已从SQLite恢复");
            Ok(())
        },
        StorageError::SQLiteCorrupted => {
            // 重建SQLite缓存
            rebuild_sqlite_cache()?;
            log::warn!("SQLite缓存损坏，已重建");
            Ok(())
        },
        _ => Err(UserFriendlyError::StorageUnavailable)
    }
}
```

## 🔗 相关行为

- **[单池模型行为](single-pool.md)** - 数据如何组织到空间中
- **[同步行为](sync-behavior.md)** - 数据如何在设备间同步
- **[密码安全行为](password-security.md)** - 空间数据如何加密保护

## 💬 设计哲学

**为什么不用单一存储？**

我们发现单一存储方案都有明显短板：
- **纯SQLite**：无法处理多设备同步冲突
- **纯Loro**：查询性能差，不支持复杂搜索
- **混合但紧耦合**：逻辑复杂，容易出错

**双层分离的优势：**

1. **关注点分离**：写入和读取各自优化
2. **故障隔离**：一层出问题不影响另一层
3. **技术选型自由**：每层选择最适合的技术
4. **渐进式升级**：可以单独改进某一层

这种架构让CardMind既有了学术级CRDT的可靠性，又有了产品级SQLite的性能，是理论与实践的完美结合。