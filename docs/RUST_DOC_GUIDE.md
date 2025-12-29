# Rust 代码文档注释指南

本文档提供 CardMind 项目中 Rust 代码文档注释的最佳实践和示例。

---

## 为什么要写详细的文档注释?

1. **自动生成 API 文档**: `cargo doc` 自动生成 HTML 文档
2. **IDE 智能提示**: 在编辑器中显示函数说明和示例
3. **代码即文档**: 代码和文档永不失同步
4. **编译时检查**: `cargo test --doc` 验证示例代码

---

## 文档注释基础

### 1. 使用 `///` 为公开 API 添加文档

```rust
/// 创建新卡片并自动同步到 SQLite
///
/// # 参数
///
/// * `title` - 卡片标题 (可为空字符串)
/// * `content` - Markdown 格式的内容 (不能为空)
///
/// # 返回
///
/// 返回创建的 `Card` 对象,包含生成的 UUID v7 和时间戳
///
/// # 错误
///
/// * `CardMindError::LoroError` - Loro 操作失败
/// * `CardMindError::IoError` - 文件写入失败
///
/// # 示例
///
/// ```
/// use card_mind::api::create_card;
///
/// let card = create_card(
///     "我的想法".to_string(),
///     "今天想到的一个点子".to_string()
/// )?;
///
/// assert!(!card.id.is_empty());
/// ```
///
/// # 内部流程
///
/// 1. 生成 UUID v7 作为卡片 ID
/// 2. 创建 Loro 文档并写入数据
/// 3. 调用 `loro_doc.commit()` 触发订阅
/// 4. 持久化 Loro 文件到磁盘
/// 5. SQLite 自动通过订阅回调更新
#[flutter_rust_bridge::frb(sync)]
pub fn create_card(title: String, content: String) -> Result<Card, CardMindError> {
    // 实现...
}
```

### 2. 为模块添加文档

```rust
//! 卡片存储模块
//!
//! 本模块实现了 Loro CRDT 和 SQLite 缓存的双层数据架构。
//!
//! # 架构设计
//!
//! - **Loro**: 主数据源,所有写操作通过 Loro
//! - **SQLite**: 只读缓存,通过订阅机制自动同步
//!
//! # 使用示例
//!
//! ```
//! use card_mind::store::CardStore;
//!
//! let mut store = CardStore::new("/path/to/data")?;
//! let card = store.create_card("标题", "内容")?;
//! ```

