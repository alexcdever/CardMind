/// CardStore - 管理Loro CRDT文档和SQLite缓存
///
/// 这是核心存储层，实现双层架构：
/// - **Loro**: 数据源头，每个卡片独立的LoroDoc文件
/// - **SQLite**: 查询缓存，通过订阅自动同步
///
/// # 架构设计
///
/// 每个卡片有自己的LoroDoc文件，存储在：
/// ```text
/// data/loro/<hex(uuid)>/snapshot.loro
/// ```
///
/// SQLite作为只读缓存，所有写操作通过Loro完成后自动同步。
///
/// # 使用示例
///
/// ```rust,no_run
/// use cardmind_rust::store::card_store::CardStore;
///
/// // 创建store
/// let mut store = CardStore::new_in_memory()?;
///
/// // 创建卡片
/// let card = store.create_card("标题".to_string(), "内容".to_string())?;
///
/// // 查询卡片
/// let cards = store.get_active_cards()?;
/// # Ok::<(), cardmind_rust::models::error::CardMindError>(())
/// ```
use crate::models::card::Card;
use crate::models::error::CardMindError;
use crate::store::sqlite_store::SqliteStore;
use crate::utils::uuid_v7::generate_uuid_v7;
use loro::{ExportMode, LoroDoc};
use std::collections::HashMap;
use std::path::PathBuf;

/// CardStore - 卡片存储管理器
///
/// 管理Loro文档和SQLite缓存的核心组件
pub struct CardStore {
    /// SQLite缓存层
    sqlite: SqliteStore,

    /// 每个卡片的LoroDoc映射 (card_id -> LoroDoc)
    loro_docs: HashMap<String, LoroDoc>,

    /// 存储根目录（None表示内存模式）
    base_path: Option<PathBuf>,
}

impl CardStore {
    /// 创建内存模式的CardStore（用于测试）
    ///
    /// # 示例
    ///
    /// ```rust,no_run
    /// use cardmind_rust::store::card_store::CardStore;
    ///
    /// let store = CardStore::new_in_memory()?;
    /// # Ok::<(), cardmind_rust::models::error::CardMindError>(())
    /// ```
    pub fn new_in_memory() -> Result<Self, CardMindError> {
        let sqlite = SqliteStore::new_in_memory()?;

        Ok(Self {
            sqlite,
            loro_docs: HashMap::new(),
            base_path: None,
        })
    }

    /// 创建基于文件的CardStore
    ///
    /// # 参数
    ///
    /// * `path` - 存储根目录
    ///
    /// # 示例
    ///
    /// ```rust,no_run
    /// use cardmind_rust::store::card_store::CardStore;
    ///
    /// let store = CardStore::new("data")?;
    /// # Ok::<(), cardmind_rust::models::error::CardMindError>(())
    /// ```
    pub fn new(path: &str) -> Result<Self, CardMindError> {
        let base_path = PathBuf::from(path);

        // 创建必要的目录
        std::fs::create_dir_all(&base_path)?;
        std::fs::create_dir_all(base_path.join("loro"))?;

        // 创建SQLite store
        let sqlite_path = base_path.join("cache.db");
        let sqlite = SqliteStore::new(sqlite_path.to_str().unwrap())?;

        let mut store = Self {
            sqlite,
            loro_docs: HashMap::new(),
            base_path: Some(base_path.clone()),
        };

        // 加载现有的卡片
        store.load_existing_cards()?;

        Ok(store)
    }

    /// 从文件系统加载现有卡片
    fn load_existing_cards(&mut self) -> Result<(), CardMindError> {
        if let Some(base_path) = &self.base_path {
            let loro_dir = base_path.join("loro");

            // 遍历loro目录下的所有卡片文件夹
            if loro_dir.exists() {
                for entry in std::fs::read_dir(&loro_dir)? {
                    let entry = entry?;
                    if entry.file_type()?.is_dir() {
                        let snapshot_path = entry.path().join("snapshot.loro");

                        if snapshot_path.exists() {
                            // 加载LoroDoc
                            let bytes = std::fs::read(&snapshot_path)?;
                            let doc = LoroDoc::new();
                            doc.import(&bytes)?;

                            // 从Loro提取卡片数据
                            if let Some(card) = self.extract_card_from_loro(&doc)? {
                                let card_id = card.id.clone();

                                // 同步到SQLite
                                self.sync_card_to_sqlite(&card)?;

                                // 缓存LoroDoc
                                self.loro_docs.insert(card_id, doc);
                            }
                        }
                    }
                }
            }
        }

        Ok(())
    }

