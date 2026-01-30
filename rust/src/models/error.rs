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

    #[error("Not authorized: {0}")]
    NotAuthorized(String),

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
        Self::DatabaseError(err.to_string())
    }
}

impl From<crate::security::keyring_store::KeyringError> for CardMindError {
    fn from(err: crate::security::keyring_store::KeyringError) -> Self {
        Self::Unknown(err.to_string())
    }
}

/// Result type alias for CardMind operations
pub type Result<T> = std::result::Result<T, CardMindError>;
