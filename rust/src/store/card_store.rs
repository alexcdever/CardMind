//! # 卡片存储模块
//!
//! 实现卡片的本地存储与读写分离架构。
//!
//! ## 架构说明
//!
//! 本模块采用双引擎存储架构：
//!
//! 1. **Loro CRDT 写模型**：以 Loro 文档形式存储，提供冲突自由复制数据类型支持
//! 2. **SQLite 读模型**：以结构化表形式存储，提供高效查询能力
//!
//! 写操作顺序：
//! 1. 先写入 Loro 文档（写模型）
//! 2. 再投影到 SQLite（读模型）
//!
//! 读操作直接从 SQLite 读模型获取，确保性能。
//!
//! ## 软删除机制
//!
//! 卡片支持软删除，删除的卡片保留在 Loro 中，但在 SQLite 中标记为已删除。
//! 可通过 `restore_card` 方法恢复。
//!
//! ## 调用约束
//!
//! - 初始化时需要提供有效的 base_path
//! - 卡片 ID 使用 UUID v7 生成，保证时间有序性
//!
//! ## 性能说明
//!
//! - 创建/更新：O(1) - 单个文档写入
//! - 查询：O(log n) - SQLite 索引查询
//! - 列表：O(limit) - 分页查询

use crate::models::card::Card;
use crate::models::error::CardMindError;
use crate::store::loro_store::{load_loro_doc, note_doc_path, save_loro_doc};
use crate::store::path_resolver::DataPaths;
use crate::store::sqlite_store::SqliteStore;
use crate::utils::uuid_v7::new_uuid_v7;
use std::path::Path;
use std::time::{SystemTime, UNIX_EPOCH};
use uuid::Uuid;

/// 投影模式
///
/// 控制 Loro 到 SQLite 的投影行为。正常模式下会同步更新 SQLite，
/// 测试模式下可模拟投影失败以测试容错逻辑。
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum ProjectionMode {
    /// 正常模式，投影到 SQLite
    Normal,
    /// 测试模式，模拟投影失败
    FailWrites,
}

/// 本地卡片笔记存储仓库
///
/// 提供卡片的完整生命周期管理，包括创建、读取、更新、删除（软删除）和恢复。
///
/// # 示例
///
/// ```rust,ignore
/// // 需要有效的文件系统路径
/// let repo = CardNoteRepository::new("/path/to/data").unwrap();
/// let card = repo.create_card("标题", "内容").unwrap();
/// println!("创建卡片: {}", card.id);
/// ```
pub struct CardNoteRepository {
    /// 数据路径集合
    paths: DataPaths,
    /// SQLite 读模型存储
    sqlite: SqliteStore,
    /// 投影模式
    projection_mode: ProjectionMode,
}

impl CardNoteRepository {
    const CARD_ENTITY: &'static str = "card";
    const RETRY_PROJECTION: &'static str = "retry_projection";

    /// 创建卡片存储实例
    ///
    /// # 参数
    /// * `base_path` - 数据存储根目录路径
    ///
    /// # 返回
    /// * `Ok(CardNoteRepository)` - 成功创建的存储实例
    /// * `Err(CardMindError)` - 初始化失败时的错误
    ///
    /// # Errors
    /// - `CardMindError::InvalidArgument` - base_path 为空
    /// - `CardMindError::Io` - 目录创建失败
    /// - `CardMindError::Sqlite` - 数据库初始化失败
    ///
    /// # 示例
    /// ```rust,ignore
    /// // 需要有效的文件系统路径
    /// let repo = CardNoteRepository::new("/path/to/data").unwrap();
    /// ```
    pub fn new(base_path: &str) -> Result<Self, CardMindError> {
        Self::new_with_projection_mode(base_path, ProjectionMode::Normal)
    }

    /// 创建注入投影失败的存储实例（仅用于测试）
    ///
    /// 此模式下的写操作会故意让 SQLite 投影失败，用于测试
    /// `ProjectionNotConverged` 错误处理逻辑。
    ///
    /// # 参数
    /// * `base_path` - 数据存储根目录路径
    ///
    /// # 返回
    /// * `Ok(CardNoteRepository)` - 成功创建的存储实例（测试模式）
    /// * `Err(CardMindError)` - 初始化失败时的错误
    ///
    /// # 注意
    /// 此方法仅用于测试，生产环境应使用 `new`。
    pub fn new_with_projection_failure(base_path: &str) -> Result<Self, CardMindError> {
        Self::new_with_projection_mode(base_path, ProjectionMode::FailWrites)
    }

