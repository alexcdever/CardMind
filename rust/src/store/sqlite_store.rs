/// SQLite缓存层实现
///
/// 该模块提供SQLite数据库的管理和操作功能，作为Loro CRDT的查询缓存层。
///
/// # 架构原则
///
/// - **只读设计**: 应用代码不直接写入SQLite，只通过Loro订阅更新
/// - **快速查询**: 优化的索引和查询性能
/// - **可重建**: SQLite数据可以随时从Loro重建
///
/// # 使用示例
///
/// ```rust,no_run
/// use cardmind_rust::store::sqlite_store::SqliteStore;
/// use cardmind_rust::models::card::Card;
///
/// // 创建SQLite store
/// let store = SqliteStore::new_in_memory()?;
///
/// // 查询所有活跃卡片
/// let cards = store.get_active_cards()?;
/// # Ok::<(), cardmind_rust::models::error::CardMindError>(())
/// ```
use crate::models::card::Card;
use crate::models::error::CardMindError;
use rusqlite::{Connection, Result as SqliteResult};

/// SQLite存储管理器
///
/// 负责SQLite数据库的创建、优化和CRUD操作。
pub struct SqliteStore {
    conn: Connection,
}

impl SqliteStore {
    /// 创建一个新的内存SQLite store（用于测试）
    ///
    /// # 示例
    ///
    /// ```rust,no_run
    /// # use cardmind_rust::store::sqlite_store::SqliteStore;
    /// let store = SqliteStore::new_in_memory()?;
    /// # Ok::<(), cardmind_rust::models::error::CardMindError>(())
    /// ```
    pub fn new_in_memory() -> Result<Self, CardMindError> {
        let conn = Connection::open_in_memory()?;
        let mut store = Self { conn };
        store.initialize()?;
        Ok(store)
    }

    /// 创建一个基于文件的SQLite store
    ///
    /// # 参数
    ///
    /// * `path` - SQLite数据库文件路径
    ///
    /// # 示例
    ///
    /// ```rust,no_run
    /// # use cardmind_rust::store::sqlite_store::SqliteStore;
    /// let store = SqliteStore::new("data/cache.db")?;
    /// # Ok::<(), cardmind_rust::models::error::CardMindError>(())
    /// ```
    pub fn new(path: &str) -> Result<Self, CardMindError> {
        let conn = Connection::open(path)?;
        let mut store = Self { conn };
        store.initialize()?;
        Ok(store)
    }

    /// 初始化数据库（创建表和优化参数）
    fn initialize(&mut self) -> Result<(), CardMindError> {
        self.create_tables()?;
        self.optimize()?;
        Ok(())
    }

    /// 创建cards表和索引
    ///
    /// 表结构:
    /// - id (TEXT PRIMARY KEY): UUID v7
    /// - title (TEXT): 卡片标题
    /// - content (TEXT): Markdown内容
    /// - created_at (INTEGER): 创建时间戳（Unix毫秒）
    /// - updated_at (INTEGER): 更新时间戳（Unix毫秒）
    /// - deleted (INTEGER): 软删除标记（0/1）
    fn create_tables(&self) -> Result<(), CardMindError> {
        // 创建cards表
        self.conn.execute(
            "CREATE TABLE IF NOT EXISTS cards (
                id TEXT PRIMARY KEY NOT NULL,
                title TEXT NOT NULL,
                content TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                deleted INTEGER NOT NULL DEFAULT 0
            )",
            [],
        )?;

