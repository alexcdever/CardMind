//! 同步领域模型
//!
//! 本模块定义了同步相关的数据结构和枚举，包括同步状态、同步操作类型和冲突解决策略。
//!
//! 实现规格: openspec/specs/domain/sync/model.md

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// 同步状态
///
/// # 字段说明
///
/// - `peer_id`: 对等设备标识
/// - `last_sync_version`: 最后同步版本向量
/// - `last_sync_time`: 最后同步时间（Unix 毫秒时间戳）
/// - `sync_status`: 同步状态
///
/// # 示例
///
/// ```
/// use cardmind_rust::models::sync::SyncState;
/// use std::collections::HashMap;
///
/// let mut version_vector = HashMap::new();
/// version_vector.insert("peer-001".to_string(), 42u64);
///
/// let sync_state = SyncState {
///     peer_id: "peer-001".to_string(),
///     last_sync_version: version_vector,
///     last_sync_time: 1704067200000,
///     sync_status: SyncStatus::Idle,
/// };
///
/// assert_eq!(sync_state.peer_id, "peer-001");
/// assert_eq!(sync_state.last_sync_time, 1704067200000);
/// ```
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct SyncState {
    /// 对等设备标识
    pub peer_id: String,

    /// 最后同步版本向量
    pub last_sync_version: HashMap<String, u64>,

    /// 最后同步时间（Unix 毫秒时间戳）
    pub last_sync_time: i64,

    /// 同步状态
    pub sync_status: SyncStatus,
}

impl SyncState {
    /// 创建新的同步状态
    ///
    /// # 参数
    ///
    /// - `peer_id`: 对等设备 ID
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::models::sync::SyncState;
    ///
    /// let sync_state = SyncState::new("peer-001");
    /// assert_eq!(sync_state.peer_id, "peer-001");
    /// assert!(sync_state.last_sync_version.is_empty());
    /// ```
    #[must_use]
    pub fn new(peer_id: &str) -> Self {
        Self {
            peer_id: peer_id.to_string(),
            last_sync_version: HashMap::new(),
            last_sync_time: 0,
            sync_status: SyncStatus::Idle,
        }
    }

    /// 更新同步状态
    ///
    /// # 参数
    ///
    /// - `new_version_vector`: 新的版本向量
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::models::sync::SyncState;
    /// use std::collections::HashMap;
    ///
    /// let mut sync_state = SyncState::new("peer-001");
    /// let mut new_versions = HashMap::new();
    /// new_versions.insert("peer-001".to_string(), 42u64);
    ///
    /// sync_state.update(&new_versions);
    /// assert_eq!(sync_state.last_sync_time > 0, true);
    /// assert_eq!(sync_state.last_sync_version["peer-001"], 42);
    /// ```
    pub fn update(&mut self, new_version_vector: &HashMap<String, u64>) {
        use std::time::{SystemTime, UNIX_EPOCH};

        self.last_sync_version = new_version_vector.clone();

        let now_ms = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|duration| duration.as_millis())
            .ok()
            .and_then(|millis| i64::try_from(millis).ok())
            .unwrap_or(i64::MAX);
        self.last_sync_time = now_ms;
        self.sync_status = SyncStatus::Completed;
    }

    /// 检查是否需要同步
    ///
    /// # 参数
    ///
    /// - `remote_version_vector`: 对等设备的版本向量
    ///
    /// # Returns
    ///
    /// 如果对等设备有本设备没有的数据，返回 true
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::models::sync::SyncState;
    /// use std::collections::HashMap;
    ///
    /// let mut sync_state = SyncState::new("peer-001");
    /// sync_state
    ///     .last_sync_version
    ///     .insert("peer-001".to_string(), 10u64);
    ///
    /// let mut remote_versions = HashMap::new();
    /// remote_versions.insert("device-001".to_string(), 20u64);
    ///
    /// assert!(sync_state.needs_sync(&remote_versions));
    /// ```
    #[must_use]
    pub fn needs_sync(&self, remote_version_vector: &HashMap<String, u64>) -> bool {
        for (device_id, remote_version) in remote_version_vector {
            let local_version = self.last_sync_version.get(device_id).copied().unwrap_or(0);
            if *remote_version > local_version {
                return true;
            }
        }
        false
    }

    #[must_use]
    pub fn get_last_sync_version(&self) -> &HashMap<String, u64> {
        &self.last_sync_version
    }
}

/// 同步状态
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum SyncStatus {
    Idle,
    Syncing,
    Failed,
    Completed,
}

/// 同步操作类型
///
/// 定义同步操作的方向和模式。
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum SyncOp {
    /// 推送本地变更到对等设备
    Push,

    /// 从对等设备拉取变更
    Pull,

    /// 双向同步（推送 + 拉取）
    Bidirectional,
}

/// 冲突解决策略
///
/// 定义当检测到数据冲突时的解决方式。
///
/// # 注意
///
/// CardMind 主要使用 CRDT 自动解决冲突，此枚举用于特殊场景。
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum ConflictResolution {
    /// 最后写入优先（基于时间戳）
    LastWriteWins,

    /// 合并冲突数据（仅适用于特定类型）
    Merge,

    /// 手动解决（需要用户介入）
    Manual,
}

