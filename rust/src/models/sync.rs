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
/// - `device_id`: 设备唯一标识（UUID v7）
/// - `last_sync`: 最后同步时间（Unix 毫秒时间戳）
/// - `version_vector`: 版本向量（Lamport 时间戳，用于增量同步）
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
///     device_id: "device-001".to_string(),
///     last_sync: 1704067200000,
///     version_vector,
/// };
///
/// assert_eq!(sync_state.device_id, "device-001");
/// assert_eq!(sync_state.last_sync, 1704067200000);
/// ```
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct SyncState {
    /// 设备唯一标识
    pub device_id: String,

    /// 最后同步时间（Unix 毫秒时间戳）
    pub last_sync: u64,

    /// 版本向量（Lamport 时间戳）
    ///
    /// Key: 设备 ID
    /// Value: 该设备的最后已知版本号
    pub version_vector: HashMap<String, u64>,
}

impl SyncState {
    /// 创建新的同步状态
    ///
    /// # 参数
    ///
    /// - `device_id`: 设备 UUID
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::models::sync::SyncState;
    ///
    /// let sync_state = SyncState::new("device-001");
    /// assert_eq!(sync_state.device_id, "device-001");
    /// assert!(sync_state.version_vector.is_empty());
    /// ```
    #[must_use]
    pub fn new(device_id: &str) -> Self {
        Self {
            device_id: device_id.to_string(),
            last_sync: 0,
            version_vector: HashMap::new(),
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
    /// let mut sync_state = SyncState::new("device-001");
    /// let mut new_versions = HashMap::new();
    /// new_versions.insert("peer-001".to_string(), 42u64);
    ///
    /// sync_state.update(&new_versions);
    /// assert_eq!(sync_state.last_sync > 0, true);
    /// assert_eq!(sync_state.version_vector["peer-001"], 42);
    /// ```
    pub fn update(&mut self, new_version_vector: &HashMap<String, u64>) {
        use std::time::{SystemTime, UNIX_EPOCH};

        // 更新版本向量（合并新版本）
        for (device_id, version) in new_version_vector {
            let current_version = self.version_vector.get(device_id).copied().unwrap_or(0);
            if *version > current_version {
                self.version_vector.insert(device_id.clone(), *version);
            }
        }

        // 更新最后同步时间
        self.last_sync = u64::try_from(
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_millis(),
        )
        .unwrap_or(u64::MAX);
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
    /// let mut sync_state = SyncState::new("device-001");
    /// sync_state.version_vector.insert("peer-001".to_string(), 10u64);
    ///
    /// let mut remote_versions = HashMap::new();
    /// remote_versions.insert("device-001".to_string(), 20u64);
    ///
    /// assert!(sync_state.needs_sync(&remote_versions));
    /// ```
    #[must_use]
    pub fn needs_sync(&self, remote_version_vector: &HashMap<String, u64>) -> bool {
        for (device_id, remote_version) in remote_version_vector {
            let local_version = self.version_vector.get(device_id).copied().unwrap_or(0);
            if *remote_version > local_version {
                return true;
            }
        }
        false
    }
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
    fn it_should_sync_state_creation() {
        let sync_state = SyncState::new("device-001");
        assert_eq!(sync_state.device_id, "device-001");
        assert_eq!(sync_state.last_sync, 0);
        assert!(sync_state.version_vector.is_empty());
    }

    #[test]
    fn it_should_sync_state_update() {
        let mut sync_state = SyncState::new("device-001");
        let mut new_versions = HashMap::new();
        new_versions.insert("peer-001".to_string(), 42u64);
        new_versions.insert("peer-002".to_string(), 100u64);

        sync_state.update(&new_versions);

        assert_eq!(sync_state.version_vector["peer-001"], 42);
        assert_eq!(sync_state.version_vector["peer-002"], 100);
        assert!(sync_state.last_sync > 0);
    }

    #[test]
    fn it_should_sync_state_update_merge() {
        let mut sync_state = SyncState::new("device-001");
        sync_state
            .version_vector
            .insert("peer-001".to_string(), 10u64);

        let mut new_versions = HashMap::new();
        new_versions.insert("peer-001".to_string(), 5u64); // 更小的版本，应该被忽略
        new_versions.insert("peer-002".to_string(), 20u64);

        sync_state.update(&new_versions);

        assert_eq!(sync_state.version_vector["peer-001"], 10); // 保持更大的版本
        assert_eq!(sync_state.version_vector["peer-002"], 20);
    }

    #[test]
    fn it_should_needs_sync_true() {
        let mut sync_state = SyncState::new("device-001");
        sync_state
            .version_vector
            .insert("peer-001".to_string(), 10u64);

        let mut remote_versions = HashMap::new();
        remote_versions.insert("peer-001".to_string(), 20u64); // 对等设备有更新版本

        assert!(sync_state.needs_sync(&remote_versions));
    }

    #[test]
    fn it_should_needs_sync_false() {
        let mut sync_state = SyncState::new("device-001");
        sync_state
            .version_vector
            .insert("peer-001".to_string(), 20u64);

        let mut remote_versions = HashMap::new();
        remote_versions.insert("peer-001".to_string(), 10u64); // 对等设备版本更旧

        assert!(!sync_state.needs_sync(&remote_versions));
    }

    #[test]
    fn it_should_needs_sync_equal() {
        let mut sync_state = SyncState::new("device-001");
        sync_state
            .version_vector
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
        let mut sync_state = SyncState::new("device-001");
        sync_state
            .version_vector
            .insert("peer-001".to_string(), 42u64);

        // 序列化
        let json = serde_json::to_string(&sync_state).unwrap();
        assert!(json.contains("device-001"));
        assert!(json.contains("42"));

        // 反序列化
        let deserialized: SyncState = serde_json::from_str(&json).unwrap();
        assert_eq!(deserialized.device_id, sync_state.device_id);
        assert_eq!(deserialized.version_vector, sync_state.version_vector);
    }
}
