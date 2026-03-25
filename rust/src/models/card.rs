//! # 卡片模型
//!
//! 定义 CardMind 应用的卡片领域模型，包含卡片的元数据和内容。
//!
//! ## 数据结构
//!
//! - `Card` - 卡片实体，包含完整的卡片信息
//!
//! ## 设计说明
//!
//! 本模块仅定义数据结构，不包含业务逻辑。卡片模型用于：
//! - 存储层与序列化流程的数据交换
//! - API 层与客户端的数据共享
//! - 同步模块的数据传输
//!
//! ## 字段约束
//!
//! - `id`: UUID v7 格式，全局唯一标识
//! - `created_at`/`updated_at`: Unix 时间戳（秒级）
//! - `deleted`: 软删除标记，避免物理删除导致的数据丢失
//!
//! ## 示例
//!
//! ```rust
//! use uuid::Uuid;
//! use cardmind_rust::models::card::Card;
//!
//! let card = Card {
//!     id: Uuid::now_v7(),
//!     title: "Rust 学习笔记".to_string(),
//!     content: "# 所有权\n\nRust 的核心特性...".to_string(),
//!     created_at: 1700000000,
//!     updated_at: 1700000000,
//!     deleted: false,
//! };
//! ```

use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// 卡片实体
///
/// 表示用户创建的单张卡片，包含标题、内容、时间戳和删除标记。
/// 支持序列化和反序列化，用于存储和 API 传输。
///
/// # 字段说明
///
/// - `id`: 卡片唯一标识符（UUID v7）
/// - `title`: 卡片标题，用户可编辑
/// - `content`: 卡片正文内容，支持 Markdown 格式
/// - `created_at`: 创建时间戳（Unix 秒）
/// - `updated_at`: 最后更新时间戳（Unix 秒）
/// - `deleted`: 软删除标记，`true` 表示已删除但未物理清除
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Card {
    /// 卡片 ID（UUID v7）
    ///
    /// 使用 UUID v7 生成，保证全局唯一性和大致有序性，
    /// 便于数据库索引和时间范围查询。
    pub id: Uuid,

    /// 卡片标题
    ///
    /// 用户为卡片指定的简短标题，用于列表展示和搜索。
    /// 长度限制由上层业务逻辑控制。
    pub title: String,

    /// 卡片正文（Markdown）
    ///
    /// 支持 Markdown 格式的富文本内容，可包含代码块、
    /// 列表、链接等元素。内容由用户在编辑器中编写。
    pub content: String,

    /// 创建时间（秒）
    ///
    /// Unix 时间戳，精确到秒。创建后不可修改。
    pub created_at: i64,

    /// 更新时间（秒）
    ///
    /// Unix 时间戳，精确到秒。每次内容修改时自动更新。
    pub updated_at: i64,

    /// 软删除标记
    ///
    /// `true` 表示卡片已被用户删除，但数据仍保留在存储中。
    /// 支持数据恢复和同步冲突处理。
    pub deleted: bool,
}

impl Card {
    /// 创建新卡片
    ///
    /// 自动生成 UUID v7 ID 和当前时间戳。
    ///
    /// # 参数
    ///
    /// * `title` - 卡片标题
    /// * `content` - 卡片内容（Markdown）
    ///
    /// # 返回
    ///
    /// 返回一个新创建的 `Card` 实例，`deleted` 默认为 `false`。
    ///
    /// # 示例
    ///
    /// ```rust
    /// use cardmind_rust::models::card::Card;
    ///
    /// let card = Card::new("Hello".to_string(), "World".to_string());
    /// assert!(!card.deleted);
    /// ```
    pub fn new(title: String, content: String) -> Self {
        let now = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs() as i64;

        Self {
            id: Uuid::now_v7(),
            title,
            content,
            created_at: now,
            updated_at: now,
            deleted: false,
        }
    }

    /// 标记卡片为已删除
    ///
    /// 软删除操作，将 `deleted` 设为 `true` 并更新 `updated_at`。
    /// 数据仍保留在存储中，可通过恢复操作还原。
    ///
    /// # 示例
    ///
    /// ```rust
    /// use cardmind_rust::models::card::Card;
    ///
    /// let mut card = Card::new("Test".to_string(), "Content".to_string());
    /// card.mark_deleted();
    /// assert!(card.deleted);
    /// ```
    pub fn mark_deleted(&mut self) {
        self.deleted = true;
        self.updated_at = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs() as i64;
    }

    /// 恢复已删除的卡片
    ///
    /// 将 `deleted` 设为 `false` 并更新 `updated_at`。
    ///
    /// # 示例
    ///
    /// ```rust
    /// use cardmind_rust::models::card::Card;
    ///
    /// let mut card = Card::new("Test".to_string(), "Content".to_string());
    /// card.mark_deleted();
    /// card.restore();
    /// assert!(!card.deleted);
    /// ```
    pub fn restore(&mut self) {
        self.deleted = false;
        self.updated_at = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs() as i64;
    }

    /// 更新卡片内容
    ///
    /// 修改标题和内容，自动更新 `updated_at` 时间戳。
    ///
    /// # 参数
    ///
    /// * `title` - 新标题
    /// * `content` - 新内容
    ///
    /// # 示例
    ///
    /// ```rust
    /// use cardmind_rust::models::card::Card;
    ///
    /// let mut card = Card::new("Old".to_string(), "Old content".to_string());
    /// let old_updated = card.updated_at;
    /// card.update("New".to_string(), "New content".to_string());
    /// assert_eq!(card.title, "New");
    /// assert!(card.updated_at >= old_updated);
    /// ```
    pub fn update(&mut self, title: String, content: String) {
        self.title = title;
        self.content = content;
        self.updated_at = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs() as i64;
    }
}
