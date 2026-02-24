# FRB API 与持久化 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 接入 FRB API（句柄式生命周期）并落地 Loro+SQLite 持久化，使卡片与数据池元数据可读写。  
**Architecture:** Flutter 仅负责调用 FRB；Rust 负责路径校验、Loro 写入与 SQLite 缓存更新；所有读操作走 SQLite；池外不启用 P2P。  
**Tech Stack:** Flutter、flutter_rust_bridge、Rust、Loro、rusqlite。

---

### Task 1: 更新规格文档（FRB 与持久化）

**Files:**
- Modify: `docs/specs/README.md`
- Modify: `docs/specs/domain/card.md`
- Modify: `docs/specs/domain/pool.md`
- Modify: `docs/specs/domain/types.md`
- Modify: `docs/specs/architecture/storage/dual_layer.md`
- Create: `docs/specs/architecture/bridge/frb_api.md`

**Step 1: 增加 FRB 规格索引**

```markdown
# docs/specs/README.md

## 架构
- architecture/storage/dual_layer.md
- architecture/bridge/frb_api.md
```

**Step 2: 补充卡片写读与 SQLite 规则**

```markdown
# docs/specs/domain/card.md

## 行为
GIVEN 用户创建/更新/删除卡片
WHEN Loro commit 完成
THEN SQLite 缓存更新且后续读取仅走 SQLite

GIVEN 用户按关键字搜索
WHEN 发起搜索请求
THEN SQLite 使用 LIKE 查询标题与正文并返回分页结果
```

**Step 3: 补充数据池元数据与加入逻辑**

```markdown
# docs/specs/domain/pool.md

## 行为
GIVEN 数据池元数据保存在 Loro 文档
WHEN 本地写入/更新元数据
THEN SQLite 缓存同步更新

GIVEN 本地已有笔记且未加入池
WHEN 加入池并确认加入
THEN 本地已有笔记 id 写入池元数据 card_ids
```

**Step 4: 补充类型与错误码**

```markdown
# docs/specs/domain/types.md

## 行为
GIVEN API 对外暴露错误
WHEN Rust 返回错误
THEN 错误必须包含 code 与 message
```

**Step 5: 补充双层存储细则**

```markdown
# docs/specs/architecture/storage/dual_layer.md

## 行为
GIVEN 任何写操作
WHEN Loro commit 并导出 Snapshot
THEN 写入 Loro 文件并更新 SQLite 缓存
```

**Step 6: 新增 FRB 规范**

```markdown
# docs/specs/architecture/bridge/frb_api.md

## 行为
GIVEN Flutter 初始化 Store
WHEN 传入 base_path
THEN Rust 校验并创建 data 目录

GIVEN 任意 FRB API 出错
WHEN 返回错误
THEN code 与 message 必须非空
```

**Step 7: Commit**

```bash
git add docs/specs

git commit -m "docs: add frb and persistence specs"
```

---

### Task 2: 添加 FRB 与 UUID 依赖、库类型配置

**Files:**
- Modify: `pubspec.yaml`
- Modify: `rust/Cargo.toml`
- Modify: `rust/src/lib.rs`

**Step 1: Flutter 依赖**

```yaml
# pubspec.yaml

dependencies:
  flutter_rust_bridge: ^2.11.1
  uuid: ^4.5.3
```

**Step 2: Rust 依赖与 crate-type**

```toml
# rust/Cargo.toml

[lib]
crate-type = ["cdylib", "staticlib"]

[dependencies]
flutter_rust_bridge = { version = "2.11.1", features = ["uuid"] }
```

**Step 3: 暴露 api 模块**

```rust
// rust/src/lib.rs
/// FRB 接口层
pub mod api;
```

**Step 4: 运行 Rust 测试**

Run: `cd rust && cargo test`
Expected: FAIL（因缺少 api.rs）

**Step 5: Commit**

```bash
git add pubspec.yaml rust/Cargo.toml rust/src/lib.rs

git commit -m "chore: add frb and uuid dependencies"
```

---

### Task 3: 统一错误类型与 ApiError 映射

**Files:**
- Modify: `rust/src/models/error.rs`
- Create: `rust/src/models/api_error.rs`
- Modify: `rust/src/models/mod.rs`
- Create: `rust/tests/api_error_test.rs`

