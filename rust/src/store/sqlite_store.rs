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
    pub(crate) conn: Connection,
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

    /// 创建数据库表和索引
    ///
    /// 表结构:
    ///
    /// **cards 表**:
    /// - id (TEXT PRIMARY KEY): UUID v7
    /// - title (TEXT): 卡片标题
    /// - content (TEXT): Markdown内容
    /// - created_at (INTEGER): 创建时间戳（Unix毫秒）
    /// - updated_at (INTEGER): 更新时间戳（Unix毫秒）
    /// - deleted (INTEGER): 软删除标记（0/1）
    ///
    /// **pools 表** (Phase 6):
    /// - pool_id (TEXT PRIMARY KEY): UUID v7
    /// - name (TEXT): 数据池名称
    /// - password_hash (TEXT): bcrypt 哈希
    /// - created_at (INTEGER): 创建时间戳
    /// - updated_at (INTEGER): 更新时间戳
    ///
    /// **card_pool_bindings 表** (Phase 6):
    /// - card_id (TEXT): 卡片 ID（外键）
    /// - pool_id (TEXT): 数据池 ID（外键）
    /// - 主键: (card_id, pool_id)
    fn create_tables(&self) -> Result<(), CardMindError> {
        // 创建 cards 表
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

        // 创建索引 - 优化 deleted 字段查询
        self.conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_cards_deleted ON cards(deleted)",
            [],
        )?;

        // 创建索引 - 优化按创建时间排序
        self.conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_cards_created_at ON cards(created_at DESC)",
            [],
        )?;

        // 创建 pools 表 (Phase 6)
        self.conn.execute(
            "CREATE TABLE IF NOT EXISTS pools (
                pool_id TEXT PRIMARY KEY NOT NULL,
                name TEXT NOT NULL,
                password_hash TEXT NOT NULL,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
            )",
            [],
        )?;

        // 创建索引 - 优化按更新时间排序
        self.conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_pools_updated_at ON pools(updated_at DESC)",
            [],
        )?;

        // 创建 card_pool_bindings 表 (Phase 6)
        // 表示卡片和数据池的多对多关系
        // 注意: pool_id 不需要外键约束，因为数据池在 Loro 中独立管理
        self.conn.execute(
            "CREATE TABLE IF NOT EXISTS card_pool_bindings (
                card_id TEXT NOT NULL,
                pool_id TEXT NOT NULL,
                PRIMARY KEY (card_id, pool_id),
                FOREIGN KEY (card_id) REFERENCES cards(id) ON DELETE CASCADE
            )",
            [],
        )?;

        // 创建索引 - 优化按 pool_id 查询卡片
        self.conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_bindings_pool_id ON card_pool_bindings(pool_id)",
            [],
        )?;

        // 创建索引 - 优化按 card_id 查询数据池
        self.conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_bindings_card_id ON card_pool_bindings(card_id)",
            [],
        )?;

        // 创建 trusted_devices 表（设备管理）
        // 存储已配对的信任设备列表
        self.conn.execute(
            "CREATE TABLE IF NOT EXISTS trusted_devices (
                peer_id TEXT PRIMARY KEY NOT NULL,
                device_name TEXT NOT NULL,
                device_type TEXT NOT NULL,
                paired_at INTEGER NOT NULL,
                last_seen INTEGER NOT NULL
            )",
            [],
        )?;

        // 创建索引 - 优化按最后在线时间排序
        self.conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_trusted_devices_last_seen ON trusted_devices(last_seen DESC)",
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
        self.conn.pragma_update(None, "journal_mode", "WAL")?;
        self.conn.pragma_update(None, "cache_size", -10000)?;
        self.conn.pragma_update(None, "synchronous", "NORMAL")?;
        self.conn.pragma_update(None, "foreign_keys", true)?;
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
        let rows_affected = self.conn.execute("DELETE FROM cards WHERE id = ?1", [id])?;

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
                    tags: Vec::new(),
                    last_edit_device: None,
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
                    tags: Vec::new(),
                    last_edit_device: None,
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
                tags: Vec::new(),
                last_edit_device: None,
            })
        });

        match card {
            Ok(ref c) => Ok(c.clone()),
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

        let active: i64 =
            self.conn
                .query_row("SELECT COUNT(*) FROM cards WHERE deleted = 0", [], |row| {
                    row.get(0)
                })?;

        let deleted = total - active;

        Ok((total, active, deleted))
    }

    // ==================== 卡片-数据池绑定操作 ====================

    /// 添加卡片到数据池的绑定关系
    ///
    /// **注意**: 该方法仅供Loro订阅回调使用，应用代码不应直接调用。
    ///
    /// # 参数
    ///
    /// * `card_id` - 卡片ID
    /// * `pool_id` - 数据池ID
    #[allow(dead_code)]
    pub(crate) fn add_card_pool_binding(
        &self,
        card_id: &str,
        pool_id: &str,
    ) -> Result<(), CardMindError> {
        self.conn.execute(
            "INSERT OR IGNORE INTO card_pool_bindings (card_id, pool_id)
             VALUES (?1, ?2)",
            rusqlite::params![card_id, pool_id],
        )?;
        Ok(())
    }

    /// 移除卡片和数据池的绑定关系
    ///
    /// **注意**: 该方法仅供Loro订阅回调使用，应用代码不应直接调用。
    ///
    /// # 参数
    ///
    /// * `card_id` - 卡片ID
    /// * `pool_id` - 数据池ID
    #[allow(dead_code)]
    pub(crate) fn remove_card_pool_binding(
        &self,
        card_id: &str,
        pool_id: &str,
    ) -> Result<(), CardMindError> {
        self.conn.execute(
            "DELETE FROM card_pool_bindings WHERE card_id = ?1 AND pool_id = ?2",
            rusqlite::params![card_id, pool_id],
        )?;
        Ok(())
    }

    /// 获取卡片绑定的所有数据池ID
    ///
    /// # 参数
    ///
    /// * `card_id` - 卡片ID
    ///
    /// # 返回
    ///
    /// 数据池ID列表
    pub fn get_card_pools(&self, card_id: &str) -> Result<Vec<String>, CardMindError> {
        let mut stmt = self
            .conn
            .prepare("SELECT pool_id FROM card_pool_bindings WHERE card_id = ?1")?;

        let pool_ids = stmt
            .query_map([card_id], |row| row.get(0))?
            .collect::<Result<Vec<String>, _>>()?;

        Ok(pool_ids)
    }

    /// 获取数据池中的所有卡片ID
    ///
    /// # 参数
    ///
    /// * `pool_id` - 数据池ID
    ///
    /// # 返回
    ///
    /// 卡片ID列表
    pub fn get_pool_cards(&self, pool_id: &str) -> Result<Vec<String>, CardMindError> {
        let mut stmt = self
            .conn
            .prepare("SELECT card_id FROM card_pool_bindings WHERE pool_id = ?1")?;

        let card_ids = stmt
            .query_map([pool_id], |row| row.get(0))?
            .collect::<Result<Vec<String>, _>>()?;

        Ok(card_ids)
    }

    /// 清除卡片的所有数据池绑定
    ///
    /// **注意**: 该方法仅供Loro订阅回调使用，应用代码不应直接调用。
    ///
    /// # 参数
    ///
    /// * `card_id` - 卡片ID
    #[allow(dead_code)]
    pub(crate) fn clear_card_pools(&self, card_id: &str) -> Result<(), CardMindError> {
        self.conn.execute(
            "DELETE FROM card_pool_bindings WHERE card_id = ?1",
            [card_id],
        )?;
        Ok(())
    }

    /// 获取属于指定数据池的所有活跃卡片（同步过滤）
    ///
    /// 实现同步过滤逻辑：单池模型 - 所有卡片都属于唯一的数据池
    ///
    /// # 参数
    ///
    /// * `pool_ids` - 设备加入的数据池ID列表
    ///
    /// # 返回
    ///
    /// 属于任一数据池的活跃卡片列表
    pub fn get_cards_in_pools(&self, pool_ids: &[String]) -> Result<Vec<Card>, CardMindError> {
        if pool_ids.is_empty() {
            return Ok(Vec::new());
        }

        // 构建 IN 子句的占位符
        let placeholders = pool_ids.iter().map(|_| "?").collect::<Vec<_>>().join(",");
        let query = format!(
            "SELECT DISTINCT c.id, c.title, c.content, c.created_at, c.updated_at, c.deleted
             FROM cards c
             INNER JOIN card_pool_bindings cpb ON c.id = cpb.card_id
             WHERE cpb.pool_id IN ({}) AND c.deleted = 0
             ORDER BY c.created_at DESC",
            placeholders
        );

        let mut stmt = self.conn.prepare(&query)?;

        let cards = stmt
            .query_map(rusqlite::params_from_iter(pool_ids.iter()), |row| {
                Ok(Card {
                    id: row.get(0)?,
                    title: row.get(1)?,
                    content: row.get(2)?,
                    created_at: row.get(3)?,
                    updated_at: row.get(4)?,
                    deleted: row.get(5)?,
                    tags: Vec::new(),
                    last_edit_device: None,
                })
            })?
            .collect::<Result<Vec<Card>, _>>()?;

        Ok(cards)
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

    #[test]
    fn test_pools_and_bindings_tables_creation() {
        let store = SqliteStore::new_in_memory().unwrap();

        // 验证 pools 表已创建
        let result = store.conn.query_row(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='pools'",
            [],
            |row| row.get::<_, String>(0),
        );
        assert!(result.is_ok(), "pools 表应该已创建");

        // 验证 card_pool_bindings 表已创建
        let result = store.conn.query_row(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='card_pool_bindings'",
            [],
            |row| row.get::<_, String>(0),
        );
        assert!(result.is_ok(), "card_pool_bindings 表应该已创建");

        // 验证索引已创建
        let result = store.conn.query_row(
            "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_pools_updated_at'",
            [],
            |row| row.get::<_, String>(0),
        );
        assert!(result.is_ok(), "pools 更新时间索引应该已创建");

        let result = store.conn.query_row(
            "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_bindings_pool_id'",
            [],
            |row| row.get::<_, String>(0),
        );
        assert!(result.is_ok(), "card_pool_bindings pool_id 索引应该已创建");
    }

    #[test]
    fn test_add_and_get_card_pool_binding() {
        let store = SqliteStore::new_in_memory().unwrap();
        let card = Card::new(
            generate_uuid_v7(),
            "测试卡片".to_string(),
            "内容".to_string(),
        );
        let pool_id = generate_uuid_v7();

        // 插入卡片
        store.insert_card(&card).unwrap();

        // 添加绑定
        store.add_card_pool_binding(&card.id, &pool_id).unwrap();

        // 查询卡片的数据池
        let pools = store.get_card_pools(&card.id).unwrap();
        assert_eq!(pools.len(), 1);
        assert_eq!(pools[0], pool_id);

        // 查询数据池的卡片
        let cards = store.get_pool_cards(&pool_id).unwrap();
        assert_eq!(cards.len(), 1);
        assert_eq!(cards[0], card.id);
    }

    #[test]
    fn test_remove_card_pool_binding() {
        let store = SqliteStore::new_in_memory().unwrap();
        let card = Card::new(
            generate_uuid_v7(),
            "测试卡片".to_string(),
            "内容".to_string(),
        );
        let pool_id = generate_uuid_v7();

        // 插入卡片和绑定
        store.insert_card(&card).unwrap();
        store.add_card_pool_binding(&card.id, &pool_id).unwrap();

        // 验证绑定存在
        let pools = store.get_card_pools(&card.id).unwrap();
        assert_eq!(pools.len(), 1);

        // 移除绑定
        store.remove_card_pool_binding(&card.id, &pool_id).unwrap();

        // 验证绑定已移除
        let pools = store.get_card_pools(&card.id).unwrap();
        assert_eq!(pools.len(), 0);
    }

    #[test]
    fn test_clear_card_pools() {
        let store = SqliteStore::new_in_memory().unwrap();
        let card = Card::new(
            generate_uuid_v7(),
            "测试卡片".to_string(),
            "内容".to_string(),
        );
        let pool1 = generate_uuid_v7();
        let pool2 = generate_uuid_v7();

        // 插入卡片和多个绑定
        store.insert_card(&card).unwrap();
        store.add_card_pool_binding(&card.id, &pool1).unwrap();
        store.add_card_pool_binding(&card.id, &pool2).unwrap();

        // 验证绑定存在
        let pools = store.get_card_pools(&card.id).unwrap();
        assert_eq!(pools.len(), 2);

        // 清除所有绑定
        store.clear_card_pools(&card.id).unwrap();

        // 验证绑定已清除
        let pools = store.get_card_pools(&card.id).unwrap();
        assert_eq!(pools.len(), 0);
    }

    #[test]
    fn test_get_cards_in_pools() {
        let store = SqliteStore::new_in_memory().unwrap();

        // 创建3个卡片
        let card1 = Card::new(generate_uuid_v7(), "卡片1".to_string(), "内容1".to_string());
        let card2 = Card::new(generate_uuid_v7(), "卡片2".to_string(), "内容2".to_string());
        let card3 = Card::new(generate_uuid_v7(), "卡片3".to_string(), "内容3".to_string());

        // 创建2个数据池
        let pool1 = generate_uuid_v7();
        let pool2 = generate_uuid_v7();

        // 插入卡片
        store.insert_card(&card1).unwrap();
        store.insert_card(&card2).unwrap();
        store.insert_card(&card3).unwrap();

        // 绑定关系: card1->pool1, card2->pool1, card2->pool2, card3->pool2
        store.add_card_pool_binding(&card1.id, &pool1).unwrap();
        store.add_card_pool_binding(&card2.id, &pool1).unwrap();
        store.add_card_pool_binding(&card2.id, &pool2).unwrap();
        store.add_card_pool_binding(&card3.id, &pool2).unwrap();

        // 查询 pool1 的卡片（应该有 card1 和 card2）
        let cards = store.get_cards_in_pools(&[pool1.clone()]).unwrap();
        assert_eq!(cards.len(), 2);
        let card_ids: Vec<String> = cards.iter().map(|c| c.id.clone()).collect();
        assert!(card_ids.contains(&card1.id));
        assert!(card_ids.contains(&card2.id));

        // 查询 pool2 的卡片（应该有 card2 和 card3）
        let cards = store.get_cards_in_pools(&[pool2.clone()]).unwrap();
        assert_eq!(cards.len(), 2);
        let card_ids: Vec<String> = cards.iter().map(|c| c.id.clone()).collect();
        assert!(card_ids.contains(&card2.id));
        assert!(card_ids.contains(&card3.id));

        // 查询 pool1 和 pool2 的卡片（应该有所有3个卡片）
        let cards = store.get_cards_in_pools(&[pool1, pool2]).unwrap();
        assert_eq!(cards.len(), 3);
    }

    #[test]
    fn test_get_cards_in_pools_excludes_deleted() {
        let store = SqliteStore::new_in_memory().unwrap();

        let mut card1 = Card::new(generate_uuid_v7(), "卡片1".to_string(), "内容1".to_string());
        let card2 = Card::new(generate_uuid_v7(), "卡片2".to_string(), "内容2".to_string());
        let pool_id = generate_uuid_v7();

        // 插入卡片和绑定
        store.insert_card(&card1).unwrap();
        store.insert_card(&card2).unwrap();
        store.add_card_pool_binding(&card1.id, &pool_id).unwrap();
        store.add_card_pool_binding(&card2.id, &pool_id).unwrap();

        // 软删除 card1
        card1.mark_deleted();
        store.update_card(&card1).unwrap();

        // 查询数据池卡片（应该只有 card2）
        let cards = store.get_cards_in_pools(&[pool_id]).unwrap();
        assert_eq!(cards.len(), 1);
        assert_eq!(cards[0].id, card2.id);
    }

    #[test]
    fn test_get_cards_in_pools_empty_pools() {
        let store = SqliteStore::new_in_memory().unwrap();

        // 空数据池列表应返回空结果
        let cards = store.get_cards_in_pools(&[]).unwrap();
        assert_eq!(cards.len(), 0);
    }
}
