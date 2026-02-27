// input: 池成员与同步数据
// output: 组网消息枚举
// pos: 组网消息定义（修改本文件需同步更新文件头与所属 DIR.md）
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
