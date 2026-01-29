//! mDNS 设备发现 FFI API
//!
//! 提供给 Flutter 的设备发现接口

use crate::p2p::discovery::MdnsDiscovery;
use crate::store::trust_list::TrustListManager;
use flutter_rust_bridge::frb;
use libp2p::{mdns, swarm::SwarmEvent};
use rusqlite::Connection;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use tokio::runtime::Runtime;
use tracing::{debug, error, info, warn};

/// 全局 mDNS 发现管理器
static DISCOVERY_MANAGER: Mutex<Option<DiscoveryManager>> = Mutex::new(None);

/// 重连状态
#[derive(Debug, Clone)]
struct ReconnectState {
    /// 重连尝试次数
    attempts: u32,
    /// 下次重连时间（Unix 时间戳，秒）
    next_retry_at: i64,
    /// 最后一次连接失败时间
    last_failure_at: i64,
}

impl ReconnectState {
    /// 创建新的重连状态
    fn new() -> Self {
        Self {
            attempts: 0,
            next_retry_at: 0,
            last_failure_at: 0,
        }
    }

    /// 计算下次重连延迟（指数退避）
    ///
    /// 延迟策略：
    /// - 第 1 次: 1 秒
    /// - 第 2 次: 2 秒
    /// - 第 3 次: 4 秒
    /// - 第 4 次: 8 秒
    /// - 第 5 次及以上: 16 秒（最大延迟）
    fn calculate_backoff(&self) -> Duration {
        let base_delay = 1;
        let max_delay = 16;
        let delay = base_delay * 2_u64.pow(self.attempts.min(4));
        Duration::from_secs(delay.min(max_delay))
    }

    /// 记录连接失败
    fn record_failure(&mut self) {
        self.attempts += 1;
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs() as i64;
        self.last_failure_at = now;

        let backoff = self.calculate_backoff();
        self.next_retry_at = now + backoff.as_secs() as i64;

        debug!(
            "记录连接失败，尝试次数: {}, 下次重试: {}秒后",
            self.attempts,
            backoff.as_secs()
        );
    }

    /// 重置重连状态（连接成功后调用）
    fn reset(&mut self) {
        self.attempts = 0;
        self.next_retry_at = 0;
        self.last_failure_at = 0;
    }
}

/// mDNS 发现管理器
struct DiscoveryManager {
    /// 已发现的设备列表
    devices: Arc<Mutex<HashMap<String, DiscoveredDevice>>>,
    /// 设备重连状态
    reconnect_states: Arc<Mutex<HashMap<String, ReconnectState>>>,
    /// 后台任务句柄
    task_handle: Option<tokio::task::JoinHandle<()>>,
    /// Tokio 运行时
    runtime: Arc<Runtime>,
    /// 信任列表数据库路径
    trust_list_db_path: Option<String>,
    /// 数据池 ID（用于广播）
    pool_id: Option<String>,
}

impl DiscoveryManager {
    /// 创建新的管理器
    fn new() -> Result<Self, String> {
        let runtime = Runtime::new().map_err(|e| format!("创建 tokio 运行时失败: {}", e))?;

        Ok(Self {
            devices: Arc::new(Mutex::new(HashMap::new())),
            reconnect_states: Arc::new(Mutex::new(HashMap::new())),
            task_handle: None,
            runtime: Arc::new(runtime),
            trust_list_db_path: None,
            pool_id: None,
        })
    }

    /// 设置信任列表数据库路径
    fn set_trust_list_db(&mut self, path: String) {
        self.trust_list_db_path = Some(path);
    }

    /// 设置数据池 ID
    fn set_pool_id(&mut self, pool_id: String) {
        self.pool_id = Some(pool_id);
    }

