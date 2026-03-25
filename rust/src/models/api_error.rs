//! # API 错误模块
//!
//! 定义对外 API 的错误码和错误结构。
//!
//! ## 错误分类
//! - 配置错误：`AppConfigNotInitialized`, `AppConfigConflict`
//! - 参数错误：`InvalidArgument`, `InvalidPoolHash`, `InvalidKeyHash`, `InvalidHandle`
//! - 资源错误：`NotFound`, `PoolNotFound`
//! - 网络错误：`NetworkUnavailable`, `RequestTimeout`, `AdminOffline`
//! - 同步错误：`SyncTimeout`, `ProjectionNotConverged`
//! - 权限错误：`NotMember`, `AlreadyMember`, `RejectedByAdmin`
//! - 系统错误：`IoError`, `SqliteError`, `Internal`
//! - 未实现：`NotImplemented`

use serde::{Deserialize, Serialize};

/// 对外 API 错误码
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ApiErrorCode {
    /// 应用配置未初始化
    AppConfigNotInitialized,
    /// 应用配置目录冲突
    AppConfigConflict,
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
    /// 投影未收敛
    ProjectionNotConverged,
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
    /// 将错误码转换为稳定字符串表示。
    ///
    /// # 返回
    /// 错误码的大写字符串形式，如 `"APP_CONFIG_NOT_INITIALIZED"`。
    ///
    /// # Examples
    /// ```
    /// use cardmind_rust::models::api_error::ApiErrorCode;
    ///
    /// assert_eq!(ApiErrorCode::NotFound.as_str(), "NOT_FOUND");
    /// assert_eq!(ApiErrorCode::InvalidArgument.as_str(), "INVALID_ARGUMENT");
    /// ```
    pub fn as_str(&self) -> &'static str {
        match self {
            ApiErrorCode::AppConfigNotInitialized => "APP_CONFIG_NOT_INITIALIZED",
            ApiErrorCode::AppConfigConflict => "APP_CONFIG_CONFLICT",
            ApiErrorCode::InvalidArgument => "INVALID_ARGUMENT",
            ApiErrorCode::NotFound => "NOT_FOUND",
            ApiErrorCode::NotImplemented => "NOT_IMPLEMENTED",
            ApiErrorCode::IoError => "IO_ERROR",
            ApiErrorCode::SqliteError => "SQLITE_ERROR",
            ApiErrorCode::ProjectionNotConverged => "PROJECTION_NOT_CONVERGED",
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
    /// 创建新的 API 错误实例。
    ///
    /// # 参数
    /// * `code` - 错误码，决定错误的分类。
    /// * `message` - 人类可读的错误描述。
    ///
    /// # 返回
    /// 包含错误码和消息的 `ApiError` 实例。
    ///
    /// # Examples
    /// ```
    /// use cardmind_rust::models::api_error::{ApiError, ApiErrorCode};
    ///
    /// let err = ApiError::new(ApiErrorCode::NotFound, "card not found");
    /// assert_eq!(err.code, "NOT_FOUND");
    /// assert_eq!(err.message, "card not found");
    /// ```
    pub fn new(code: ApiErrorCode, message: &str) -> Self {
        Self {
            code: code.as_str().to_string(),
            message: message.to_string(),
        }
    }
}
