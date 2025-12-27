# CardMind 数据库设计文档

## 1. 数据架构总览

CardMind采用**双层数据架构**：

```
┌─────────────────────────────────────────┐
│         Loro CRDT (主数据源)            │
│  - 所有写操作                            │
│  - 文件持久化                            │
│  - CRDT冲突解决                         │
│  - P2P同步                              │
└──────────────┬──────────────────────────┘
               │ 订阅机制
               ↓
┌──────────────▼──────────────────────────┐
│       SQLite (查询缓存层)                │
│  - 只读缓存                              │
│  - 快速查询                              │
│  - 全文搜索                              │
│  - 列表展示                              │
└─────────────────────────────────────────┘
```

**核心原则**:
- **Loro是真理源（Source of Truth）**: 所有数据修改只通过Loro
- **SQLite是缓存**: 数据通过Loro订阅机制自动同步
- **SQLite只读**: 应用层不直接写入SQLite

## 2. Loro CRDT数据结构

### 2.1 每卡片一LoroDoc架构

**重要**: 每个卡片维护独立的LoroDoc，而不是所有卡片共享一个大LoroDoc。

**单个卡片的Loro文档结构**:
```rust
// 每个卡片有自己的LoroDoc
{
  "card": LoroMap {
    "id": "<uuid-v7>",
    "title": "卡片标题",
    "content": "Markdown内容",
    "created_at": 1234567890000,
    "updated_at": 1234567890000,
    "is_deleted": false  // 软删除标记
  }
}
```

### 2.2 Loro文件组织和持久化

**文件目录结构**:
```
应用数据目录/
└── data/
    └── loro/
        ├── <base64(uuid-1)>/
        │   ├── snapshot.loro    # 完整快照
        │   └── update.loro      # 增量更新（追加写入）
        ├── <base64(uuid-2)>/
        │   ├── snapshot.loro
        │   └── update.loro
        └── ...
```

**更新策略**:
```rust
// 追加更新到update.loro
pub fn append_update(card_id: &str, doc: &LoroDoc) -> Result<()> {
    let update_path = get_update_path(card_id);
    let updates = doc.export_updates_since_last_save()?;

    let mut file = OpenOptions::new()
        .create(true)
        .append(true)  // 追加模式
        .open(&update_path)?;

    file.write_all(&updates)?;

    // 检查是否需要合并
    let size = std::fs::metadata(&update_path)?.len();
    if size > 1024 * 1024 {  // 1MB阈值
        merge_snapshot_and_updates(card_id, doc)?;
    }

    Ok(())
}

// 合并快照和更新
pub fn merge_snapshot_and_updates(card_id: &str, doc: &LoroDoc) -> Result<()> {
    let snapshot_path = get_snapshot_path(card_id);
    let update_path = get_update_path(card_id);

    // 导出完整快照
    let snapshot = doc.export_snapshot();
    std::fs::write(&snapshot_path, snapshot)?;

    // 清空update.loro
    std::fs::write(&update_path, &[])?;

    Ok(())
}

// 加载卡片Loro文档
pub fn load_card_doc(card_id: &str) -> Result<LoroDoc> {
    let snapshot_path = get_snapshot_path(card_id);
    let update_path = get_update_path(card_id);

    let doc = LoroDoc::new();

    // 1. 加载快照
    if snapshot_path.exists() {
        let snapshot_data = std::fs::read(&snapshot_path)?;
        doc.import(&snapshot_data)?;
    }

    // 2. 应用增量更新
    if update_path.exists() {
        let update_data = std::fs::read(&update_path)?;
        if !update_data.is_empty() {
            doc.import(&update_data)?;
        }
    }

    Ok(doc)
}
```

### 2.3 为什么选择每卡片一LoroDoc

- ✅ **隔离性好**: 每个卡片的版本历史独立，互不影响
- ✅ **性能优秀**: 小文档加载和操作速度快
- ✅ **P2P友好**: 可以按需同步单个卡片，减少流量
- ✅ **灵活性高**: 便于实现卡片级别的权限控制
- ✅ **文件管理简单**: 删除卡片只需删除对应目录
- ✅ **性能优秀**: Rust实现，零开销

## 3. SQLite缓存层设计

