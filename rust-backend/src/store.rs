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
    /// 软删时间（回收站条目展示"删除于"用；未删除 = None）
    pub deleted_at: Option<String>,
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

/// 配对设备行（paired_devices 表，FRB 可序列化）
#[derive(Debug, Clone)]
pub struct PairedDeviceRow {
    /// 对端 iroh node id
    pub peer_id: String,
    /// 对端设备名
    pub name: String,
    /// 最后成功连接/同步时间（ISO8601；尚未连接过 = None）
    pub last_seen: Option<String>,
    /// 配对时间（ISO8601）
    pub paired_at: String,
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
                updated_at TEXT NOT NULL,
                deleted_at TEXT NULL
            );
            CREATE TABLE IF NOT EXISTS links (
                source_id TEXT NOT NULL,
                target_id TEXT NOT NULL,
                alias     TEXT NOT NULL DEFAULT '',
                PRIMARY KEY (source_id, target_id)
            );
            CREATE TABLE IF NOT EXISTS paired_devices (
                peer_id   TEXT PRIMARY KEY,
                name      TEXT NOT NULL,
                last_seen TEXT NULL,
                paired_at TEXT NOT NULL
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
        // 迁移已有库：旧 notes 表没有 deleted_at 列时补列（SQLite 无 IF NOT EXISTS for column）。
        let has_deleted_at = {
            let mut stmt = conn.prepare("PRAGMA table_info(notes)")?;
            let columns: Vec<String> = stmt
                .query_map([], |row| row.get(1))?
                .collect::<std::result::Result<Vec<_>, _>>()?;
            columns.iter().any(|name| name == "deleted_at")
        };
        if !has_deleted_at {
            conn.execute_batch("ALTER TABLE notes ADD COLUMN deleted_at TEXT NULL;")?;
            // 旧库的既有行不在刚创建的 notes_fts 索引中；若不重建，之后任何
            // UPDATE notes（如软删除的 deleted_at 标记）都会触发 FTS 触发器报
            // "Content in the virtual table is corrupt"。重建使索引与 notes 一致。
            conn.execute_batch(
                "INSERT INTO notes_fts(notes_fts) VALUES('rebuild');",
            )?;
        }
        Ok(Self {
            conn: Mutex::new(conn),
        })
    }

    /// 读取笔记的 deleted_at 标记（无删除 = None，有删除 = ISO8601 时间）。
    pub fn deleted_at(&self, note_id: &str) -> Result<Option<String>> {
        let conn = self.conn.lock().unwrap();
        Ok(conn
            .query_row(
                "SELECT deleted_at FROM notes WHERE id = ?1",
                [note_id],
                |row| row.get(0),
            )
            .unwrap_or(None))
    }

    /// 投影清理：从 SQLite 删除笔记行并级联删除该笔记的出链 links。
    ///
    /// 仅由 `sync_notes_to_store` 在 Loro 墓碑（tombstones）清理时调用——
    /// store 不再独立决定删除，删除状态全部来自 Loro。
    pub fn purge_note(&self, note_id: &str) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute("DELETE FROM notes WHERE id = ?1", [note_id])?;
        conn.execute("DELETE FROM links WHERE source_id = ?1", [note_id])?;
        Ok(())
    }

    /// 回收站列表：deleted_at 非空，按删除时间倒序。
    pub fn trash_list(&self) -> Result<Vec<NoteRow>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, title, content, tags, updated_at, deleted_at FROM notes
             WHERE deleted_at IS NOT NULL
             ORDER BY deleted_at DESC",
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
                    deleted_at: row.get(5)?,
                })
            })?
            .collect::<std::result::Result<Vec<_>, _>>()?;

        Ok(rows)
    }

    /// 同步一个 NoteCrdt 的内容到 SQLite（INSERT OR REPLACE）
    ///
    /// 从 LoroDoc 中读取当前内容 + 标题 + meta tags + meta.deleted_at，
    /// 写入 notes 表（deleted_at 为读投影：软删/恢复状态来自 Loro，store 不
    /// 独立决定删除）。创建时间首次持久化后不再覆盖。末尾重建该笔记的 links 索引。
    pub fn sync_note(&self, note_id: &str, crdt: &NoteCrdt) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        let content = crdt.get_content();
        let title = crdt.get_title();
        let now = Utc::now().to_rfc3339();
        // 删除状态来自 Loro meta：软删 = Some(时间)，恢复 = None
        let deleted_at = crdt.get_deleted_at();

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
            "INSERT OR REPLACE INTO notes (id, title, content, tags, created_at, updated_at, deleted_at)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
            rusqlite::params![note_id, title, content, tags, created_at, now, deleted_at],
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
            "SELECT id, title, content, tags, updated_at, deleted_at FROM notes
             WHERE deleted_at IS NULL
             ORDER BY updated_at DESC",
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
                    deleted_at: row.get(5)?,
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
            "SELECT id, title, content, tags, updated_at, deleted_at FROM notes
             WHERE (title LIKE ?1 OR content LIKE ?1 OR tags LIKE ?1)
               AND deleted_at IS NULL
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
                    deleted_at: row.get(5)?,
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
            "SELECT n.id, n.title, n.content, n.tags, n.updated_at, n.deleted_at,
                    snippet(notes_fts, 1, '', '', '…', 12)
             FROM notes_fts
             JOIN notes n ON n.rowid = notes_fts.rowid
             WHERE notes_fts MATCH ?1
               AND n.deleted_at IS NULL
             ORDER BY bm25(notes_fts)",
        )?;

        let rows = stmt
            .query_map([&match_expr], |row| {
                let content: String = row.get(2)?;
                let fallback = Self::content_preview(&content);
                let snippet: String = row.get(6)?;
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
                    deleted_at: row.get(5)?,
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
            "SELECT id, title, content, tags, updated_at, deleted_at FROM notes
             WHERE title LIKE ?1 ESCAPE '\\'
               AND deleted_at IS NULL
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
                    deleted_at: row.get(5)?,
                })
            })?
            .collect::<std::result::Result<Vec<_>, _>>()?;

        Ok(rows)
    }

    /// 解析全部笔记的 tags 列，去重并按名称排序
    pub fn get_all_tags(&self) -> Result<Vec<String>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare("SELECT tags FROM notes WHERE deleted_at IS NULL")?;
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
            "SELECT id, title, content, tags, updated_at, deleted_at FROM notes
             WHERE tags LIKE ?1
               AND deleted_at IS NULL
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
                    deleted_at: row.get(5)?,
                })
            })?
            .collect::<std::result::Result<Vec<_>, _>>()?;

        Ok(rows)
    }

    /// 列出所有配对设备，最近连接优先（last_seen DESC，从未连接的最后；同名按 peer_id 稳定排序）。
    pub fn list_paired_devices(&self) -> Result<Vec<PairedDeviceRow>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT peer_id, name, last_seen, paired_at FROM paired_devices
             ORDER BY (last_seen IS NULL), last_seen DESC, peer_id ASC",
        )?;
        let rows = stmt
            .query_map([], |row| {
                Ok(PairedDeviceRow {
                    peer_id: row.get(0)?,
                    name: row.get(1)?,
                    last_seen: row.get(2)?,
                    paired_at: row.get(3)?,
                })
            })?
            .collect::<std::result::Result<Vec<_>, _>>()?;
        Ok(rows)
    }

    /// 添加/更新一台配对设备（重复 peer_id 覆盖 name；paired_at 保持不变）。
    pub fn upsert_paired_device(&self, peer_id: &str, name: &str) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        let now = Utc::now().to_rfc3339();
        conn.execute(
            "INSERT INTO paired_devices (peer_id, name, last_seen, paired_at)
             VALUES (?1, ?2, NULL, ?3)
             ON CONFLICT(peer_id) DO UPDATE SET name = excluded.name",
            rusqlite::params![peer_id, name, now],
        )?;
        Ok(())
    }

    /// 更新配对设备的最后连接/同步时间（ISO8601 now）。
    pub fn update_last_seen(&self, peer_id: &str) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        let now = Utc::now().to_rfc3339();
        conn.execute(
            "UPDATE paired_devices SET last_seen = ?2 WHERE peer_id = ?1",
            rusqlite::params![peer_id, now],
        )?;
        Ok(())
    }

    /// 移除一台配对设备。
    pub fn remove_paired_device(&self, peer_id: &str) -> Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute("DELETE FROM paired_devices WHERE peer_id = ?1", [peer_id])?;
        Ok(())
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
