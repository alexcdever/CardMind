// input: 
// output: 
// pos: 
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// 卡片实体
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Card {
    /// 卡片 ID（UUID v7）
    pub id: Uuid,
    /// 卡片标题
    pub title: String,
    /// 卡片正文（Markdown）
    pub content: String,
    /// 创建时间（秒）
    pub created_at: i64,
    /// 更新时间（秒）
    pub updated_at: i64,
    /// 软删除标记
    pub deleted: bool,
}