### 3.1 为什么需要SQLite

虽然Loro是主数据源，但SQLite提供以下优势：

- ✅ **快速查询**: SQL索引优化，列表查询毫秒级
- ✅ **全文搜索**: FTS5支持，搜索体验好
- ✅ **排序分页**: SQL原生支持，实现简单
- ✅ **熟悉度高**: 开发者熟悉SQL语法

### 3.2 SQLite表结构

#### 3.2.1 cards表（MVP阶段，支持软删除）

```sql
CREATE TABLE IF NOT EXISTS cards (
    id TEXT PRIMARY KEY NOT NULL,
    title TEXT,
    content TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    is_deleted INTEGER DEFAULT 0 NOT NULL  -- 软删除标记（0=未删除，1=已删除）
);

-- 索引（优先查询未删除的卡片）
CREATE INDEX IF NOT EXISTS idx_cards_not_deleted_created
    ON cards(is_deleted, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_cards_not_deleted_updated
    ON cards(is_deleted, updated_at DESC);
```

**字段说明**:
- `id`: UUID v7字符串，主键
- `title`: 卡片标题（可选）
- `content`: Markdown内容
- `created_at`: 创建时间（Unix毫秒时间戳）
- `updated_at`: 更新时间（Unix毫秒时间戳）
- `is_deleted`: 软删除标记（0=未删除，1=已删除）

**软删除机制**:
- 所有查询默认只查询 `is_deleted = 0`（未删除）的卡片
- 删除操作只更新标记为 `is_deleted = 1`，不真正删除数据
- 支持回收站功能（查询 `is_deleted = 1` 的已删除卡片）
- 支持恢复功能（将 `is_deleted` 从 1 改回 0）

#### 3.2.2 全文搜索表（Phase 3）

```sql
-- FTS5虚拟表用于全文搜索（仅搜索未删除的卡片）
CREATE VIRTUAL TABLE IF NOT EXISTS cards_fts USING fts5(
    title,
    content,
    content='cards',
    content_rowid='rowid'
);

-- 触发器：自动同步cards表到FTS表
CREATE TRIGGER IF NOT EXISTS cards_ai AFTER INSERT ON cards BEGIN
    INSERT INTO cards_fts(rowid, title, content)
    VALUES (new.rowid, new.title, new.content);
END;

CREATE TRIGGER IF NOT EXISTS cards_au AFTER UPDATE ON cards BEGIN
    UPDATE cards_fts
    SET title = new.title, content = new.content
    WHERE rowid = old.rowid;
END;

CREATE TRIGGER IF NOT EXISTS cards_ad AFTER DELETE ON cards BEGIN
    DELETE FROM cards_fts WHERE rowid = old.rowid;
END;
```

## 4. Loro到SQLite同步机制

### 4.1 订阅机制实现

```rust
use loro::{LoroDoc, LoroEvent, SubscribeOptions};
use rusqlite::{Connection, params};

pub struct CardStore {
    loro_doc: LoroDoc,
    sqlite_conn: Connection,
}

impl CardStore {
    pub fn new(loro_path: &Path, sqlite_path: &Path) -> Result<Self> {
        let loro_doc = load_loro_doc(loro_path)?;
        let sqlite_conn = Connection::open(sqlite_path)?;

        // 初始化SQLite
        init_sqlite(&sqlite_conn)?;

        let mut store = Self { loro_doc, sqlite_conn };

        // 设置订阅
        store.setup_subscription()?;

        // 首次同步：将Loro中的所有数据同步到SQLite
        store.full_sync_to_sqlite()?;

        Ok(store)
    }

    fn setup_subscription(&mut self) -> Result<()> {
        let conn_clone = // ... 获取连接的clone或Arc

        self.loro_doc.subscribe(
            &SubscribeOptions::default(),
            move |event: &LoroEvent| {
                if let Err(e) = handle_loro_event(&conn_clone, event) {
                    tracing::error!("Failed to sync Loro event to SQLite: {}", e);
                }
            }
        );

        Ok(())
    }

    // 首次全量同步
    fn full_sync_to_sqlite(&self) -> Result<()> {
        let cards_map = self.loro_doc.get_map("cards");

        for (id, card_value) in cards_map.iter() {
            let card = card_value.as_map()?;
            sync_card_to_sqlite(&self.sqlite_conn, id, card)?;
        }

        Ok(())
    }
}
```