**Step 1: 写失败测试（错误码非空）**

```rust
// rust/tests/api_error_test.rs
use cardmind_rust::models::api_error::{ApiError, ApiErrorCode};

#[test]
fn it_should_have_non_empty_error_code_and_message() {
    let err = ApiError::new(ApiErrorCode::InvalidArgument, "msg");
    assert!(!err.code.is_empty());
    assert!(!err.message.is_empty());
}
```

**Step 2: 实现 ApiError 与错误码**

```rust
// rust/src/models/api_error.rs
use serde::{Deserialize, Serialize};

/// 对外 API 错误码
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ApiErrorCode {
    /// 参数不合法
    InvalidArgument,
    /// 资源不存在
    NotFound,
    /// 未实现
    NotImplemented,
    /// IO 错误
    IoError,
    /// SQLite 错误
    SqliteError,
    /// 数据池不存在
    PoolNotFound,
    /// 数据池哈希非法
    InvalidPoolHash,
    /// 密钥哈希非法
    InvalidKeyHash,
    /// 管理员离线
    AdminOffline,
    /// 请求超时
    RequestTimeout,
    /// 管理员拒绝
    RejectedByAdmin,
    /// 已是成员
    AlreadyMember,
    /// 内部错误
    Internal,
}

impl ApiErrorCode {
    /// 转换为稳定字符串
    pub fn as_str(&self) -> &'static str {
        match self {
            ApiErrorCode::InvalidArgument => "INVALID_ARGUMENT",
            ApiErrorCode::NotFound => "NOT_FOUND",
            ApiErrorCode::NotImplemented => "NOT_IMPLEMENTED",
            ApiErrorCode::IoError => "IO_ERROR",
            ApiErrorCode::SqliteError => "SQLITE_ERROR",
            ApiErrorCode::PoolNotFound => "POOL_NOT_FOUND",
            ApiErrorCode::InvalidPoolHash => "INVALID_POOL_HASH",
            ApiErrorCode::InvalidKeyHash => "INVALID_KEY_HASH",
            ApiErrorCode::AdminOffline => "ADMIN_OFFLINE",
            ApiErrorCode::RequestTimeout => "REQUEST_TIMEOUT",
            ApiErrorCode::RejectedByAdmin => "REJECTED_BY_ADMIN",
            ApiErrorCode::AlreadyMember => "ALREADY_MEMBER",
            ApiErrorCode::Internal => "INTERNAL",
        }
    }
}

/// 对外 API 错误
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ApiError {
    /// 错误码
    pub code: String,
    /// 错误信息
    pub message: String,
}

impl ApiError {
    /// 创建 ApiError
    pub fn new(code: ApiErrorCode, message: &str) -> Self {
        Self {
            code: code.as_str().to_string(),
            message: message.to_string(),
        }
    }
}
```

**Step 3: 扩展 CardMindError**

```rust
// rust/src/models/error.rs
use thiserror::Error;

/// CardMind 统一错误类型
#[derive(Debug, Error)]
pub enum CardMindError {
    /// IO 错误
    #[error("io error: {0}")]
    Io(String),
    /// SQLite 错误
    #[error("sqlite error: {0}")]
    Sqlite(String),
    /// Loro 错误
    #[error("loro error: {0}")]
    Loro(String),
    /// 参数非法
    #[error("invalid argument: {0}")]
    InvalidArgument(String),
    /// 未找到
    #[error("not found: {0}")]
    NotFound(String),
    /// 未实现
    #[error("not implemented: {0}")]
    NotImplemented(String),
    /// 内部错误
    #[error("internal error: {0}")]
    Internal(String),
}
```

**Step 4: re-export**

```rust
// rust/src/models/mod.rs
/// API 错误
pub mod api_error;
```

**Step 5: 运行测试**

Run: `cd rust && cargo test`
Expected: FAIL → PASS

**Step 6: Commit**

```bash
git add rust/src/models rust/tests/api_error_test.rs

git commit -m "feat(rust): add api error and error codes"
```

---

### Task 4: 路径解析与目录初始化

**Files:**
- Create: `rust/src/store/path_resolver.rs`
- Modify: `rust/src/store/mod.rs`
- Create: `rust/tests/path_resolver_test.rs`

**Step 1: 写失败测试**

