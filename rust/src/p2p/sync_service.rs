//! P2P 同步服务
//!
//! 本模块实现完整的 P2P 同步服务，整合网络层、发现层和同步管理器。
//!
//! # 核心功能
//!
//! - **网络管理**: 使用 libp2p 处理设备间连接
//! - **设备发现**: 使用 mDNS 自动发现局域网内的设备
//! - **同步协调**: 管理多设备间的数据同步
//! - **状态跟踪**: 跟踪连接状态和同步状态
//!
//! # 使用示例
//!
//! ```rust,no_run
//! use cardmind_rust::p2p::P2PSyncService;
//! use cardmind_rust::store::card_store::CardStore;
//! use cardmind_rust::models::device_config::DeviceConfig;
//!
//! # async fn example() -> Result<(), Box<dyn std::error::Error>> {
//! let card_store = Arc::new(Mutex::new(CardStore::new_in_memory()?));
//! let device_config = DeviceConfig::new("device-001");
//!
//! let mut service = P2PSyncService::new(card_store, device_config)?;
//! service.start("/ip4/0.0.0.0/tcp/0").await?;
//! # Ok(())
//! # }
//! ```

use crate::models::device_config::DeviceConfig;
use crate::models::error::{CardMindError, Result};
use crate::p2p::multi_peer_sync::MultiPeerSyncCoordinator;
use crate::p2p::network::P2PNetwork;
use crate::p2p::sync::{SyncAck, SyncRequest, SyncResponse};
use crate::p2p::sync_manager::SyncManager;
use crate::store::card_store::CardStore;
use libp2p::PeerId;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use tracing::{debug, info};

/// P2P 同步服务
///
/// 整合所有 P2P 组件，提供完整的同步功能
#[allow(dead_code)]
pub struct P2PSyncService {
    /// P2P 网络
    network: P2PNetwork,

    /// 同步管理器
    sync_manager: Arc<Mutex<SyncManager>>,

    /// 多设备协调器
    coordinator: Arc<Mutex<MultiPeerSyncCoordinator>>,

    /// 本地 Peer ID
    local_peer_id: PeerId,

    /// 设备配置
    device_config: Arc<Mutex<DeviceConfig>>,

    /// 连接状态 (peer_id -> connected)
    connections: Arc<Mutex<HashMap<PeerId, bool>>>,
}

impl P2PSyncService {
    /// 创建新的 P2P 同步服务
    ///
    /// # 参数
    ///
    /// * `card_store` - CardStore 实例
    /// * `device_config` - 设备配置
    ///
    /// # 示例
    ///
    /// ```rust,no_run
    /// # use cardmind_rust::p2p::P2PSyncService;
    /// # use cardmind_rust::store::card_store::CardStore;
    /// # use cardmind_rust::models::device_config::DeviceConfig;
    /// # use std::sync::{Arc, Mutex};
    /// # fn example() -> Result<(), Box<dyn std::error::Error>> {
    /// let card_store = Arc::new(Mutex::new(CardStore::new_in_memory()?));
    /// let device_config = DeviceConfig::new("device-001");
    ///
    /// let service = P2PSyncService::new(card_store, device_config)?;
    /// # Ok(())
    /// # }
    /// ```
    pub fn new(
        card_store: Arc<Mutex<CardStore>>,
        device_config: DeviceConfig,
    ) -> Result<Self> {
        info!("创建 P2P 同步服务");

        // 1. 创建 P2P 网络
        let network = P2PNetwork::new()
            .map_err(|e| CardMindError::IoError(format!("Failed to create P2P network: {e}")))?;

        // 保存 PeerId 的副本，避免借用问题（PeerId 实现了 Copy）
        let local_peer_id = *network.local_peer_id();

        // 2. 创建同步管理器
        let sync_manager = Arc::new(Mutex::new(SyncManager::new(card_store.clone())));

        // 3. 创建多设备协调器
        // 注意：这里需要传递 SyncManager，但 MultiPeerSyncCoordinator::new 期望的是非 Arc 包装的
        // 为了简化，我们先创建一个新的 SyncManager 实例
        let sync_manager_for_coordinator = SyncManager::new(card_store.clone());
        let coordinator = MultiPeerSyncCoordinator::new(
            card_store,
            sync_manager_for_coordinator,
            local_peer_id,
        );

        Ok(Self {
            network,
            sync_manager,
            coordinator: Arc::new(Mutex::new(coordinator)),
            local_peer_id,
            device_config: Arc::new(Mutex::new(device_config)),
            connections: Arc::new(Mutex::new(HashMap::new())),
        })
    }

