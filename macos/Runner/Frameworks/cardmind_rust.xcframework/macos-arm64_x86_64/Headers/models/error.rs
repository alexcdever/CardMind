use flutter_rust_bridge::frb;
use thiserror::Error;

/// mDNS 错误类型
#[derive(Error, Debug, Clone, PartialEq, Eq)]
#[frb(dart_metadata=("freezed"))]
pub enum MdnsError {
    #[error("mDNS 权限不足: {0}")]
    PermissionDenied(String),

    #[error("mDNS Socket 不可用: {0}")]
    SocketUnavailable(String),

    #[error("mDNS 不支持: {0}")]
    Unsupported(String),

    #[error("mDNS 启动失败: {0}")]
    StartFailed(String),
}

impl MdnsError {
    #[must_use]
    pub fn from_message(message: &str) -> Self {
        let lowered = message.to_lowercase();
        if lowered.contains("permission denied") || lowered.contains("operation not permitted") {
            Self::PermissionDenied(message.to_string())
        } else if lowered.contains("address in use")
            || lowered.contains("address already in use")
            || lowered.contains("addrinuse")
            || lowered.contains("eaddrinuse")
            || lowered.contains("socket")
        {
            Self::SocketUnavailable(message.to_string())
        } else if lowered.contains("unsupported") || lowered.contains("not supported") {
            Self::Unsupported(message.to_string())
        } else {
            Self::StartFailed(message.to_string())
        }
    }
}

/// 业务状态错误
#[derive(Error, Debug, Clone, PartialEq, Eq)]
#[frb(dart_metadata=("freezed"))]
pub enum InvalidStateError {
    #[error("NotJoinedPool: 设备未加入任何数据池")]
    NotJoinedPool,
}

/// 输入校验错误
#[derive(Error, Debug, Clone, PartialEq, Eq)]
#[frb(dart_metadata=("freezed"))]
pub enum ValidationError {
    #[error("标题不能为空")]
    TitleEmpty,

    #[error("标题长度不能超过200字符")]
    TitleTooLong,

    #[error("内容不能为空")]
    ContentEmpty,

    #[error("PeerId 格式无效")]
    PeerIdInvalid,

    #[error("设备名称不能为空")]
    DeviceNameEmpty,

    #[error("设备名称长度不能超过50字符")]
    DeviceNameTooLong,

    #[error("数据池 ID 不能为空")]
    PoolIdEmpty,

    #[error("数据池 ID 与所有权不匹配")]
    PoolIdInvalid,

    #[error("设备 ID 格式无效")]
    DeviceIdInvalid,
}

/// CardMind error types
#[derive(Error, Debug, Clone)]
#[frb(dart_metadata=("freezed"))]
pub enum CardMindError {
    #[error("Loro CRDT error: {0}")]
    LoroError(String),

    #[error("SQLite database error: {0}")]
    DatabaseError(String),

    #[error("Card not found: {0}")]
    CardNotFound(String),

    #[error("Not authorized: {0}")]
    NotAuthorized(String),

    #[error("Invalid UUID: {0}")]
    InvalidUuid(String),

    #[error("Serialization error: {0}")]
    SerializationError(String),

    #[error("IO error: {0}")]
    IoError(String),

    #[error("mDNS error: {0}")]
    Mdns(MdnsError),

    #[error("Invalid state: {0}")]
    InvalidState(InvalidStateError),

    #[error("Validation error: {0}")]
    Validation(ValidationError),

    #[error("Unknown error: {0}")]
    Unknown(String),
}

// Implement From traits for converting errors
impl From<rusqlite::Error> for CardMindError {
    fn from(err: rusqlite::Error) -> Self {
        Self::DatabaseError(err.to_string())
    }
}

impl From<serde_json::Error> for CardMindError {
    fn from(err: serde_json::Error) -> Self {
        Self::SerializationError(err.to_string())
    }
}

impl From<std::io::Error> for CardMindError {
    fn from(err: std::io::Error) -> Self {
        Self::IoError(err.to_string())
    }
}

impl From<loro::LoroError> for CardMindError {
    fn from(err: loro::LoroError) -> Self {
        Self::LoroError(err.to_string())
    }
}

impl From<loro::LoroEncodeError> for CardMindError {
    fn from(err: loro::LoroEncodeError) -> Self {
        Self::LoroError(err.to_string())
    }
}

impl From<crate::security::password::PasswordError> for CardMindError {
    fn from(err: crate::security::password::PasswordError) -> Self {
        Self::Unknown(err.to_string())
    }
}

impl From<crate::models::device_config::DeviceConfigError> for CardMindError {
    fn from(err: crate::models::device_config::DeviceConfigError) -> Self {
        match err {
            crate::models::device_config::DeviceConfigError::ValidationError(validation) => {
                Self::Validation(validation)
            }
            other => Self::DatabaseError(other.to_string()),
        }
    }
}

impl From<MdnsError> for CardMindError {
    fn from(err: MdnsError) -> Self {
        Self::Mdns(err)
    }
}

impl From<ValidationError> for CardMindError {
    fn from(err: ValidationError) -> Self {
        Self::Validation(err)
    }
}

/// Result type alias for CardMind operations
pub type Result<T> = std::result::Result<T, CardMindError>;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_should_display_validation_error_messages() {
        assert_eq!(ValidationError::TitleEmpty.to_string(), "标题不能为空");
        assert_eq!(
            ValidationError::DeviceNameTooLong.to_string(),
            "设备名称长度不能超过50字符"
        );
    }

    #[test]
    fn it_should_convert_validation_error_to_cardmind_error() {
        let err: CardMindError = ValidationError::ContentEmpty.into();
        assert!(matches!(
            err,
            CardMindError::Validation(ValidationError::ContentEmpty)
        ));
    }
}
