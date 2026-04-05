//! # SqliteStore 模块
//!
//! SQLite 读模型存储实现，负责结构化数据表的创建、查询和维护。
//!
//! ## 架构说明
//! 本模块是双引擎架构中的读模型层：
//! - **SQLite**：作为读模型，提供高效的结构化查询能力
//! - **数据来源**：所有数据通过投影从 Loro 写模型同步而来
//!
//! 数据流向：Loro 写模型 → 投影操作 → SQLite 读模型 → 业务查询
//!
//! ## 调用约束
//! - 不直接接受业务写入，所有写入应通过 Loro 投影完成
//! - 读取操作可直接调用，性能优先
//! - 初始化时会自动创建必要的表结构
//!
//! ## 主要功能
//! - 卡片（Card）的 CRUD 操作
//! - 数据池（Pool）的元数据管理
//! - 投影失败记录的追踪与恢复
//! - 支持分页、搜索和筛选的卡片查询
//!
//! ## 数据库 Schema
//! - `cards`：卡片主表（id, title, content, created_at, updated_at, deleted）
//! - `pools`：数据池主表（pool_id）
//! - `pools`：数据池主表（pool_id, is_dissolved）
//! - `pool_members`：池成员关联表（pool_id, endpoint_id, nickname, os, is_admin）
//! - `pool_cards`：池卡片关联表（pool_id, card_id）
//! - `projection_failures`：投影失败记录表（entity_type, entity_id, retry_action）
//!
//! ## 示例
//! ```rust,ignore
//! use rust::store::sqlite_store::SqliteStore;
//! use std::path::Path;
//!
//! // 创建存储实例（自动初始化表结构）
//! let store = SqliteStore::new(Path::new("/path/to/data.db"))?;
//!
//! // 写入卡片（通常从 Loro 投影）
//! store.upsert_card(&card)?;
//!
//! // 查询卡片
//! let card = store.get_card(&card_id)?;
//! let cards = store.list_cards(10, 0)?;
//! ```
use crate::models::card::Card;
use crate::models::error::CardMindError;
use crate::models::pool::{Pool, PoolMember};
use rusqlite::{params, Connection, Row};
use std::path::Path;
use uuid::Uuid;

/// SQLite 读模型存储结构体
///
/// 封装了 rusqlite 连接，提供卡片和数据池的查询接口。
///
/// ## 字段说明
pub struct SqliteStore {
    /// SQLite 数据库连接
    conn: Connection,
    /// 存储是否已就绪（初始化完成）
    ready: bool,
}

impl SqliteStore {
    /// 创建并初始化 SQLite 存储实例
    ///
    /// 打开数据库连接并创建必要的表结构（如果不存在）。
    ///
    /// # 参数
    /// * `path` - SQLite 数据库文件路径
    ///
    /// # 返回
    /// 初始化后的 [`SqliteStore`] 实例
    ///
    /// # Errors
    /// - 当数据库打开失败时返回 [`CardMindError::Sqlite`]
    /// - 当表创建失败时返回 [`CardMindError::Sqlite`]
    ///
    /// # Note
    /// 此方法会创建以下表（如果不存在）：cards, pools, pool_members, pool_cards, projection_failures
    ///
    /// # Examples
    /// ```rust,ignore
    /// use std::path::Path;
    ///
    /// let store = SqliteStore::new(Path::new("data.db"))?;
    /// assert!(store.is_ready());
    /// ```
    pub fn new(path: &Path) -> Result<Self, CardMindError> {
        let conn = Connection::open(path).map_err(|e| CardMindError::Sqlite(e.to_string()))?;
        conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS cards (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                content TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                deleted INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS pools (
                pool_id TEXT PRIMARY KEY,
                is_dissolved INTEGER NOT NULL DEFAULT 0
            );
            CREATE TABLE IF NOT EXISTS pool_members (
                pool_id TEXT NOT NULL,
                endpoint_id TEXT NOT NULL,
                nickname TEXT NOT NULL,
                os TEXT NOT NULL,
                is_admin INTEGER NOT NULL,
                PRIMARY KEY (pool_id, endpoint_id)
            );
             CREATE TABLE IF NOT EXISTS pool_cards (
                 pool_id TEXT NOT NULL,
                 card_id TEXT NOT NULL,
                 PRIMARY KEY (pool_id, card_id)
             );
             CREATE TABLE IF NOT EXISTS projection_failures (
                 entity_type TEXT NOT NULL,
                 entity_id TEXT NOT NULL,
                 retry_action TEXT NOT NULL,
                 PRIMARY KEY (entity_type, entity_id)
             );",
        )
        .map_err(|e| CardMindError::Sqlite(e.to_string()))?;
        Ok(Self { conn, ready: true })
    }