```rust
// rust/tests/path_resolver_test.rs
use cardmind_rust::store::path_resolver::DataPaths;

#[test]
fn it_should_build_data_paths() -> Result<(), Box<dyn std::error::Error>> {
    let paths = DataPaths::new("/tmp/cardmind")?;
    assert!(paths.loro_note_dir.to_string_lossy().contains("data/loro/note"));
    assert!(paths.sqlite_path.to_string_lossy().contains("data/sqlite"));
    Ok(())
}
```

**Step 2: 实现路径解析**

```rust
// rust/src/store/path_resolver.rs
use crate::models::error::CardMindError;
use std::fs;
use std::path::{Path, PathBuf};

/// 数据路径集合
pub struct DataPaths {
    /// base_path 根路径
    pub base_path: PathBuf,
    /// Loro 笔记目录
    pub loro_note_dir: PathBuf,
    /// Loro 数据池目录
    pub loro_pool_dir: PathBuf,
    /// SQLite 路径
    pub sqlite_path: PathBuf,
}

impl DataPaths {
    /// 解析并确保目录存在
    pub fn new(base_path: &str) -> Result<Self, CardMindError> {
        if base_path.trim().is_empty() {
            return Err(CardMindError::InvalidArgument("base_path empty".to_string()));
        }
        let base = Path::new(base_path).to_path_buf();
        let loro_note_dir = base.join("data").join("loro").join("note");
        let loro_pool_dir = base.join("data").join("loro").join("pool");
        let sqlite_dir = base.join("data").join("sqlite");
        let sqlite_path = sqlite_dir.join("cardmind.sqlite");

        fs::create_dir_all(&loro_note_dir)
            .map_err(|e| CardMindError::Io(e.to_string()))?;
        fs::create_dir_all(&loro_pool_dir)
            .map_err(|e| CardMindError::Io(e.to_string()))?;
        fs::create_dir_all(&sqlite_dir)
            .map_err(|e| CardMindError::Io(e.to_string()))?;

        Ok(Self {
            base_path: base,
            loro_note_dir,
            loro_pool_dir,
            sqlite_path,
        })
    }
}
```

**Step 3: 注册模块**

```rust
// rust/src/store/mod.rs
/// 路径解析
pub mod path_resolver;
```

**Step 4: 运行测试**

Run: `cd rust && cargo test`
Expected: FAIL → PASS

**Step 5: Commit**

```bash
git add rust/src/store/path_resolver.rs rust/src/store/mod.rs rust/tests/path_resolver_test.rs

git commit -m "feat(rust): add data path resolver"
```

---

### Task 5: Loro 文件持久化辅助

**Files:**
- Modify: `rust/src/store/loro_store.rs`
- Create: `rust/tests/loro_persist_test.rs`

**Step 1: 写失败测试**

```rust
// rust/tests/loro_persist_test.rs
use cardmind_rust::store::loro_store::{load_loro_doc, save_loro_doc};
use loro::LoroDoc;
use tempfile::tempdir;

#[test]
fn it_should_save_and_load_loro_doc() -> Result<(), Box<dyn std::error::Error>> {
    let dir = tempdir()?;
    let path = dir.path().join("doc.loro");

    let doc = LoroDoc::new();
    doc.get_map("card").insert("title", "t")?;
    doc.commit();

    save_loro_doc(&path, &doc)?;

    let loaded = load_loro_doc(&path)?;
    let value = loaded.get_map("card").get("title").ok_or_else(|| {
        std::io::Error::new(std::io::ErrorKind::Other, "missing title")
    })?;
    assert!(value.to_string().contains("t"));
    Ok(())
}
```

**Step 2: 实现读写**

