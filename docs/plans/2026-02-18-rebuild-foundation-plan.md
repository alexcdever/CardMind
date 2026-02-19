# CardMind 基础重建 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 重建 CardMind 的最小工程骨架与本地数据层，为后续同步与 UI 打基础。  
**Architecture:** Flutter 负责 UI，Rust 负责数据层（Loro 真相源 + SQLite 缓存）；池外不启用 P2P。  
**Tech Stack:** Flutter、Rust、flutter_rust_bridge、Loro、SQLite（rusqlite）。

---

### Task 1: 初始化 Flutter 工程骨架

**Files:**
- Create: `lib/`, `test/`（由 `flutter create` 生成）
- Modify: `.gitignore`（保留 `.worktrees/` 忽略规则）

**Step 1: 生成工程**

Run: `flutter create . --platforms=macos,windows,linux,ios,android`

**Step 2: 恢复 `.worktrees/` 忽略**

```gitignore
.worktrees/
```

**Step 3: 运行基础测试**

Run: `flutter test`  
Expected: 默认计数器测试通过

**Step 4: Commit**

```bash
git add .gitignore lib test pubspec.yaml pubspec.lock
git commit -m "chore(flutter): bootstrap app skeleton"
```

---

### Task 2: 初始化 Rust 工程 + FRB 配置

**Files:**
- Create: `rust/Cargo.toml`, `rust/src/lib.rs`
- Create: `flutter_rust_bridge.yaml`
- Create: `rust/tests/smoke_test.rs`

**Step 1: 生成 Rust crate**

Run: `cargo new rust --lib --name cardmind_rust`

**Step 2: 更新依赖**

```toml
# rust/Cargo.toml
[dependencies]
serde = { version = "1", features = ["derive"] }
uuid = { version = "1", features = ["v7", "serde", "fast-rng"] }
thiserror = "1"
loro = "1.10.3"
rusqlite = { version = "0.31", features = ["bundled"] }
base64 = "0.22"

[dev-dependencies]
tempfile = "3"
```

**Step 3: Rust lib 骨架**

```rust
// rust/src/lib.rs
pub mod models;
pub mod store;
pub mod utils;
```

**Step 4: FRB 配置**

```yaml
# flutter_rust_bridge.yaml
rust_input: rust/src/api.rs
dart_output: lib/bridge_generated.dart
```

**Step 5: 基础测试**

```rust
// rust/tests/smoke_test.rs
#[test]
fn it_should_build_crate() {
    assert!(true);
}
```

Run: `cd rust && cargo test`  
Expected: PASS

**Step 6: Commit**

```bash
git add rust flutter_rust_bridge.yaml
git commit -m "chore(rust): bootstrap crate and frb config"
```

---

### Task 3: 重建规格文档骨架

**Files:**
- Create: `docs/specs/README.md`
- Create: `docs/specs/domain/card.md`
- Create: `docs/specs/domain/pool.md`
- Create: `docs/specs/domain/types.md`
- Create: `docs/specs/architecture/storage/dual_layer.md`

**Step 1: 规格索引**

```markdown
# CardMind 规格文档

## 领域模型
- domain/card.md
- domain/pool.md
- domain/types.md

## 架构
- architecture/storage/dual_layer.md
```

**Step 2: Card 规格（GIVEN-WHEN-THEN）**

```markdown
GIVEN 已存在本地笔记
WHEN 用户更新标题或正文并保存
THEN Loro 写入并触发 SQLite 缓存更新
```

**Step 3: Pool 规格（GIVEN-WHEN-THEN）**

```markdown
GIVEN 本地已有笔记且未加入池
WHEN 用户加入池
THEN 所有本地笔记 id 写入池元数据 card_ids
```

**Step 4: Dual Layer 规格**

```markdown
GIVEN 任何写操作
WHEN Loro commit 完成
THEN 订阅回调更新 SQLite 缓存
```

**Step 5: Commit**

```bash
git add docs/specs
git commit -m "docs: add base specs for rebuild"
```

---

### Task 4: Rust 核心模型 + 错误类型 + UUID v7

**Files:**
- Create: `rust/src/models/mod.rs`
- Create: `rust/src/models/card.rs`
- Create: `rust/src/models/pool.rs`
- Create: `rust/src/models/error.rs`
- Create: `rust/src/utils/uuid_v7.rs`
- Create: `rust/src/utils/mod.rs`
- Create: `rust/tests/uuid_v7_test.rs`
- Create: `rust/tests/card_model_test.rs`

**Step 1: 编写失败测试**

```rust
// rust/tests/uuid_v7_test.rs
use cardmind_rust::utils::uuid_v7::new_uuid_v7;

#[test]
fn it_should_generate_uuid_v7() {
    let value = new_uuid_v7();
    assert_eq!(value.get_version_num(), 7);
}
```

**Step 2: 实现 UUID v7**

```rust
// rust/src/utils/uuid_v7.rs
use uuid::Uuid;

pub fn new_uuid_v7() -> Uuid {
    Uuid::now_v7()
}
```

**Step 3: 实现模型与错误**

```rust
// rust/src/models/error.rs
use thiserror::Error;

#[derive(Debug, Error)]
pub enum CardMindError {
    #[error("io error")]
    Io(#[from] std::io::Error),
    #[error("sqlite error")]
    Sqlite(#[from] rusqlite::Error),
}
```