    /// 检查存储是否就绪
    ///
    /// # 返回
    /// - `true` - 存储已初始化完成
    /// - `false` - 存储未就绪
    pub fn is_ready(&self) -> bool {
        self.ready
    }

    /// 将数据库行映射为 Card 结构体
    ///
    /// # 参数
    /// * `row` - 数据库查询结果行
    ///
    /// # 返回
    /// 解析后的 [`Card`] 实例，或转换错误
    fn map_card(row: &Row<'_>) -> rusqlite::Result<Card> {
        let id_str: String = row.get(0)?;
        let id = Uuid::parse_str(&id_str).map_err(|_| {
            rusqlite::Error::FromSqlConversionFailure(
                0,
                rusqlite::types::Type::Text,
                Box::new(std::fmt::Error),
            )
        })?;
        Ok(Card {
            id,
            title: row.get(1)?,
            content: row.get(2)?,
            created_at: row.get(3)?,
            updated_at: row.get(4)?,
            deleted: row.get::<_, i64>(5)? != 0,
        })
    }

    /// 写入或更新卡片
    ///
    /// 使用 INSERT OR REPLACE 语义，如果卡片已存在则更新。
    ///
    /// # 参数
    /// * `card` - 要写入的卡片实例
    ///
    /// # 返回
    /// 成功时返回 `()`
    ///
    /// # Errors
    /// - 当数据库操作失败时返回 [`CardMindError::Sqlite`]
    pub fn upsert_card(&self, card: &Card) -> Result<(), CardMindError> {
        self.conn
            .execute(
                "INSERT OR REPLACE INTO cards (id, title, content, created_at, updated_at, deleted)
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6);",
                params![
                    card.id.to_string(),
                    card.title,
                    card.content,
                    card.created_at,
                    card.updated_at,
                    if card.deleted { 1 } else { 0 }
                ],
            )
            .map_err(|e| CardMindError::Sqlite(e.to_string()))?;
        Ok(())
    }

    /// 获取指定 ID 的卡片
    ///
    /// # 参数
    /// * `id` - 卡片 UUID
    ///
    /// # 返回
    /// 查询到的 [`Card`] 实例
    ///
    /// # Errors
    /// - 当卡片不存在时返回 [`CardMindError::NotFound`]
    /// - 当数据库操作失败时返回 [`CardMindError::Sqlite`]
    pub fn get_card(&self, id: &Uuid) -> Result<Card, CardMindError> {
        let id_str = id.to_string();
        let row = self.conn.query_row(
            "SELECT id, title, content, created_at, updated_at, deleted FROM cards WHERE id = ?1;",
            params![id_str],
            |row| {
                let id_str: String = row.get(0)?;
                let id = Uuid::parse_str(&id_str).map_err(|_| {
                    rusqlite::Error::FromSqlConversionFailure(
                        0,
                        rusqlite::types::Type::Text,
                        Box::new(std::fmt::Error),
                    )
                })?;
                Ok(Card {
                    id,
                    title: row.get(1)?,
                    content: row.get(2)?,
                    created_at: row.get(3)?,
                    updated_at: row.get(4)?,
                    deleted: row.get::<_, i64>(5)? != 0,
                })
            },
        );
        match row {
            Ok(card) => Ok(card),
            Err(rusqlite::Error::QueryReturnedNoRows) => {
                Err(CardMindError::NotFound("card not found".to_string()))
            }
            Err(err) => Err(CardMindError::Sqlite(err.to_string())),
        }
    }

    /// 分页列出卡片
    ///
    /// 返回所有卡片（包括已删除的），按插入顺序。
    ///
    /// # 参数
    /// * `limit` - 返回的最大卡片数量
    /// * `offset` - 跳过的卡片数量
    ///
    /// # 返回
    /// 卡片列表
    ///
    /// # Errors
    /// - 当数据库操作失败时返回 [`CardMindError::Sqlite`]
    pub fn list_cards(&self, limit: i64, offset: i64) -> Result<Vec<Card>, CardMindError> {
        let mut stmt = self
            .conn
            .prepare(
                "SELECT id, title, content, created_at, updated_at, deleted FROM cards LIMIT ?1 OFFSET ?2;",
            )
            .map_err(|e| CardMindError::Sqlite(e.to_string()))?;
        let rows = stmt
            .query_map(params![limit, offset], Self::map_card)
            .map_err(|e| CardMindError::Sqlite(e.to_string()))?;
        let mut cards = Vec::new();
        for row in rows {
            cards.push(row.map_err(|e| CardMindError::Sqlite(e.to_string()))?);
        }
        Ok(cards)
    }

    /// 搜索卡片
    ///
    /// 在标题和内容中搜索包含关键字的卡片。
    ///
    /// # 参数
    /// * `keyword` - 搜索关键字
    /// * `limit` - 返回的最大卡片数量
    /// * `offset` - 跳过的卡片数量
    ///
    /// # 返回
    /// 匹配的卡片列表
    ///
    /// # Errors
    /// - 当数据库操作失败时返回 [`CardMindError::Sqlite`]
    pub fn search_cards(
        &self,
        keyword: &str,
        limit: i64,
        offset: i64,
    ) -> Result<Vec<Card>, CardMindError> {
        let like = format!("%{}%", keyword);
        let mut stmt = self
            .conn
            .prepare(
                "SELECT id, title, content, created_at, updated_at, deleted FROM cards
                 WHERE title LIKE ?1 OR content LIKE ?1
                 LIMIT ?2 OFFSET ?3;",
            )
            .map_err(|e| CardMindError::Sqlite(e.to_string()))?;
        let rows = stmt
            .query_map(params![like, limit, offset], Self::map_card)
            .map_err(|e| CardMindError::Sqlite(e.to_string()))?;
        let mut cards = Vec::new();
        for row in rows {
            cards.push(row.map_err(|e| CardMindError::Sqlite(e.to_string()))?);
        }
        Ok(cards)
    }

    /// 高级卡片查询
    ///
    /// 支持关键字搜索、数据池筛选和软删除控制。
    ///
    /// # 参数
    /// * `keyword` - 搜索关键字（标题和内容）
    /// * `pool_id` - 可选的数据池 ID 筛选
    /// * `include_deleted` - 是否包含已删除的卡片
    /// * `limit` - 返回的最大卡片数量
    /// * `offset` - 跳过的卡片数量
    ///
    /// # 返回
    /// 符合条件的卡片列表，按 updated_at 降序排列
    ///
    /// # Errors
    /// - 当数据库操作失败时返回 [`CardMindError::Sqlite`]
    pub fn query_cards(
        &self,
        keyword: &str,
        pool_id: Option<&str>,
        include_deleted: bool,
        limit: i64,
        offset: i64,
    ) -> Result<Vec<Card>, CardMindError> {
        let normalized = keyword.trim().to_lowercase();
        let like = format!("%{}%", normalized);

        // 构建基础 SQL
        let mut sql = String::from(
            "SELECT c.id, c.title, c.content, c.created_at, c.updated_at, c.deleted
             FROM cards c",
        );

        // 如果指定了 pool_id，JOIN pool_cards 表
        if pool_id.is_some() {
            sql.push_str(" JOIN pool_cards pc ON c.id = pc.card_id");
        }

        sql.push_str(" WHERE 1=1");

        // 添加 pool_id 筛选
        if pool_id.is_some() {
            sql.push_str(" AND pc.pool_id = ?");
        }

        // 添加软删除筛选
        if !include_deleted {
            sql.push_str(" AND c.deleted = 0");
        }

        // 添加关键字筛选
        if !normalized.is_empty() {
            sql.push_str(" AND (LOWER(c.title) LIKE ? OR LOWER(c.content) LIKE ?)");
        }

        sql.push_str(" ORDER BY c.updated_at DESC, c.created_at DESC, c.id ASC");
        sql.push_str(" LIMIT ? OFFSET ?");

        // 执行查询
        let mut stmt = self
            .conn
            .prepare(&sql)
            .map_err(|e| CardMindError::Sqlite(e.to_string()))?;

        // 构建参数列表，按 SQL 中出现的顺序
        let mut params: Vec<&dyn rusqlite::ToSql> = Vec::new();
        if pool_id.is_some() {
            params.push(&pool_id);
        }
        if !normalized.is_empty() {
            params.push(&like);
            params.push(&like);
        }
        params.push(&limit);
        params.push(&offset);

        let rows = stmt
            .query_map(params.as_slice(), Self::map_card)
            .map_err(|e| CardMindError::Sqlite(e.to_string()))?;

        let mut cards = Vec::new();
        for row in rows {
            cards.push(row.map_err(|e| CardMindError::Sqlite(e.to_string()))?);
        }
        Ok(cards)
    }

    /// 写入或更新数据池
    ///
    /// 完整更新数据池的元数据、成员列表和关联卡片。
    ///
    /// # 参数
    /// * `pool` - 要写入的数据池实例
    ///
    /// # 返回
    /// 成功时返回 `()`
    ///
    /// # Errors
    /// - 当数据库操作失败时返回 [`CardMindError::Sqlite`]
    ///
    /// # Note
    /// 此操作会先清空再重建 pool_members 和 pool_cards 表的相关记录
    pub fn upsert_pool(&self, pool: &Pool) -> Result<(), CardMindError> {
        self.conn
            .execute(
                "INSERT OR REPLACE INTO pools (pool_id, is_dissolved) VALUES (?1, ?2);",
                params![
                    pool.pool_id.to_string(),
                    if pool.is_dissolved { 1 } else { 0 }
                ],
            )
            .map_err(|e| CardMindError::Sqlite(e.to_string()))?;
        self.conn
            .execute(
                "DELETE FROM pool_members WHERE pool_id = ?1;",
                params![pool.pool_id.to_string()],
            )
            .map_err(|e| CardMindError::Sqlite(e.to_string()))?;
        self.conn
            .execute(
                "DELETE FROM pool_cards WHERE pool_id = ?1;",
                params![pool.pool_id.to_string()],
            )
            .map_err(|e| CardMindError::Sqlite(e.to_string()))?;

        for member in &pool.members {
            self.conn
                .execute(
                    "INSERT OR REPLACE INTO pool_members
                    (pool_id, endpoint_id, nickname, os, is_admin)
                    VALUES (?1, ?2, ?3, ?4, ?5);",
                    params![
                        pool.pool_id.to_string(),
                        member.endpoint_id,
                        member.nickname,
                        member.os,
                        if member.is_admin { 1 } else { 0 }
                    ],
                )
                .map_err(|e| CardMindError::Sqlite(e.to_string()))?;
        }

        for card_id in &pool.card_ids {
            self.conn
                .execute(
                    "INSERT OR REPLACE INTO pool_cards (pool_id, card_id) VALUES (?1, ?2);",
                    params![pool.pool_id.to_string(), card_id.to_string()],
                )
                .map_err(|e| CardMindError::Sqlite(e.to_string()))?;
        }

        Ok(())
    }

    /// 记录投影失败
    ///
    /// 当 Loro 到 SQLite 的投影失败时，记录失败信息以便后续恢复。
    ///
    /// # 参数
    /// * `entity_type` - 实体类型（如 "pool"）
    /// * `entity_id` - 实体 ID
    /// * `retry_action` - 重试动作标识
    ///
    /// # 返回
    /// 成功时返回 `()`
    ///
    /// # Errors
    /// - 当数据库操作失败时返回 [`CardMindError::Sqlite`]
    pub fn record_projection_failure(
        &self,
        entity_type: &str,
        entity_id: &str,
        retry_action: &str,
    ) -> Result<(), CardMindError> {
        self.conn
            .execute(
                "INSERT OR REPLACE INTO projection_failures (entity_type, entity_id, retry_action)
                 VALUES (?1, ?2, ?3);",
                params![entity_type, entity_id, retry_action],
            )
            .map_err(|e| CardMindError::Sqlite(e.to_string()))?;
        Ok(())
    }

    /// 清除投影失败记录
    ///
    /// 当投影成功完成后，清除对应的失败记录。
    ///
    /// # 参数
    /// * `entity_type` - 实体类型
    /// * `entity_id` - 实体 ID
    ///
    /// # 返回
    /// 成功时返回 `()`
    ///
    /// # Errors
    /// - 当数据库操作失败时返回 [`CardMindError::Sqlite`]
    pub fn clear_projection_failure(
        &self,
        entity_type: &str,
        entity_id: &str,
    ) -> Result<(), CardMindError> {
        self.conn
            .execute(
                "DELETE FROM projection_failures WHERE entity_type = ?1 AND entity_id = ?2;",
                params![entity_type, entity_id],
            )
            .map_err(|e| CardMindError::Sqlite(e.to_string()))?;
        Ok(())
    }

    /// 获取投影失败的重试动作
    ///
    /// 检查指定实体是否存在投影失败记录。
    ///
    /// # 参数
    /// * `entity_type` - 实体类型
    /// * `entity_id` - 实体 ID
    ///
    /// # 返回
    /// - `Some(String)` - 存在失败记录，返回重试动作
    /// - `None` - 无失败记录
    ///
    /// # Errors
    /// - 当数据库操作失败时返回 [`CardMindError::Sqlite`]
    pub fn get_projection_retry_action(
        &self,
        entity_type: &str,
        entity_id: &str,
    ) -> Result<Option<String>, CardMindError> {
        let row = self.conn.query_row(
            "SELECT retry_action FROM projection_failures WHERE entity_type = ?1 AND entity_id = ?2;",
            params![entity_type, entity_id],
            |row| row.get(0),
        );
        match row {
            Ok(retry_action) => Ok(Some(retry_action)),
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(err) => Err(CardMindError::Sqlite(err.to_string())),
        }
    }

    /// 检查是否存在待恢复的投影失败
    ///
    /// # 返回
    /// - `true` - 存在至少一个待恢复的投影失败
    /// - `false` - 所有投影都正常
    ///
    /// # Errors
    /// - 当数据库操作失败时返回 [`CardMindError::Sqlite`]
    pub fn has_projection_failures(&self) -> Result<bool, CardMindError> {
        let count: i64 = self
            .conn
            .query_row("SELECT COUNT(1) FROM projection_failures;", [], |row| {
                row.get(0)
            })
            .map_err(|e| CardMindError::Sqlite(e.to_string()))?;
        Ok(count > 0)
    }

    /// 获取指定 ID 的数据池
    ///
    /// 完整读取数据池的元数据、成员列表和关联卡片。
    ///
    /// # 参数
    /// * `id` - 数据池 UUID
    ///
    /// # 返回
    /// 查询到的 [`Pool`] 实例
    ///
    /// # Errors
    /// - 当数据池不存在时返回 [`CardMindError::NotFound`]
    /// - 当数据库操作失败时返回 [`CardMindError::Sqlite`]
    pub fn get_pool(&self, id: &Uuid) -> Result<Pool, CardMindError> {
        let id_str = id.to_string();
        let pool_row = self.conn.query_row(
            "SELECT pool_id, is_dissolved FROM pools WHERE pool_id = ?1;",
            params![id_str],
            |row| {
                let pool_id: String = row.get(0)?;
                let pool_id = Uuid::parse_str(&pool_id).map_err(|_| {
                    rusqlite::Error::FromSqlConversionFailure(
                        0,
                        rusqlite::types::Type::Text,
                        Box::new(std::fmt::Error),
                    )
                })?;
                let is_dissolved = row.get::<_, i64>(1)? != 0;
                Ok((pool_id, is_dissolved))
            },
        );
        let (pool_id, is_dissolved) = match pool_row {
            Ok(row) => row,
            Err(rusqlite::Error::QueryReturnedNoRows) => {
                return Err(CardMindError::NotFound("pool not found".to_string()));
            }
            Err(err) => return Err(CardMindError::Sqlite(err.to_string())),
        };

        let mut member_stmt = self
            .conn
            .prepare(
                "SELECT endpoint_id, nickname, os, is_admin
                 FROM pool_members WHERE pool_id = ?1;",
            )
            .map_err(|e| CardMindError::Sqlite(e.to_string()))?;
        let member_rows = member_stmt
            .query_map(params![pool_id.to_string()], |row| {
                Ok(PoolMember {
                    endpoint_id: row.get(0)?,
                    nickname: row.get(1)?,
                    os: row.get(2)?,
                    is_admin: row.get::<_, i64>(3)? != 0,
                })
            })
            .map_err(|e| CardMindError::Sqlite(e.to_string()))?;
        let mut members = Vec::new();
        for row in member_rows {
            members.push(row.map_err(|e| CardMindError::Sqlite(e.to_string()))?);
        }

        let mut card_stmt = self
            .conn
            .prepare("SELECT card_id FROM pool_cards WHERE pool_id = ?1;")
            .map_err(|e| CardMindError::Sqlite(e.to_string()))?;
        let card_rows = card_stmt
            .query_map(params![pool_id.to_string()], |row| {
                let card_id: String = row.get(0)?;
                let card_id = Uuid::parse_str(&card_id).map_err(|_| {
                    rusqlite::Error::FromSqlConversionFailure(
                        0,
                        rusqlite::types::Type::Text,
                        Box::new(std::fmt::Error),
                    )
                })?;
                Ok(card_id)
            })
            .map_err(|e| CardMindError::Sqlite(e.to_string()))?;
        let mut card_ids = Vec::new();
        for row in card_rows {
            card_ids.push(row.map_err(|e| CardMindError::Sqlite(e.to_string()))?);
        }

        Ok(Pool {
            pool_id,
            members,
            card_ids,
            is_dissolved,
            join_requests: Vec::new(),
        })
    }

    /// 列出所有数据池 ID
    ///
    /// # 返回
    /// 数据池 UUID 列表，按 pool_id 排序
    ///
    /// # Errors
    /// - 当数据库操作失败时返回 [`CardMindError::Sqlite`]
    pub fn list_pool_ids(&self) -> Result<Vec<Uuid>, CardMindError> {
        let mut stmt = self
            .conn
            .prepare("SELECT pool_id FROM pools ORDER BY pool_id;")
            .map_err(|e| CardMindError::Sqlite(e.to_string()))?;
        let rows = stmt
            .query_map([], |row| {
                let pool_id: String = row.get(0)?;
                let pool_id = Uuid::parse_str(&pool_id).map_err(|_| {
                    rusqlite::Error::FromSqlConversionFailure(
                        0,
                        rusqlite::types::Type::Text,
                        Box::new(std::fmt::Error),
                    )
                })?;
                Ok(pool_id)
            })
            .map_err(|e| CardMindError::Sqlite(e.to_string()))?;
        let mut ids = Vec::new();
        for row in rows {
            ids.push(row.map_err(|e| CardMindError::Sqlite(e.to_string()))?);
        }
        Ok(ids)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    /// 创建临时 SQLite 存储用于测试
    fn create_store() -> (SqliteStore, TempDir, std::path::PathBuf) {
        let temp = TempDir::new().unwrap();
        let db = temp.path().join("test.db");
        let store = SqliteStore::new(&db).unwrap();
        (store, temp, db)
    }

    /// 测试无效的 UUID 文本是否返回 SQLite 错误
    #[test]
    fn map_card_returns_sqlite_error_for_invalid_uuid_text() {
        let (_store, _temp, db) = create_store();
        let conn = Connection::open(&db).unwrap();
        conn.execute(
            "INSERT INTO cards (id, title, content, created_at, updated_at, deleted) VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            params!["not-a-uuid", "t", "c", 1_i64, 1_i64, 0_i64],
        )
        .unwrap();
        let mut stmt = conn
            .prepare("SELECT id, title, content, created_at, updated_at, deleted FROM cards")
            .unwrap();
        let err = stmt
            .query_row([], SqliteStore::map_card)
            .expect_err("expected invalid uuid conversion failure");

        match err {
            rusqlite::Error::FromSqlConversionFailure(..) => {}
            other => panic!("unexpected error: {:?}", other),
        }
    }

    /// 测试无效的池 UUID 文本是否返回 SQLite 错误
    #[test]
    fn get_pool_returns_sqlite_error_for_invalid_pool_uuid_text() {
        let (_store, _temp, db) = create_store();
        let conn = Connection::open(&db).unwrap();
        conn.execute("INSERT INTO pools (pool_id) VALUES ('bad-pool-id')", [])
            .unwrap();
        let store = SqliteStore::new(&db).unwrap();

        let result = store.get_pool(&Uuid::new_v4()).unwrap_err();

        match result {
            CardMindError::Sqlite(_) | CardMindError::NotFound(_) => {}
            other => panic!("unexpected error: {:?}", other),
        }
    }

    /// 测试列出池 ID 时无效的 UUID 文本是否返回 SQLite 错误
    #[test]
    fn list_pool_ids_returns_sqlite_error_for_invalid_uuid_text() {
        let (_store, _temp, db) = create_store();
        let conn = Connection::open(&db).unwrap();
        conn.execute("INSERT INTO pools (pool_id) VALUES ('bad-pool-id')", [])
            .unwrap();
        let store = SqliteStore::new(&db).unwrap();

        let result = store.list_pool_ids().unwrap_err();

        match result {
            CardMindError::Sqlite(_) => {}
            other => panic!("unexpected error: {:?}", other),
        }
    }

    /// 测试投影重试操作在表不存在时返回 SQLite 错误
    #[test]
    fn get_projection_retry_action_returns_sqlite_error_when_table_missing() {
        let (store, _temp, _db) = create_store();
        store
            .conn
            .execute("DROP TABLE projection_failures", [])
            .unwrap();

        let result = store.get_projection_retry_action("card", "id").unwrap_err();

        match result {
            CardMindError::Sqlite(_) => {}
            other => panic!("unexpected error: {:?}", other),
        }
    }
}
