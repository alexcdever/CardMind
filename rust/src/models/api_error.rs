// input: rust/src/models/api_error.rs 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Rust 数据模型模块，定义跨层共享的数据结构。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Rust 数据模型模块，定义跨层共享的数据结构。
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
    /// 非成员
    NotMember,
    /// 网络不可用
    NetworkUnavailable,
    /// 同步超时
    SyncTimeout,
    /// 句柄无效
    InvalidHandle,
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
            ApiErrorCode::NotMember => "NOT_MEMBER",
            ApiErrorCode::NetworkUnavailable => "NETWORK_UNAVAILABLE",
            ApiErrorCode::SyncTimeout => "SYNC_TIMEOUT",
            ApiErrorCode::InvalidHandle => "INVALID_HANDLE",
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

impl std::fmt::Display for ApiError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}: {}", self.code, self.message)
    }
}

impl std::error::Error for ApiError {}

impl ApiError {
    /// 创建 ApiError
    pub fn new(code: ApiErrorCode, message: &str) -> Self {
        Self {
            code: code.as_str().to_string(),
            message: message.to_string(),
        }
    }
}