### 4.2 事件处理

```rust
fn handle_loro_event(conn: &Connection, event: &LoroEvent) -> Result<()> {
    // 解析Loro事件，更新SQLite
    for diff in &event.diffs {
        match diff {
            Diff::Map(map_diff) => {
                for (key, value_diff) in map_diff {
                    match value_diff {
                        ValueDiff::Create(value) => {
                            // 新建卡片
                            insert_card_to_sqlite(conn, key, value)?;
                        }
                        ValueDiff::Update(value) => {
                            // 更新卡片
                            update_card_in_sqlite(conn, key, value)?;
                        }
                        ValueDiff::Delete => {
                            // 删除卡片
                            delete_card_from_sqlite(conn, key)?;
                        }
                    }
                }
            }
            _ => {}
        }
    }
    Ok(())
}

fn insert_card_to_sqlite(conn: &Connection, id: &str, card: &LoroMap) -> Result<()> {
    conn.execute(
        "INSERT OR REPLACE INTO cards (id, title, content, created_at, updated_at)
         VALUES (?1, ?2, ?3, ?4, ?5)",
        params![
            id,
            card.get("title")?.as_str()?,
            card.get("content")?.as_str()?,
            card.get("created_at")?.as_i64()?,
            card.get("updated_at")?.as_i64()?,
        ],
    )?;
    Ok(())
}

fn update_card_in_sqlite(conn: &Connection, id: &str, card: &LoroMap) -> Result<()> {
    conn.execute(
        "UPDATE cards SET title = ?1, content = ?2, updated_at = ?3 WHERE id = ?4",
        params![
            card.get("title")?.as_str()?,
            card.get("content")?.as_str()?,
            card.get("updated_at")?.as_i64()?,
            id,
        ],
    )?;
    Ok(())
}

fn delete_card_from_sqlite(conn: &Connection, id: &str) -> Result<()> {
    conn.execute("DELETE FROM cards WHERE id = ?1", params![id])?;
    Ok(())
}
```

## 5. 数据操作模式

### 5.1 写操作（通过Loro）

```rust
impl CardStore {
    // 创建卡片
    pub fn create_card(&mut self, title: &str, content: &str) -> Result<Card> {
        let cards = self.loro_doc.get_map("cards");

        let id = Uuid::now_v7().to_string();
        let now = Utc::now().timestamp_millis();

        // 写入Loro
        let card_map = cards.insert_container(&id, LoroMap::new())?;
        card_map.insert("id", id.clone())?;
        card_map.insert("title", title)?;
        card_map.insert("content", content)?;
        card_map.insert("created_at", now)?;
        card_map.insert("updated_at", now)?;

        // commit触发订阅，自动同步到SQLite
        self.loro_doc.commit();

        // 持久化Loro文档
        self.save_loro()?;

        Ok(Card {
            id,
            title: title.to_string(),
            content: content.to_string(),
            created_at: now,
            updated_at: now,
        })
    }

    // 更新卡片
    pub fn update_card(&mut self, id: &str, title: &str, content: &str) -> Result<()> {
        let cards = self.loro_doc.get_map("cards");
        let card = cards.get(id)?.as_map()?;

        // 修改Loro
        card.insert("title", title)?;
        card.insert("content", content)?;
        card.insert("updated_at", Utc::now().timestamp_millis())?;

        // commit触发订阅
        self.loro_doc.commit();
        self.save_loro()?;

        Ok(())
    }

    // 删除卡片
    pub fn delete_card(&mut self, id: &str) -> Result<()> {
        let cards = self.loro_doc.get_map("cards");
        cards.delete(id)?;

        // commit触发订阅
        self.loro_doc.commit();
        self.save_loro()?;

        Ok(())
    }
}
```

### 5.2 读操作（从SQLite）