        // 创建索引 - 优化deleted字段查询
        self.conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_cards_deleted ON cards(deleted)",
            [],
        )?;

        // 创建索引 - 优化按创建时间排序
        self.conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_cards_created_at ON cards(created_at DESC)",
            [],
        )?;

        Ok(())
    }

    /// 配置SQLite优化参数
    ///
    /// 优化设置:
    /// - journal_mode=WAL: Write-Ahead Logging模式（文件数据库）
    /// - cache_size=-10000: 10MB缓存
    /// - synchronous=NORMAL: 平衡性能和安全性
    /// - foreign_keys=ON: 启用外键约束
    fn optimize(&self) -> Result<(), CardMindError> {
        self.conn
            .pragma_update(None, "journal_mode", "WAL")?;
        self.conn
            .pragma_update(None, "cache_size", -10000)?;
        self.conn
            .pragma_update(None, "synchronous", "NORMAL")?;
        self.conn
            .pragma_update(None, "foreign_keys", true)?;
        Ok(())
    }

    // ==================== CRUD操作 ====================

    /// 插入卡片到SQLite
    ///
    /// **注意**: 该方法仅供Loro订阅回调使用，应用代码不应直接调用。
    ///
    /// # 参数
    ///
    /// * `card` - 要插入的卡片
    #[allow(dead_code)]
    pub(crate) fn insert_card(&self, card: &Card) -> Result<(), CardMindError> {
        self.conn.execute(
            "INSERT INTO cards (id, title, content, created_at, updated_at, deleted)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            rusqlite::params![
                &card.id,
                &card.title,
                &card.content,
                card.created_at,
                card.updated_at,
                card.deleted,
            ],
        )?;
        Ok(())
    }

    /// 更新卡片
    ///
    /// **注意**: 该方法仅供Loro订阅回调使用，应用代码不应直接调用。
    ///
    /// # 参数
    ///
    /// * `card` - 要更新的卡片
    #[allow(dead_code)]
    pub(crate) fn update_card(&self, card: &Card) -> Result<(), CardMindError> {
        let rows_affected = self.conn.execute(
            "UPDATE cards
             SET title = ?1, content = ?2, updated_at = ?3, deleted = ?4
             WHERE id = ?5",
            rusqlite::params![
                &card.title,
                &card.content,
                card.updated_at,
                card.deleted,
                &card.id,
            ],
        )?;

        if rows_affected == 0 {
            return Err(CardMindError::CardNotFound(card.id.clone()));
        }

        Ok(())
    }

    /// 硬删除卡片
    ///
    /// **注意**: 一般不使用，建议使用软删除（update deleted=true）。
    ///
    /// # 参数
    ///
    /// * `id` - 卡片ID
    #[allow(dead_code)]
    pub(crate) fn delete_card(&self, id: &str) -> Result<(), CardMindError> {
        let rows_affected = self
            .conn
            .execute("DELETE FROM cards WHERE id = ?1", [id])?;

        if rows_affected == 0 {
            return Err(CardMindError::CardNotFound(id.to_string()));
        }

        Ok(())
    }

    /// 查询所有卡片（包括已删除）
    ///
    /// # 返回
    ///
    /// 按创建时间倒序排列的卡片列表
    pub fn get_all_cards(&self) -> Result<Vec<Card>, CardMindError> {
        let mut stmt = self.conn.prepare(
            "SELECT id, title, content, created_at, updated_at, deleted
             FROM cards
             ORDER BY created_at DESC",
        )?;

        let cards = stmt
            .query_map([], |row| {
                Ok(Card {
                    id: row.get(0)?,
                    title: row.get(1)?,
                    content: row.get(2)?,
                    created_at: row.get(3)?,
                    updated_at: row.get(4)?,
                    deleted: row.get(5)?,
                })
            })?
            .collect::<SqliteResult<Vec<_>>>()?;

        Ok(cards)
    }

    /// 查询所有活跃卡片（排除已删除）
    ///
    /// # 返回
    ///
    /// 按创建时间倒序排列的活跃卡片列表
    ///
    /// # 示例
    ///
    /// ```rust,no_run
    /// # use cardmind_rust::store::sqlite_store::SqliteStore;
    /// let store = SqliteStore::new_in_memory()?;
    /// let active_cards = store.get_active_cards()?;
    /// # Ok::<(), cardmind_rust::models::error::CardMindError>(())
    /// ```
    pub fn get_active_cards(&self) -> Result<Vec<Card>, CardMindError> {
        let mut stmt = self.conn.prepare(
            "SELECT id, title, content, created_at, updated_at, deleted
             FROM cards
             WHERE deleted = 0
             ORDER BY created_at DESC",
        )?;

        let cards = stmt
            .query_map([], |row| {
                Ok(Card {
                    id: row.get(0)?,
                    title: row.get(1)?,
                    content: row.get(2)?,
                    created_at: row.get(3)?,
                    updated_at: row.get(4)?,
                    deleted: row.get(5)?,
                })
            })?
            .collect::<SqliteResult<Vec<_>>>()?;

        Ok(cards)
    }

    /// 按ID查询卡片
    ///
    /// # 参数
    ///
    /// * `id` - 卡片ID
    ///
    /// # 返回
    ///
    /// 找到的卡片，如果不存在则返回CardNotFound错误
    ///
    /// # 示例
    ///
    /// ```rust,no_run
    /// # use cardmind_rust::store::sqlite_store::SqliteStore;
    /// let store = SqliteStore::new_in_memory()?;
    /// let card = store.get_card_by_id("some-uuid-v7")?;
    /// # Ok::<(), cardmind_rust::models::error::CardMindError>(())
    /// ```
    pub fn get_card_by_id(&self, id: &str) -> Result<Card, CardMindError> {
        let mut stmt = self.conn.prepare(
            "SELECT id, title, content, created_at, updated_at, deleted
             FROM cards
             WHERE id = ?1",
        )?;

        let card = stmt.query_row([id], |row| {
            Ok(Card {
                id: row.get(0)?,
                title: row.get(1)?,
                content: row.get(2)?,
                created_at: row.get(3)?,
                updated_at: row.get(4)?,
                deleted: row.get(5)?,
            })
        });

        match card {
            Ok(c) => Ok(c),
            Err(rusqlite::Error::QueryReturnedNoRows) => {
                Err(CardMindError::CardNotFound(id.to_string()))
            }
            Err(e) => Err(CardMindError::DatabaseError(e.to_string())),
        }
    }

    /// 获取卡片数量统计
    ///
    /// # 返回
    ///
    /// (总数, 活跃数, 已删除数)
    pub fn get_card_count(&self) -> Result<(i64, i64, i64), CardMindError> {
        let total: i64 = self
            .conn
            .query_row("SELECT COUNT(*) FROM cards", [], |row| row.get(0))?;

        let active: i64 = self.conn.query_row(
            "SELECT COUNT(*) FROM cards WHERE deleted = 0",
            [],
            |row| row.get(0),
        )?;

        let deleted = total - active;

        Ok((total, active, deleted))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::utils::uuid_v7::generate_uuid_v7;

    #[test]
    fn test_sqlite_store_creation() {
        let store = SqliteStore::new_in_memory();
        assert!(store.is_ok(), "应该能创建内存SQLite store");
    }

    #[test]
    fn test_insert_and_get_card() {
        let store = SqliteStore::new_in_memory().unwrap();

        let card = Card::new(generate_uuid_v7(), "标题".to_string(), "内容".to_string());
        let card_id = card.id.clone();

        // 插入卡片
        store.insert_card(&card).unwrap();

        // 查询卡片
        let retrieved = store.get_card_by_id(&card_id).unwrap();
        assert_eq!(retrieved.id, card_id);
        assert_eq!(retrieved.title, "标题");
        assert_eq!(retrieved.content, "内容");
    }

    #[test]
    fn test_get_active_cards_excludes_deleted() {
        let store = SqliteStore::new_in_memory().unwrap();

        // 插入两个卡片
        let mut card1 = Card::new(generate_uuid_v7(), "卡片1".to_string(), "内容1".to_string());
        let card2 = Card::new(generate_uuid_v7(), "卡片2".to_string(), "内容2".to_string());

        store.insert_card(&card1).unwrap();
        store.insert_card(&card2).unwrap();

        // 软删除card1
        card1.mark_deleted();
        store.update_card(&card1).unwrap();

        // 查询活跃卡片
        let active_cards = store.get_active_cards().unwrap();
        assert_eq!(active_cards.len(), 1);
        assert_eq!(active_cards[0].id, card2.id);
    }

    #[test]
    fn test_card_count() {
        let store = SqliteStore::new_in_memory().unwrap();

        // 初始状态
        let (total, active, deleted) = store.get_card_count().unwrap();
        assert_eq!(total, 0);
        assert_eq!(active, 0);
        assert_eq!(deleted, 0);

        // 插入两个卡片
        let mut card1 = Card::new(generate_uuid_v7(), "卡片1".to_string(), "内容1".to_string());
        let card2 = Card::new(generate_uuid_v7(), "卡片2".to_string(), "内容2".to_string());

        store.insert_card(&card1).unwrap();
        store.insert_card(&card2).unwrap();

        // 检查数量
        let (total, active, deleted) = store.get_card_count().unwrap();
        assert_eq!(total, 2);
        assert_eq!(active, 2);
        assert_eq!(deleted, 0);

        // 软删除一个
        card1.mark_deleted();
        store.update_card(&card1).unwrap();

        let (total, active, deleted) = store.get_card_count().unwrap();
        assert_eq!(total, 2);
        assert_eq!(active, 1);
        assert_eq!(deleted, 1);
    }
}
