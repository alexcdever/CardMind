use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// 卡片实体
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Card {
    pub id: Uuid,
    pub title: String,
    pub content: String,
    pub created_at: i64,
    pub updated_at: i64,
    pub deleted: bool,
}
