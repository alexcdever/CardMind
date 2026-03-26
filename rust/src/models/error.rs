//! # 错误模型
//!
//! 定义 CardMind 应用的统一错误类型 `CardMindError`，用于收敛各子系统的错误语义。
//!
//! ## 设计目标
//!
//! - 统一 Rust 侧所有错误的表示形式
//! - 提供清晰的错误分类和可读的错误信息
//! - 支持错误传播和上下文转换
//! - 便于映射到 API 层的 [`ApiErrorCode`](crate::models::api_error::ApiErrorCode)
//!
//! ## 错误分类
//!
//! | 错误类型 | 说明 | 典型场景 |
//! |---------|------|---------|
//! | `Io` | IO 错误 | 文件读写、网络操作失败 |
//! | `Sqlite` | 数据库错误 | SQLite 查询或事务失败 |
//! | `Loro` | CRDT 错误 | Loro 文档操作失败 |
//! | `InvalidArgument` | 参数非法 | 输入验证失败 |
//! | `NotFound` | 未找到 | 查询的资源不存在 |
//! | `ProjectionNotConverged` | 投影未收敛 | 数据投影未完成，需重试 |
//! | `NotImplemented` | 未实现 | 调用了未实现的功能 |
//! | `NotMember` | 非成员 | 操作需要成员权限但当前非成员 |
//! | `Internal` | 内部错误 | 未知的内部故障 |
//!
//! ## 使用示例
//!
//! ```rust
//! use cardmind_rust::models::error::CardMindError;
//!
//! fn may_fail() -> Result<(), CardMindError> {
//!     // 返回 IO 错误
//!     Err(CardMindError::Io("文件读取失败".to_string()))
//! }
//!
//! fn find_user(id: &str) -> Result<String, CardMindError> {
//!     // 返回未找到错误
//!     Err(CardMindError::NotFound(format!("用户 {} 不存在", id)))
//! }
//! ```

use thiserror::Error;

/// CardMind 统一错误类型
///
/// 应用内所有错误的标准表示，使用 `thiserror` 派生实现 `std::error::Error`。
/// 每个变体包含描述性字符串，提供人类可读的错误信息。
///
/// # 变体说明
///
/// - `Io`: 底层 IO 操作失败（文件系统、网络等）
/// - `Sqlite`: SQLite 数据库操作失败
/// - `Loro`: Loro CRDT 库操作失败
/// - `InvalidArgument`: 输入参数验证失败
/// - `NotFound`: 请求的资源不存在
/// - `ProjectionNotConverged`: 数据投影未完成，建议稍后重试
/// - `NotImplemented`: 功能尚未实现
/// - `NotMember`: 当前用户不是数据池成员
/// - `Internal`: 内部逻辑错误或意外状态
#[derive(Debug, Error)]
pub enum CardMindError {
    /// IO 错误
    ///
    /// 文件系统、网络或其他 IO 操作失败时返回。
    /// 包含原始错误信息的字符串描述。
    #[error("io error: {0}")]
    Io(String),

    /// SQLite 错误
    ///
    /// 数据库查询、事务或连接失败时返回。
    /// 通常由 `rusqlite` 错误转换而来。
    #[error("sqlite error: {0}")]
    Sqlite(String),

    /// Loro 错误
    ///
    /// Loro CRDT 文档操作失败时返回。
    /// 包括文档导入/导出、更新应用等错误。
    #[error("loro error: {0}")]
    Loro(String),

    /// 参数非法
    ///
    /// 输入参数未通过验证时返回。
    /// 例如：空字符串、无效 UUID 格式、越界值等。
    #[error("invalid argument: {0}")]
    InvalidArgument(String),

    /// 未找到
    ///
    /// 按 ID 或条件查询的资源不存在时返回。
    /// 例如：卡片不存在、数据池不存在等。
    #[error("not found: {0}")]
    NotFound(String),

    /// 投影未收敛
    ///
    /// 事件溯源投影尚未完成时返回。
    /// 这通常是一个临时状态，客户端应稍后重试。
    ///
    /// # 字段
    ///
    /// - `entity`: 实体类型名称（如 "Card", "Pool"）
    /// - `entity_id`: 实体标识符
    /// - `retry_action`: 建议的重试操作描述
    #[error("projection not converged: {entity}:{entity_id}, retry via {retry_action}")]
    ProjectionNotConverged {
        /// 实体类型
        entity: String,
        /// 实体 ID
        entity_id: String,
        /// 重试操作建议
        retry_action: String,
    },

    /// 未实现
    ///
    /// 调用了尚未实现的功能时返回。
    /// 通常在开发中的功能占位使用。
    #[error("not implemented: {0}")]
    NotImplemented(String),

    /// 非成员
    ///
    /// 执行需要数据池成员权限的操作，但当前设备不是成员时返回。
    /// 例如：尝试同步非成员池的数据。
    #[error("not member: {0}")]
    NotMember(String),

    /// 内部错误
    ///
    /// 不应发生的内部逻辑错误或意外状态。
    /// 此类错误通常表示代码缺陷，需要开发者关注。
    #[error("internal error: {0}")]
    Internal(String),
}

impl CardMindError {
    /// 创建 IO 错误
    ///
    /// # 参数
    ///
    /// * `msg` - 错误描述信息
    ///
    /// # 返回
    ///
    /// 返回 `CardMindError::Io` 变体。
    ///
    /// # 示例
    ///
    /// ```rust
    /// use cardmind_rust::models::error::CardMindError;
    ///
    /// let err = CardMindError::io("文件未找到");
    /// assert!(matches!(err, CardMindError::Io(_)));
    /// ```
    pub fn io(msg: impl Into<String>) -> Self {
        Self::Io(msg.into())
    }