pub mod loro_store;
pub mod sqlite_cache;
pub mod subscription;
```

### 3. 为结构体添加文档

```rust
/// Card 数据模型
///
/// 代表一个卡片笔记,包含标题、内容和时间戳。
///
/// # 重要约束
///
/// - `id` 使用 UUID v7,保证时间有序性
/// - 所有修改必须通过 Loro CRDT 进行
/// - SQLite 中的记录是只读缓存
///
/// # 示例
///
/// ```
/// use card_mind::models::Card;
/// use uuid::Uuid;
/// use chrono::Utc;
///
/// let card = Card {
///     id: Uuid::now_v7().to_string(),
///     title: "我的想法".to_string(),
///     content: "今天想到的一个点子".to_string(),
///     created_at: Utc::now().timestamp_millis(),
///     updated_at: Utc::now().timestamp_millis(),
///     is_deleted: false,
/// };
/// ```
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Card {
    /// UUID v7 格式的唯一标识符 (时间有序)
    pub id: String,

    /// 卡片标题 (可选,可为空字符串)
    pub title: String,

    /// Markdown 格式的内容 (必填,不能为空)
    pub content: String,

    /// 创建时间 (Unix 毫秒时间戳)
    pub created_at: i64,

    /// 最后更新时间 (Unix 毫秒时间戳)
    pub updated_at: i64,

    /// 软删除标记
    ///
    /// - `false`: 正常卡片
    /// - `true`: 已删除 (可恢复)
    pub is_deleted: bool,
}
```

### 4. 为枚举添加文档

```rust
/// CardMind 统一错误类型
///
/// 所有 API 使用 `Result<T, CardMindError>` 返回错误。
///
/// # 错误分类
///
/// - **数据层错误**: `LoroError`, `SqliteError`
/// - **业务逻辑错误**: `CardNotFound`, `InvalidUuid`
/// - **系统错误**: `IoError`
/// - **网络错误**: `SyncError` (Phase 2)
///
/// # 示例
///
/// ```
/// use card_mind::models::CardMindError;
///
/// fn get_card(id: &str) -> Result<Card, CardMindError> {
///     if !is_valid_uuid(id) {
///         return Err(CardMindError::InvalidUuid(id.to_string()));
///     }
///     // ...
/// }
/// ```
#[derive(Debug, Error)]
pub enum CardMindError {
    /// Loro CRDT 操作失败
    ///
    /// 可能的原因:
    /// - commit 失败
    /// - 文档格式损坏
    /// - 数据类型不匹配
    #[error("Loro CRDT error: {0}")]
    LoroError(#[from] loro::Error),

    /// SQLite 数据库操作失败
    ///
    /// 可能的原因:
    /// - 查询语法错误
    /// - 表不存在
    /// - 数据库文件损坏
    #[error("SQLite database error: {0}")]
    SqliteError(#[from] rusqlite::Error),

    /// 卡片不存在
    ///
    /// 当尝试获取或更新不存在的卡片时抛出
    #[error("Card not found: {0}")]
    CardNotFound(String),

    /// 文件 I/O 错误
    ///
    /// 可能的原因:
    /// - Loro 文件持久化失败
    /// - 权限不足
    /// - 磁盘空间不足
    #[error("IO error: {0}")]
    IoError(#[from] std::io::Error),

    /// UUID 格式错误
    ///
    /// 当传入的 ID 不是有效的 UUID v7 格式时抛出
    #[error("Invalid UUID format: {0}")]
    InvalidUuid(String),

    /// P2P 同步错误 (Phase 2)
    ///
    /// 可能的原因:
    /// - 网络连接失败
    /// - 对等节点不可达
    /// - 协议版本不兼容
    #[error("Sync error: {0}")]
    SyncError(String),
}
```

---

## 文档注释的标准章节

### 推荐的章节顺序

```rust
/// 简短的一句话描述
///
/// 更详细的多段落说明 (可选)
///
/// # 参数 (Parameters)
///
/// * `param1` - 参数说明
/// * `param2` - 参数说明
///
/// # 返回 (Returns)
///
/// 返回值说明
///
/// # 错误 (Errors)
///
/// * `ErrorType1` - 错误情况 1
/// * `ErrorType2` - 错误情况 2
///
/// # 示例 (Examples)
///
/// ```
/// // 示例代码
/// ```
///
/// # Panics (可选)
///
/// 何时会 panic
///
/// # Safety (仅 unsafe 函数)
///
/// 安全性说明
///
/// # 注意事项 (Notes) (可选)
///
/// 重要的使用注意事项
pub fn example_function() {}
```

---

## 完整示例:CardStore 结构体

```rust
//! CardStore - 卡片存储管理器
//!
//! 本模块实现了 Loro CRDT 和 SQLite 的双层存储架构。

use std::collections::HashMap;
use std::path::PathBuf;
use loro::LoroDoc;
use rusqlite::Connection;

/// 卡片存储管理器
///
/// `CardStore` 管理 Loro CRDT 文档和 SQLite 缓存,提供统一的卡片 CRUD 接口。
///
/// # 架构设计
///
/// - **Loro CRDT**: 主数据源,所有写操作通过 Loro
/// - **SQLite**: 只读缓存,通过订阅机制自动同步
/// - **订阅机制**: Loro commit 自动触发 SQLite 更新
///
/// # 使用示例
///
/// ```
/// use card_mind::store::CardStore;
/// use std::path::Path;
///
/// // 初始化存储
/// let data_dir = Path::new("/path/to/data");
/// let mut store = CardStore::new(data_dir)?;
///
/// // 创建卡片
/// let card = store.create_card("标题", "内容")?;
///
/// // 查询卡片
/// let all_cards = store.get_all_cards()?;
/// ```
///
/// # 线程安全
///
/// `CardStore` 不是线程安全的,如需多线程访问,请使用 `Arc<Mutex<CardStore>>`。
///
/// # 性能特性
///
/// - 创建卡片: < 50ms
/// - 查询列表: < 10ms (1000 张卡片)
/// - Loro → SQLite 同步: < 5ms
pub struct CardStore {
    /// 数据目录路径
    data_dir: PathBuf,

    /// 已加载的卡片 Loro 文档缓存
    ///
    /// Key: 卡片 ID (UUID v7)
    /// Value: Loro 文档
    loaded_cards: HashMap<String, LoroDoc>,

    /// SQLite 缓存数据库连接
    sqlite_conn: Connection,

    /// update.loro 文件大小阈值 (字节)
    ///
    /// 超过此阈值时合并到 snapshot.loro
    update_size_threshold: usize,
}

impl CardStore {
    /// 创建新的 CardStore 实例
    ///
    /// # 参数
    ///
    /// * `data_dir` - 数据目录路径 (必须存在)
    ///
    /// # 返回
    ///
    /// 返回初始化完成的 `CardStore` 实例
    ///
    /// # 错误
    ///
    /// * `IoError` - 目录不存在或无权限访问
    /// * `SqliteError` - SQLite 数据库初始化失败
    ///
    /// # 示例
    ///
    /// ```
    /// use card_mind::store::CardStore;
    /// use std::path::Path;
    ///
    /// let store = CardStore::new(Path::new("/path/to/data"))?;
    /// ```
    pub fn new(data_dir: &Path) -> Result<Self, CardMindError> {
        // 实现...
    }

    /// 创建新卡片
    ///
    /// 生成 UUID v7 作为卡片 ID,写入 Loro 文档,并自动同步到 SQLite。
    ///
    /// # 参数
    ///
    /// * `title` - 卡片标题 (可为空字符串)
    /// * `content` - Markdown 格式的内容 (不能为空)
    ///
    /// # 返回
    ///
    /// 返回创建的 `Card` 对象,包含生成的 UUID v7 和时间戳
    ///
    /// # 错误
    ///
    /// * `LoroError` - Loro commit 失败
    /// * `IoError` - 文件持久化失败
    ///
    /// # 示例
    ///
    /// ```
    /// let card = store.create_card("我的想法", "今天想到的一个点子")?;
    /// assert!(!card.id.is_empty());
    /// assert_eq!(card.title, "我的想法");
    /// ```
    ///
    /// # 内部流程
    ///
    /// 1. 生成 UUID v7
    /// 2. 创建 Loro 文档并插入数据
    /// 3. 调用 `commit()` 触发订阅
    /// 4. 订阅回调自动 INSERT 到 SQLite
    /// 5. 追加更新到 `update.loro`
    pub fn create_card(&mut self, title: &str, content: &str) -> Result<Card, CardMindError> {
        // 实现...
    }

    /// 获取所有未删除的卡片
    ///
    /// 从 SQLite 缓存查询,按创建时间降序排列 (最新的在前)。
    ///
    /// # 返回
    ///
    /// 返回卡片列表,自动过滤 `is_deleted = true` 的卡片
    ///
    /// # 错误
    ///
    /// * `SqliteError` - 数据库查询失败
    ///
    /// # 示例
    ///
    /// ```
    /// let cards = store.get_all_cards()?;
    /// for card in cards {
    ///     println!("{}: {}", card.title, card.content);
    /// }
    /// ```
    ///
    /// # 性能
    ///
    /// 利用 `(is_deleted, created_at DESC)` 复合索引,查询时间 < 10ms (1000 张卡片)
    pub fn get_all_cards(&self) -> Result<Vec<Card>, CardMindError> {
        // 实现...
    }

    /// 获取单个卡片
    ///
    /// # 参数
    ///
    /// * `id` - 卡片 UUID v7 字符串
    ///
    /// # 返回
    ///
    /// * `Some(Card)` - 找到卡片
    /// * `None` - 卡片不存在或已删除
    ///
    /// # 错误
    ///
    /// * `SqliteError` - 数据库查询失败
    ///
    /// # 示例
    ///
    /// ```
    /// match store.get_card("01234567-89ab-7def-0123-456789abcdef")? {
    ///     Some(card) => println!("找到卡片: {}", card.title),
    ///     None => println!("卡片不存在"),
    /// }
    /// ```
    pub fn get_card(&self, id: &str) -> Result<Option<Card>, CardMindError> {
        // 实现...
    }

    /// 更新卡片
    ///
    /// 修改 Loro 文档中的标题和内容,并自动更新 `updated_at` 字段。
    ///
    /// # 参数
    ///
    /// * `id` - 卡片 UUID v7 字符串
    /// * `title` - 新标题
    /// * `content` - 新内容
    ///
    /// # 返回
    ///
    /// 成功返回 `Ok(())`
    ///
    /// # 错误
    ///
    /// * `CardNotFound` - 卡片不存在
    /// * `LoroError` - Loro commit 失败
    /// * `IoError` - 文件持久化失败
    ///
    /// # 示例
    ///
    /// ```
    /// store.update_card(
    ///     card_id,
    ///     "更新后的标题",
    ///     "更新后的内容"
    /// )?;
    /// ```
    pub fn update_card(&mut self, id: &str, title: &str, content: &str) -> Result<(), CardMindError> {
        // 实现...
    }

    /// 删除卡片 (软删除)
    ///
    /// 设置 `is_deleted = true`,不真正删除数据,支持恢复。
    ///
    /// # 参数
    ///
    /// * `id` - 卡片 UUID v7 字符串
    ///
    /// # 返回
    ///
    /// 成功返回 `Ok(())`
    ///
    /// # 错误
    ///
    /// * `CardNotFound` - 卡片不存在
    /// * `LoroError` - Loro commit 失败
    ///
    /// # 示例
    ///
    /// ```
    /// store.delete_card(card_id)?;
    ///
    /// // 此时 get_all_cards() 不会返回这张卡片
    /// let cards = store.get_all_cards()?;
    /// ```
    ///
    /// # 注意
    ///
    /// - 这是软删除,文件仍保留,可通过 `restore_card` 恢复
    /// - 如需彻底删除,请手动删除 Loro 文件目录
    pub fn delete_card(&mut self, id: &str) -> Result<(), CardMindError> {
        // 实现...
    }
}
```

---

## 测试文档示例

```rust
#[cfg(test)]
mod tests {
    use super::*;

    /// 测试卡片创建流程
    ///
    /// # 验证
    ///
    /// - UUID v7 生成
    /// - Loro 文档创建
    /// - SQLite 自动同步
    #[test]
    fn test_create_card() {
        let mut store = CardStore::new_in_memory().unwrap();

        let card = store.create_card("测试标题", "测试内容").unwrap();

        // 验证 ID 不为空
        assert!(!card.id.is_empty());

        // 验证时间戳
        assert!(card.created_at > 0);
        assert_eq!(card.created_at, card.updated_at);

        // 验证 SQLite 同步
        let cards = store.get_all_cards().unwrap();
        assert_eq!(cards.len(), 1);
        assert_eq!(cards[0].id, card.id);
    }
}
```

---

## 配置 Cargo.toml

在 `rust/Cargo.toml` 中添加文档配置:

```toml
[package]
name = "card_mind"
version = "0.1.0"
edition = "2021"

# 文档配置
[package.metadata.docs.rs]
all-features = true
rustdoc-args = ["--document-private-items"]

# 文档示例需要的依赖
[dev-dependencies]
tempfile = "3.8"  # 用于测试临时文件
```

---

## 生成和查看文档

### 1. 生成 HTML 文档

```bash
cd rust
cargo doc --open
```

这会:
1. 生成所有 crate 的文档
2. 在浏览器中打开 `target/doc/card_mind/index.html`

### 2. 测试文档中的示例代码

```bash
cargo test --doc
```

这会运行文档注释中的所有 ` ``` ` 代码块。

### 3. 生成包含私有项的文档

```bash
cargo doc --document-private-items --open
```

用于查看内部实现的文档。

---

## 文档注释最佳实践总结

1. **所有公开 API 必须有文档注释**
2. **包含完整的示例代码** (可被 `cargo test --doc` 验证)
3. **明确列出所有可能的错误**
4. **使用标准章节** (Parameters, Returns, Errors, Examples)
5. **解释"为什么"而不只是"是什么"**
6. **保持简洁**,详细说明放在独立的 Markdown 文档
7. **定期运行 `cargo doc`** 确保文档正确

---

## 相关资源

- [Rust 文档注释官方指南](https://doc.rust-lang.org/rustdoc/)
- [API 文档最佳实践](https://rust-lang.github.io/api-guidelines/documentation.html)
- [DATA_MODELS.md](DATA_MODELS.md) - 数据模型快速参考
- [API_DESIGN.md](API_DESIGN.md) - API 设计理念

---

**提示**: 当您编写新的 Rust 代码时,请参考本文档添加完整的文档注释。这样可以确保 `cargo doc` 生成的文档始终是最新且准确的。
