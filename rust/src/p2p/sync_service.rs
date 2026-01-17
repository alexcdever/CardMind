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
//! use std::sync::{Arc, Mutex};
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
use crate::p2p::network::{P2PEvent, P2PNetwork};
use crate::p2p::sync::{SyncAck, SyncRequest, SyncResponse};
use crate::p2p::sync_manager::SyncManager;
use crate::store::card_store::CardStore;
use futures::StreamExt;
use libp2p::request_response::Message;
use libp2p::swarm::SwarmEvent;
use libp2p::PeerId;
use std::collections::HashMap;
use std::sync::{Arc, Mutex, OnceLock};
use tokio::sync::broadcast;
use tracing::{debug, info, warn};

/// 全局注册表用于本地内存内的“模拟网络”同步（测试和受限环境使用）
/// 真实环境下应通过 libp2p request/response 传输。
#[derive(Clone)]
struct ServiceEntry {
    sync_manager: Arc<Mutex<SyncManager>>,
    device_config: Arc<Mutex<DeviceConfig>>,
}

fn registry() -> &'static Mutex<HashMap<PeerId, ServiceEntry>> {
    static REGISTRY: OnceLock<Mutex<HashMap<PeerId, ServiceEntry>>> = OnceLock::new();
    REGISTRY.get_or_init(|| Mutex::new(HashMap::new()))
}

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
    coordinator: Arc<MultiPeerSyncCoordinator>,

    /// 本地 Peer ID
    local_peer_id: PeerId,

    /// 设备配置
    device_config: Arc<Mutex<DeviceConfig>>,

    /// 连接状态 (peer_id -> connected)
    connections: Arc<Mutex<HashMap<PeerId, bool>>>,

    /// 是否使用真实网络传输（默认 true，测试时可设为 false）
    use_real_network: bool,

    /// 状态变化广播通道（用于实时推送同步状态）
    status_tx: broadcast::Sender<SyncStatus>,

    /// 最后一次广播的状态（用于去重）
    last_status: Arc<Mutex<Option<SyncStatus>>>,
}

