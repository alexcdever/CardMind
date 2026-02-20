use thiserror::Error;

/// CardMind 统一错误类型
#[derive(Debug, Error)]
pub enum CardMindError {
    #[error("io error")]
    Io(#[from] std::io::Error),
    #[error("sqlite error")]
    Sqlite(#[from] rusqlite::Error),
}
