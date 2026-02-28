// input: rust/src/models/error.rs 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Rust 数据模型模块，定义跨层共享的数据结构。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Rust 数据模型模块，定义跨层共享的数据结构。
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