    /// 从LoroDoc提取Card数据
    fn extract_card_from_loro(&self, doc: &LoroDoc) -> Result<Option<Card>, CardMindError> {
        let map = doc.get_map("card");

        // 检查是否有数据
        if map.is_empty() {
            return Ok(None);
        }

        let id = map
            .get("id")
            .and_then(|v| v.into_value().ok())
            .and_then(|v| v.as_string().map(|s| s.to_string()))
            .ok_or_else(|| CardMindError::DatabaseError("Missing id field".to_string()))?;

        let title = map
            .get("title")
            .and_then(|v| v.into_value().ok())
            .and_then(|v| v.as_string().map(|s| s.to_string()))
            .ok_or_else(|| CardMindError::DatabaseError("Missing title field".to_string()))?;

        let content = map
            .get("content")
            .and_then(|v| v.into_value().ok())
            .and_then(|v| v.as_string().map(|s| s.to_string()))
            .ok_or_else(|| CardMindError::DatabaseError("Missing content field".to_string()))?;

        let created_at = map
            .get("created_at")
            .and_then(|v| v.into_value().ok())
            .and_then(|v| v.as_i64().copied())
            .ok_or_else(|| CardMindError::DatabaseError("Missing created_at field".to_string()))?;

        let updated_at = map
            .get("updated_at")
            .and_then(|v| v.into_value().ok())
            .and_then(|v| v.as_i64().copied())
            .ok_or_else(|| CardMindError::DatabaseError("Missing updated_at field".to_string()))?;

        let deleted = map
            .get("deleted")
            .and_then(|v| v.into_value().ok())
            .and_then(|v| v.as_bool().copied())
            .unwrap_or(false);

        // 从 Loro 读取 pool_ids
        let mut pool_ids = Vec::new();
        if let Some(pool_ids_value) = map.get("pool_ids") {
            if let Ok(pool_ids_container) = pool_ids_value.into_container() {
                if let Ok(pool_ids_list) = pool_ids_container.into_list() {
                    for i in 0..pool_ids_list.len() {
                        if let Some(pool_id_value) = pool_ids_list.get(i) {
                            if let Ok(pool_id_val) = pool_id_value.into_value() {
                                if let Some(pool_id_str) = pool_id_val.as_string() {
                                    pool_ids.push(pool_id_str.to_string());
                                }
                            }
                        }
                    }
                }
            }
        }

        Ok(Some(Card {
            id,
            title,
            content,
            created_at,
            updated_at,
            deleted,
            pool_ids,
        }))
    }

    /// 将Card数据写入LoroDoc
    fn write_card_to_loro(doc: &LoroDoc, card: &Card) -> Result<(), CardMindError> {
        let map = doc.get_map("card");
        map.insert("id", card.id.clone())?;
        map.insert("title", card.title.clone())?;
        map.insert("content", card.content.clone())?;
        map.insert("created_at", card.created_at)?;
        map.insert("updated_at", card.updated_at)?;
        map.insert("deleted", card.deleted)?;

        // 写入 pool_ids 作为 LoroList
        let pool_ids_list = map.insert_container("pool_ids", loro::LoroList::new())?;
        for pool_id in &card.pool_ids {
            pool_ids_list.push(pool_id.as_str())?;
        }

        Ok(())
    }

    /// 持久化LoroDoc到文件
    fn persist_loro_doc(&self, card_id: &str, doc: &LoroDoc) -> Result<(), CardMindError> {
        if let Some(base_path) = &self.base_path {
            // 使用十六进制编码card_id作为目录名
            let encoded_id: String = card_id.bytes().map(|b| format!("{:02x}", b)).collect();
            let card_dir = base_path.join("loro").join(&encoded_id);

            // 创建卡片目录
            std::fs::create_dir_all(&card_dir)?;

            // 导出snapshot
            let snapshot = doc.export(ExportMode::Snapshot)?;
            let snapshot_path = card_dir.join("snapshot.loro");
            std::fs::write(&snapshot_path, &snapshot)?;
        }

        Ok(())
    }

