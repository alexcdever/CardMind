// input: 来自存储层与序列化流程的卡片字段值（id/title/content/timestamp/deleted）。
// output: 可序列化的 Card 结构体，供 API/存储/同步模块共享使用。
// pos: 卡片领域模型定义文件，负责约束单张卡片的数据形状。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件仅定义 Card 数据结构。
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
