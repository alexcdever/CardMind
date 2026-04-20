use crate::models::pool::PoolMember;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum MemberRuntimeStatus {
    Connected,
    Syncing,
    Offline,
}

impl MemberRuntimeStatus {
    pub fn from_signals(is_connected: bool, is_syncing: bool) -> Self {
        if is_syncing {
            Self::Syncing
        } else if is_connected {
            Self::Connected
        } else {
            Self::Offline
        }
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Connected => "connected",
            Self::Syncing => "syncing",
            Self::Offline => "offline",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PoolMemberRuntime {
    pub endpoint_id: String,
    pub nickname: String,
    pub os: String,
    pub role: String,
    pub status: MemberRuntimeStatus,
    pub last_active_at: Option<i64>,
    pub is_current_device: bool,
}

impl PoolMemberRuntime {
    pub fn from_member(
        member: &PoolMember,
        current_endpoint_id: &str,
        status: MemberRuntimeStatus,
        last_active_at: Option<i64>,
    ) -> Self {
        Self {
            endpoint_id: member.endpoint_id.clone(),
            nickname: member.nickname.clone(),
            os: member.os.clone(),
            role: if member.is_admin {
                "admin".to_string()
            } else {
                "member".to_string()
            },
            status,
            last_active_at,
            is_current_device: member.endpoint_id == current_endpoint_id,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PoolRuntimeSummary {
    pub member_count: usize,
    pub connected_count: usize,
    pub syncing_count: usize,
    pub offline_count: usize,
}
