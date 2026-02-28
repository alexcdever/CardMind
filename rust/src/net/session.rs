// input: rust/src/net/session.rs 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Rust 网络与同步模块，负责连接、会话与消息流转。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Rust 网络与同步模块，负责连接、会话与消息流转。
use crate::models::error::CardMindError;
use crate::models::pool::PoolMember;
use std::collections::HashSet;
use uuid::Uuid;

#[derive(Clone)]
pub enum SyncPhase {
    Idle,
    Connected,
}

#[derive(Clone)]
pub struct SyncSession {
    phase: SyncPhase,
    target: Option<String>,
}

impl SyncSession {
    pub fn new() -> Self {
        Self {
            phase: SyncPhase::Idle,
            target: None,
        }
    }

    pub fn connect(&mut self, target: String) -> Result<(), CardMindError> {
        if target.trim().is_empty() {
            return Err(CardMindError::InvalidArgument(
                "target is empty".to_string(),
            ));
        }
        self.phase = SyncPhase::Connected;
        self.target = Some(target);
        Ok(())
    }

    pub fn disconnect(&mut self) {
        self.phase = SyncPhase::Idle;
        self.target = None;
    }

    pub fn state(&self) -> &'static str {
        match self.phase {
            SyncPhase::Idle => "idle",
            SyncPhase::Connected => "connected",
        }
    }
}

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