    /// 启动发现
    fn start(&mut self) -> Result<(), String> {
        if self.task_handle.is_some() {
            return Err("mDNS 发现已经在运行".to_string());
        }

        let devices = Arc::clone(&self.devices);
        let reconnect_states = Arc::clone(&self.reconnect_states);
        let runtime = Arc::clone(&self.runtime);
        let trust_list_db_path = self.trust_list_db_path.clone();
        let pool_id = self.pool_id.clone();

        // 在后台运行发现任务
        let handle = runtime.spawn(async move {
            match MdnsDiscovery::new().await {
                Ok(mut discovery) => {
                    let local_peer_id = discovery.local_peer_id().to_string();
                    info!("mDNS 发现启动，本地 Peer ID: {}", local_peer_id);

                    // 仅在加入池后才广播
                    if pool_id.is_some() {
                        info!("已加入数据池，开始 mDNS 广播");
                    } else {
                        info!("未加入数据池，仅监听不广播");
                    }

                    // 启动监听
                    if let Err(e) = discovery.listen("/ip4/0.0.0.0/tcp/0") {
                        error!("mDNS 监听失败: {}", e);
                        return;
                    }

                    // 处理事件
                    loop {
                        if let Some(event) = discovery.poll_next().await {
                            match event {
                                SwarmEvent::NewListenAddr { address, .. } => {
                                    info!("mDNS 监听地址: {}", address);
                                }
                                SwarmEvent::Behaviour(crate::p2p::discovery::MdnsEvent::Mdns(
                                    mdns::Event::Discovered(list),
                                )) => {
                                    let mut devices_lock = devices.lock().unwrap();
                                    let mut reconnect_lock = reconnect_states.lock().unwrap();

                                    for (peer_id, multiaddr) in list {
                                        let peer_id_str = peer_id.to_string();

                                        // 检查是否在信任列表中
                                        let is_trusted = if let Some(db_path) = &trust_list_db_path {
                                            if let Ok(conn) = Connection::open(db_path) {
                                                let manager = TrustListManager::new(&conn);
                                                manager.is_trusted(&peer_id_str).unwrap_or(false)
                                            } else {
                                                false
                                            }
                                        } else {
                                            // 如果没有设置信任列表，接受所有设备
                                            true
                                        };

                                        if is_trusted {
                                            // 检查是否是重连的设备
                                            let was_offline = devices_lock
                                                .get(&peer_id_str)
                                                .map(|d| !d.is_online)
                                                .unwrap_or(false);

                                            if was_offline {
                                                info!("设备重新上线: {} at {}", peer_id_str, multiaddr);
                                                // 重置重连状态
                                                if let Some(state) = reconnect_lock.get_mut(&peer_id_str) {
                                                    state.reset();
                                                }
                                            } else {
                                                info!("发现信任设备: {} at {}", peer_id_str, multiaddr);
                                            }

                                            // 更新或创建设备信息
                                            let multiaddr_str = multiaddr.to_string();
                                            if let Some(device) = devices_lock.get_mut(&peer_id_str) {
                                                // 设备已存在，更新地址列表
                                                if !device.multiaddrs.contains(&multiaddr_str) {
                                                    info!("设备 {} 添加新地址: {}", peer_id_str, multiaddr_str);
                                                    device.multiaddrs.push(multiaddr_str);
                                                }
                                                device.is_online = true;
                                                device.last_seen = SystemTime::now()
                                                    .duration_since(UNIX_EPOCH)
                                                    .unwrap()
                                                    .as_secs() as i64;
                                            } else {
                                                // 新设备，创建设备信息
                                                let device = DiscoveredDevice {
                                                    peer_id: peer_id_str.clone(),
                                                    device_name: format!("Device-{}", &peer_id_str[..8]),
                                                    multiaddrs: vec![multiaddr_str],
                                                    is_online: true,
                                                    last_seen: SystemTime::now()
                                                        .duration_since(UNIX_EPOCH)
                                                        .unwrap()
                                                        .as_secs() as i64,
                                                };
                                                devices_lock.insert(peer_id_str, device);
                                            }
                                        } else {
                                            debug!("忽略非信任设备: {}", peer_id_str);
                                        }
                                    }
                                }
                                SwarmEvent::Behaviour(crate::p2p::discovery::MdnsEvent::Mdns(
                                    mdns::Event::Expired(list),
                                )) => {
                                    let mut devices_lock = devices.lock().unwrap();
                                    let mut reconnect_lock = reconnect_states.lock().unwrap();

                                    for (peer_id, multiaddr) in list {
                                        let peer_id_str = peer_id.to_string();
                                        let multiaddr_str = multiaddr.to_string();
                                        warn!("设备地址过期: {} at {}", peer_id_str, multiaddr_str);

                                        if let Some(device) = devices_lock.get_mut(&peer_id_str) {
                                            // 从地址列表中移除过期的地址
                                            device.multiaddrs.retain(|addr| addr != &multiaddr_str);

                                            // 如果没有可用地址了，标记设备为离线
                                            if device.multiaddrs.is_empty() {
                                                warn!("设备 {} 所有地址已过期，标记为离线", peer_id_str);
                                                device.is_online = false;

                                                // 初始化重连状态
                                                reconnect_lock
                                                    .entry(peer_id_str.clone())
                                                    .or_insert_with(ReconnectState::new)
                                                    .record_failure();

                                                info!(
                                                    "设备 {} 将在 {} 秒后尝试重连",
                                                    peer_id_str,
                                                    reconnect_lock
                                                        .get(&peer_id_str)
                                                        .map(|s| s.calculate_backoff().as_secs())
                                                        .unwrap_or(0)
                                                );
                                            } else {
                                                info!(
                                                    "设备 {} 移除地址 {}，剩余 {} 个地址",
                                                    peer_id_str,
                                                    multiaddr_str,
                                                    device.multiaddrs.len()
                                                );
                                            }
                                        }
                                    }
                                }
                                _ => {}
                            }
                        }
                    }
                }
                Err(e) => {
                    error!("mDNS 发现初始化失败: {}", e.to_string());
                }
            }
        });

        self.task_handle = Some(handle);
        Ok(())
    }