```rust
// rust/src/store/loro_store.rs
use crate::models::error::CardMindError;
use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use base64::Engine;
use loro::{ExportMode, LoroDoc};
use std::fs;
use std::path::{Path, PathBuf};
use uuid::Uuid;

/// 构建笔记 Loro 文档路径
pub fn note_doc_path(id: &Uuid) -> PathBuf {
    Path::new("data")
        .join("loro")
        .join("note")
        .join(URL_SAFE_NO_PAD.encode(id.as_bytes()))
}

/// 构建数据池 Loro 文档路径
pub fn pool_doc_path(id: &Uuid) -> PathBuf {
    Path::new("data")
        .join("loro")
        .join("pool")
        .join(URL_SAFE_NO_PAD.encode(id.as_bytes()))
}

/// 从文件加载 Loro 文档
pub fn load_loro_doc(path: &Path) -> Result<LoroDoc, CardMindError> {
    let doc = LoroDoc::new();
    if path.exists() {
        let bytes = fs::read(path).map_err(|e| CardMindError::Io(e.to_string()))?;
        doc.import(&bytes)
            .map_err(|e| CardMindError::Loro(e.to_string()))?;
    }
    Ok(doc)
}

/// 保存 Loro 文档到文件
pub fn save_loro_doc(path: &Path, doc: &LoroDoc) -> Result<(), CardMindError> {
    let bytes = doc
        .export(ExportMode::Snapshot)
        .map_err(|e| CardMindError::Loro(e.to_string()))?;
    fs::write(path, bytes).map_err(|e| CardMindError::Io(e.to_string()))?;
    Ok(())
}
```

**Step 3: 运行测试**

Run: `cd rust && cargo test`
Expected: FAIL → PASS

**Step 4: Commit**

```bash
git add rust/src/store/loro_store.rs rust/tests/loro_persist_test.rs

git commit -m "feat(rust): add loro load/save helpers"
```

---

### Task 6: SQLite Schema 与卡片/池缓存操作

**Files:**
- Modify: `rust/src/store/sqlite_store.rs`
- Create: `rust/tests/sqlite_store_cards_test.rs`
- Create: `rust/tests/sqlite_store_pool_test.rs`

**Step 1: 写失败测试（卡片 upsert 与查询）**

```rust
// rust/tests/sqlite_store_cards_test.rs
use cardmind_rust::models::card::Card;
use cardmind_rust::store::sqlite_store::SqliteStore;
use tempfile::tempdir;
use uuid::Uuid;

#[test]
fn it_should_upsert_and_get_card() -> Result<(), Box<dyn std::error::Error>> {
    let dir = tempdir()?;
    let path = dir.path().join("cardmind.sqlite");
    let store = SqliteStore::new(&path)?;
    let card = Card {
        id: Uuid::now_v7(),
        title: "t".to_string(),
        content: "c".to_string(),
        created_at: 1,
        updated_at: 2,
        deleted: false,
    };
    store.upsert_card(&card)?;
    let loaded = store.get_card(&card.id)?;
    assert_eq!(loaded.title, "t");
    Ok(())
}
```

**Step 2: 写失败测试（池元数据）**

```rust
// rust/tests/sqlite_store_pool_test.rs
use cardmind_rust::models::pool::{Pool, PoolMember};
use cardmind_rust::store::sqlite_store::SqliteStore;
use tempfile::tempdir;
use uuid::Uuid;

#[test]
fn it_should_upsert_and_get_pool() -> Result<(), Box<dyn std::error::Error>> {
    let dir = tempdir()?;
    let path = dir.path().join("cardmind.sqlite");
    let store = SqliteStore::new(&path)?;
    let pool = Pool {
        pool_id: Uuid::now_v7(),
        pool_key: "k".to_string(),
        members: vec![PoolMember {
            peer_id: "p".to_string(),
            public_key: "pk".to_string(),
            multiaddr: "addr".to_string(),
            os: "os".to_string(),
            hostname: "h".to_string(),
            is_admin: true,
        }],
        card_ids: vec![Uuid::now_v7()],
    };
    store.upsert_pool(&pool)?;
    let loaded = store.get_pool(&pool.pool_id)?;
    assert_eq!(loaded.pool_key, "k");
    assert_eq!(loaded.members.len(), 1);
    Ok(())
}
```

**Step 3: 实现 schema 与方法**

```rust
// rust/src/store/sqlite_store.rs

pub fn new(path: &Path) -> Result<Self, CardMindError> { ... }

pub fn upsert_card(&self, card: &Card) -> Result<(), CardMindError> { ... }
pub fn get_card(&self, id: &Uuid) -> Result<Card, CardMindError> { ... }
pub fn list_cards(&self, limit: i64, offset: i64) -> Result<Vec<Card>, CardMindError> { ... }
pub fn search_cards(&self, keyword: &str, limit: i64, offset: i64) -> Result<Vec<Card>, CardMindError> { ... }

pub fn upsert_pool(&self, pool: &Pool) -> Result<(), CardMindError> { ... }
pub fn get_pool(&self, id: &Uuid) -> Result<Pool, CardMindError> { ... }
```

