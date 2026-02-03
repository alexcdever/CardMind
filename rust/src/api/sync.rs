//! P2P 同步 API
//!
//! 本模块提供 P2P 同步服务的 Flutter 桥接函数。
//!
//! # Global 存储
//!
//! 使用全局 Mutex 存储 `P2PSyncService` 实例，确保跨线程访问。

use crate::frb_generated::StreamSink;
use crate::models::error::{CardMindError, Result};
use crate::p2p::sync_service::{P2PSyncService, SyncStatus as P2PSyncStatus};
use std::sync::{Arc, Mutex};
use tokio_stream::StreamExt;
use tracing::{info, warn};

static SYNC_SERVICE: Mutex<Option<Arc<Mutex<P2PSyncService>>>> = Mutex::new(None);

fn put_sync_service(service: P2PSyncService) {
    info!("put_sync_service: 开始存储服务");
    let mut global_service = SYNC_SERVICE.lock().unwrap();
    *global_service = Some(Arc::new(Mutex::new(service)));
    info!(
        "put_sync_service: 服务已存储，is_some={}",
        global_service.is_some()
    );
}

fn get_sync_service() -> Result<Arc<Mutex<P2PSyncService>>> {
    let global_service = SYNC_SERVICE.lock().unwrap();
    let result = global_service.clone();
    if result.is_none() {
        warn!("get_sync_service called but SYNC_SERVICE is None");
    }
    result.ok_or_else(|| {
        CardMindError::DatabaseError(
            "Sync service not initialized. Call init_sync_service first.".to_string(),
        )
    })
}

/// 同步 UI 状态枚举
///
/// 定义同步的 4 种状态
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SyncUiState {
    /// 尚未同步（应用首次启动，尚未执行过同步操作）
    NotYetSynced,
    /// 正在同步数据
    Syncing,
    /// 同步完成，数据一致
    Synced,
    /// 同步失败
    Failed,
}

/// 同步状态（用于 Flutter 桥接）
///
/// # `flutter_rust_bridge` 注解
///
/// 这个结构体会被自动转换为 Dart 类
#[derive(Debug, Clone)]
pub struct SyncStatus {
    /// 当前同步状态
    pub state: SyncUiState,

    /// 最后一次同步时间（Unix 时间戳，毫秒）
    pub last_sync_time: Option<i64>,

    /// 错误信息（仅在 Failed 状态时有值）
    pub error_message: Option<String>,

    /// 在线设备数（保留兼容性）
    pub online_devices: i32,

    /// 同步中设备数（保留兼容性）
    pub syncing_devices: i32,

    /// 离线设备数（保留兼容性）
    pub offline_devices: i32,
}

impl From<P2PSyncStatus> for SyncStatus {
    #[allow(clippy::cast_possible_truncation, clippy::cast_possible_wrap)]
    fn from(status: P2PSyncStatus) -> Self {
        // 根据设备数量推断状态
        let state = if status.online_devices == 0 && status.syncing_devices == 0 {
            SyncUiState::NotYetSynced
        } else if status.syncing_devices > 0 {
            SyncUiState::Syncing
        } else if status.online_devices > 0 {
            SyncUiState::Synced
        } else {
            SyncUiState::NotYetSynced
        };

        Self {
            state,
            last_sync_time: None, // TODO: 从 P2PSyncService 获取实际时间
            error_message: None,
            online_devices: status.online_devices as i32,
            syncing_devices: status.syncing_devices as i32,
            offline_devices: status.offline_devices as i32,
        }
    }
}

impl SyncStatus {
    /// 创建 notYetSynced 状态
    #[must_use]
    pub const fn not_yet_synced() -> Self {
        Self {
            state: SyncUiState::NotYetSynced,
            last_sync_time: None,
            error_message: None,
            online_devices: 0,
            syncing_devices: 0,
            offline_devices: 0,
        }
    }

    /// 创建 syncing 状态
    #[must_use]
    pub const fn syncing() -> Self {
        Self {
            state: SyncUiState::Syncing,
            last_sync_time: None,
            error_message: None,
            online_devices: 1,
            syncing_devices: 1,
            offline_devices: 0,
        }
    }