```rust
impl CardStore {
    // 获取所有卡片（从SQLite读取，快速）
    pub fn get_all_cards(&self) -> Result<Vec<Card>> {
        let mut stmt = self.sqlite_conn.prepare(
            "SELECT id, title, content, created_at, updated_at
             FROM cards
             ORDER BY created_at DESC"
        )?;

        let cards = stmt.query_map([], |row| {
            Ok(Card {
                id: row.get(0)?,
                title: row.get(1)?,
                content: row.get(2)?,
                created_at: row.get(3)?,
                updated_at: row.get(4)?,
            })
        })?
        .collect::<Result<Vec<_>, _>>()?;

        Ok(cards)
    }

    // 获取单个卡片
    pub fn get_card(&self, id: &str) -> Result<Option<Card>> {
        let mut stmt = self.sqlite_conn.prepare(
            "SELECT id, title, content, created_at, updated_at
             FROM cards
             WHERE id = ?1"
        )?;

        let card = stmt.query_row([id], |row| {
            Ok(Card {
                id: row.get(0)?,
                title: row.get(1)?,
                content: row.get(2)?,
                created_at: row.get(3)?,
                updated_at: row.get(4)?,
            })
        }).optional()?;

        Ok(card)
    }

    // 分页查询
    pub fn get_cards_paginated(&self, offset: usize, limit: usize) -> Result<Vec<Card>> {
        let mut stmt = self.sqlite_conn.prepare(
            "SELECT id, title, content, created_at, updated_at
             FROM cards
             ORDER BY created_at DESC
             LIMIT ?1 OFFSET ?2"
        )?;

        let cards = stmt.query_map([limit, offset], |row| {
            Ok(Card {
                id: row.get(0)?,
                title: row.get(1)?,
                content: row.get(2)?,
                created_at: row.get(3)?,
                updated_at: row.get(4)?,
            })
        })?
        .collect::<Result<Vec<_>, _>>()?;

        Ok(cards)
    }

    // 搜索卡片（Phase 3）
    pub fn search_cards(&self, keyword: &str) -> Result<Vec<Card>> {
        let mut stmt = self.sqlite_conn.prepare(
            "SELECT c.id, c.title, c.content, c.created_at, c.updated_at
             FROM cards c
             JOIN cards_fts fts ON c.rowid = fts.rowid
             WHERE cards_fts MATCH ?1
             ORDER BY rank"
        )?;

        let cards = stmt.query_map([keyword], |row| {
            Ok(Card {
                id: row.get(0)?,
                title: row.get(1)?,
                content: row.get(2)?,
                created_at: row.get(3)?,
                updated_at: row.get(4)?,
            })
        })?
        .collect::<Result<Vec<_>, _>>()?;

        Ok(cards)
    }
}
```

## 6. SQLite优化配置

### 6.1 PRAGMA设置

```rust
pub fn init_sqlite(conn: &Connection) -> Result<()> {
    // 创建表
    conn.execute_batch(
        "
        CREATE TABLE IF NOT EXISTS cards (
            id TEXT PRIMARY KEY NOT NULL,
            title TEXT,
            content TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
        );

        CREATE INDEX IF NOT EXISTS idx_cards_created_at ON cards(created_at DESC);
        CREATE INDEX IF NOT EXISTS idx_cards_updated_at ON cards(updated_at DESC);

        -- 性能优化PRAGMA
        PRAGMA journal_mode = WAL;           -- 提高并发性能
        PRAGMA synchronous = NORMAL;         -- 平衡性能和安全
        PRAGMA cache_size = -32000;          -- 32MB缓存
        PRAGMA temp_store = MEMORY;          -- 临时表在内存
        PRAGMA mmap_size = 30000000000;      -- 使用内存映射
        PRAGMA page_size = 4096;             -- 页大小
        "
    )?;

    Ok(())
}
```

### 6.2 索引策略

**当前索引**:
- `id` (主键) - 自动索引
- `created_at` - 按创建时间排序
- `updated_at` - 按更新时间排序

**未来扩展**:
- 全文搜索索引（FTS5）
- 标签索引（如果添加标签功能）

## 7. 数据一致性保证

### 7.1 数据同步流程

```
用户操作 → Loro修改 → commit
                         ↓
                   触发订阅回调
                         ↓
                   更新SQLite
                         ↓
                   持久化Loro到文件
```

### 7.2 异常处理

