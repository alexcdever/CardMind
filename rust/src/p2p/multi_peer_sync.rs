//! 多设备同步协调器
//!
//! 本模块实现多点对多点的同步协调逻辑。
//!
//! # 核心功能
//!
//! - **设备状态跟踪**: 跟踪所有连接设备的在线状态
//! - **并行同步**: 同时与多个设备进行同步
//! - **版本管理**: 跟踪每个设备的同步版本
//! - **冲突避免**: 避免重复同步和循环同步
//!
//! # 同步策略
//!
//! ```text
//! 1. 设备 A、B、C 相互连接
//! 2. 每个设备维护其他设备的版本号
//! 3. 同步时仅发送本地变更（避免重复）
//! 4. CRDT 自动处理冲突
//! ```

use crate::p2p::sync_manager::SyncManager;
use crate::store::card_store::CardStore;
use libp2p::PeerId;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use tracing::{debug, info, warn};

/// 设备状态
#[derive(Debug, Clone)]
pub enum DeviceStatus {
    /// 设备在线
    Online,

    /// 设备离线
    Offline,

    /// 同步中
    Syncing,
}

/// 设备信息
#[derive(Debug, Clone)]
pub struct DeviceInfo {
    /// 设备 Peer ID
    pub peer_id: PeerId,

    /// 设备状态
    pub status: DeviceStatus,

    /// 最后连接时间
    pub last_seen: chrono::DateTime<chrono::Utc>,

    /// 各数据池的最后同步版本
    pub pool_versions: HashMap<String, Vec<u8>>,
}

/// 多设备同步协调器
///
/// 管理与多个设备的同步关系和状态
#[allow(dead_code)]
pub struct MultiPeerSyncCoordinator {
    /// CardStore 引用
    card_store: Arc<Mutex<CardStore>>,

    /// 同步管理器
    sync_manager: SyncManager,

    /// 设备信息 (peer_id -> DeviceInfo)
    devices: Arc<Mutex<HashMap<PeerId, DeviceInfo>>>,

    /// 本地 Peer ID
    local_peer_id: PeerId,
}

impl MultiPeerSyncCoordinator {
    /// 创建新的多设备同步协调器
    ///
    /// # 参数
    ///
    /// * `card_store` - CardStore 实例
    /// * `sync_manager` - SyncManager 实例
    /// * `local_peer_id` - 本地 Peer ID
    pub fn new(
        card_store: Arc<Mutex<CardStore>>,
        sync_manager: SyncManager,
        local_peer_id: PeerId,
    ) -> Self {
        Self {
            card_store,
            sync_manager,
            devices: Arc::new(Mutex::new(HashMap::new())),
            local_peer_id,
        }
    }

    /// 添加或更新设备
    ///
    /// # 参数
    ///
    /// * `peer_id` - 设备 Peer ID
    pub fn add_or_update_device(&self, peer_id: PeerId) {
        let mut devices = self.devices.lock().unwrap();
        let now = chrono::Utc::now();

        if let Some(device) = devices.get_mut(&peer_id) {
            // 更新现有设备
            device.last_seen = now;
            device.status = DeviceStatus::Online;
            debug!("更新设备信息: {}", peer_id);
        } else {
            // 添加新设备
            let device = DeviceInfo {
                peer_id: peer_id.clone(),
                status: DeviceStatus::Online,
                last_seen: now,
                pool_versions: HashMap::new(),
            };
            devices.insert(peer_id.clone(), device);
            info!("添加新设备: {}", peer_id);
        }
    }

    /// 标记设备离线
    ///
    /// # 参数
    ///
    /// * `peer_id` - 设备 Peer ID
    pub fn mark_device_offline(&self, peer_id: &PeerId) {
        let mut devices = self.devices.lock().unwrap();
        if let Some(device) = devices.get_mut(peer_id) {
            device.status = DeviceStatus::Offline;
            info!("设备离线: {}", peer_id);
        }
    }

    /// 标记设备同步中
    ///
    /// # 参数
    ///
    /// * `peer_id` - 设备 Peer ID
    /// * `pool_id` - 数据池 ID
    pub fn mark_device_syncing(&self, peer_id: &PeerId, pool_id: &str) {
        let mut devices = self.devices.lock().unwrap();
        if let Some(device) = devices.get_mut(peer_id) {
            device.status = DeviceStatus::Syncing;
            debug!("设备同步中: {} (pool: {})", peer_id, pool_id);
        }
    }

