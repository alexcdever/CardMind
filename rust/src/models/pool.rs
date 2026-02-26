// input: 
// output: 
// pos: 
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// 数据池元数据
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Pool {
    /// 数据池 ID（UUID v7）
    pub pool_id: Uuid,
    /// 数据池密钥（Base64）
    pub pool_key: String,
    /// 成员列表
    pub members: Vec<PoolMember>,
    /// 关联卡片 ID 列表
    pub card_ids: Vec<Uuid>,
}

/// 数据池成员信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PoolMember {
    /// 成员应用 peer id
    pub peer_id: String,
    /// 成员应用公钥
    pub public_key: String,
    /// 成员访问地址（multiaddr）
    pub multiaddr: String,
    /// 操作系统平台名称
    pub os: String,
    /// 主机名
    pub hostname: String,
    /// 是否管理员
    pub is_admin: bool,
}