    fn new_with_projection_mode(
        base_path: &str,
        projection_mode: ProjectionMode,
    ) -> Result<Self, CardMindError> {
        let paths = DataPaths::new(base_path)?;
        let sqlite = SqliteStore::new(&paths.sqlite_path)?;
        Ok(Self {
            paths,
            sqlite,
            projection_mode,
        })
    }

    /// 获取存储根路径
    ///
    /// # 返回
    /// 存储根目录的 Path 引用
    pub fn base_path(&self) -> &Path {
        &self.paths.base_path
    }

    /// 创建新卡片
    ///
    /// 生成新的 UUID v7 作为卡片 ID，将卡片数据写入 Loro 文档并投影到 SQLite。
    ///
    /// # 参数
    /// * `title` - 卡片标题
    /// * `content` - 卡片内容
    ///
    /// # 返回
    /// * `Ok(Card)` - 成功创建的卡片，包含生成的 ID 和时间戳
    /// * `Err(CardMindError)` - 创建失败时的错误
    ///
    /// # Errors
    /// - `CardMindError::Loro` - Loro 文档操作失败
    /// - `CardMindError::Sqlite` - SQLite 投影失败
    /// - `CardMindError::ProjectionNotConverged` - 投影未收敛（测试模式）
    ///
    /// # 示例
    /// ```rust,ignore
    /// // 需要 CardNoteRepository 实例
    /// let card = repo.create_card("Rust 所有权", "所有权是 Rust 的核心特性...").unwrap();
    /// assert!(!card.title.is_empty());
    /// ```
    pub fn create_card(&self, title: &str, content: &str) -> Result<Card, CardMindError> {
        let now = current_timestamp();
        let card = Card {
            id: new_uuid_v7(),
            title: title.to_string(),
            content: content.to_string(),
            created_at: now,
            updated_at: now,
            deleted: false,
        };
        self.persist_card(&card)?;
        Ok(card)
    }

    /// 更新卡片
    ///
    /// 更新卡片的标题和内容，自动更新 `updated_at` 时间戳。
    ///
    /// # 参数
    /// * `id` - 要更新的卡片 ID
    /// * `title` - 新的标题
    /// * `content` - 新的内容
    ///
    /// # 返回
    /// * `Ok(Card)` - 更新后的卡片
    /// * `Err(CardMindError)` - 更新失败时的错误
    ///
    /// # Errors
    /// - `CardMindError::NotFound` - 卡片不存在
    /// - `CardMindError::Loro` - Loro 文档操作失败
    /// - `CardMindError::Sqlite` - SQLite 投影失败
    ///
    /// # 示例
    /// ```rust,ignore
    /// // 需要 CardNoteRepository 实例和有效的卡片 ID
    /// let updated = repo.update_card(&card_id, "新标题", "新内容").unwrap();
    /// assert_eq!(updated.title, "新标题");
    /// ```
    pub fn update_card(
        &self,
        id: &Uuid,
        title: &str,
        content: &str,
    ) -> Result<Card, CardMindError> {
        let mut card = self.sqlite.get_card(id)?;
        card.title = title.to_string();
        card.content = content.to_string();
        card.updated_at = current_timestamp();
        self.persist_card(&card)?;
        Ok(card)
    }

    /// 删除卡片（软删除）
    ///
    /// 将卡片标记为已删除，而非物理删除。已删除的卡片可通过 `restore_card` 恢复。
    ///
    /// # 参数
    /// * `id` - 要删除的卡片 ID
    ///
    /// # 返回
    /// * `Ok(())` - 删除成功
    /// * `Err(CardMindError)` - 删除失败时的错误
    ///
    /// # Errors
    /// - `CardMindError::NotFound` - 卡片不存在
    /// - `CardMindError::Loro` - Loro 文档操作失败
    /// - `CardMindError::Sqlite` - SQLite 投影失败
    ///
    /// # 示例
    /// ```rust,ignore
    /// // 需要 CardNoteRepository 实例和有效的卡片 ID
    /// repo.delete_card(&card_id).unwrap();
    /// // 卡片现在被标记为已删除，但数据仍然存在
    /// ```
    pub fn delete_card(&self, id: &Uuid) -> Result<(), CardMindError> {
        let mut card = self.sqlite.get_card(id)?;
        card.deleted = true;
        card.updated_at = current_timestamp();
        self.persist_card(&card)?;
        Ok(())
    }

