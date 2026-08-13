use anyhow::Result;
use chrono::Utc;
use rusqlite::Connection;
use std::collections::BTreeSet;
use std::sync::Mutex;

use crate::sync::NoteCrdt;

/// SQLite 读投影 — 缓存 NoteCrdt 的扁平化视图
pub struct NoteStore {
    conn: Mutex<Connection>,
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

/// 链接行（outgoing/backlink 查询结果，FRB 可序列化）
#[derive(Debug)]
pub struct LinkRow {
    /// 对端笔记 id
    pub id: String,
    /// 对端实时标题（JOIN 得出，空串 = 悬空）
    pub title: String,
    /// 源正文里写的显示名
    pub alias: String,
    /// 对端笔记是否存在（false = 悬空链接）
    pub exists: bool,
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
            );
            CREATE TABLE IF NOT EXISTS links (
                source_id TEXT NOT NULL,
                target_id TEXT NOT NULL,
                alias     TEXT NOT NULL DEFAULT '',
                PRIMARY KEY (source_id, target_id)
            );
            CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
                title, content, tags,
                content='notes', content_rowid='rowid',
                tokenize='trigram'
            );
            CREATE TRIGGER IF NOT EXISTS notes_fts_ai AFTER INSERT ON notes BEGIN
                INSERT INTO notes_fts(rowid, title, content, tags)
                VALUES (new.rowid, new.title, new.content, new.tags);
            END;
            CREATE TRIGGER IF NOT EXISTS notes_fts_ad AFTER DELETE ON notes BEGIN
                INSERT INTO notes_fts(notes_fts, rowid, title, content, tags)
                VALUES ('delete', old.rowid, old.title, old.content, old.tags);
            END;
            CREATE TRIGGER IF NOT EXISTS notes_fts_au AFTER UPDATE ON notes BEGIN
                INSERT INTO notes_fts(notes_fts, rowid, title, content, tags)
                VALUES ('delete', old.rowid, old.title, old.content, old.tags);
                INSERT INTO notes_fts(rowid, title, content, tags)
                VALUES (new.rowid, new.title, new.content, new.tags);
            END;",
        )?;
        Ok(Self {
            conn: Mutex::new(conn),
        })
    }

    /// 同步一个 NoteCrdt 的内容到 SQLite（INSERT OR REPLACE）
    ///
    /// 从 LoroDoc 中读取当前内容 + 标题 + meta tags，写入 notes 表。
    /// 创建时间首次持久化后不再覆盖。末尾重建该笔记的 links 索引。
    pub fn sync_note(&self, note_id: &str, crdt: &NoteCrdt) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        let content = crdt.get_content();
        let title = crdt.get_title();
        let now = Utc::now().to_rfc3339();

        // 标签来自 NoteCrdt 的 meta tags（不再从正文提取）
        let tags = crdt.get_tags().join(",");

        // 读取已有 created_at，若不存在则使用当前时间
        let created_at: String = conn
            .query_row(
                "SELECT created_at FROM notes WHERE id = ?1",
                [note_id],
                |row| row.get(0),
            )
            .unwrap_or_else(|_| now.clone());

        conn.execute(
            "INSERT OR REPLACE INTO notes (id, title, content, tags, created_at, updated_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            rusqlite::params![note_id, title, content, tags, created_at, now],
        )?;

        // 重建链接索引：先删旧链接，再插入当前解析结果
        conn.execute("DELETE FROM links WHERE source_id = ?1", [note_id])?;
        for (target_id, alias) in crdt.parse_links() {
            conn.execute(
                "INSERT OR REPLACE INTO links (source_id, target_id, alias)
                 VALUES (?1, ?2, ?3)",
                rusqlite::params![note_id, target_id, alias],
            )?;
        }

        Ok(())
    }

    /// 返回旧 SQLite 中的完整内容，用于首次迁移到 Loro 真源。
    pub fn legacy_notes(&self) -> Result<Vec<(String, String)>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare("SELECT id, content FROM notes ORDER BY updated_at ASC")?;
        let rows = stmt
            .query_map([], |row| Ok((row.get(0)?, row.get(1)?)))?
            .collect::<std::result::Result<Vec<_>, _>>()?;
        Ok(rows)
    }

    /// 获取所有笔记（按更新时间倒序）
    pub fn list_notes(&self) -> Result<Vec<NoteRow>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, title, content, tags, updated_at FROM notes ORDER BY updated_at DESC",
        )?;

        let rows = stmt
            .query_map([], |row| {
                let content: String = row.get(2)?;
                let preview = Self::content_preview(&content);
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
        let conn = self.conn.lock().unwrap();
        let pattern = format!("%{}%", query);
        let mut stmt = conn.prepare(
            "SELECT id, title, content, tags, updated_at FROM notes
             WHERE title LIKE ?1 OR content LIKE ?1 OR tags LIKE ?1
             ORDER BY updated_at DESC",
        )?;

        let rows = stmt
            .query_map([&pattern], |row| {
                let content: String = row.get(2)?;
                let preview = Self::content_preview(&content);
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

    /// 全文搜索（FTS5，trigram tokenizer）
    ///
    /// - 查询少于 3 个字符时回退 LIKE 搜索
    /// - ≥3 字符走 FTS5 MATCH + ORDER BY bm25，preview 用 snippet 取匹配上下文
    /// - 特殊字符（双引号等）转义后作为短语查询
    pub fn search_notes(&self, query: &str) -> Result<Vec<NoteRow>> {
        if query.chars().count() < 3 {
            return self.search(query);
        }
        let escaped = query.replace('"', "\"\"");
        let match_expr = format!("\"{}\"", escaped);
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT n.id, n.title, n.content, n.tags, n.updated_at,
                    snippet(notes_fts, 1, '', '', '…', 12)
             FROM notes_fts
             JOIN notes n ON n.rowid = notes_fts.rowid
             WHERE notes_fts MATCH ?1
             ORDER BY bm25(notes_fts)",
        )?;

        let rows = stmt
            .query_map([&match_expr], |row| {
                let content: String = row.get(2)?;
                let fallback = Self::content_preview(&content);
                let snippet: String = row.get(5)?;
                let preview = if snippet.trim().is_empty() {
                    fallback
                } else {
                    snippet
                };
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

    /// 出链查询：note_id 指向的所有链接
    pub fn outgoing_links(&self, note_id: &str) -> Result<Vec<LinkRow>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT l.target_id, n.title, l.alias
             FROM links l
             LEFT JOIN notes n ON n.id = l.target_id
             WHERE l.source_id = ?1
             ORDER BY l.target_id",
        )?;

        let rows = stmt
            .query_map([note_id], |row| {
                let title: Option<String> = row.get(1)?;
                Ok(LinkRow {
                    id: row.get(0)?,
                    title: title.clone().unwrap_or_default(),
                    alias: row.get(2)?,
                    exists: title.is_some(),
                })
            })?
            .collect::<std::result::Result<Vec<_>, _>>()?;

        Ok(rows)
    }

    /// 反链查询：指向 note_id 的所有链接
    pub fn backlinks(&self, note_id: &str) -> Result<Vec<LinkRow>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT l.source_id, n.title, l.alias
             FROM links l
             LEFT JOIN notes n ON n.id = l.source_id
             WHERE l.target_id = ?1
             ORDER BY l.source_id",
        )?;

        let rows = stmt
            .query_map([note_id], |row| {
                let title: Option<String> = row.get(1)?;
                Ok(LinkRow {
                    id: row.get(0)?,
                    title: title.clone().unwrap_or_default(),
                    alias: row.get(2)?,
                    exists: title.is_some(),
                })
            })?
            .collect::<std::result::Result<Vec<_>, _>>()?;

        Ok(rows)
    }

    /// 链接自动补全：按标题前缀匹配，取最近更新的 20 条
    pub fn auto_complete_links(&self, prefix: &str) -> Result<Vec<NoteRow>> {
        let conn = self.conn.lock().unwrap();
        let escaped = prefix
            .replace('\\', "\\\\")
            .replace('%', "\\%")
            .replace('_', "\\_");
        let pattern = format!("{}%", escaped);
        let mut stmt = conn.prepare(
            "SELECT id, title, content, tags, updated_at FROM notes
             WHERE title LIKE ?1 ESCAPE '\\'
             ORDER BY updated_at DESC
             LIMIT 20",
        )?;

        let rows = stmt
            .query_map([&pattern], |row| {
                let content: String = row.get(2)?;
                let preview = Self::content_preview(&content);
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

    /// 解析全部笔记的 tags 列，去重并按名称排序
    pub fn get_all_tags(&self) -> Result<Vec<String>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare("SELECT tags FROM notes")?;
        let tag_rows: Vec<String> = stmt
            .query_map([], |row| row.get(0))?
            .collect::<std::result::Result<Vec<_>, _>>()?;

        let mut tags = BTreeSet::new();
        for row in tag_rows {
            for tag in row.split(',') {
                let tag = tag.trim();
                if !tag.is_empty() {
                    tags.insert(tag.to_string());
                }
            }
        }
        Ok(tags.into_iter().collect())
    }

    /// 按标签搜索笔记（tags 列 LIKE 匹配）
    pub fn search_by_tag(&self, tag: &str) -> Result<Vec<NoteRow>> {
        let conn = self.conn.lock().unwrap();
        let pattern = format!("%{}%", tag);
        let mut stmt = conn.prepare(
            "SELECT id, title, content, tags, updated_at FROM notes
             WHERE tags LIKE ?1
             ORDER BY updated_at DESC",
        )?;

        let rows = stmt
            .query_map([&pattern], |row| {
                let content: String = row.get(2)?;
                let preview = Self::content_preview(&content);
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

    /// 预览只包含正文：移除标题首行及标签 marker，避免列表重复显示标题。
    fn content_preview(content: &str) -> String {
        content
            .lines()
            .skip(1)
            .filter(|line| !line.trim_start().starts_with("<!--tags:") || !line.contains("-->"))
            .collect::<Vec<_>>()
            .join("\n")
            .trim()
            .chars()
            .take(80)
            .collect()
    }
}