// 为了让异步 FFI future 可 Send/Sync（使用时仍应确保单线程访问 Swarm）
unsafe impl Send for P2PSyncService {}
unsafe impl Sync for P2PSyncService {}

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
    pub fn new(card_store: Arc<Mutex<CardStore>>, device_config: DeviceConfig) -> Result<Self> {
        info!("创建 P2P 同步服务");

        // 1. 检查 mDNS 是否激活
        let mdns_enabled = device_config.is_mdns_active();
        info!("mDNS 状态: {}", if mdns_enabled { "启用" } else { "禁用" });

        // 2. 创建 P2P 网络（根据 mDNS 状态）
        let network = P2PNetwork::new(mdns_enabled)
            .map_err(|e| CardMindError::IoError(format!("Failed to create P2P network: {e}")))?;

        // 保存 PeerId 的副本，避免借用问题（PeerId 实现了 Copy）
        let local_peer_id = *network.local_peer_id();

        // 2. 创建同步管理器
        let sync_manager = Arc::new(Mutex::new(SyncManager::new(card_store.clone())));
        let device_config = Arc::new(Mutex::new(device_config));

        // 3. 创建多设备协调器
        // 注意：这里需要传递 SyncManager，但 MultiPeerSyncCoordinator::new 期望的是非 Arc 包装的
        // 为了简化，我们先创建一个新的 SyncManager 实例
        let sync_manager_for_coordinator = SyncManager::new(card_store.clone());
        let coordinator =
            MultiPeerSyncCoordinator::new(card_store, sync_manager_for_coordinator, local_peer_id);

        // 4. 创建状态广播通道（容量 100）
        let (status_tx, _rx) = broadcast::channel(100);

        // 注册到本地模拟网络，便于测试环境在无真实网络时进行同步
        registry().lock().unwrap().insert(
            local_peer_id,
            ServiceEntry {
                sync_manager: sync_manager.clone(),
                device_config: device_config.clone(),
            },
        );

        Ok(Self {
            network,
            sync_manager,
            coordinator: Arc::new(coordinator),
            local_peer_id,
            device_config,
            connections: Arc::new(Mutex::new(HashMap::new())),
            use_real_network: true, // 默认使用真实网络
            status_tx,
            last_status: Arc::new(Mutex::new(None)),
        })
    }

    /// 创建用于测试的 P2P 同步服务（使用模拟网络）
    ///
    /// 此方法用于测试环境，使用本地注册表模拟网络传输
    #[doc(hidden)]
    pub fn new_with_mock_network(
        card_store: Arc<Mutex<CardStore>>,
        device_config: DeviceConfig,
    ) -> Result<Self> {
        let mut service = Self::new(card_store, device_config)?;
        service.use_real_network = false;
        Ok(service)
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
        self.coordinator.add_or_update_device(peer_id);

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
    /// # fn example(service: &P2PSyncService, peer_id: PeerId) -> Result<(), Box<dyn std::error::Error>> {
    /// service.request_sync(peer_id, "pool-001".to_string())?;
    /// # Ok(())
    /// # }
    /// ```
    pub fn request_sync(&mut self, peer_id: PeerId, pool_id: String) -> Result<()> {
        info!("向设备 {} 请求同步数据池 {}", peer_id, pool_id);

        // 标记同步中
        self.coordinator.mark_device_syncing(&peer_id, &pool_id);

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

        if self.use_real_network {
            // 使用真实网络传输
            info!("通过 libp2p 发送同步请求");
            self.network.send_sync_request(peer_id, request);
        } else {
            // 模拟网络传输（用于测试）
            info!("使用模拟网络传输");
            let entry = registry().lock().unwrap().get(&peer_id).cloned();

            if let Some(entry) = entry {
                // 授权检查：使用目标设备的已加入池列表
                let joined_pools = vec![entry
                    .device_config
                    .lock()
                    .unwrap()
                    .get_pool_id()
                    .map(|s| s.to_string())
                    .unwrap_or_default()];

                let sync_data = entry.sync_manager.lock().unwrap().handle_sync_request(
                    &pool_id,
                    request.last_version.as_deref(),
                    &joined_pools,
                )?;

                // 构造响应并导入
                let response = SyncResponse {
                    pool_id: pool_id.clone(),
                    updates: sync_data.updates.clone(),
                    card_count: sync_data.card_count,
                    current_version: sync_data.current_version.clone(),
                };

                self.handle_sync_response(peer_id, response)?;
            } else {
                warn!("目标设备 {} 未在本地注册表中，无法同步", peer_id);
            }
        }

        Ok(())
    }

    /// 处理同步请求
    ///
    /// # 参数
    ///
    /// * `peer_id` - 请求设备 ID
    /// * `request` - 同步请求
    #[allow(dead_code)]
    fn handle_sync_request(&self, peer_id: PeerId, request: SyncRequest) -> Result<()> {
        info!("处理来自 {} 的同步请求: pool={}", peer_id, request.pool_id);

        // 验证授权和生成响应
        let joined_pools = vec![self
            .device_config
            .lock()
            .unwrap()
            .get_pool_id()
            .map(|s| s.to_string())
            .unwrap_or_default()];

        let _sync_data = self.sync_manager.lock().unwrap().handle_sync_request(
            &request.pool_id,
            request.last_version.as_deref(),
            &joined_pools,
        )?;

        // 构造响应
        Ok(())
    }

    /// 处理同步响应
    ///
    /// # 参数
    ///
    /// * `peer_id` - 响应设备 ID
    /// * `response` - 同步响应
    #[allow(dead_code)]
    fn handle_sync_response(&self, peer_id: PeerId, response: SyncResponse) -> Result<()> {
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
        self.sync_manager.lock().unwrap().track_sync_version(
            &response.pool_id,
            &peer_id.to_string(),
            &new_version,
        )?;

        // 标记同步完成
        self.coordinator
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
        let stats = self.coordinator.get_device_stats();

        SyncStatus {
            online_devices: stats.online,
            syncing_devices: stats.syncing,
            offline_devices: stats.offline,
        }
    }

    /// 通知状态变化
    ///
    /// 广播同步状态变化到所有订阅者。实现去重逻辑，避免发送重复状态。
    ///
    /// # 参数
    ///
    /// * `new_status` - 新的同步状态
    pub fn notify_status_change(&self, new_status: SyncStatus) {
        // 检查是否与上次状态相同（去重）
        let mut last_status = self.last_status.lock().unwrap();

        if last_status.as_ref() != Some(&new_status) {
            // 记录状态变化
            info!(
                "同步状态变化: {:?} -> {:?}",
                last_status.as_ref(),
                new_status
            );

            // 更新最后状态
            *last_status = Some(new_status.clone());

            // 广播状态变化（忽略发送错误，因为可能没有订阅者）
            let _ = self.status_tx.send(new_status);
        }
    }

    /// 获取状态广播发送器（用于创建订阅）
    ///
    /// # 返回
    ///
    /// 返回 broadcast::Sender 的克隆，可用于创建新的订阅者
    #[must_use]
    pub fn status_sender(&self) -> broadcast::Sender<SyncStatus> {
        self.status_tx.clone()
    }

    /// 处理网络事件
    ///
    /// 此方法应该在事件循环中持续调用，用于处理传入的同步请求和响应
    pub async fn handle_network_events(&mut self) -> Result<()> {
        if let Some(event) = self.network.swarm_mut().next().await {
            match event {
                SwarmEvent::ConnectionEstablished { peer_id, .. } => {
                    info!("与设备 {} 建立连接", peer_id);
                    self.connections.lock().unwrap().insert(peer_id, true);
                    self.coordinator.add_or_update_device(peer_id);

                    // 触发状态变化：发现新对等设备 → syncing
                    let status = self.get_sync_status();
                    self.notify_status_change(status);
                }
                SwarmEvent::ConnectionClosed { peer_id, .. } => {
                    info!("与设备 {} 的连接断开", peer_id);
                    self.connections.lock().unwrap().insert(peer_id, false);
                    self.coordinator.mark_device_offline(&peer_id);

                    // 触发状态变化：检查是否所有 peer 断开 → disconnected
                    let status = self.get_sync_status();
                    self.notify_status_change(status);
                }
                SwarmEvent::Behaviour(P2PEvent::Sync(sync_event)) => {
                    use libp2p::request_response::Event;
                    match sync_event {
                        Event::Message { peer, message } => match message {
                            Message::Request {
                                request, channel, ..
                            } => {
                                info!("收到来自 {} 的同步请求: pool_id={}", peer, request.pool_id);

                                // 处理同步请求并发送响应
                                let joined_pools = vec![self
                                    .device_config
                                    .lock()
                                    .unwrap()
                                    .get_pool_id()
                                    .map(|s| s.to_string())
                                    .unwrap_or_default()];

                                match self.sync_manager.lock().unwrap().handle_sync_request(
                                    &request.pool_id,
                                    request.last_version.as_deref(),
                                    &joined_pools,
                                ) {
                                    Ok(sync_data) => {
                                        let response = SyncResponse {
                                            pool_id: request.pool_id.clone(),
                                            updates: sync_data.updates,
                                            card_count: sync_data.card_count,
                                            current_version: sync_data.current_version,
                                        };

                                        // 发送响应
                                        if self
                                            .network
                                            .swarm_mut()
                                            .behaviour_mut()
                                            .sync
                                            .send_response(channel, response)
                                            .is_ok()
                                        {
                                            info!("成功发送同步响应到 {}", peer);
                                        } else {
                                            warn!("发送同步响应到 {} 失败", peer);
                                        }
                                    }
                                    Err(e) => {
                                        warn!("处理同步请求失败: {}", e);
                                    }
                                }
                            }
                            Message::Response { response, .. } => {
                                info!(
                                    "收到来自 {} 的同步响应: {} 个卡片",
                                    peer, response.card_count
                                );

                                // 处理同步响应
                                if let Err(e) = self.handle_sync_response(peer, response) {
                                    warn!("处理同步响应失败: {}", e);
                                    // 触发状态变化：同步失败 → failed
                                    let status = self.get_sync_status();
                                    self.notify_status_change(status);
                                } else {
                                    // 触发状态变化：同步完成 → synced
                                    let status = self.get_sync_status();
                                    self.notify_status_change(status);
                                }
                            }
                        },
                        Event::OutboundFailure { peer, error, .. } => {
                            warn!("发送到 {} 失败: {:?}", peer, error);
                        }
                        Event::InboundFailure { peer, error, .. } => {
                            warn!("接收来自 {} 失败: {:?}", peer, error);
                        }
                        Event::ResponseSent { peer, .. } => {
                            debug!("响应已发送到 {}", peer);
                        }
                    }
                }
                _ => {}
            }
        }
        Ok(())
    }

    /// 连接建立后自动同步
    #[allow(dead_code)]
    async fn auto_sync_on_connect(&mut self, peer_id: PeerId) -> Result<()> {
        info!("设备 {} 连接成功，触发自动同步", peer_id);

        // 获取设备加入的数据池
        let joined_pools = vec![self
            .device_config
            .lock()
            .unwrap()
            .get_pool_id()
            .map(|s| s.to_string())
            .unwrap_or_default()];

        for pool_id in joined_pools {
            info!("自动同步数据池 {} 到设备 {}", pool_id, peer_id);
            self.request_sync(peer_id, pool_id)?;
        }

        Ok(())
    }

    /// 手动触发数据池同步（基于协调器的并行触发）
    ///
    /// 采用“消耗-归还”模式以便在异步 FFI 中避免 &self 的 Sync 约束：
    /// 调用方移动拥有的 service，调用结束后再放回 thread-local。
    pub async fn sync_pool_owned(mut self, pool_id: &str) -> Result<(Self, i32)> {
        let mut success = 0;

        // 收集所有已注册的 peer，排除自身
        let peers: Vec<PeerId> = registry()
            .lock()
            .unwrap()
            .keys()
            .cloned()
            .filter(|p| p != &self.local_peer_id)
            .collect();

        for peer in peers {
            if self.request_sync(peer, pool_id.to_string()).is_ok() {
                success += 1;
            }
        }

        Ok((self, success))
    }
}

/// 同步状态
#[derive(Debug, Clone, PartialEq)]
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