    /// 恢复已删除的卡片
    ///
    /// 将标记为已删除的卡片恢复为正常状态。
    ///
    /// # 参数
    /// * `id` - 要恢复的卡片 ID
    ///
    /// # 返回
    /// * `Ok(())` - 恢复成功
    /// * `Err(CardMindError)` - 恢复失败时的错误
    ///
    /// # Errors
    /// - `CardMindError::NotFound` - 卡片不存在或未被删除
    /// - `CardMindError::Loro` - Loro 文档操作失败
    /// - `CardMindError::Sqlite` - SQLite 投影失败
    pub fn restore_card(&self, id: &Uuid) -> Result<(), CardMindError> {
        let mut card = self.sqlite.get_card(id)?;
        card.deleted = false;
        card.updated_at = current_timestamp();
        self.persist_card(&card)?;
        Ok(())
    }

    /// 获取单张卡片
    ///
    /// 从 SQLite 读模型获取卡片。如果卡片在 Loro 中存在但在 SQLite 中不存在
    /// （投影未收敛），会返回 `ProjectionNotConverged` 错误。
    ///
    /// # 参数
    /// * `id` - 卡片 ID
    ///
    /// # 返回
    /// * `Ok(Card)` - 找到的卡片
    /// * `Err(CardMindError)` - 获取失败时的错误
    ///
    /// # Errors
    /// - `CardMindError::NotFound` - 卡片不存在
    /// - `CardMindError::ProjectionNotConverged` - 投影未收敛，需重试
    /// - `CardMindError::Sqlite` - 数据库查询错误
    pub fn get_card(&self, id: &Uuid) -> Result<Card, CardMindError> {
        match self.sqlite.get_card(id) {
            Ok(card) => Ok(card),
            Err(CardMindError::NotFound(_)) => {
                if let Some(error) = self.projection_not_converged_for(id)? {
                    return Err(error);
                }
                Err(CardMindError::NotFound("card not found".to_string()))
            }
            Err(err) => Err(err),
        }
    }

    /// 分页列出卡片
    ///
    /// 从 SQLite 读模型按创建时间倒序列出卡片。
    ///
    /// # 参数
    /// * `limit` - 每页数量限制
    /// * `offset` - 偏移量（跳过的记录数）
    ///
    /// # 返回
    /// * `Ok(Vec<Card>)` - 卡片列表
    /// * `Err(CardMindError)` - 查询失败时的错误
    ///
    /// # Errors
    /// - `CardMindError::Sqlite` - 数据库查询错误
    pub fn list_cards(&self, limit: i64, offset: i64) -> Result<Vec<Card>, CardMindError> {
        self.sqlite.list_cards(limit, offset)
    }

    /// 搜索卡片
    ///
    /// 在标题和内容中搜索包含关键字的卡片（不区分大小写）。
    ///
    /// # 参数
    /// * `keyword` - 搜索关键字
    /// * `limit` - 结果数量限制
    /// * `offset` - 偏移量
    ///
    /// # 返回
    /// * `Ok(Vec<Card>)` - 匹配的卡片列表
    /// * `Err(CardMindError)` - 搜索失败时的错误
    ///
    /// # Errors
    /// - `CardMindError::Sqlite` - 数据库查询错误
    pub fn search_cards(
        &self,
        keyword: &str,
        limit: i64,
        offset: i64,
    ) -> Result<Vec<Card>, CardMindError> {
        self.sqlite.search_cards(keyword, limit, offset)
    }

    /// 高级查询卡片
    ///
    /// 支持按池筛选和软删除状态筛选的灵活查询。
    ///
    /// # 参数
    /// * `keyword` - 搜索关键字（可选，空字符串表示不过滤）
    /// * `pool_id` - 池 ID 筛选（None 表示不过滤）
    /// * `include_deleted` - 是否包含已删除的卡片
    ///
    /// # 返回
    /// * `Ok(Vec<Card>)` - 匹配的卡片列表（最多 10000 条）
    /// * `Err(CardMindError)` - 查询失败时的错误
    ///
    /// # Errors
    /// - `CardMindError::Sqlite` - 数据库查询错误
    pub fn query_cards(
        &self,
        keyword: &str,
        pool_id: Option<&str>,
        include_deleted: bool,
    ) -> Result<Vec<Card>, CardMindError> {
        self.sqlite
            .query_cards(keyword, pool_id, include_deleted, 10_000, 0)
    }