**Step 4: 运行测试**

Run: `cd rust && cargo test`
Expected: FAIL → PASS

**Step 5: Commit**

```bash
git add rust/src/store/sqlite_store.rs rust/tests/sqlite_store_cards_test.rs rust/tests/sqlite_store_pool_test.rs

git commit -m "feat(rust): add sqlite schema for cards and pools"
```

---

### Task 7: CardStore 持久化实现

**Files:**
- Modify: `rust/src/store/card_store.rs`
- Create: `rust/tests/card_store_persist_test.rs`

**Step 1: 写失败测试**

```rust
// rust/tests/card_store_persist_test.rs
use cardmind_rust::store::card_store::CardStore;
use tempfile::tempdir;

#[test]
fn it_should_create_and_read_card_from_sqlite() -> Result<(), Box<dyn std::error::Error>> {
    let dir = tempdir()?;
    let store = CardStore::new(dir.path().to_string_lossy().as_ref())?;
    let card = store.create_card("t", "c")?;
    let loaded = store.get_card(&card.id)?;
    assert_eq!(loaded.title, "t");
    Ok(())
}
```

**Step 2: 实现 CardStore**

```rust
// rust/src/store/card_store.rs
pub struct CardStore {
    paths: DataPaths,
    sqlite: SqliteStore,
}

impl CardStore {
    pub fn new(base_path: &str) -> Result<Self, CardMindError> { ... }
    pub fn create_card(&self, title: &str, content: &str) -> Result<Card, CardMindError> { ... }
    pub fn update_card(&self, id: &Uuid, title: &str, content: &str) -> Result<Card, CardMindError> { ... }
    pub fn delete_card(&self, id: &Uuid) -> Result<(), CardMindError> { ... }
    pub fn get_card(&self, id: &Uuid) -> Result<Card, CardMindError> { ... }
    pub fn list_cards(&self, limit: i64, offset: i64) -> Result<Vec<Card>, CardMindError> { ... }
    pub fn search_cards(&self, keyword: &str, limit: i64, offset: i64) -> Result<Vec<Card>, CardMindError> { ... }
}
```

**Step 3: 运行测试**

Run: `cd rust && cargo test`
Expected: FAIL → PASS

**Step 4: Commit**

```bash
git add rust/src/store/card_store.rs rust/tests/card_store_persist_test.rs

git commit -m "feat(rust): persist cards with loro and sqlite"
```

---

### Task 8: PoolStore 持久化实现

**Files:**
- Modify: `rust/src/store/pool_store.rs`
- Create: `rust/tests/pool_store_persist_test.rs`

**Step 1: 写失败测试**

```rust
// rust/tests/pool_store_persist_test.rs
use cardmind_rust::store::pool_store::PoolStore;
use tempfile::tempdir;

#[test]
fn it_should_create_and_read_pool() -> Result<(), Box<dyn std::error::Error>> {
    let dir = tempdir()?;
    let store = PoolStore::new(dir.path().to_string_lossy().as_ref())?;
    let pool = store.create_pool("key", "peer", "pk", "addr", "os", "host")?;
    let loaded = store.get_pool(&pool.pool_id)?;
    assert_eq!(loaded.pool_key, "key");
    Ok(())
}
```

**Step 2: 实现 PoolStore**

```rust
// rust/src/store/pool_store.rs
pub struct PoolStore {
    paths: DataPaths,
    sqlite: SqliteStore,
}

impl PoolStore {
    pub fn new(base_path: &str) -> Result<Self, CardMindError> { ... }
    pub fn create_pool(&self, pool_key: &str, peer_id: &str, public_key: &str, multiaddr: &str, os: &str, hostname: &str) -> Result<Pool, CardMindError> { ... }
    pub fn get_pool(&self, pool_id: &Uuid) -> Result<Pool, CardMindError> { ... }
    pub fn join_pool(&self, pool: &Pool, new_member: PoolMember, local_card_ids: Vec<Uuid>) -> Result<Pool, CardMindError> { ... }
    pub fn leave_pool(&self, pool_id: &Uuid, peer_id: &str) -> Result<Pool, CardMindError> { ... }
}
```

