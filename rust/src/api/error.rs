// API错误类型定义

use thiserror::Error;

/// API操作可能返回的错误类型
#[derive(Error, Debug)]
pub enum ApiError {
    /// 数据库操作错误
    #[error("数据库错误: {0}")]
    DatabaseError(#[from] sea_orm::DbErr),

    /// UUID解析错误
    #[error("无效的UUID: {0}")]
    InvalidUuid(#[from] uuid::Error),

    /// 输入验证错误
    #[error("输入验证失败: {0}")]
    ValidationError(String),

    /// 资源未找到错误
    #[error("资源未找到: {0}")]
    NotFound(String),

    /// 权限错误（如密码错误）
    #[error("权限错误: {0}")]
    PermissionDenied(String),

    /// 密码哈希错误
    #[error("密码处理错误: {0}")]
    PasswordError(String),

    /// 业务逻辑错误
    #[error("业务错误: {0}")]
    BusinessLogic(String),

    /// 内部错误
    #[error("内部错误: {0}")]
    Internal(String),
}

impl ApiError {
    /// 创建验证错误
    pub fn validation<S: Into<String>>(msg: S) -> Self {
        ApiError::ValidationError(msg.into())
    }

    /// 创建未找到错误
    pub fn not_found<S: Into<String>>(msg: S) -> Self {
        ApiError::NotFound(msg.into())
    }

    /// 创建权限错误
    pub fn permission_denied<S: Into<String>>(msg: S) -> Self {
        ApiError::PermissionDenied(msg.into())
    }

    /// 创建业务逻辑错误
    pub fn business<S: Into<String>>(msg: S) -> Self {
        ApiError::BusinessLogic(msg.into())
    }

    /// 创建内部错误
    pub fn internal<S: Into<String>>(msg: S) -> Self {
        ApiError::Internal(msg.into())
    }
}

/// 将ApiError转换为String（用于FFI）
impl From<ApiError> for String {
    fn from(error: ApiError) -> Self {
        error.to_string()
    }
}

/// 将String转换为ApiError（用于CRDT等返回String错误的函数）
impl From<String> for ApiError {
    fn from(error: String) -> Self {
        ApiError::Internal(error)
    }
}

/// API操作的Result类型别名
pub type ApiResult<T> = Result<T, ApiError>;