**SQLite同步失败处理**:
```rust
fn handle_loro_event(conn: &Connection, event: &LoroEvent) -> Result<()> {
    // 使用事务保证原子性
    let tx = conn.transaction()?;

    for diff in &event.diffs {
        match sync_diff_to_sqlite(&tx, diff) {
            Ok(_) => {}
            Err(e) => {
                tracing::error!("Sync failed: {}", e);
                tx.rollback()?;
                return Err(e);
            }
        }
    }

    tx.commit()?;
    Ok(())
}
```

**SQLite损坏恢复**:
```rust
pub fn rebuild_sqlite_from_loro(store: &CardStore) -> Result<()> {
    // 1. 删除旧的SQLite数据库
    drop(store.sqlite_conn);
    std::fs::remove_file(&store.sqlite_path)?;

    // 2. 重新创建数据库
    let conn = Connection::open(&store.sqlite_path)?;
    init_sqlite(&conn)?;

    // 3. 从Loro全量同步
    let cards_map = store.loro_doc.get_map("cards");
    for (id, card_value) in cards_map.iter() {
        let card = card_value.as_map()?;
        sync_card_to_sqlite(&conn, id, card)?;
    }

    Ok(())
}
```

## 8. 性能基准

### 8.1 目标性能指标

| 操作 | 目标时间 | 数据量 |
|------|---------|--------|
| 创建卡片 | < 50ms | - |
| 读取列表 | < 10ms | 1000张卡片 |
| 搜索 | < 100ms | 1000张卡片 |
| Loro同步到SQLite | < 5ms | 单条记录 |

### 8.2 性能测试

```rust
#[cfg(test)]
mod benchmarks {
    use super::*;

    #[test]
    fn bench_create_1000_cards() {
        let mut store = CardStore::new_in_memory().unwrap();
        let start = Instant::now();

        for i in 0..1000 {
            store.create_card(
                &format!("标题{}", i),
                &format!("内容{}", i)
            ).unwrap();
        }

        let duration = start.elapsed();
        println!("创建1000张卡片耗时: {:?}", duration);
        assert!(duration.as_secs() < 5); // 应该在5秒内完成
    }

    #[test]
    fn bench_query_1000_cards() {
        let store = setup_store_with_1000_cards();
        let start = Instant::now();

        let cards = store.get_all_cards().unwrap();

        let duration = start.elapsed();
        println!("查询1000张卡片耗时: {:?}", duration);
        assert!(cards.len() == 1000);
        assert!(duration.as_millis() < 100); // 应该在100ms内完成
    }
}
```

## 9. 数据文件位置

### 9.1 文件结构

```
应用数据目录/
├── loro_doc.loro          # Loro CRDT文档（主数据）
└── cache.db               # SQLite缓存数据库
```

### 9.2 备份策略

**Loro文档备份**:
```rust
pub fn backup_loro_doc(src: &Path, backup_dir: &Path) -> Result<PathBuf> {
    let timestamp = Utc::now().format("%Y%m%d_%H%M%S");
    let backup_path = backup_dir.join(format!("loro_doc_{}.loro", timestamp));

    std::fs::copy(src, &backup_path)?;
    Ok(backup_path)
}
```

**注意**: 只需要备份Loro文档即可，SQLite可以从Loro重建。

## 10. 导入导出设计

### 10.1 导出（Phase 3）

```rust
// 导出为Loro文档压缩包
pub fn export_data(loro_path: &Path, output_path: &Path) -> Result<()> {
    let mut zip = ZipWriter::new(File::create(output_path)?);

    // 1. 添加Loro文档
    let loro_data = std::fs::read(loro_path)?;
    zip.start_file("cardmind.loro", FileOptions::default())?;
    zip.write_all(&loro_data)?;

    // 2. 添加元数据（可选）
    let metadata = json!({
        "version": env!("CARGO_PKG_VERSION"),
        "exported_at": Utc::now().to_rfc3339(),
        "card_count": get_card_count()?,
    });
    zip.start_file("metadata.json", FileOptions::default())?;
    zip.write_all(metadata.to_string().as_bytes())?;

    zip.finish()?;
    Ok(())
}
```

### 10.2 导入（Phase 3）