    /// 标记设备同步完成
    ///
    /// # 参数
    ///
    /// * `peer_id` - 设备 Peer ID
    /// * `pool_id` - 数据池 ID
    /// * `version` - 新的同步版本
    pub fn mark_device_synced(&self, peer_id: &PeerId, pool_id: &str, version: &[u8]) {
        let mut devices = self.devices.lock().unwrap();
        if let Some(device) = devices.get_mut(peer_id) {
            device.status = DeviceStatus::Online;
            device.pool_versions.insert(pool_id.to_string(), version.to_vec());
            debug!("设备同步完成: {} (pool: {}, version: {:?})", peer_id, pool_id, version);
        }
    }

    /// 获取所有在线设备
    ///
    /// # 返回
    ///
    /// 在线设备列表
    #[must_use]
    pub fn get_online_devices(&self) -> Vec<PeerId> {
        let devices = self.devices.lock().unwrap();
        devices
            .iter()
            .filter(|(_, device)| matches!(device.status, DeviceStatus::Online))
            .map(|(peer_id, _)| peer_id.clone())
            .collect()
    }

    /// 获取设备信息
    ///
    /// # 参数
    ///
    /// * `peer_id` - 设备 Peer ID
    ///
    /// # 返回
    ///
    /// 设备信息，如果不存在则返回 None
    #[must_use]
    pub fn get_device_info(&self, peer_id: &PeerId) -> Option<DeviceInfo> {
        let devices = self.devices.lock().unwrap();
        devices.get(peer_id).cloned()
    }

    /// 获取所有设备信息
    #[must_use]
    pub fn get_all_devices(&self) -> Vec<DeviceInfo> {
        let devices = self.devices.lock().unwrap();
        devices.values().cloned().collect()
    }

    /// 触发多设备同步
    ///
    /// # 参数
    ///
    /// * `pool_id` - 数据池 ID
    ///
    /// # 同步策略
    ///
    /// 1. 获取所有在线设备
    /// 2. 对每个设备发起同步请求
    /// 3. 并行处理同步响应
    /// 4. CRDT 自动处理冲突
    pub async fn trigger_multi_peer_sync(
        &self,
        pool_id: &str,
    ) -> Result<Vec<PeerId>, Box<dyn std::error::Error>> {
        info!("触发多设备同步: pool_id={}", pool_id);

        // 1. 获取所有在线设备
        let online_devices = self.get_online_devices();

        if online_devices.is_empty() {
            info!("没有在线设备可同步");
            return Ok(Vec::new());
        }

        info!("发现 {} 个在线设备", online_devices.len());

        // 2. 并行发起同步请求
        let mut sync_tasks = Vec::new();

        for peer_id in online_devices.clone() {
            let coordinator = self.clone_ref();
            let pool_id = pool_id.to_string();

            let task = tokio::spawn(async move {
                // 获取设备信息
                let device_info = coordinator.get_device_info(&peer_id);

                if let Some(device) = device_info {
                    // 获取该设备的最后同步版本
                    let last_version = device.pool_versions.get(&pool_id).cloned();

                    debug!(
                        "向设备 {} 请求同步 (pool: {}, version: {:?})",
                        peer_id, pool_id, last_version
                    );

                    // TODO: 实际发送同步请求
                    // 这里需要集成到 P2PSyncService
                    // 暂时模拟成功
                    let _last_version = last_version.as_deref();

                    Some(peer_id)
                } else {
                    warn!("设备信息不存在: {}", peer_id);
                    None
                }
            });

            sync_tasks.push(task);
        }

        // 3. 等待所有同步任务完成
        let mut synced_devices = Vec::new();
        for task in sync_tasks {
            if let Ok(Some(peer_id)) = task.await {
                synced_devices.push(peer_id);
            }
        }

        info!("多设备同步完成: {}/{}", synced_devices.len(), online_devices.len());

        Ok(synced_devices)
    }

    /// 清理长时间离线的设备
    ///
    /// # 参数
    ///
    /// * `timeout_minutes` - 超时时间（分钟）
    pub fn cleanup_offline_devices(&self, timeout_minutes: i64) {
        let mut devices = self.devices.lock().unwrap();
        let now = chrono::Utc::now();
        let timeout = chrono::Duration::minutes(timeout_minutes);

        let mut to_remove = Vec::new();

        for (peer_id, device) in devices.iter() {
            let elapsed = now.signed_duration_since(device.last_seen);

            if elapsed > timeout {
                to_remove.push(peer_id.clone());
                info!("清理长时间离线设备: {} (离线时间: {:?})", peer_id, elapsed);
            }
        }

        for peer_id in to_remove {
            devices.remove(&peer_id);
        }
    }

