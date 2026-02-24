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