impl ConflictResolution {
    /// 默认冲突解决策略
    ///
    /// CardMind 默认使用 CRDT 自动合并，此方法保留用于未来扩展。
    #[must_use]
    pub const fn default() -> Self {
        Self::Merge
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn it_should_sync_state_defaults() {
        let sync_state = SyncState::new("peer-001");
        assert_eq!(sync_state.peer_id, "peer-001");
        assert_eq!(sync_state.last_sync_time, 0);
        assert!(sync_state.last_sync_version.is_empty());
        assert_eq!(sync_state.sync_status, SyncStatus::Idle);
    }

    #[test]
    fn it_should_update_sync_state_sets_version_time_status() {
        let mut sync_state = SyncState::new("peer-001");
        let mut new_versions = HashMap::new();
        new_versions.insert("peer-001".to_string(), 10u64);

        sync_state.update(&new_versions);

        assert_eq!(
            sync_state.last_sync_version.get("peer-001"),
            Some(&10u64)
        );
        assert!(sync_state.last_sync_time > 0);
        assert_eq!(sync_state.sync_status, SyncStatus::Completed);
    }

    #[test]
    fn it_should_get_last_sync_version_returns_empty_when_new() {
        let sync_state = SyncState::new("peer-001");
        assert!(sync_state.get_last_sync_version().is_empty());
    }

    #[test]
    fn it_should_sync_status_variants() {
        assert_eq!(SyncStatus::Idle, SyncStatus::Idle);
        assert_eq!(SyncStatus::Syncing, SyncStatus::Syncing);
        assert_eq!(SyncStatus::Failed, SyncStatus::Failed);
        assert_eq!(SyncStatus::Completed, SyncStatus::Completed);
    }

    #[test]
    fn it_should_sync_state_creation() {
        let sync_state = SyncState::new("peer-001");
        assert_eq!(sync_state.peer_id, "peer-001");
        assert_eq!(sync_state.last_sync_time, 0);
        assert!(sync_state.last_sync_version.is_empty());
        assert_eq!(sync_state.sync_status, SyncStatus::Idle);
    }

    #[test]
    fn it_should_sync_state_update() {
        let mut sync_state = SyncState::new("peer-001");
        let mut new_versions = HashMap::new();
        new_versions.insert("peer-001".to_string(), 42u64);
        new_versions.insert("peer-002".to_string(), 100u64);

        sync_state.update(&new_versions);

        assert_eq!(sync_state.last_sync_version["peer-001"], 42);
        assert_eq!(sync_state.last_sync_version["peer-002"], 100);
        assert!(sync_state.last_sync_time > 0);
        assert_eq!(sync_state.sync_status, SyncStatus::Completed);
    }

    #[test]
    fn it_should_sync_state_update_overwrites_version() {
        let mut sync_state = SyncState::new("peer-001");
        sync_state
            .last_sync_version
            .insert("peer-001".to_string(), 10u64);

        let mut new_versions = HashMap::new();
        new_versions.insert("peer-001".to_string(), 5u64);
        new_versions.insert("peer-002".to_string(), 20u64);

        sync_state.update(&new_versions);

        assert_eq!(sync_state.last_sync_version["peer-001"], 5);
        assert_eq!(sync_state.last_sync_version["peer-002"], 20);
    }

    #[test]
    fn it_should_needs_sync_true() {
        let mut sync_state = SyncState::new("peer-001");
        sync_state
            .last_sync_version
            .insert("peer-001".to_string(), 10u64);

        let mut remote_versions = HashMap::new();
        remote_versions.insert("peer-001".to_string(), 20u64); // 对等设备有更新版本

        assert!(sync_state.needs_sync(&remote_versions));
    }

    #[test]
    fn it_should_needs_sync_false() {
        let mut sync_state = SyncState::new("peer-001");
        sync_state
            .last_sync_version
            .insert("peer-001".to_string(), 20u64);

        let mut remote_versions = HashMap::new();
        remote_versions.insert("peer-001".to_string(), 10u64); // 对等设备版本更旧

        assert!(!sync_state.needs_sync(&remote_versions));
    }

    #[test]
    fn it_should_needs_sync_equal() {
        let mut sync_state = SyncState::new("peer-001");
        sync_state
            .last_sync_version
            .insert("peer-001".to_string(), 20u64);

        let mut remote_versions = HashMap::new();
        remote_versions.insert("peer-001".to_string(), 20u64); // 版本相同

        assert!(!sync_state.needs_sync(&remote_versions));
    }

    #[test]
    fn it_should_sync_op_variants() {
        assert_eq!(SyncOp::Push, SyncOp::Push);
        assert_eq!(SyncOp::Pull, SyncOp::Pull);
        assert_eq!(SyncOp::Bidirectional, SyncOp::Bidirectional);
    }

    #[test]
    fn it_should_conflict_resolution_variants() {
        assert_eq!(
            ConflictResolution::LastWriteWins,
            ConflictResolution::LastWriteWins
        );
        assert_eq!(ConflictResolution::Merge, ConflictResolution::Merge);
        assert_eq!(ConflictResolution::Manual, ConflictResolution::Manual);
    }

    #[test]
    fn it_should_conflict_resolution_default() {
        assert_eq!(ConflictResolution::default(), ConflictResolution::Merge);
    }

    #[test]
    fn it_should_sync_state_serialization() {
        let mut sync_state = SyncState::new("peer-001");
        sync_state
            .last_sync_version
            .insert("peer-001".to_string(), 42u64);

        // 序列化
        let json = serde_json::to_string(&sync_state).unwrap();
        assert!(json.contains("peer-001"));
        assert!(json.contains("42"));

        // 反序列化
        let deserialized: SyncState = serde_json::from_str(&json).unwrap();
        assert_eq!(deserialized.peer_id, sync_state.peer_id);
        assert_eq!(deserialized.last_sync_version, sync_state.last_sync_version);
    }
}
