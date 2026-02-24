use crate::models::card::Card;
use crate::models::error::CardMindError;
use crate::store::loro_store::{load_loro_doc, note_doc_path, save_loro_doc};
use crate::store::path_resolver::DataPaths;
use crate::store::sqlite_store::SqliteStore;
use crate::utils::uuid_v7::new_uuid_v7;
use std::time::{SystemTime, UNIX_EPOCH};
use uuid::Uuid;

/// 本地卡片存储
pub struct CardStore {
    paths: DataPaths,
    sqlite: SqliteStore,
}

impl CardStore {
    /// 创建卡片存储
    pub fn new(base_path: &str) -> Result<Self, CardMindError> {
        let paths = DataPaths::new(base_path)?;
        let sqlite = SqliteStore::new(&paths.sqlite_path)?;
        Ok(Self { paths, sqlite })
    }

    /// 创建卡片
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
    pub fn delete_card(&self, id: &Uuid) -> Result<(), CardMindError> {
        let mut card = self.sqlite.get_card(id)?;
        card.deleted = true;
        card.updated_at = current_timestamp();
        self.persist_card(&card)?;
        Ok(())
    }

    /// 获取卡片
    pub fn get_card(&self, id: &Uuid) -> Result<Card, CardMindError> {
        self.sqlite.get_card(id)
    }

    /// 列出卡片
    pub fn list_cards(&self, limit: i64, offset: i64) -> Result<Vec<Card>, CardMindError> {
        self.sqlite.list_cards(limit, offset)
    }

    /// 搜索卡片
    pub fn search_cards(
        &self,
        keyword: &str,
        limit: i64,
        offset: i64,
    ) -> Result<Vec<Card>, CardMindError> {
        self.sqlite.search_cards(keyword, limit, offset)
    }

    fn persist_card(&self, card: &Card) -> Result<(), CardMindError> {
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
        save_loro_doc(&path, &doc)?;
        self.sqlite.upsert_card(card)?;
        Ok(())
    }
}

fn current_timestamp() -> i64 {
    match SystemTime::now().duration_since(UNIX_EPOCH) {
        Ok(duration) => duration.as_secs() as i64,
        Err(_) => 0,
    }
}
