// input: rust/src/models/card.rs 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Rust 数据模型模块，定义跨层共享的数据结构。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Rust 数据模型模块，定义跨层共享的数据结构。
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
