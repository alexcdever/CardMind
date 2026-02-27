// input: 数据池与成员字段定义（不含 pool_key）
// output: Pool/PoolMember 数据结构
// pos: 数据池模型定义（修改本文件需同步更新文件头与所属 DIR.md）
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// 数据池元数据
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Pool {
    /// 数据池 ID（UUID v7）
    pub pool_id: Uuid,
    /// 成员列表
    pub members: Vec<PoolMember>,
    /// 关联卡片 ID 列表
    pub card_ids: Vec<Uuid>,
}

/// 数据池成员信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PoolMember {
    /// 成员应用 endpoint id
    pub endpoint_id: String,
    /// 成员昵称
    pub nickname: String,
    /// 操作系统平台名称
    pub os: String,
    /// 是否管理员
    pub is_admin: bool,
}
