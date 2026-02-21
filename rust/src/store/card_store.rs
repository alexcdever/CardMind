use crate::models::card::Card;
use crate::utils::uuid_v7::new_uuid_v7;
use std::time::{SystemTime, UNIX_EPOCH};

/// 本地卡片存储
pub struct CardStore;

/// 本地卡片存储实现
impl CardStore {
    /// 创建内存存储
    pub fn memory() -> Self {
        Self
    }

    /// 创建卡片
    pub fn create_card(&self, title: &str, content: &str) -> Card {
        let now = match SystemTime::now().duration_since(UNIX_EPOCH) {
            Ok(duration) => duration.as_secs() as i64,
            Err(_) => 0,
        };

        Card {
            id: new_uuid_v7(),
            title: title.to_string(),
            content: content.to_string(),
            created_at: now,
            updated_at: now,
            deleted: false,
        }
    }
}