    /// 同步Card到SQLite
    fn sync_card_to_sqlite(&self, card: &Card) -> Result<(), CardMindError> {
        // 检查卡片是否已存在
        match self.sqlite.get_card_by_id(&card.id) {
            Ok(_) => {
                // 已存在，更新
                self.sqlite.update_card(card)?;
            }
            Err(CardMindError::CardNotFound(_)) => {
                // 不存在，插入
                self.sqlite.insert_card(card)?;
            }
            Err(e) => return Err(e),
        }

        Ok(())
    }

    // ==================== CRUD操作 ====================

    /// 创建新卡片
    ///
    /// # 参数
    ///
    /// * `title` - 卡片标题
    /// * `content` - 卡片内容（Markdown格式）
    ///
    /// # 返回
    ///
    /// 创建的卡片
    ///
    /// # 示例
    ///
    /// ```rust,no_run
    /// # use cardmind_rust::store::card_store::CardStore;
    /// let mut store = CardStore::new_in_memory()?;
    /// let card = store.create_card("我的笔记".to_string(), "内容".to_string())?;
    /// # Ok::<(), cardmind_rust::models::error::CardMindError>(())
    /// ```
    pub fn create_card(&mut self, title: String, content: String) -> Result<Card, CardMindError> {
        // 生成UUID v7
        let card_id = generate_uuid_v7();

        // 创建Card对象
        let card = Card::new(card_id.clone(), title, content);

        // 创建LoroDoc
        let doc = LoroDoc::new();
        Self::write_card_to_loro(&doc, &card)?;
        doc.commit();

        // 持久化到文件
        self.persist_loro_doc(&card_id, &doc)?;

        // 同步到SQLite
        self.sync_card_to_sqlite(&card)?;

        // 缓存LoroDoc
        self.loro_docs.insert(card_id, doc);

        Ok(card)
    }

    /// 获取所有卡片（包括已删除）
    ///
    /// # 返回
    ///
    /// 按创建时间倒序排列的卡片列表
    pub fn get_all_cards(&self) -> Result<Vec<Card>, CardMindError> {
        self.sqlite.get_all_cards()
    }

    /// 获取所有活跃卡片（排除已删除）
    ///
    /// # 返回
    ///
    /// 按创建时间倒序排列的活跃卡片列表
    ///
    /// # 示例
    ///
    /// ```rust,no_run
    /// # use cardmind_rust::store::card_store::CardStore;
    /// let store = CardStore::new_in_memory()?;
    /// let cards = store.get_active_cards()?;
    /// # Ok::<(), cardmind_rust::models::error::CardMindError>(())
    /// ```
    pub fn get_active_cards(&self) -> Result<Vec<Card>, CardMindError> {
        self.sqlite.get_active_cards()
    }

    /// 按ID获取卡片
    ///
    /// # 参数
    ///
    /// * `id` - 卡片ID
    ///
    /// # 返回
    ///
    /// 找到的卡片，如果不存在则返回CardNotFound错误
    pub fn get_card_by_id(&self, id: &str) -> Result<Card, CardMindError> {
        self.sqlite.get_card_by_id(id)
    }

