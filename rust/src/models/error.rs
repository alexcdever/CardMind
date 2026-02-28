// input: IO/SQLite/Loro/参数校验等子系统在业务流程中产生的错误上下文字符串。
// output: 统一 CardMindError 枚举，供各层传播并在 API 层映射。
// pos: 领域错误模型定义文件，负责收敛 Rust 侧通用错误语义。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件定义统一业务错误类型。
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
    /// 非成员
    #[error("not member: {0}")]
    NotMember(String),
    /// 内部错误
    #[error("internal error: {0}")]
    Internal(String),
}
