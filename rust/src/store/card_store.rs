// input: 卡片增删改查参数、当前时间戳、Loro 文档读写与 SQLite 查询结果。
// output: Card 创建/更新结果、软删除状态持久化与基于 SQLite 读模型的检索结果。
// pos: 卡片存储实现文件，负责先写 Loro 写模型，再更新 SQLite 读模型。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件实现卡片本地读写分离存储。
use crate::models::card::Card;
use crate::models::error::CardMindError;
use crate::store::loro_store::{load_loro_doc, note_doc_path, save_loro_doc};
use crate::store::path_resolver::DataPaths;
use crate::store::sqlite_store::SqliteStore;
use crate::utils::uuid_v7::new_uuid_v7;
use std::path::Path;
use std::time::{SystemTime, UNIX_EPOCH};
use uuid::Uuid;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum ProjectionMode {
    Normal,
    FailWrites,
}

/// 本地卡片笔记存储组件
pub struct CardNoteRepository {
    paths: DataPaths,
    sqlite: SqliteStore,
    projection_mode: ProjectionMode,
}

impl CardNoteRepository {
    const CARD_ENTITY: &'static str = "card";
    const RETRY_PROJECTION: &'static str = "retry_projection";

    /// 创建卡片存储
    pub fn new(base_path: &str) -> Result<Self, CardMindError> {
        Self::new_with_projection_mode(base_path, ProjectionMode::Normal)
    }

    /// 创建一个注入投影失败的卡片存储（测试用）
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
    pub fn base_path(&self) -> &Path {
        &self.paths.base_path
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

    /// 恢复卡片
    pub fn restore_card(&self, id: &Uuid) -> Result<(), CardMindError> {
        let mut card = self.sqlite.get_card(id)?;
        card.deleted = false;
        card.updated_at = current_timestamp();
        self.persist_card(&card)?;
        Ok(())
    }

    /// 获取卡片
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

    /// 按产品语义查询卡片（支持池筛选和软删除选项）
    pub fn query_cards(
        &self,
        keyword: &str,
        pool_id: Option<&str>,
        include_deleted: bool,
    ) -> Result<Vec<Card>, CardMindError> {
        self.sqlite
            .query_cards(keyword, pool_id, include_deleted, 10_000, 0)
    }

    fn persist_card(&self, card: &Card) -> Result<(), CardMindError> {
        self.write_card_to_loro(card)?;
        self.project_card_to_sqlite(card)?;
        Ok(())
    }

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

    fn projection_not_converged_for(
        &self,
        id: &Uuid,
    ) -> Result<Option<CardMindError>, CardMindError> {
        Ok(self
            .sqlite
            .get_projection_retry_action(Self::CARD_ENTITY, &id.to_string())?
            .map(|retry_action| Self::build_projection_error(*id, retry_action)))
    }

    fn build_projection_error(id: Uuid, retry_action: String) -> CardMindError {
        CardMindError::ProjectionNotConverged {
            entity: Self::CARD_ENTITY.to_string(),
            entity_id: id.to_string(),
            retry_action,
        }
    }
}

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