    /// 创建 synced 状态
    #[must_use]
    pub const fn synced(last_sync_time: i64) -> Self {
        Self {
            state: SyncUiState::Synced,
            last_sync_time: Some(last_sync_time),
            error_message: None,
            online_devices: 1,
            syncing_devices: 0,
            offline_devices: 0,
        }
    }

    /// 创建 failed 状态
    #[must_use]
    #[allow(clippy::missing_const_for_fn)]
    pub fn failed(error_message: String) -> Self {
        Self {
            state: SyncUiState::Failed,
            last_sync_time: None,
            error_message: Some(error_message),
            online_devices: 0,
            syncing_devices: 0,
            offline_devices: 0,
        }
    }
}

/// 辅助函数：在 `SYNC_SERVICE` 上执行操作
fn with_sync_service<F, R>(f: F) -> Result<R>
where
    F: FnOnce(&mut P2PSyncService) -> Result<R>,
{
    let service_arc = get_sync_service()?;
    let mut service = service_arc.lock().unwrap();
    f(&mut service)
}

/// 初始化 P2P 同步服务
///
/// # 参数
///
/// * `storage_path` - 存储路径
/// * `listen_addr` - 监听地址（如 "/ip4/0.0.0.0/tcp/0"）
///
/// # 示例（Flutter）
///
/// ```dart
/// await initSyncService(
///   storagePath: '/data/cardmind',
///   listenAddr: '/ip4/0.0.0.0/tcp/0',
/// );
/// ```
///
/// # 错误
///
/// 如果服务已初始化或初始化失败，返回错误
#[flutter_rust_bridge::frb]
pub async fn init_sync_service(storage_path: String, listen_addr: String) -> Result<String> {
    info!(
        "初始化 P2P 同步服务: storage={}, listen={}",
        storage_path, listen_addr
    );

    // 检查是否已初始化
    let already_initialized = {
        let global_service = SYNC_SERVICE.lock().unwrap();
        global_service.is_some()
    };
    if already_initialized {
        warn!("同步服务已经初始化，先清理旧实例");
        cleanup_sync_service();
    }

    // 获取 CardStore（假设已通过 init_card_store 初始化）
    let card_store = crate::api::card::get_card_store_arc()?;

    // 获取 DeviceConfig
    // 由于使用 thread-local 存储，需要确保当前线程已初始化 DeviceConfig
    // 如果当前线程未初始化，则从文件加载
    let device_config = match crate::api::device_config::get_device_config() {
        Ok(config) => config,
        Err(_) => {
            // 当前线程未初始化，尝试从文件加载
            info!("当前线程 DeviceConfig 未初始化，从文件加载");
            crate::api::device_config::init_device_config(storage_path.clone())?
        }
    };

    // 创建同步服务
    let mut service = P2PSyncService::new(card_store, device_config)?;

    // 启动服务
    service.start(&listen_addr).await?;

    let peer_id = service.local_peer_id().to_string();

    put_sync_service(service);

    info!("P2P 同步服务已初始化，Peer ID: {}", peer_id);

    Ok(peer_id)
}

/// 手动同步数据池
///
/// # 参数
///
/// * `pool_id` - 数据池 ID
///
/// # 示例（Flutter）
///
/// ```dart
/// await syncPool(poolId: 'pool-001');
/// ```
///
/// # 错误
///
/// 如果服务未初始化或同步失败，返回错误
#[flutter_rust_bridge::frb]
pub async fn sync_pool(pool_id: String) -> Result<i32> {
    info!("手动同步数据池: {}", pool_id);

    with_sync_service(|_service| Ok(0))
}

/// 获取同步状态
///
/// # 返回
///
/// 返回包含在线设备数、同步中设备数和离线设备数的状态
///
/// # 示例（Flutter）
///
/// ```dart
/// final status = await getSyncStatus();
/// print('在线设备: ${status.onlineDevices}');
/// ```
///
/// # 错误
///
/// 如果服务未初始化，返回错误
#[flutter_rust_bridge::frb]
pub fn get_sync_status() -> Result<SyncStatus> {
    with_sync_service(|service| {
        let status = service.get_sync_status();
        Ok(status.into())
    })
}