```rust
// 从压缩包导入
pub fn import_data(zip_path: &Path, loro_path: &Path) -> Result<()> {
    let file = File::open(zip_path)?;
    let mut archive = ZipArchive::new(file)?;

    // 1. 提取Loro文档
    let mut loro_file = archive.by_name("cardmind.loro")?;
    let mut loro_data = Vec::new();
    loro_file.read_to_end(&mut loro_data)?;

    // 2. 写入Loro文档
    std::fs::write(loro_path, loro_data)?;

    // 3. 重建SQLite缓存
    rebuild_sqlite_from_loro()?;

    Ok(())
}
```

## 11. 数据版本管理和迁移

### 11.1 版本号管理

在Loro文档的元数据中存储schema版本号，用于未来的数据迁移。

**版本号方案**:
```rust
// 在每个卡片的Loro文档中存储schema版本
{
  "schema_version": 1,  // 当前版本
  "card": {
    "id": "...",
    "title": "...",
    // ...
  }
}
```

**初始化时设置版本**:
```rust
impl CardStore {
    fn create_card_with_version(&mut self, title: &str, content: &str) -> Result<Card> {
        let doc = LoroDoc::new();
        let root = doc.get_map("root");

        // 设置schema版本
        root.insert("schema_version", 1)?;

        // 设置卡片数据
        let card_map = root.insert_container("card", LoroMap::new())?;
        // ... 插入卡片字段

        Ok(card)
    }
}
```

### 11.2 迁移策略

当schema发生变更时（如添加新字段、修改数据结构），使用版本号进行迁移。

**迁移函数示例**:
```rust
pub fn migrate_card_if_needed(doc: &LoroDoc) -> Result<()> {
    let root = doc.get_map("root");
    let version = root.get("schema_version")
        .and_then(|v| v.as_i64())
        .unwrap_or(0);  // 旧版本没有version字段，默认为0

    match version {
        1 => {
            // 当前版本，无需迁移
            Ok(())
        }
        0 => {
            // 从v0升级到v1：添加is_deleted字段
            info!("迁移卡片schema: v0 -> v1");
            migrate_v0_to_v1(doc)?;
            root.insert("schema_version", 1)?;
            doc.commit();
            Ok(())
        }
        _ => {
            error!("不支持的schema版本: {}", version);
            Err(CardMindError::UnsupportedVersion(version))
        }
    }
}

fn migrate_v0_to_v1(doc: &LoroDoc) -> Result<()> {
    let root = doc.get_map("root");
    let card_map = root.get("card")?.as_map()?;

    // 添加is_deleted字段（默认为false）
    if !card_map.contains_key("is_deleted") {
        card_map.insert("is_deleted", false)?;
        info!("已添加is_deleted字段");
    }

    Ok(())
}
```

**加载卡片时自动迁移**:
```rust
impl CardStore {
    fn load_or_create_card_doc(&mut self, card_id: &str) -> Result<&mut LoroDoc> {
        if !self.loaded_cards.contains_key(card_id) {
            let card_dir = self.get_card_dir(card_id);
            let doc = load_card_doc_from_files(&card_dir)?;

            // 自动迁移
            migrate_card_if_needed(&doc)?;

            self.setup_subscription_for_card(&doc, card_id)?;
            self.loaded_cards.insert(card_id.to_string(), doc);
        }

        Ok(self.loaded_cards.get_mut(card_id).unwrap())
    }
}
```

### 11.3 SQLite schema变更

SQLite是缓存层，可以随时重建，因此schema变更相对简单。

**方案1: 删除并重建**（推荐，简单可靠）
```rust
pub fn rebuild_sqlite_cache(sqlite_path: &Path, loro_dir: &Path) -> Result<()> {
    info!("重建SQLite缓存");

    // 1. 删除旧数据库
    if sqlite_path.exists() {
        std::fs::remove_file(sqlite_path)?;
        info!("已删除旧SQLite数据库");
    }

    // 2. 创建新数据库
    let conn = Connection::open(sqlite_path)?;
    init_sqlite(&conn)?;
    info!("已创建新SQLite数据库");

    // 3. 从Loro全量同步
    full_sync_from_loro(&conn, loro_dir)?;
    info!("SQLite缓存重建完成");

    Ok(())
}

fn full_sync_from_loro(conn: &Connection, loro_dir: &Path) -> Result<()> {
    // 遍历所有Loro文档目录
    for entry in std::fs::read_dir(loro_dir)? {
        let entry = entry?;
        let card_dir = entry.path();

        if card_dir.is_dir() {
            // 加载Loro文档
            let doc = load_card_doc_from_files(&card_dir)?;

            // 迁移（如果需要）
            migrate_card_if_needed(&doc)?;

            // 同步到SQLite
            let root = doc.get_map("root");
            let card_map = root.get("card")?.as_map()?;
            sync_card_to_sqlite(conn, card_map)?;
        }
    }

    Ok(())
}
```

