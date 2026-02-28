// input: 同步协议需要交换的池、成员、卡片快照与增量字段定义。
// output: 可序列化 PoolMessage 枚举，统一点对点消息载荷类型。
// pos: 同步消息模型文件，负责声明网络层可传输消息协议。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件定义网络消息枚举。
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
