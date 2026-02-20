use rusqlite::{Connection, Result};
use std::path::Path;

/// SQLite 缓存存储
pub struct SqliteStore {
    _conn: Connection,
    ready: bool,
}

impl SqliteStore {
    /// 创建并初始化缓存 schema
    pub fn new(path: &Path) -> Result<Self> {
        let conn = Connection::open(path)?;
        conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS cards (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                content TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                deleted INTEGER NOT NULL
            );",
        )?;
        Ok(Self { _conn: conn, ready: true })
    }

    /// 判断缓存层是否可用
    pub fn is_ready(&self) -> bool {
        self.ready
    }
}
