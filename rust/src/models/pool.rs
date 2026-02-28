// input: rust/src/models/pool.rs 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Rust 数据模型模块，定义跨层共享的数据结构。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Rust 数据模型模块，定义跨层共享的数据结构。
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