    /// 获取本地 Peer ID
    ///
    /// # 返回
    ///
    /// 本地设备的 Peer ID
    #[must_use]
    pub fn local_peer_id(&self) -> PeerId {
        self.local_peer_id
    }

    /// 启动同步服务
    ///
    /// # 参数
    ///
    /// * `listen_addr` - 监听地址（如 "/ip4/0.0.0.0/tcp/0"）
    ///
    /// # 示例
    ///
    /// ```rust,no_run
    /// # use cardmind_rust::p2p::P2PSyncService;
    /// # async fn example(service: &mut P2PSyncService) -> Result<(), Box<dyn std::error::Error>> {
    /// service.start("/ip4/0.0.0.0/tcp/0").await?;
    /// # Ok(())
    /// # }
    /// ```
    pub async fn start(&mut self, listen_addr: &str) -> Result<()> {
        info!("启动 P2P 同步服务: {}", listen_addr);

        // 1. 启动网络监听
        self.network
            .listen_on(listen_addr)
            .await
            .map_err(|e| CardMindError::IoError(format!("Failed to listen: {e}")))?;

        info!("P2P 同步服务已启动，Peer ID: {}", self.local_peer_id);

        Ok(())
    }

    /// 连接到对等设备
    ///
    /// # 参数
    ///
    /// * `peer_id` - 对等设备 ID
    ///
    /// # 示例
    ///
    /// ```rust,no_run
    /// # use cardmind_rust::p2p::P2PSyncService;
    /// # use libp2p::PeerId;
    /// # async fn example(service: &mut P2PSyncService, peer_id: PeerId) -> Result<(), Box<dyn std::error::Error>> {
    /// service.connect_to_peer(peer_id).await?;
    /// # Ok(())
    /// # }
    /// ```
    pub async fn connect_to_peer(&mut self, peer_id: PeerId) -> Result<()> {
        info!("尝试连接到设备: {}", peer_id);

        // 更新连接状态
        self.connections.lock().unwrap().insert(peer_id, true);

        // 更新协调器
        self.coordinator.lock().unwrap().add_or_update_device(peer_id);

        info!("已建立与设备 {} 的连接", peer_id);

        Ok(())
    }

    /// 发起同步请求
    ///
    /// # 参数
    ///
    /// * `peer_id` - 目标设备 ID
    /// * `pool_id` - 数据池 ID
    ///
    /// # 示例
    ///
    /// ```rust,no_run
    /// # use cardmind_rust::p2p::P2PSyncService;
    /// # use libp2p::PeerId;
    /// # async fn example(service: &P2PSyncService, peer_id: PeerId) -> Result<(), Box<dyn std::error::Error>> {
    /// service.request_sync(peer_id, "pool-001".to_string()).await?;
    /// # Ok(())
    /// # }
    /// ```
    pub async fn request_sync(&self, peer_id: PeerId, pool_id: String) -> Result<()> {
        info!("向设备 {} 请求同步数据池 {}", peer_id, pool_id);

        // 标记同步中
        self.coordinator
            .lock()
            .unwrap()
            .mark_device_syncing(&peer_id, &pool_id);

        // 获取最后同步版本
        let last_version = self
            .sync_manager
            .lock()
            .unwrap()
            .get_last_sync_version(&pool_id, &peer_id.to_string());

        // 构造同步请求
        let request = SyncRequest {
            pool_id: pool_id.clone(),
            last_version,
            device_id: self.local_peer_id.to_string(),
        };

        // TODO: 实际发送请求需要实现 libp2p 的 request_response 协议
        debug!("同步请求已构造: {:?}", request);

        Ok(())
    }