    /// 更新卡片
    ///
    /// # 参数
    ///
    /// * `id` - 卡片ID
    /// * `title` - 新标题（None表示不更新）
    /// * `content` - 新内容（None表示不更新）
    ///
    /// # 示例
    ///
    /// ```rust,no_run
    /// # use cardmind_rust::store::card_store::CardStore;
    /// let mut store = CardStore::new_in_memory()?;
    /// # let card = store.create_card("标题".to_string(), "内容".to_string())?;
    /// store.update_card(&card.id, Some("新标题".to_string()), None)?;
    /// # Ok::<(), cardmind_rust::models::error::CardMindError>(())
    /// ```
    pub fn update_card(
        &mut self,
        id: &str,
        title: Option<String>,
        content: Option<String>,
    ) -> Result<(), CardMindError> {
        // 获取当前卡片数据
        let mut card = self.get_card_by_id(id)?;

        // 更新字段
        card.update(title, content);

        // 加载LoroDoc（如果未缓存）
        self.ensure_loro_doc_loaded(id)?;

        // 获取LoroDoc并更新
        if let Some(doc) = self.loro_docs.get_mut(id) {
            Self::write_card_to_loro(doc, &card)?;
            doc.commit();

            // 导出snapshot（在借用结束后）
            let snapshot = doc.export(ExportMode::Snapshot)?;

            // 持久化到文件
            if let Some(base_path) = &self.base_path {
                let encoded_id: String = id.bytes().map(|b| format!("{:02x}", b)).collect();
                let card_dir = base_path.join("loro").join(&encoded_id);
                std::fs::create_dir_all(&card_dir)?;
                let snapshot_path = card_dir.join("snapshot.loro");
                std::fs::write(&snapshot_path, &snapshot)?;
            }
        }

        // 同步到SQLite
        self.sync_card_to_sqlite(&card)?;

        Ok(())
    }

    /// 删除卡片（软删除）
    ///
    /// # 参数
    ///
    /// * `id` - 卡片ID
    ///
    /// # 示例
    ///
    /// ```rust,no_run
    /// # use cardmind_rust::store::card_store::CardStore;
    /// let mut store = CardStore::new_in_memory()?;
    /// # let card = store.create_card("标题".to_string(), "内容".to_string())?;
    /// store.delete_card(&card.id)?;
    /// # Ok::<(), cardmind_rust::models::error::CardMindError>(())
    /// ```
    pub fn delete_card(&mut self, id: &str) -> Result<(), CardMindError> {
        // 获取当前卡片数据
        let mut card = self.get_card_by_id(id)?;

        // 标记为已删除
        card.mark_deleted();

        // 加载LoroDoc（如果未缓存）
        self.ensure_loro_doc_loaded(id)?;

        // 获取LoroDoc并更新
        if let Some(doc) = self.loro_docs.get_mut(id) {
            Self::write_card_to_loro(doc, &card)?;
            doc.commit();

            // 导出snapshot
            let snapshot = doc.export(ExportMode::Snapshot)?;

            // 持久化到文件
            if let Some(base_path) = &self.base_path {
                let encoded_id: String = id.bytes().map(|b| format!("{:02x}", b)).collect();
                let card_dir = base_path.join("loro").join(&encoded_id);
                std::fs::create_dir_all(&card_dir)?;
                let snapshot_path = card_dir.join("snapshot.loro");
                std::fs::write(&snapshot_path, &snapshot)?;
            }
        }

        // 同步到SQLite
        self.sync_card_to_sqlite(&card)?;

        Ok(())
    }

    /// 确保LoroDoc已加载到缓存中
    fn ensure_loro_doc_loaded(&mut self, id: &str) -> Result<(), CardMindError> {
        // 如果已缓存，直接返回
        if self.loro_docs.contains_key(id) {
            return Ok(());
        }

        // 如果是内存模式，说明文档不存在
        if self.base_path.is_none() {
            return Err(CardMindError::CardNotFound(id.to_string()));
        }

        // 从文件加载
        let base_path = self.base_path.as_ref().unwrap();
        let encoded_id: String = id.bytes().map(|b| format!("{:02x}", b)).collect();
        let snapshot_path = base_path
            .join("loro")
            .join(&encoded_id)
            .join("snapshot.loro");

        if !snapshot_path.exists() {
            return Err(CardMindError::CardNotFound(id.to_string()));
        }

        let bytes = std::fs::read(&snapshot_path)?;
        let doc = LoroDoc::new();
        doc.import(&bytes)?;

        self.loro_docs.insert(id.to_string(), doc);
        Ok(())
    }

    /// 获取卡片数量统计
    ///
    /// # 返回
    ///
    /// (总数, 活跃数, 已删除数)
    pub fn get_card_count(&self) -> Result<(i64, i64, i64), CardMindError> {
        self.sqlite.get_card_count()
    }