**方案2: ALTER TABLE（复杂场景）**
```rust
// 仅在必须保留SQLite数据时使用（通常不需要，因为可以从Loro重建）
pub fn migrate_sqlite_schema(conn: &Connection, from_version: i32, to_version: i32) -> Result<()> {
    match (from_version, to_version) {
        (1, 2) => {
            // 添加新列
            conn.execute(
                "ALTER TABLE cards ADD COLUMN new_field TEXT DEFAULT ''",
                [],
            )?;
        }
        _ => {
            return Err(CardMindError::UnsupportedMigration(from_version, to_version));
        }
    }
    Ok(())
}
```

### 11.4 应用启动时的迁移检查

在应用启动时检查并执行必要的迁移：

```rust
impl CardStore {
    pub fn new(data_dir: PathBuf, sqlite_path: &Path) -> Result<Self> {
        let sqlite_conn = Connection::open(sqlite_path)?;

        // 检查SQLite版本
        let sqlite_version = get_sqlite_schema_version(&sqlite_conn)?;
        if sqlite_version < CURRENT_SQLITE_VERSION {
            warn!("SQLite schema版本过旧: {} < {}", sqlite_version, CURRENT_SQLITE_VERSION);

            // 重建SQLite（简单可靠）
            drop(sqlite_conn);
            rebuild_sqlite_cache(sqlite_path, &data_dir.join("loro"))?;
            let sqlite_conn = Connection::open(sqlite_path)?;
        }

        Ok(Self {
            data_dir,
            loaded_cards: HashMap::new(),
            sqlite_conn,
            update_size_threshold: 1024 * 1024,
        })
    }
}

fn get_sqlite_schema_version(conn: &Connection) -> Result<i32> {
    // 可以用user_version pragma存储版本号
    let version: i32 = conn.query_row("PRAGMA user_version", [], |row| row.get(0))?;
    Ok(version)
}

fn set_sqlite_schema_version(conn: &Connection, version: i32) -> Result<()> {
    conn.execute(&format!("PRAGMA user_version = {}", version), [])?;
    Ok(())
}

fn init_sqlite(conn: &Connection) -> Result<()> {
    // 创建表
    conn.execute_batch(
        "
        CREATE TABLE IF NOT EXISTS cards (
            id TEXT PRIMARY KEY,
            title TEXT,
            content TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            is_deleted INTEGER DEFAULT 0
        );

        CREATE INDEX IF NOT EXISTS idx_cards_not_deleted_created
            ON cards(is_deleted, created_at DESC);
        "
    )?;

    // 设置schema版本
    set_sqlite_schema_version(conn, 1)?;

    Ok(())
}
```

### 11.5 迁移测试

**测试旧版本数据能否正确迁移**:
```rust
#[cfg(test)]
mod migration_tests {
    use super::*;

    #[test]
    fn test_migrate_v0_to_v1() {
        // 创建v0格式的Loro文档（没有is_deleted字段）
        let doc = LoroDoc::new();
        let root = doc.get_map("root");
        let card_map = root.insert_container("card", LoroMap::new()).unwrap();

        card_map.insert("id", "test-id").unwrap();
        card_map.insert("title", "测试").unwrap();
        card_map.insert("content", "内容").unwrap();
        // 注意：没有is_deleted字段（模拟v0）

        // 执行迁移
        migrate_card_if_needed(&doc).unwrap();

        // 验证迁移结果
        let card_map = root.get("card").unwrap().as_map().unwrap();
        assert!(card_map.contains_key("is_deleted"));
        assert_eq!(card_map.get("is_deleted").unwrap().as_bool().unwrap(), false);

        // 验证版本号更新
        assert_eq!(root.get("schema_version").unwrap().as_i64().unwrap(), 1);
    }

    #[test]
    fn test_rebuild_sqlite_from_loro() {
        let temp_dir = tempdir().unwrap();
        let sqlite_path = temp_dir.path().join("cache.db");
        let loro_dir = temp_dir.path().join("loro");

        // 创建测试Loro文档
        std::fs::create_dir_all(&loro_dir).unwrap();
        // ... 创建测试数据

        // 重建SQLite
        rebuild_sqlite_cache(&sqlite_path, &loro_dir).unwrap();

        // 验证数据正确
        let conn = Connection::open(&sqlite_path).unwrap();
        let count: i64 = conn.query_row("SELECT COUNT(*) FROM cards", [], |row| row.get(0)).unwrap();
        assert!(count > 0);
    }
}
```

