use anyhow::Result;
use chrono::Utc;
use rusqlite::Connection;

use crate::sync::NoteCrdt;

/// SQLite 读投影 — 缓存 NoteCrdt 的扁平化视图
pub struct NoteStore {
    conn: Connection,
}

/// 笔记的只读行（从 SQLite 反查）
#[derive(Debug)]
pub struct NoteRow {
    pub id: String,
    pub title: String,
    pub content_preview: String,
    pub tags: String,
    pub updated_at: String,
}

impl NoteStore {
    /// 创建/打开 SQLite 数据库，自动建表
    pub fn new(path: &str) -> Result<Self> {
        let conn = Connection::open(path)?;
        conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS notes (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                content TEXT NOT NULL,
                tags TEXT NOT NULL DEFAULT '',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );",
        )?;
        Ok(Self { conn })
    }

    /// 同步一个 NoteCrdt 的内容到 SQLite（INSERT OR REPLACE）
    ///
    /// 从 LoroDoc 中读取当前内容 + 标题，写入 notes 表。
    /// 创建时间首次持久化后不再覆盖。
    pub fn sync_note(&self, note_id: &str, crdt: &NoteCrdt) -> Result<()> {
        let content = crdt.get_content();
        let title = crdt.get_title();
        let now = Utc::now().to_rfc3339();

        // 读取已有 created_at，若不存在则使用当前时间
        let created_at: String = self
            .conn
            .query_row(
                "SELECT created_at FROM notes WHERE id = ?1",
                [note_id],
                |row| row.get(0),
            )
            .unwrap_or_else(|_| now.clone());

        self.conn.execute(
            "INSERT OR REPLACE INTO notes (id, title, content, tags, created_at, updated_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            rusqlite::params![note_id, title, content, "", created_at, now],
        )?;

        Ok(())
    }

    /// 获取所有笔记（按更新时间倒序）
    pub fn list_notes(&self) -> Result<Vec<NoteRow>> {
        let mut stmt = self.conn.prepare(
            "SELECT id, title, content, tags, updated_at FROM notes ORDER BY updated_at DESC",
        )?;

        let rows = stmt
            .query_map([], |row| {
                let content: String = row.get(2)?;
                let preview: String = content.chars().take(80).collect();
                Ok(NoteRow {
                    id: row.get(0)?,
                    title: row.get(1)?,
                    content_preview: preview,
                    tags: row.get(3)?,
                    updated_at: row.get(4)?,
                })
            })?
            .collect::<std::result::Result<Vec<_>, _>>()?;

        Ok(rows)
    }

    /// 搜索笔记（标题/内容/标签 LIKE 匹配）
    ///
    /// `query` 中的特殊 LIKE 字符（`%`、`_`）会被原样搜索。
    pub fn search(&self, query: &str) -> Result<Vec<NoteRow>> {
        let pattern = format!("%{}%", query);
        let mut stmt = self.conn.prepare(
            "SELECT id, title, content, tags, updated_at FROM notes
             WHERE title LIKE ?1 OR content LIKE ?1 OR tags LIKE ?1
             ORDER BY updated_at DESC",
        )?;

        let rows = stmt
            .query_map([&pattern], |row| {
                let content: String = row.get(2)?;
                let preview: String = content.chars().take(80).collect();
                Ok(NoteRow {
                    id: row.get(0)?,
                    title: row.get(1)?,
                    content_preview: preview,
                    tags: row.get(3)?,
                    updated_at: row.get(4)?,
                })
            })?
            .collect::<std::result::Result<Vec<_>, _>>()?;

        Ok(rows)
    }
}