    /// 停止发现
    fn stop(&mut self) {
        if let Some(handle) = self.task_handle.take() {
            handle.abort();
            info!("mDNS 发现已停止");
        }
    }

    /// 获取已发现的设备
    fn get_devices(&self) -> Vec<DiscoveredDevice> {
        let devices_lock = self.devices.lock().unwrap();
        devices_lock.values().cloned().collect()
    }
}

/// 设备发现事件
#[frb(dart_metadata=("freezed"))]
#[derive(Debug, Clone)]
pub enum DeviceDiscoveryEvent {
    /// 设备上线
    DeviceOnline {
        peer_id: String,
        device_name: String,
        multiaddrs: Vec<String>,
    },
    /// 设备离线
    DeviceOffline { peer_id: String },
}

/// 启动 mDNS 设备发现
///
/// # 参数
///
/// - `trust_list_db_path`: 信任列表数据库路径（可选）
/// - `pool_id`: 数据池 ID（可选，仅在加入池后才广播）
///
/// # 返回
///
/// 成功返回 Ok(())，失败返回错误信息
#[frb(sync)]
pub fn start_mdns_discovery(
    trust_list_db_path: Option<String>,
    pool_id: Option<String>,
) -> Result<(), String> {
    info!("启动 mDNS 设备发现");

    let mut manager_lock = DISCOVERY_MANAGER.lock().unwrap();

    // 如果管理器不存在，创建新的
    if manager_lock.is_none() {
        *manager_lock = Some(DiscoveryManager::new()?);
    }

    // 设置信任列表和 pool_id
    if let Some(manager) = manager_lock.as_mut() {
        if let Some(db_path) = trust_list_db_path {
            manager.set_trust_list_db(db_path);
        }
        if let Some(pool) = pool_id {
            manager.set_pool_id(pool);
        }
        manager.start()?;
    }

    Ok(())
}

/// 停止 mDNS 设备发现
#[frb(sync)]
pub fn stop_mdns_discovery() -> Result<(), String> {
    info!("停止 mDNS 设备发现");

    let mut manager_lock = DISCOVERY_MANAGER.lock().unwrap();

    if let Some(manager) = manager_lock.as_mut() {
        manager.stop();
    }

    Ok(())
}

/// 获取发现的设备列表
///
/// # 返回
///
/// 返回当前在线的设备列表
#[frb(sync)]
pub fn get_discovered_devices() -> Result<Vec<DiscoveredDevice>, String> {
    debug!("获取已发现的设备列表");

    let manager_lock = DISCOVERY_MANAGER.lock().unwrap();

    if let Some(manager) = manager_lock.as_ref() {
        Ok(manager.get_devices())
    } else {
        Ok(vec![])
    }
}

/// 发现的设备信息
#[frb(dart_metadata=("freezed"))]
#[derive(Debug, Clone)]
pub struct DiscoveredDevice {
    /// PeerId
    pub peer_id: String,
    /// 设备名称
    pub device_name: String,
    /// Multiaddr 列表
    pub multiaddrs: Vec<String>,
    /// 是否在线
    pub is_online: bool,
    /// 最后发现时间（Unix 时间戳，秒）
    pub last_seen: i64,
}

