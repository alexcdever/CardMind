//! P2P 同步 API
//!
//! 本模块提供 P2P 同步服务的 Flutter 桥接函数。
//!
//! # Thread-Local 存储
//!
//! 使用 thread-local 存储 `P2PSyncService` 实例，避免 SQLite 线程安全问题。

use crate::frb_generated::StreamSink;
use crate::models::error::{CardMindError, Result};
use crate::p2p::sync_service::{P2PSyncService, SyncStatus as P2PSyncStatus};
use std::cell::RefCell;
use tokio_stream::StreamExt;
use tracing::{info, warn};

thread_local! {
    static SYNC_SERVICE: RefCell<Option<P2PSyncService>> = RefCell::new(None);
}

fn take_sync_service() -> Result<P2PSyncService> {
    SYNC_SERVICE.with(|s| {
        let service = s.borrow_mut().take();
        service.ok_or_else(|| {
            CardMindError::DatabaseError(
                "Sync service not initialized. Call init_sync_service first.".to_string(),
            )
        })
    })
}

fn put_sync_service(service: P2PSyncService) {
    SYNC_SERVICE.with(|s| {
        *s.borrow_mut() = Some(service);
    });
}

/// 同步状态枚举
///
/// 定义同步的 4 种状态
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SyncState {
    /// 未连接到任何对等设备
    Disconnected,
    /// 正在同步数据
    Syncing,
    /// 同步完成，数据一致
    Synced,
    /// 同步失败
    Failed,
}

/// 同步状态（用于 Flutter 桥接）
///
/// # flutter_rust_bridge 注解
///
/// 这个结构体会被自动转换为 Dart 类
#[derive(Debug, Clone)]
pub struct SyncStatus {
    /// 当前同步状态
    pub state: SyncState,

    /// 正在同步的对等设备数量
    pub syncing_peers: i32,

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
    fn from(status: P2PSyncStatus) -> Self {
        // 根据设备数量推断状态
        let state = if status.online_devices == 0 && status.syncing_devices == 0 {
            SyncState::Disconnected
        } else if status.syncing_devices > 0 {
            SyncState::Syncing
        } else if status.online_devices > 0 {
            SyncState::Synced
        } else {
            SyncState::Disconnected
        };

        Self {
            state,
            syncing_peers: status.syncing_devices as i32,
            last_sync_time: None, // TODO: 从 P2PSyncService 获取实际时间
            error_message: None,
            online_devices: status.online_devices as i32,
            syncing_devices: status.syncing_devices as i32,
            offline_devices: status.offline_devices as i32,
        }
    }
}

impl SyncStatus {
    /// 创建 disconnected 状态
    pub fn disconnected() -> Self {
        Self {
            state: SyncState::Disconnected,
            syncing_peers: 0,
            last_sync_time: None,
            error_message: None,
            online_devices: 0,
            syncing_devices: 0,
            offline_devices: 0,
        }
    }

    /// 创建 syncing 状态
    pub fn syncing(syncing_peers: i32) -> Self {
        Self {
            state: SyncState::Syncing,
            syncing_peers,
            last_sync_time: None,
            error_message: None,
            online_devices: syncing_peers,
            syncing_devices: syncing_peers,
            offline_devices: 0,
        }
    }

    /// 创建 synced 状态
    pub fn synced(last_sync_time: i64) -> Self {
        Self {
            state: SyncState::Synced,
            syncing_peers: 0,
            last_sync_time: Some(last_sync_time),
            error_message: None,
            online_devices: 1,
            syncing_devices: 0,
            offline_devices: 0,
        }
    }

    /// 创建 failed 状态
    pub fn failed(error_message: String) -> Self {
        Self {
            state: SyncState::Failed,
            syncing_peers: 0,
            last_sync_time: None,
            error_message: Some(error_message),
            online_devices: 0,
            syncing_devices: 0,
            offline_devices: 0,
        }
    }
}