```rust
// rust/src/models/card.rs
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Card {
    pub id: Uuid,
    pub title: String,
    pub content: String,
    pub created_at: i64,
    pub updated_at: i64,
    pub deleted: bool,
}
```

**Step 4: 运行测试**

Run: `cd rust && cargo test`  
Expected: FAIL → PASS

**Step 5: Commit**

```bash
git add rust/src/models rust/src/utils rust/tests
git commit -m "feat(rust): add core models and uuid v7"
```

---

### Task 5: Loro 存储层（池与笔记）

**Files:**
- Create: `rust/src/store/mod.rs`
- Create: `rust/src/store/loro_store.rs`
- Create: `rust/tests/loro_store_test.rs`

**Step 1: 编写失败测试**

```rust
use cardmind_rust::store::loro_store::note_doc_path;
use uuid::Uuid;

#[test]
fn it_should_build_note_path() {
    let id = Uuid::now_v7();
    let path = note_doc_path(&id);
    assert!(path.to_string_lossy().contains("data/loro/note"));
}
```

**Step 2: 实现路径与基础接口**

```rust
// rust/src/store/loro_store.rs
use base64::engine::general_purpose::STANDARD;
use base64::Engine;
use std::path::{Path, PathBuf};
use uuid::Uuid;

pub fn note_doc_path(id: &Uuid) -> PathBuf {
    Path::new("data")
        .join("loro")
        .join("note")
        .join(STANDARD.encode(id.as_bytes()))
}

pub fn pool_doc_path(id: &Uuid) -> PathBuf {
    Path::new("data")
        .join("loro")
        .join("pool")
        .join(STANDARD.encode(id.as_bytes()))
}
```

**Step 3: 运行测试**

Run: `cd rust && cargo test`  
Expected: FAIL → PASS

**Step 4: Commit**

```bash
git add rust/src/store rust/tests/loro_store_test.rs
git commit -m "feat(rust): add loro storage paths"
```

---

### Task 6: SQLite 缓存层骨架

**Files:**
- Create: `rust/src/store/sqlite_store.rs`
- Create: `rust/tests/sqlite_store_test.rs`

**Step 1: 编写失败测试**

```rust
use cardmind_rust::store::sqlite_store::SqliteStore;
use tempfile::tempdir;

#[test]
fn it_should_init_schema() -> Result<(), Box<dyn std::error::Error>> {
    let dir = tempdir()?;
    let db_path = dir.path().join("cardmind.sqlite");
    let store = SqliteStore::new(&db_path)?;
    assert!(store.is_ready());
    Ok(())
}
```

**Step 2: 实现最小 Schema**

```rust
// rust/src/store/sqlite_store.rs
use rusqlite::{Connection, Result};
use std::path::Path;

pub struct SqliteStore {
    conn: Connection,
    ready: bool,
}

impl SqliteStore {
    pub fn new(path: &Path) -> Result<Self> {
        let conn = Connection::open(path)?;
        conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS cards (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                content TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                deleted INTEGER NOT NULL
            );",
        )?;
        Ok(Self { conn, ready: true })
    }

    pub fn is_ready(&self) -> bool {
        self.ready
    }
}
```

**Step 3: 运行测试**

Run: `cd rust && cargo test`  
Expected: FAIL → PASS

**Step 4: Commit**

```bash
git add rust/src/store/sqlite_store.rs rust/tests/sqlite_store_test.rs
git commit -m "feat(rust): add sqlite cache skeleton"
```

---

### Task 7: 本地卡片 CRUD 与池元数据基础逻辑

**Files:**
- Create: `rust/src/store/card_store.rs`
- Create: `rust/src/store/pool_store.rs`
- Create: `rust/tests/card_store_test.rs`
- Create: `rust/tests/pool_store_test.rs`

**Step 1: 编写失败测试**

```rust
// rust/tests/card_store_test.rs
use cardmind_rust::store::card_store::CardStore;

#[test]
fn it_should_create_card() {
    let store = CardStore::memory();
    let card = store.create_card("t", "c");
    assert_eq!(card.title, "t");
}
```

**Step 2: 实现最小 CRUD（仅本地）**

```rust
// rust/src/store/card_store.rs
use crate::models::card::Card;
use crate::utils::uuid_v7::new_uuid_v7;
use std::time::{SystemTime, UNIX_EPOCH};

pub struct CardStore;

impl CardStore {
    pub fn memory() -> Self {
        Self
    }

    pub fn create_card(&self, title: &str, content: &str) -> Card {
        let now = match SystemTime::now().duration_since(UNIX_EPOCH) {
            Ok(duration) => duration.as_secs() as i64,
            Err(_) => 0,
        };
        Card {
            id: new_uuid_v7(),
            title: title.to_string(),
            content: content.to_string(),
            created_at: now,
            updated_at: now,
            deleted: false,
        }
    }
}
```

**Step 3: 运行测试**

Run: `cd rust && cargo test`  
Expected: FAIL → PASS

**Step 4: Commit**

```bash
git add rust/src/store/card_store.rs rust/tests/card_store_test.rs
git commit -m "feat(rust): add local card store skeleton"
```

---

## 执行说明
该计划仅覆盖“本地数据层与规格骨架”。完成后再继续规划：
- libp2p + mDNS 加入/审批流程
- Flutter 双端 UI 与交互
- FRB API 暴露与状态管理