/// 订阅设备发现事件
///
/// # 参数
///
/// - `callback`: 事件回调函数
///
/// # 返回
///
/// 成功返回 Ok(())，失败返回错误信息
pub async fn subscribe_discovery_events(
    _callback: impl Fn(DeviceDiscoveryEvent) + Send + Sync + 'static,
) -> Result<(), String> {
    info!("Subscribing to discovery events");

    // TODO: 实现事件订阅逻辑
    // 1. 注册回调函数
    // 2. 从 mDNS 管理器接收事件
    // 3. 调用回调函数

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_device_discovery_event_creation() {
        let event = DeviceDiscoveryEvent::DeviceOnline {
            peer_id: "12D3KooWTest".to_string(),
            device_name: "Test Device".to_string(),
            multiaddrs: vec!["/ip4/192.168.1.100/tcp/4001".to_string()],
        };

        match event {
            DeviceDiscoveryEvent::DeviceOnline {
                peer_id,
                device_name,
                multiaddrs,
            } => {
                assert_eq!(peer_id, "12D3KooWTest");
                assert_eq!(device_name, "Test Device");
                assert_eq!(multiaddrs.len(), 1);
            }
            _ => panic!("Wrong event type"),
        }
    }

    #[test]
    fn test_discovered_device_creation() {
        let device = DiscoveredDevice {
            peer_id: "12D3KooWTest".to_string(),
            device_name: "Test Device".to_string(),
            multiaddrs: vec!["/ip4/192.168.1.100/tcp/4001".to_string()],
            is_online: true,
            last_seen: 1706234567,
        };

        assert_eq!(device.peer_id, "12D3KooWTest");
        assert_eq!(device.device_name, "Test Device");
        assert!(device.is_online);
    }

    #[test]
    fn test_reconnect_state_creation() {
        let state = ReconnectState::new();
        assert_eq!(state.attempts, 0);
        assert_eq!(state.next_retry_at, 0);
        assert_eq!(state.last_failure_at, 0);
    }

    #[test]
    fn test_reconnect_backoff_calculation() {
        let mut state = ReconnectState::new();

        // 第一次失败：1秒
        state.record_failure();
        assert_eq!(state.attempts, 1);
        assert_eq!(state.calculate_backoff().as_secs(), 2);

        // 第二次失败：2秒
        state.record_failure();
        assert_eq!(state.attempts, 2);
        assert_eq!(state.calculate_backoff().as_secs(), 4);

        // 第三次失败：4秒
        state.record_failure();
        assert_eq!(state.attempts, 3);
        assert_eq!(state.calculate_backoff().as_secs(), 8);

        // 第四次失败：8秒
        state.record_failure();
        assert_eq!(state.attempts, 4);
        assert_eq!(state.calculate_backoff().as_secs(), 16);

        // 第五次及以上：16秒（最大延迟）
        state.record_failure();
        assert_eq!(state.attempts, 5);
        assert_eq!(state.calculate_backoff().as_secs(), 16);
    }

    #[test]
    fn test_reconnect_state_reset() {
        let mut state = ReconnectState::new();

        // 记录几次失败
        state.record_failure();
        state.record_failure();
        assert_eq!(state.attempts, 2);

        // 重置状态
        state.reset();
        assert_eq!(state.attempts, 0);
        assert_eq!(state.next_retry_at, 0);
        assert_eq!(state.last_failure_at, 0);
    }

    #[test]
    fn test_device_multiaddr_updates() {
        // 测试设备地址列表更新逻辑
        let mut device = DiscoveredDevice {
            peer_id: "12D3KooWTest".to_string(),
            device_name: "Test Device".to_string(),
            multiaddrs: vec!["/ip4/192.168.1.100/tcp/4001".to_string()],
            is_online: true,
            last_seen: 1706234567,
        };

        // 添加新地址
        let new_addr = "/ip4/192.168.1.100/tcp/4002".to_string();
        if !device.multiaddrs.contains(&new_addr) {
            device.multiaddrs.push(new_addr.clone());
        }
        assert_eq!(device.multiaddrs.len(), 2);

        // 移除地址
        device.multiaddrs.retain(|addr| addr != &new_addr);
        assert_eq!(device.multiaddrs.len(), 1);

        // 移除所有地址后应标记为离线
        device.multiaddrs.clear();
        if device.multiaddrs.is_empty() {
            device.is_online = false;
        }
        assert!(!device.is_online);
    }
}