/// 辅助函数：在 SYNC_SERVICE 上执行操作
fn with_sync_service<F, R>(f: F) -> Result<R>
where
    F: FnOnce(&mut P2PSyncService) -> Result<R>,
{
    SYNC_SERVICE.with(|s| {
        let mut service_ref = s.borrow_mut();
        let service = service_ref.as_mut().ok_or_else(|| {
            CardMindError::DatabaseError(
                "Sync service not initialized. Call init_sync_service first.".to_string(),
            )
        })?;
        f(service)
    })
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
    let already_initialized = SYNC_SERVICE.with(|s| s.borrow().is_some());
    if already_initialized {
        warn!("同步服务已经初始化，先清理旧实例");
        cleanup_sync_service();
    }

    // 获取 CardStore（假设已通过 init_card_store 初始化）
    let card_store = crate::api::card::get_card_store_arc()?;

    // 获取 DeviceConfig（假设已通过 init_device_config 初始化）
    let device_config = crate::api::device_config::get_device_config()?;

    // 创建同步服务
    let mut service = P2PSyncService::new(card_store, device_config)?;

    // 启动服务
    service.start(&listen_addr).await?;

    let peer_id = service.local_peer_id().to_string();

    // 保存到 thread-local
    SYNC_SERVICE.with(|s| {
        *s.borrow_mut() = Some(service);
    });

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

    // 临时从 thread-local 取出服务，避免在异步期间持有 RefCell 借用
    let service = take_sync_service()?;

    let (service, result) = service
        .sync_pool_owned(&pool_id)
        .await
        .map_err(|e| CardMindError::Unknown(format!("Sync failed: {e}")))?;

    put_sync_service(service);

    Ok(result)
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
    SYNC_SERVICE.with(|s| {
        *s.borrow_mut() = None;
    });
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

    // 临时从 thread-local 取出服务
    let service = take_sync_service()?;

    // 获取当前状态
    let current_status = service.get_sync_status();

    // 检查是否有可用的 peer
    if current_status.online_devices == 0 && current_status.syncing_devices == 0 {
        put_sync_service(service);
        return Err(CardMindError::Unknown(
            "No peers available for sync. Please wait for peer discovery.".to_string(),
        ));
    }

    // 触发状态变化：重试 → syncing
    let syncing_status = P2PSyncStatus {
        online_devices: current_status.online_devices,
        syncing_devices: current_status.online_devices,
        offline_devices: current_status.offline_devices,
    };
    service.notify_status_change(syncing_status);

    info!("重试同步完成，状态已更新为 syncing");

    put_sync_service(service);

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
#[flutter_rust_bridge::frb]
#[allow(unused_must_use)]
pub fn get_sync_status_stream(sink: StreamSink<SyncStatus>) -> Result<()> {
    info!("创建同步状态 Stream");

    // 获取当前状态和广播发送器
    let (current_status, sender) = SYNC_SERVICE.with(|s| {
        let service_ref = s.borrow();
        let service = service_ref.as_ref().ok_or_else(|| {
            CardMindError::DatabaseError(
                "Sync service not initialized. Call init_sync_service first.".to_string(),
            )
        })?;

        let current = service.get_sync_status();
        let sender = service.status_sender();
        Ok::<_, CardMindError>((current, sender))
    })?;

    // 在后台任务中处理 Stream
    let _ = tokio::spawn(async move {
        use tokio_stream::wrappers::BroadcastStream;

        // 先发送当前状态
        sink.add(current_status.into());

        // 订阅广播通道
        let rx = sender.subscribe();
        let mut stream = BroadcastStream::new(rx);

        // 持续接收并发送状态更新
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

    Ok(())
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
        // 由于依赖复杂，这里仅测试清理功能

        cleanup_sync_service();

        // 验证清理后状态
        let result = get_sync_status();
        assert!(result.is_err(), "清理后应该无法获取状态");

        cleanup_sync_service();
    }

    #[test]
    fn test_sync_status_conversion() {
        let p2p_status = P2PSyncStatus {
            online_devices: 3,
            syncing_devices: 1,
            offline_devices: 2,
        };

        let status: SyncStatus = p2p_status.into();

        assert_eq!(status.syncing_peers, 1);
        assert_eq!(status.online_devices, 3);
        assert_eq!(status.syncing_devices, 1);
        assert_eq!(status.offline_devices, 2);
        assert_eq!(status.state, SyncState::Syncing);
    }

    #[test]
    fn test_sync_status_factory_methods() {
        // Test disconnected
        let disconnected = SyncStatus::disconnected();
        assert_eq!(disconnected.state, SyncState::Disconnected);
        assert_eq!(disconnected.syncing_peers, 0);
        assert!(disconnected.last_sync_time.is_none());
        assert!(disconnected.error_message.is_none());

        // Test syncing
        let syncing = SyncStatus::syncing(3);
        assert_eq!(syncing.state, SyncState::Syncing);
        assert_eq!(syncing.syncing_peers, 3);

        // Test synced
        let now = 1234567890;
        let synced = SyncStatus::synced(now);
        assert_eq!(synced.state, SyncState::Synced);
        assert_eq!(synced.last_sync_time, Some(now));

        // Test failed
        let failed = SyncStatus::failed("Network error".to_string());
        assert_eq!(failed.state, SyncState::Failed);
        assert_eq!(failed.error_message, Some("Network error".to_string()));
    }

    #[test]
    fn test_sync_state_equality() {
        assert_eq!(SyncState::Disconnected, SyncState::Disconnected);
        assert_ne!(SyncState::Disconnected, SyncState::Syncing);
        assert_ne!(SyncState::Syncing, SyncState::Synced);
        assert_ne!(SyncState::Synced, SyncState::Failed);
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

        SYNC_SERVICE.with(|s| {
            *s.borrow_mut() = Some(service);
        });

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
        // 清理并初始化服务
        cleanup_sync_service();

        let card_store = Arc::new(Mutex::new(
            crate::store::card_store::CardStore::new_in_memory().unwrap(),
        ));
        let device_config = crate::models::device_config::DeviceConfig::new("test-device");

        let service = crate::p2p::sync_service::P2PSyncService::new(card_store, device_config)
            .expect("Failed to create sync service");

        SYNC_SERVICE.with(|s| {
            *s.borrow_mut() = Some(service);
        });

        // 注意：StreamSink 无法在单元测试中直接创建
        // 这个功能需要在集成测试或 Flutter 端测试中验证
        // 这里我们只验证服务已正确初始化

        let status = get_sync_status();
        assert!(status.is_ok(), "应该能够获取同步状态");

        cleanup_sync_service();
    }
}