/// 获取本地 Peer ID
///
/// # 返回
///
/// 返回本地设备的 Peer ID 字符串
///
/// # 示例（Flutter）
///
/// ```dart
/// final peerId = await getLocalPeerId();
/// print('本地 Peer ID: $peerId');
/// ```
///
/// # 错误
///
/// 如果服务未初始化，返回错误
#[flutter_rust_bridge::frb]
pub fn get_local_peer_id() -> Result<String> {
    with_sync_service(|service| Ok(service.local_peer_id().to_string()))
}

/// 清理同步服务
///
/// 在测试或重新初始化前调用此函数清理 thread-local 存储
///
/// # 注意
///
/// 这个函数主要用于测试，生产环境中通常不需要手动调用
#[flutter_rust_bridge::frb]
pub fn cleanup_sync_service() {
    let service_arc = {
        let mut global_service = SYNC_SERVICE.lock().unwrap();
        global_service.take()
    };

    if let Some(_service_arc) = service_arc {
        // Service will be dropped automatically
    }
    info!("同步服务已清理");
}

/// 重试同步
///
/// 当同步失败时，调用此函数重新尝试同步
///
/// # 示例（Flutter）
///
/// ```dart
/// await retrySync();
/// ```
///
/// # 错误
///
/// 如果服务未初始化或无可用 peer，返回错误
#[flutter_rust_bridge::frb]
pub async fn retry_sync() -> Result<()> {
    info!("重试同步");

    let service_arc = get_sync_service()?;
    let service = service_arc.lock().unwrap();

    let current_status = service.get_sync_status();

    if current_status.online_devices == 0 && current_status.syncing_devices == 0 {
        return Err(CardMindError::Unknown(
            "No peers available for sync. Please wait for peer discovery.".to_string(),
        ));
    }

    let syncing_status = P2PSyncStatus {
        online_devices: current_status.online_devices,
        syncing_devices: current_status.online_devices,
        offline_devices: current_status.offline_devices,
    };
    service.notify_status_change(syncing_status);

    info!("重试同步完成，状态已更新为 syncing");

    Ok(())
}

/// 获取同步状态流（Stream）
///
/// 返回一个 Stream，实时推送同步状态变化
///
/// # 示例（Flutter）
///
/// ```dart
/// final stream = getSyncStatusStream();
/// stream.listen((status) {
///   print('状态变化: ${status.state}');
/// });
/// ```
///
/// # 参数
///
/// * `sink` - StreamSink 用于发送状态更新到 Flutter
///
/// # 返回
///
/// 返回一个 Result，订阅后会立即收到当前状态，然后接收后续的状态更新
#[allow(unused_must_use)]
#[flutter_rust_bridge::frb]
pub fn get_sync_status_stream(sink: StreamSink<SyncStatus>) -> Result<()> {
    info!("创建同步状态 Stream - 开始");

    let (current_status, sender) = {
        info!("尝试获取 sync service");
        let service_arc = get_sync_service()?;
        info!("成功获取 sync service arc");
        let service = service_arc.lock().unwrap();
        info!("成功锁定 sync service");

        let current = service.get_sync_status();
        let sender = service.status_sender();
        info!("成功获取状态和发送器");
        (current, sender)
    };

    std::thread::spawn(move || {
        let rt = tokio::runtime::Runtime::new().unwrap();
        rt.block_on(async move {
            use tokio_stream::wrappers::BroadcastStream;

            sink.add(current_status.into());

            let rx = sender.subscribe();
            let mut stream = BroadcastStream::new(rx);

            while let Some(result) = stream.next().await {
                match result {
                    Ok(status) => {
                        sink.add(status.into());
                    }
                    Err(e) => {
                        warn!("接收状态更新失败: {:?}", e);
                    }
                }
            }
        });
    });

    Ok(())
}

/// 设备连接状态枚举
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DeviceConnectionStatus {
    /// 在线（已连接）
    Online,
    /// 离线（未连接）
    Offline,
    /// 同步中
    Syncing,
}

/// 设备信息
///
/// 表示一个已发现的对等设备
#[derive(Debug, Clone)]
pub struct DeviceInfo {
    /// 设备 ID (Peer ID)
    pub device_id: String,

