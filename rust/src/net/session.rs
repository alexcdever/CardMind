// input: 数据池成员列表
// output: 会话成员校验结果
// pos: 组网会话管理（修改本文件需同步更新文件头与所属 DIR.md）
use crate::models::error::CardMindError;
use crate::models::pool::PoolMember;
use std::collections::HashSet;
use uuid::Uuid;

pub struct PoolSession {
    pool_id: Uuid,
    members: HashSet<String>,
}

impl PoolSession {
    pub fn new(pool_id: Uuid, members: &[PoolMember]) -> Self {
        let members = members
            .iter()
            .map(|member| member.endpoint_id.clone())
            .collect();
        Self { pool_id, members }
    }

    pub fn pool_id(&self) -> &Uuid {
        &self.pool_id
    }

    pub fn validate_peer(&self, endpoint_id: &str) -> Result<(), CardMindError> {
        if self.members.contains(endpoint_id) {
            Ok(())
        } else {
            Err(CardMindError::NotMember("not member".to_string()))
        }
    }
}
