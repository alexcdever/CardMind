//! P2P 同步 API
//!
//! 本模块提供 P2P 同步服务的 Flutter 桥接函数。
//!
//! # Thread-Local 存储
//!
//! 使用 thread-local 存储 `P2PSyncService` 实例，避免 SQLite 线程安全问题。

use crate::models::error::{CardMindError, Result};
use crate::p2p::sync_service::{P2PSyncService, SyncStatus as P2PSyncStatus};
use std::cell::RefCell;
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

/// 同步状态（用于 Flutter 桥接）
///
/// # flutter_rust_bridge 注解
///
/// 这个结构体会被自动转换为 Dart 类
#[derive(Debug, Clone)]
pub struct SyncStatus {
    /// 在线设备数
    pub online_devices: i32,

    /// 同步中设备数
    pub syncing_devices: i32,

    /// 离线设备数
    pub offline_devices: i32,
}

impl From<P2PSyncStatus> for SyncStatus {
    fn from(status: P2PSyncStatus) -> Self {
        Self {
            online_devices: status.online_devices as i32,
            syncing_devices: status.syncing_devices as i32,
            offline_devices: status.offline_devices as i32,
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

#[cfg(test)]
mod tests {
    use super::*;
    use serial_test::serial;

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

        assert_eq!(status.online_devices, 3);
        assert_eq!(status.syncing_devices, 1);
        assert_eq!(status.offline_devices, 2);
    }
}