    /// 持久化卡片（内部方法）
    ///
    /// 执行完整的写操作：先写 Loro，再投影到 SQLite。
    fn persist_card(&self, card: &Card) -> Result<(), CardMindError> {
        self.write_card_to_loro(card)?;
        self.project_card_to_sqlite(card)?;
        Ok(())
    }

    /// 将卡片写入 Loro 文档
    ///
    /// # 参数
    /// * `card` - 要写入的卡片
    ///
    /// # Errors
    /// - `CardMindError::Loro` - Loro 操作失败
    /// - `CardMindError::Io` - 文件读写失败
    fn write_card_to_loro(&self, card: &Card) -> Result<(), CardMindError> {
        let path = self.paths.base_path.join(note_doc_path(&card.id));
        let doc = load_loro_doc(&path)?;
        let map = doc.get_map("card");
        map.insert("id", card.id.to_string())
            .map_err(|e| CardMindError::Loro(e.to_string()))?;
        map.insert("title", card.title.as_str())
            .map_err(|e| CardMindError::Loro(e.to_string()))?;
        map.insert("content", card.content.as_str())
            .map_err(|e| CardMindError::Loro(e.to_string()))?;
        map.insert("created_at", card.created_at)
            .map_err(|e| CardMindError::Loro(e.to_string()))?;
        map.insert("updated_at", card.updated_at)
            .map_err(|e| CardMindError::Loro(e.to_string()))?;
        map.insert("deleted", card.deleted)
            .map_err(|e| CardMindError::Loro(e.to_string()))?;
        doc.commit();
        save_loro_doc(&path, &doc)
    }

    /// 将卡片投影到 SQLite
    ///
    /// 根据投影模式决定是否实际写入 SQLite。
    fn project_card_to_sqlite(&self, card: &Card) -> Result<(), CardMindError> {
        if self.projection_mode == ProjectionMode::FailWrites {
            self.sqlite.record_projection_failure(
                Self::CARD_ENTITY,
                &card.id.to_string(),
                Self::RETRY_PROJECTION,
            )?;
            return Err(Self::build_projection_error(
                card.id,
                Self::RETRY_PROJECTION.to_string(),
            ));
        }
        self.sqlite.upsert_card(card)?;
        self.sqlite
            .clear_projection_failure(Self::CARD_ENTITY, &card.id.to_string())?;
        Ok(())
    }

    /// 检查投影是否未收敛
    ///
    /// 如果投影失败过，返回对应的错误信息。
    fn projection_not_converged_for(
        &self,
        id: &Uuid,
    ) -> Result<Option<CardMindError>, CardMindError> {
        Ok(self
            .sqlite
            .get_projection_retry_action(Self::CARD_ENTITY, &id.to_string())?
            .map(|retry_action| Self::build_projection_error(*id, retry_action)))
    }

    /// 构建投影错误
    fn build_projection_error(id: Uuid, retry_action: String) -> CardMindError {
        CardMindError::ProjectionNotConverged {
            entity: Self::CARD_ENTITY.to_string(),
            entity_id: id.to_string(),
            retry_action,
        }
    }
}

/// 获取当前 Unix 时间戳
fn current_timestamp() -> i64 {
    match SystemTime::now().duration_since(UNIX_EPOCH) {
        Ok(duration) => duration.as_secs() as i64,
        Err(_) => 0,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    fn create_repo() -> (CardNoteRepository, TempDir) {
        let temp = TempDir::new().unwrap();
        let repo = CardNoteRepository::new(temp.path().to_str().unwrap()).unwrap();
        (repo, temp)
    }

    #[test]
    fn get_card_propagates_sqlite_errors() {
        let (repo, _temp) = create_repo();
        let conn = rusqlite::Connection::open(&repo.paths.sqlite_path).unwrap();
        conn.execute("DROP TABLE cards", []).unwrap();

        let result = repo.get_card(&Uuid::new_v4()).unwrap_err();

        match result {
            CardMindError::Sqlite(_) => {}
            other => panic!("unexpected error: {:?}", other),
        }
    }
}