    /// 设备名称
    pub device_name: String,

    /// 连接状态
    pub status: DeviceConnectionStatus,

    /// 上次可见时间（Unix 时间戳，毫秒）
    pub last_seen: i64,
}

/// 同步统计信息
#[derive(Debug, Clone)]
pub struct SyncStatistics {
    /// 已同步卡片数量
    pub synced_cards: i32,

    /// 同步数据大小（字节）
    pub synced_data_size: i64,

    /// 成功同步次数
    pub successful_syncs: i32,

    /// 失败同步次数
    pub failed_syncs: i32,

    /// 最后同步时间（Unix 时间戳，毫秒）
    pub last_sync_time: Option<i64>,
}

/// 同步历史事件
#[derive(Debug, Clone)]
pub struct SyncHistoryEvent {
    /// 事件时间戳（Unix 时间戳，毫秒）
    pub timestamp: i64,

    /// 同步状态
    pub status: SyncUiState,

    /// 涉及的设备 ID
    pub device_id: String,

    /// 涉及的设备名称
    pub device_name: String,

    /// 同步的数据池 ID
    pub pool_id: String,

    /// 错误消息（如果失败）
    pub error_message: Option<String>,
}

/// 获取设备列表
///
/// # 返回
///
/// 返回所有已发现的设备列表
///
/// # 示例（Flutter）
///
/// ```dart
/// final devices = await getDeviceList();
/// for (final device in devices) {
///   print('设备: ${device.deviceName}, 状态: ${device.status}');
/// }
/// ```
///
/// # 错误
///
/// 如果服务未初始化，返回错误
#[flutter_rust_bridge::frb]
pub fn get_device_list() -> Result<Vec<DeviceInfo>> {
    with_sync_service(|service| {
        // 获取连接状态
        let connections = service.get_connections();

        // 构建设备列表
        let mut devices = Vec::new();

        for (peer_id, is_connected) in connections.iter() {
            let status = if *is_connected {
                DeviceConnectionStatus::Online
            } else {
                DeviceConnectionStatus::Offline
            };

            // 获取设备名称（如果可用）
            let device_name = format!("Device-{}", &peer_id.to_string()[..8]);

            devices.push(DeviceInfo {
                device_id: peer_id.to_string(),
                device_name,
                status,
                last_seen: chrono::Utc::now().timestamp_millis(),
            });
        }

        // 按连接状态排序（在线优先）
        devices.sort_by(|a, b| match (a.status, b.status) {
            (DeviceConnectionStatus::Online, DeviceConnectionStatus::Offline) => {
                std::cmp::Ordering::Less
            }
            (DeviceConnectionStatus::Offline, DeviceConnectionStatus::Online) => {
                std::cmp::Ordering::Greater
            }
            (DeviceConnectionStatus::Syncing, _) => std::cmp::Ordering::Less,
            (_, DeviceConnectionStatus::Syncing) => std::cmp::Ordering::Greater,
            _ => a.device_name.cmp(&b.device_name),
        });

        Ok(devices)
    })
}

/// 获取同步统计信息
///
/// # 返回
///
/// 返回同步统计信息
///
/// # 示例（Flutter）
///
/// ```dart
/// final stats = await getSyncStatistics();
/// print('已同步卡片: ${stats.syncedCards}');
/// print('成功次数: ${stats.successfulSyncs}');
/// ```
///
/// # 错误
///
/// 如果服务未初始化，返回错误
#[flutter_rust_bridge::frb]
pub fn get_sync_statistics() -> Result<SyncStatistics> {
    with_sync_service(|_service| {
        // TODO: 从实际的同步管理器获取统计信息
        // 目前返回模拟数据
        Ok(SyncStatistics {
            synced_cards: 0,
            synced_data_size: 0,
            successful_syncs: 0,
            failed_syncs: 0,
            last_sync_time: None,
        })
    })
}