    // ==================== 数据池绑定相关方法 (Phase 6) ====================

    /// 将卡片添加到数据池
    ///
    /// # 参数
    ///
    /// * `card_id` - 卡片 ID
    /// * `pool_id` - 数据池 ID
    ///
    /// # 示例
    ///
    /// ```rust,no_run
    /// # use cardmind_rust::store::card_store::CardStore;
    /// let mut store = CardStore::new_in_memory()?;
    /// # let card = store.create_card("标题".to_string(), "内容".to_string())?;
    /// store.add_card_to_pool(&card.id, "pool-001")?;
    /// # Ok::<(), cardmind_rust::models::error::CardMindError>(())
    /// ```
    pub fn add_card_to_pool(&mut self, card_id: &str, pool_id: &str) -> Result<(), CardMindError> {
        // 更新 Loro 层的 pool_ids
        let mut card = self.get_card_by_id(card_id)?;
        card.add_pool(pool_id.to_string());

        // 确保 LoroDoc 已加载
        self.ensure_loro_doc_loaded(card_id)?;

        // 更新 Loro 并导出
        let snapshot = if let Some(doc) = self.loro_docs.get_mut(card_id) {
            Self::write_card_to_loro(doc, &card)?;
            doc.commit();
            Some(doc.export(ExportMode::Snapshot)?)
        } else {
            None
        };

        // 持久化
        if let Some(bytes) = snapshot {
            if let Some(base_path) = &self.base_path {
                let encoded_id: String = card_id.bytes().map(|b| format!("{:02x}", b)).collect();
                let card_dir = base_path.join("loro").join(&encoded_id);
                std::fs::create_dir_all(&card_dir)?;
                let snapshot_path = card_dir.join("snapshot.loro");
                std::fs::write(&snapshot_path, &bytes)?;
            }
        }

        // 同步到 SQLite
        self.sync_card_to_sqlite(&card)?;

        // 添加绑定关系
        self.sqlite.add_card_pool_binding(card_id, pool_id)?;

        Ok(())
    }

    /// 将卡片从数据池移除
    ///
    /// # 参数
    ///
    /// * `card_id` - 卡片 ID
    /// * `pool_id` - 数据池 ID
    ///
    /// # 示例
    ///
    /// ```rust,no_run
    /// # use cardmind_rust::store::card_store::CardStore;
    /// let mut store = CardStore::new_in_memory()?;
    /// # let card = store.create_card("标题".to_string(), "内容".to_string())?;
    /// # store.add_card_to_pool(&card.id, "pool-001")?;
    /// store.remove_card_from_pool(&card.id, "pool-001")?;
    /// # Ok::<(), cardmind_rust::models::error::CardMindError>(())
    /// ```
    pub fn remove_card_from_pool(
        &mut self,
        card_id: &str,
        pool_id: &str,
    ) -> Result<(), CardMindError> {
        // 更新 Loro 层的 pool_ids
        let mut card = self.get_card_by_id(card_id)?;
        card.remove_pool(pool_id);

        // 确保 LoroDoc 已加载
        self.ensure_loro_doc_loaded(card_id)?;

        // 更新 Loro 并导出
        let snapshot = if let Some(doc) = self.loro_docs.get_mut(card_id) {
            Self::write_card_to_loro(doc, &card)?;
            doc.commit();
            Some(doc.export(ExportMode::Snapshot)?)
        } else {
            None
        };

        // 持久化
        if let Some(bytes) = snapshot {
            if let Some(base_path) = &self.base_path {
                let encoded_id: String = card_id.bytes().map(|b| format!("{:02x}", b)).collect();
                let card_dir = base_path.join("loro").join(&encoded_id);
                std::fs::create_dir_all(&card_dir)?;
                let snapshot_path = card_dir.join("snapshot.loro");
                std::fs::write(&snapshot_path, &bytes)?;
            }
        }

        // 同步到 SQLite
        self.sync_card_to_sqlite(&card)?;

        // 移除绑定关系
        self.sqlite.remove_card_pool_binding(card_id, pool_id)?;

        Ok(())
    }