**Step 3: 运行测试**

Run: `cd rust && cargo test`
Expected: FAIL → PASS

**Step 4: Commit**

```bash
git add rust/src/store/pool_store.rs rust/tests/pool_store_persist_test.rs

git commit -m "feat(rust): persist pool metadata with loro and sqlite"
```

---

### Task 9: FRB API 与句柄生命周期

**Files:**
- Create: `rust/src/api.rs`
- Create: `rust/tests/api_handle_test.rs`

**Step 1: 写失败测试（初始化与关闭）**

```rust
// rust/tests/api_handle_test.rs
use cardmind_rust::api::{init_card_store, close_card_store};

#[test]
fn it_should_init_and_close_card_store() -> Result<(), Box<dyn std::error::Error>> {
    let store_id = init_card_store("/tmp/cardmind")?;
    close_card_store(store_id)?;
    Ok(())
}
```

**Step 2: 实现句柄注册与 API**

```rust
// rust/src/api.rs
use crate::models::api_error::{ApiError, ApiErrorCode};
use crate::models::error::CardMindError;
use crate::store::card_store::CardStore;
use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};
use std::sync::atomic::{AtomicU64, Ordering};

static CARD_STORE_SEQ: AtomicU64 = AtomicU64::new(1);
static CARD_STORES: OnceLock<Mutex<HashMap<u64, CardStore>>> = OnceLock::new();

fn card_store_map() -> &'static Mutex<HashMap<u64, CardStore>> {
    CARD_STORES.get_or_init(|| Mutex::new(HashMap::new()))
}

fn map_err(err: CardMindError) -> ApiError {
    match err {
        CardMindError::InvalidArgument(msg) => ApiError::new(ApiErrorCode::InvalidArgument, &msg),
        CardMindError::NotFound(msg) => ApiError::new(ApiErrorCode::NotFound, &msg),
        CardMindError::NotImplemented(msg) => ApiError::new(ApiErrorCode::NotImplemented, &msg),
        CardMindError::Io(msg) => ApiError::new(ApiErrorCode::IoError, &msg),
        CardMindError::Sqlite(msg) => ApiError::new(ApiErrorCode::SqliteError, &msg),
        _ => ApiError::new(ApiErrorCode::Internal, "internal error"),
    }
}

/// 初始化 CardStore
pub fn init_card_store(base_path: String) -> Result<u64, ApiError> { ... }
/// 关闭 CardStore
pub fn close_card_store(store_id: u64) -> Result<(), ApiError> { ... }
```

**Step 3: 运行测试**

Run: `cd rust && cargo test`
Expected: FAIL → PASS

**Step 4: Commit**

```bash
git add rust/src/api.rs rust/tests/api_handle_test.rs

git commit -m "feat(rust): add frb api handles"
```

---

### Task 10: 生成 Dart Bridge + 最小包装层

**Files:**
- Create: `lib/rust_api.dart`
- Generate: `lib/bridge_generated.dart`

**Step 1: 安装 codegen（如本机未安装）**

Run: `cargo install flutter_rust_bridge_codegen --version 2.11.1`

**Step 2: 生成 Dart 绑定**

Run: `flutter_rust_bridge_codegen --rust-input rust/src/api.rs --dart-output lib/bridge_generated.dart`

**Step 3: 最小包装层**

```dart
// lib/rust_api.dart
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'bridge_generated.dart';

class RustApi {
  RustApi._(this._api);

  final Api _api;

  static Future<RustApi> init() async {
    await RustLib.init();
    return RustApi._(ApiImpl());
  }

  Api get api => _api;
}
```

**Step 4: 运行 Flutter 测试**

Run: `flutter test`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/bridge_generated.dart lib/rust_api.dart

git commit -m "feat(flutter): add frb bridge and wrapper"
```

---

### Task 11: 全量验证

**Step 1: Rust 测试**

Run: `cd rust && cargo test`
Expected: PASS

**Step 2: Flutter 测试**

Run: `flutter test`
Expected: PASS

**Step 3: Commit（如有遗漏）**

```bash
git add .

git commit -m "test: verify frb api and persistence"
```