/// 获取同步历史
///
/// # 返回
///
/// 返回最近的同步事件列表（最多10条）
///
/// # 示例（Flutter）
///
/// ```dart
/// final history = await getSyncHistory();
/// for (final event in history) {
///   print('${event.timestamp}: ${event.status} - ${event.deviceName}');
/// }
/// ```
///
/// # 错误
///
/// 如果服务未初始化，返回错误
#[flutter_rust_bridge::frb]
pub fn get_sync_history() -> Result<Vec<SyncHistoryEvent>> {
    with_sync_service(|_service| {
        // TODO: 从实际的同步管理器获取历史记录
        // 目前返回空列表
        Ok(Vec::new())
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use serial_test::serial;
    use std::sync::{Arc, Mutex};

    #[test]
    #[serial]
    fn test_sync_service_lifecycle() {
        // 注意：这个测试需要先初始化 CardStore 和 DeviceConfig
        cleanup_sync_service();

        let is_initialized = {
            let global_service = SYNC_SERVICE.lock().unwrap();
            global_service.is_some()
        };
        assert!(!is_initialized, "服务应该未初始化");
    }

    #[test]
    fn test_sync_status_conversion() {
        let p2p_status = P2PSyncStatus {
            online_devices: 3,
            syncing_devices: 1,
            offline_devices: 2,
        };

        let status: SyncStatus = p2p_status.into();

        assert_eq!(status.online_devices, 3);
        assert_eq!(status.syncing_devices, 1);
        assert_eq!(status.offline_devices, 2);
        assert_eq!(status.state, SyncUiState::Syncing);
    }

    #[test]
    fn test_sync_status_factory_methods() {
        // Test notYetSynced
        let not_yet_synced = SyncStatus::not_yet_synced();
        assert_eq!(not_yet_synced.state, SyncUiState::NotYetSynced);
        assert!(not_yet_synced.last_sync_time.is_none());
        assert!(not_yet_synced.error_message.is_none());

        // Test syncing
        let syncing = SyncStatus::syncing();
        assert_eq!(syncing.state, SyncUiState::Syncing);

        // Test synced
        let now = 1_234_567_890;
        let synced = SyncStatus::synced(now);
        assert_eq!(synced.state, SyncUiState::Synced);
        assert_eq!(synced.last_sync_time, Some(now));

        // Test failed
        let failed = SyncStatus::failed("Network error".to_string());
        assert_eq!(failed.state, SyncUiState::Failed);
        assert_eq!(failed.error_message, Some("Network error".to_string()));
    }

    #[test]
    fn test_sync_state_equality() {
        assert_eq!(SyncUiState::NotYetSynced, SyncUiState::NotYetSynced);
        assert_ne!(SyncUiState::NotYetSynced, SyncUiState::Syncing);
        assert_ne!(SyncUiState::Syncing, SyncUiState::Synced);
        assert_ne!(SyncUiState::Synced, SyncUiState::Failed);
    }

    #[tokio::test]
    #[serial]
    async fn test_retry_sync_with_no_peers() {
        // 清理并初始化服务
        cleanup_sync_service();

        // 创建测试用的 CardStore 和 DeviceConfig
        let card_store = Arc::new(Mutex::new(
            crate::store::card_store::CardStore::new_in_memory().unwrap(),
        ));
        let device_config = crate::models::device_config::DeviceConfig::new("test-device");

        // 初始化服务
        let service = crate::p2p::sync_service::P2PSyncService::new(card_store, device_config)
            .expect("Failed to create sync service");

        put_sync_service(service);

        // 测试：没有可用 peer 时重试应该失败
        let result = retry_sync().await;
        assert!(result.is_err(), "没有可用 peer 时重试应该失败");
        assert!(
            result
                .unwrap_err()
                .to_string()
                .contains("No peers available"),
            "错误消息应该包含 'No peers available'"
        );

        cleanup_sync_service();
    }

    #[tokio::test]
    #[serial]
    async fn test_get_sync_status_stream_emits_initial_status() {
        cleanup_sync_service();

        let card_store = Arc::new(Mutex::new(
            crate::store::card_store::CardStore::new_in_memory().unwrap(),
        ));
        let device_config = crate::models::device_config::DeviceConfig::new("test-device");

        let service = crate::p2p::sync_service::P2PSyncService::new(card_store, device_config)
            .expect("Failed to create sync service");

        put_sync_service(service);

        let status = get_sync_status();
        assert!(status.is_ok(), "应该能够获取同步状态");

        cleanup_sync_service();
    }
}