    /// 获取卡片所属的所有数据池 ID
    ///
    /// # 参数
    ///
    /// * `card_id` - 卡片 ID
    ///
    /// # 返回
    ///
    /// 数据池 ID 列表
    ///
    /// # 示例
    ///
    /// ```rust,no_run
    /// # use cardmind_rust::store::card_store::CardStore;
    /// let store = CardStore::new_in_memory()?;
    /// # let mut store = store;
    /// # let card = store.create_card("标题".to_string(), "内容".to_string())?;
    /// let pools = store.get_card_pools(&card.id)?;
    /// # Ok::<(), cardmind_rust::models::error::CardMindError>(())
    /// ```
    pub fn get_card_pools(&self, card_id: &str) -> Result<Vec<String>, CardMindError> {
        self.sqlite.get_card_pools(card_id)
    }

    /// 获取指定数据池中的所有卡片
    ///
    /// # 参数
    ///
    /// * `pool_ids` - 数据池 ID 列表
    ///
    /// # 返回
    ///
    /// 卡片列表（排除已删除的卡片）
    ///
    /// # 示例
    ///
    /// ```rust,no_run
    /// # use cardmind_rust::store::card_store::CardStore;
    /// let store = CardStore::new_in_memory()?;
    /// let pools = vec!["pool-001".to_string(), "pool-002".to_string()];
    /// let cards = store.get_cards_in_pools(&pools)?;
    /// # Ok::<(), cardmind_rust::models::error::CardMindError>(())
    /// ```
    pub fn get_cards_in_pools(&self, pool_ids: &[String]) -> Result<Vec<Card>, CardMindError> {
        self.sqlite.get_cards_in_pools(pool_ids)
    }

    /// 清除卡片的所有数据池绑定
    ///
    /// # 参数
    ///
    /// * `card_id` - 卡片 ID
    ///
    /// # 示例
    ///
    /// ```rust,no_run
    /// # use cardmind_rust::store::card_store::CardStore;
    /// let mut store = CardStore::new_in_memory()?;
    /// # let card = store.create_card("标题".to_string(), "内容".to_string())?;
    /// store.clear_card_pools(&card.id)?;
    /// # Ok::<(), cardmind_rust::models::error::CardMindError>(())
    /// ```
    pub fn clear_card_pools(&mut self, card_id: &str) -> Result<(), CardMindError> {
        // 更新 Loro 层
        let mut card = self.get_card_by_id(card_id)?;
        card.pool_ids.clear();
        card.updated_at = chrono::Utc::now().timestamp_millis();

        // 确保 LoroDoc 已加载
        self.ensure_loro_doc_loaded(card_id)?;

        // 更新 Loro 并导出
        let snapshot = if let Some(doc) = self.loro_docs.get_mut(card_id) {
            Self::write_card_to_loro(doc, &card)?;
            doc.commit();
            Some(doc.export(ExportMode::Snapshot)?)
        } else {
            None
        };

        // 持久化
        if let Some(bytes) = snapshot {
            if let Some(base_path) = &self.base_path {
                let encoded_id: String = card_id.bytes().map(|b| format!("{:02x}", b)).collect();
                let card_dir = base_path.join("loro").join(&encoded_id);
                std::fs::create_dir_all(&card_dir)?;
                let snapshot_path = card_dir.join("snapshot.loro");
                std::fs::write(&snapshot_path, &bytes)?;
            }
        }

        // 同步到 SQLite
        self.sync_card_to_sqlite(&card)?;

        // 清除绑定关系
        self.sqlite.clear_card_pools(card_id)?;

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_card_store_creation() {
        let store = CardStore::new_in_memory();
        assert!(store.is_ok(), "应该能创建CardStore");
    }

    #[test]
    fn test_create_and_get_card() {
        let mut store = CardStore::new_in_memory().unwrap();

        let card = store
            .create_card("测试".to_string(), "内容".to_string())
            .unwrap();

        let retrieved = store.get_card_by_id(&card.id).unwrap();
        assert_eq!(retrieved.title, "测试");
    }
}