    /// 获取设备统计信息
    #[must_use]
    pub fn get_device_stats(&self) -> DeviceStats {
        let devices = self.devices.lock().unwrap();

        let mut online = 0;
        let mut offline = 0;
        let mut syncing = 0;

        for device in devices.values() {
            match device.status {
                DeviceStatus::Online => online += 1,
                DeviceStatus::Offline => offline += 1,
                DeviceStatus::Syncing => syncing += 1,
            }
        }

        DeviceStats {
            total: devices.len(),
            online,
            offline,
            syncing,
        }
    }

    // ==================== 私有辅助方法 ====================

    /// 克隆引用（用于 async 块）
    fn clone_ref(&self) -> Self {
        Self {
            card_store: self.card_store.clone(),
            sync_manager: SyncManager::new(self.card_store.clone()),
            devices: self.devices.clone(),
            local_peer_id: self.local_peer_id.clone(),
        }
    }
}

/// 设备统计信息
#[derive(Debug, Clone)]
pub struct DeviceStats {
    /// 总设备数
    pub total: usize,

    /// 在线设备数
    pub online: usize,

    /// 离线设备数
    pub offline: usize,

    /// 同步中设备数
    pub syncing: usize,
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::store::card_store::CardStore;
    use libp2p::PeerId;

    #[test]
    fn test_coordinator_creation() {
        let store = Arc::new(Mutex::new(CardStore::new_in_memory().unwrap()));
        let sync_manager = SyncManager::new(store.clone());
        let local_peer_id = PeerId::random();

        let coordinator = MultiPeerSyncCoordinator::new(store, sync_manager, local_peer_id);

        let stats = coordinator.get_device_stats();
        assert_eq!(stats.total, 0);
        assert_eq!(stats.online, 0);
    }

    #[test]
    fn test_add_or_update_device() {
        let store = Arc::new(Mutex::new(CardStore::new_in_memory().unwrap()));
        let sync_manager = SyncManager::new(store.clone());
        let local_peer_id = PeerId::random();

        let coordinator = MultiPeerSyncCoordinator::new(store, sync_manager, local_peer_id);

        let peer_id = PeerId::random();
        coordinator.add_or_update_device(peer_id.clone());

        let stats = coordinator.get_device_stats();
        assert_eq!(stats.total, 1);
        assert_eq!(stats.online, 1);

        // 更新设备
        coordinator.add_or_update_device(peer_id.clone());
        let stats = coordinator.get_device_stats();
        assert_eq!(stats.total, 1); // 不应该重复添加
    }

    #[test]
    fn test_mark_device_offline() {
        let store = Arc::new(Mutex::new(CardStore::new_in_memory().unwrap()));
        let sync_manager = SyncManager::new(store.clone());
        let local_peer_id = PeerId::random();

        let coordinator = MultiPeerSyncCoordinator::new(store, sync_manager, local_peer_id);

        let peer_id = PeerId::random();
        coordinator.add_or_update_device(peer_id.clone());

        let stats = coordinator.get_device_stats();
        assert_eq!(stats.online, 1);

        coordinator.mark_device_offline(&peer_id);
        let stats = coordinator.get_device_stats();
        assert_eq!(stats.offline, 1);
    }

    #[test]
    fn test_device_sync_state() {
        let store = Arc::new(Mutex::new(CardStore::new_in_memory().unwrap()));
        let sync_manager = SyncManager::new(store.clone());
        let local_peer_id = PeerId::random();

        let coordinator = MultiPeerSyncCoordinator::new(store, sync_manager, local_peer_id);

        let peer_id = PeerId::random();
        coordinator.add_or_update_device(peer_id.clone());

        let version = vec![1, 2, 3, 4];
        coordinator.mark_device_synced(&peer_id, "test-pool", &version);

        let device_info = coordinator.get_device_info(&peer_id).unwrap();
        assert_eq!(device_info.pool_versions.get("test-pool"), Some(&version));
    }

    #[test]
    fn test_cleanup_offline_devices() {
        let store = Arc::new(Mutex::new(CardStore::new_in_memory().unwrap()));
        let sync_manager = SyncManager::new(store.clone());
        let local_peer_id = PeerId::random();

        let coordinator = MultiPeerSyncCoordinator::new(store, sync_manager, local_peer_id);

        let peer_id = PeerId::random();
        coordinator.add_or_update_device(peer_id.clone());

        // 手动设置 last_seen 为过去时间
        {
            let mut devices = coordinator.devices.lock().unwrap();
            if let Some(device) = devices.get_mut(&peer_id) {
                device.last_seen = chrono::Utc::now() - chrono::Duration::minutes(120);
            }
        }

        coordinator.cleanup_offline_devices(60); // 60 分钟超时

        let stats = coordinator.get_device_stats();
        assert_eq!(stats.total, 0); // 设备应该被清理
    }
}