    /// 创建 SQLite 错误
    ///
    /// # 参数
    ///
    /// * `msg` - 错误描述信息
    ///
    /// # 返回
    ///
    /// 返回 `CardMindError::Sqlite` 变体。
    pub fn sqlite(msg: impl Into<String>) -> Self {
        Self::Sqlite(msg.into())
    }

    /// 创建 Loro 错误
    ///
    /// # 参数
    ///
    /// * `msg` - 错误描述信息
    ///
    /// # 返回
    ///
    /// 返回 `CardMindError::Loro` 变体。
    pub fn loro(msg: impl Into<String>) -> Self {
        Self::Loro(msg.into())
    }

    /// 创建参数非法错误
    ///
    /// # 参数
    ///
    /// * `msg` - 错误描述信息
    ///
    /// # 返回
    ///
    /// 返回 `CardMindError::InvalidArgument` 变体。
    ///
    /// # 示例
    ///
    /// ```rust
    /// use cardmind_rust::models::error::CardMindError;
    ///
    /// let err = CardMindError::invalid_argument("ID 不能为空");
    /// assert!(matches!(err, CardMindError::InvalidArgument(_)));
    /// ```
    pub fn invalid_argument(msg: impl Into<String>) -> Self {
        Self::InvalidArgument(msg.into())
    }

    /// 创建未找到错误
    ///
    /// # 参数
    ///
    /// * `msg` - 错误描述信息
    ///
    /// # 返回
    ///
    /// 返回 `CardMindError::NotFound` 变体。
    pub fn not_found(msg: impl Into<String>) -> Self {
        Self::NotFound(msg.into())
    }

    /// 创建投影未收敛错误
    ///
    /// # 参数
    ///
    /// * `entity` - 实体类型名称
    /// * `entity_id` - 实体标识符
    /// * `retry_action` - 建议的重试操作
    ///
    /// # 返回
    ///
    /// 返回 `CardMindError::ProjectionNotConverged` 变体。
    ///
    /// # 示例
    ///
    /// ```rust
    /// use cardmind_rust::models::error::CardMindError;
    ///
    /// let err = CardMindError::projection_not_converged(
    ///     "Card",
    ///     "550e8400-e29b-41d4-a716-446655440000",
    ///     "等待 1 秒后重试"
    /// );
    /// assert!(matches!(err, CardMindError::ProjectionNotConverged { .. }));
    /// ```
    pub fn projection_not_converged(
        entity: impl Into<String>,
        entity_id: impl Into<String>,
        retry_action: impl Into<String>,
    ) -> Self {
        Self::ProjectionNotConverged {
            entity: entity.into(),
            entity_id: entity_id.into(),
            retry_action: retry_action.into(),
        }
    }

    /// 创建未实现错误
    ///
    /// # 参数
    ///
    /// * `msg` - 错误描述信息
    ///
    /// # 返回
    ///
    /// 返回 `CardMindError::NotImplemented` 变体。
    pub fn not_implemented(msg: impl Into<String>) -> Self {
        Self::NotImplemented(msg.into())
    }

    /// 创建非成员错误
    ///
    /// # 参数
    ///
    /// * `msg` - 错误描述信息
    ///
    /// # 返回
    ///
    /// 返回 `CardMindError::NotMember` 变体。
    pub fn not_member(msg: impl Into<String>) -> Self {
        Self::NotMember(msg.into())
    }

    /// 创建内部错误
    ///
    /// # 参数
    ///
    /// * `msg` - 错误描述信息
    ///
    /// # 返回
    ///
    /// 返回 `CardMindError::Internal` 变体。
    pub fn internal(msg: impl Into<String>) -> Self {
        Self::Internal(msg.into())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// 测试错误类型的字符串显示格式
    #[test]
    fn test_error_display() {
        let err = CardMindError::io("test error");
        assert_eq!(format!("{}", err), "io error: test error");

        let err = CardMindError::not_found("card 123");
        assert_eq!(format!("{}", err), "not found: card 123");
    }

    /// 测试投影未收敛错误的格式化输出
    #[test]
    fn test_projection_not_converged() {
        let err = CardMindError::projection_not_converged("Card", "abc", "retry");
        let display = format!("{}", err);
        assert!(display.contains("projection not converged"));
        assert!(display.contains("Card"));
        assert!(display.contains("abc"));
    }

    /// 测试错误变体辅助构造函数的创建结果
    #[test]
    fn test_error_variant_helpers() {
        assert!(matches!(CardMindError::io("test"), CardMindError::Io(_)));
        assert!(matches!(
            CardMindError::sqlite("test"),
            CardMindError::Sqlite(_)
        ));
        assert!(matches!(
            CardMindError::loro("test"),
            CardMindError::Loro(_)
        ));
        assert!(matches!(
            CardMindError::invalid_argument("test"),
            CardMindError::InvalidArgument(_)
        ));
        assert!(matches!(
            CardMindError::not_found("test"),
            CardMindError::NotFound(_)
        ));
        assert!(matches!(
            CardMindError::not_implemented("test"),
            CardMindError::NotImplemented(_)
        ));
        assert!(matches!(
            CardMindError::not_member("test"),
            CardMindError::NotMember(_)
        ));
        assert!(matches!(
            CardMindError::internal("test"),
            CardMindError::Internal(_)
        ));
    }
}
