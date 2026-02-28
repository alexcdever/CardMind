// input: rust/src/net/messages.rs 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Rust 网络与同步模块，负责连接、会话与消息流转。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Rust 网络与同步模块，负责连接、会话与消息流转。
use crate::models::pool::PoolMember;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum PoolMessage {
    Hello {
        pool_id: Uuid,
        endpoint_id: String,
        nickname: String,
        os: String,
    },
    JoinRequest {
        pool_id: Uuid,
        applicant: PoolMember,
    },
    JoinForward {
        pool_id: Uuid,
        applicant: PoolMember,
    },
    JoinDecision {
        pool_id: Uuid,
        approved: bool,
        reason: Option<String>,
    },
    PoolSnapshot {
        pool_id: Uuid,
        bytes: Vec<u8>,
    },
    PoolUpdates {
        pool_id: Uuid,
        bytes: Vec<u8>,
    },
    CardSnapshot {
        card_id: Uuid,
        bytes: Vec<u8>,
    },
    CardUpdates {
        card_id: Uuid,
        bytes: Vec<u8>,
    },
}
