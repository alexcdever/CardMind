use crate::models::card::Card;
use crate::models::error::CardMindError;
use crate::models::pool::{Pool, PoolMember};
use rusqlite::{params, Connection};
use std::path::Path;
use uuid::Uuid;

/// SQLite 缓存存储
pub struct SqliteStore {
    conn: Connection,
    ready: bool,
}

impl SqliteStore {
    /// 创建并初始化缓存 schema
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
                pool_key TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS pool_members (
                pool_id TEXT NOT NULL,
                peer_id TEXT NOT NULL,
                public_key TEXT NOT NULL,
                multiaddr TEXT NOT NULL,
                os TEXT NOT NULL,
                hostname TEXT NOT NULL,
                is_admin INTEGER NOT NULL,
                PRIMARY KEY (pool_id, peer_id)
            );
            CREATE TABLE IF NOT EXISTS pool_cards (
                pool_id TEXT NOT NULL,
                card_id TEXT NOT NULL,
                PRIMARY KEY (pool_id, card_id)
            );",
        )
        .map_err(|e| CardMindError::Sqlite(e.to_string()))?;
        Ok(Self { conn, ready: true })
    }

    /// 判断缓存层是否可用
    pub fn is_ready(&self) -> bool {
        self.ready
    }

    /// 写入或更新卡片
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

    /// 获取卡片
    pub fn get_card(&self, id: &Uuid) -> Result<Card, CardMindError> {
        let id_str = id.to_string();
        let row = self.conn.query_row(
            "SELECT id, title, content, created_at, updated_at, deleted FROM cards WHERE id = ?1;",
            params![id_str],
            |row| {
                let id_str: String = row.get(0)?;
                let id = Uuid::parse_str(&id_str)
                    .map_err(|_| rusqlite::Error::FromSqlConversionFailure(0, rusqlite::types::Type::Text, Box::new(std::fmt::Error)))?;
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
    pub fn list_cards(&self, limit: i64, offset: i64) -> Result<Vec<Card>, CardMindError> {
        let mut stmt = self
            .conn
            .prepare(
                "SELECT id, title, content, created_at, updated_at, deleted FROM cards LIMIT ?1 OFFSET ?2;",
            )
            .map_err(|e| CardMindError::Sqlite(e.to_string()))?;
        let rows = stmt
            .query_map(params![limit, offset], |row| {
                let id_str: String = row.get(0)?;
                let id = Uuid::parse_str(&id_str)
                    .map_err(|_| rusqlite::Error::FromSqlConversionFailure(0, rusqlite::types::Type::Text, Box::new(std::fmt::Error)))?;
                Ok(Card {
                    id,
                    title: row.get(1)?,
                    content: row.get(2)?,
                    created_at: row.get(3)?,
                    updated_at: row.get(4)?,
                    deleted: row.get::<_, i64>(5)? != 0,
                })
            })
            .map_err(|e| CardMindError::Sqlite(e.to_string()))?;
        let mut cards = Vec::new();
        for row in rows {
            cards.push(row.map_err(|e| CardMindError::Sqlite(e.to_string()))?);
        }
        Ok(cards)
    }

    /// 搜索卡片
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
            .query_map(params![like, limit, offset], |row| {
                let id_str: String = row.get(0)?;
                let id = Uuid::parse_str(&id_str)
                    .map_err(|_| rusqlite::Error::FromSqlConversionFailure(0, rusqlite::types::Type::Text, Box::new(std::fmt::Error)))?;
                Ok(Card {
                    id,
                    title: row.get(1)?,
                    content: row.get(2)?,
                    created_at: row.get(3)?,
                    updated_at: row.get(4)?,
                    deleted: row.get::<_, i64>(5)? != 0,
                })
            })
            .map_err(|e| CardMindError::Sqlite(e.to_string()))?;
        let mut cards = Vec::new();
        for row in rows {
            cards.push(row.map_err(|e| CardMindError::Sqlite(e.to_string()))?);
        }
        Ok(cards)
    }

    /// 写入或更新数据池元数据
    pub fn upsert_pool(&self, pool: &Pool) -> Result<(), CardMindError> {
        self.conn
            .execute(
                "INSERT OR REPLACE INTO pools (pool_id, pool_key) VALUES (?1, ?2);",
                params![pool.pool_id.to_string(), pool.pool_key],
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
                    (pool_id, peer_id, public_key, multiaddr, os, hostname, is_admin)
                    VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7);",
                    params![
                        pool.pool_id.to_string(),
                        member.peer_id,
                        member.public_key,
                        member.multiaddr,
                        member.os,
                        member.hostname,
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

    /// 获取数据池元数据
    pub fn get_pool(&self, id: &Uuid) -> Result<Pool, CardMindError> {
        let id_str = id.to_string();
        let pool_row = self.conn.query_row(
            "SELECT pool_id, pool_key FROM pools WHERE pool_id = ?1;",
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
                let pool_key: String = row.get(1)?;
                Ok((pool_id, pool_key))
            },
        );
        let (pool_id, pool_key) = match pool_row {
            Ok(row) => row,
            Err(rusqlite::Error::QueryReturnedNoRows) => {
                return Err(CardMindError::NotFound("pool not found".to_string()))
            }
            Err(err) => return Err(CardMindError::Sqlite(err.to_string())),
        };

        let mut member_stmt = self
            .conn
            .prepare(
                "SELECT peer_id, public_key, multiaddr, os, hostname, is_admin
                 FROM pool_members WHERE pool_id = ?1;",
            )
            .map_err(|e| CardMindError::Sqlite(e.to_string()))?;
        let member_rows = member_stmt
            .query_map(params![pool_id.to_string()], |row| {
                Ok(PoolMember {
                    peer_id: row.get(0)?,
                    public_key: row.get(1)?,
                    multiaddr: row.get(2)?,
                    os: row.get(3)?,
                    hostname: row.get(4)?,
                    is_admin: row.get::<_, i64>(5)? != 0,
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
            pool_key,
            members,
            card_ids,
        })
    }
}
