use flutter_rust_bridge::frb;
use thiserror::Error;

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

    #[error("Invalid UUID: {0}")]
    InvalidUuid(String),

    #[error("Serialization error: {0}")]
    SerializationError(String),

    #[error("IO error: {0}")]
    IoError(String),

    #[error("Unknown error: {0}")]
    Unknown(String),
}

// Implement From traits for converting errors
impl From<rusqlite::Error> for CardMindError {
    fn from(err: rusqlite::Error) -> Self {
        CardMindError::DatabaseError(err.to_string())
    }
}

impl From<serde_json::Error> for CardMindError {
    fn from(err: serde_json::Error) -> Self {
        CardMindError::SerializationError(err.to_string())
    }
}

impl From<std::io::Error> for CardMindError {
    fn from(err: std::io::Error) -> Self {
        CardMindError::IoError(err.to_string())
    }
}

impl From<loro::LoroError> for CardMindError {
    fn from(err: loro::LoroError) -> Self {
        CardMindError::LoroError(err.to_string())
    }
}

impl From<loro::LoroEncodeError> for CardMindError {
    fn from(err: loro::LoroEncodeError) -> Self {
        CardMindError::LoroError(err.to_string())
    }
}

impl From<crate::security::password::PasswordError> for CardMindError {
    fn from(err: crate::security::password::PasswordError) -> Self {
        CardMindError::Unknown(err.to_string())
    }
}

impl From<crate::models::device_config::DeviceConfigError> for CardMindError {
    fn from(err: crate::models::device_config::DeviceConfigError) -> Self {
        CardMindError::DatabaseError(err.to_string())
    }
}

impl From<crate::security::keyring_store::KeyringError> for CardMindError {
    fn from(err: crate::security::keyring_store::KeyringError) -> Self {
        CardMindError::Unknown(err.to_string())
    }
}

/// Result type alias for CardMind operations
pub type Result<T> = std::result::Result<T, CardMindError>;