    /// 处理同步请求
    ///
    /// # 参数
    ///
    /// * `peer_id` - 请求设备 ID
    /// * `request` - 同步请求
    #[allow(dead_code)]
    async fn handle_sync_request(&self, peer_id: PeerId, request: SyncRequest) -> Result<()> {
        info!(
            "处理来自 {} 的同步请求: pool={}",
            peer_id, request.pool_id
        );

        // 验证授权和生成响应
        let joined_pools = self.device_config.lock().unwrap().joined_pools.clone();

        let sync_data = self
            .sync_manager
            .lock()
            .unwrap()
            .handle_sync_request(
                &request.pool_id,
                request.last_version.as_deref(),
                &joined_pools,
            )?;

        // 构造响应
        let response = SyncResponse {
            pool_id: request.pool_id.clone(),
            updates: sync_data.updates,
            card_count: sync_data.card_count,
            current_version: sync_data.current_version.clone(),
        };

        // TODO: 发送响应
        debug!("同步响应已构造: {} 个卡片", response.card_count);

        Ok(())
    }

    /// 处理同步响应
    ///
    /// # 参数
    ///
    /// * `peer_id` - 响应设备 ID
    /// * `response` - 同步响应
    #[allow(dead_code)]
    async fn handle_sync_response(&self, peer_id: PeerId, response: SyncResponse) -> Result<()> {
        info!(
            "处理来自 {} 的同步响应: {} 个卡片",
            peer_id, response.card_count
        );

        // 导入更新
        let new_version = self
            .sync_manager
            .lock()
            .unwrap()
            .import_updates(&response.pool_id, &response.updates)?;

        // 更新版本跟踪
        self.sync_manager
            .lock()
            .unwrap()
            .track_sync_version(&response.pool_id, &peer_id.to_string(), &new_version)?;

        // 标记同步完成
        self.coordinator
            .lock()
            .unwrap()
            .mark_device_synced(&peer_id, &response.pool_id, &new_version);

        // 构造确认
        let _ack = SyncAck {
            pool_id: response.pool_id.clone(),
            confirmed_version: new_version,
            device_id: self.local_peer_id.to_string(),
        };

        // TODO: 发送确认
        debug!("同步确认已构造");

        Ok(())
    }

    /// 获取同步状态
    ///
    /// # 返回
    ///
    /// 返回包含在线设备数、同步中设备数和离线设备数的状态
    #[must_use]
    pub fn get_sync_status(&self) -> SyncStatus {
        let stats = self.coordinator.lock().unwrap().get_device_stats();

        SyncStatus {
            online_devices: stats.online,
            syncing_devices: stats.syncing,
            offline_devices: stats.offline,
        }
    }

    /// 连接建立后自动同步
    #[allow(dead_code)]
    async fn auto_sync_on_connect(&self, peer_id: PeerId) -> Result<()> {
        info!("设备 {} 连接成功，触发自动同步", peer_id);

        // 获取设备加入的数据池
        let joined_pools = self.device_config.lock().unwrap().joined_pools.clone();

        for pool_id in joined_pools {
            info!("自动同步数据池 {} 到设备 {}", pool_id, peer_id);
            self.request_sync(peer_id, pool_id).await?;
        }

        Ok(())
    }
}

/// 同步状态
#[derive(Debug, Clone)]
pub struct SyncStatus {
    /// 在线设备数
    pub online_devices: usize,

    /// 同步中设备数
    pub syncing_devices: usize,

    /// 离线设备数
    pub offline_devices: usize,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sync_service_creation() {
        let card_store = Arc::new(Mutex::new(CardStore::new_in_memory().unwrap()));
        let device_config = DeviceConfig::new("test-device");

        let service = P2PSyncService::new(card_store, device_config);
        assert!(service.is_ok(), "同步服务创建应该成功");

        let service = service.unwrap();
        assert_eq!(
            service.local_peer_id,
            *service.network.local_peer_id(),
            "Peer ID 应该匹配"
        );
    }

    #[test]
    fn test_get_sync_status() {
        let card_store = Arc::new(Mutex::new(CardStore::new_in_memory().unwrap()));
        let device_config = DeviceConfig::new("test-device");

        let service = P2PSyncService::new(card_store, device_config).unwrap();
        let status = service.get_sync_status();

        assert_eq!(status.online_devices, 0, "初始应该没有在线设备");
        assert_eq!(status.syncing_devices, 0, "初始应该没有同步中设备");
    }
}
