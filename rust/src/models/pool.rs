// input: 来自建池/入池/同步流程的 pool_id、成员信息与关联 card_id 集合。
// output: 可序列化的 Pool 与 PoolMember 结构体供存储和网络层复用。
// pos: 数据池领域模型定义文件，负责描述池元数据与成员数据形状。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件定义数据池与成员结构。
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
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
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
