use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Pool {
    pub pool_id: Uuid,
    pub pool_key: String,
    pub members: Vec<PoolMember>,
    pub card_ids: Vec<Uuid>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PoolMember {
    pub peer_id: String,
    pub public_key: String,
    pub multiaddr: String,
    pub os: String,
    pub hostname: String,
    pub is_admin: bool,
}