### 11.6 向后兼容原则

**重要原则**:
1. **新版本能读取旧版本数据**（向后兼容）
2. **使用默认值填充缺失字段**
3. **渐进式迁移**（逐个文档迁移，不是一次性全部迁移）
4. **失败回滚**（迁移失败时保留原始数据）

**示例：添加新字段时使用默认值**:
```rust
// 读取时提供默认值
fn read_card_from_loro(card_map: &LoroMap) -> Result<Card> {
    Ok(Card {
        id: card_map.get("id")?.as_str()?.to_string(),
        title: card_map.get("title")?.as_str()?.to_string(),
        content: card_map.get("content")?.as_str()?.to_string(),
        created_at: card_map.get("created_at")?.as_i64()?,
        updated_at: card_map.get("updated_at")?.as_i64()?,
        // 旧版本没有is_deleted，使用默认值false
        is_deleted: card_map.get("is_deleted")
            .and_then(|v| v.as_bool())
            .unwrap_or(false),
    })
}
```

### 11.7 迁移日志和通知

在迁移过程中提供清晰的日志：

```rust
pub fn migrate_all_cards(loro_dir: &Path) -> Result<usize> {
    info!("开始扫描并迁移Loro文档");
    let mut migrated_count = 0;

    for entry in std::fs::read_dir(loro_dir)? {
        let entry = entry?;
        let card_dir = entry.path();

        if card_dir.is_dir() {
            let doc = load_card_doc_from_files(&card_dir)?;
            let version_before = get_doc_version(&doc)?;

            if migrate_card_if_needed(&doc)? {
                migrated_count += 1;
                info!("已迁移卡片: {:?}, v{} -> v{}",
                      card_dir.file_name().unwrap(),
                      version_before,
                      get_doc_version(&doc)?);
            }
        }
    }

    info!("迁移完成，共迁移{}个文档", migrated_count);
    Ok(migrated_count)
}
```

### 11.8 总结

**数据迁移核心要点**:

1. **Loro是真理源** - 只需迁移Loro数据
2. **SQLite可重建** - 删除重建是最简单可靠的方案
3. **版本号管理** - 在Loro文档中存储schema_version
4. **渐进式迁移** - 加载时按需迁移，不是一次性全部迁移
5. **向后兼容** - 新版本能读取旧版本数据
6. **完善测试** - 为每个迁移路径编写测试

**MVP阶段**:
- 暂时不需要迁移逻辑（从v1开始）
- 预留schema_version字段
- 为将来的迁移做好准备

**V2.0及以后**:
- 根据需要添加迁移逻辑
- 遵循上述原则，确保平滑升级

---

## 12. 总结

CardMind的数据库设计核心特点：

1. **Loro作为真理源**:
   - 所有写操作通过Loro
   - CRDT保证数据一致性
   - 文件持久化，简单可靠

2. **SQLite作为缓存**:
   - 只读缓存，不直接写入
   - 订阅机制自动同步
   - 优化查询性能

3. **双层架构优势**:
   - 数据可靠性（Loro CRDT）
   - 查询性能（SQLite索引）
   - 易于扩展（独立的两层）

4. **简化的备份和导入导出**:
   - 只需备份Loro文档文件
   - SQLite可随时从Loro重建
   - 导入导出就是Loro文件的压缩/解压

这个设计既保证了CRDT的强大同步能力，又提供了SQLite的高性能查询，是卡片笔记应用的理想架构。
