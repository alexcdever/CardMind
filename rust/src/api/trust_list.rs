//! 信任设备列表 API
//!
//! 提供信任设备列表管理的 FFI 接口。

use crate::store::sqlite_store::SqliteStore;
use crate::store::trust_list::{TrustListManager, TrustedDevice};
use std::sync::Mutex;

/// 全局 SQLite Store 实例（用于信任列表）
static TRUST_STORE: Mutex<Option<SqliteStore>> = Mutex::new(None);

/// 初始化信任列表存储
///
/// # 参数
///
/// - `db_path`: SQLite 数据库文件路径
///
/// # 示例
///
/// ```dart
/// await initTrustListStore(dbPath: '/path/to/cache.db');
/// ```
#[flutter_rust_bridge::frb(sync)]
pub fn init_trust_list_store(db_path: String) -> Result<(), String> {
    let store = SqliteStore::new(&db_path).map_err(|e| format!("初始化失败: {e}"))?;

    let mut global = TRUST_STORE.lock().map_err(|e| format!("锁定失败: {e}"))?;
    *global = Some(store);

    Ok(())
}

/// 添加信任设备
///
/// 如果设备已存在，则更新设备信息。
///
/// # 参数
///
/// - `peer_id`: 设备 PeerId
/// - `device_name`: 设备名称
/// - `device_type`: 设备类型（phone/laptop/tablet）
/// - `paired_at`: 配对时间（Unix 毫秒时间戳）
/// - `last_seen`: 最后在线时间（Unix 毫秒时间戳）
///
/// # 示例
///
/// ```dart
/// await addTrustedDevice(
///   peerId: '12D3KooW...',
///   deviceName: 'My Phone',
///   deviceType: 'phone',
///   pairedAt: DateTime.now().millisecondsSinceEpoch,
///   lastSeen: DateTime.now().millisecondsSinceEpoch,
/// );
/// ```
#[flutter_rust_bridge::frb(sync)]
pub fn add_trusted_device(
    peer_id: String,
    device_name: String,
    device_type: String,
    paired_at: i64,
    last_seen: i64,
) -> Result<(), String> {
    let global = TRUST_STORE.lock().map_err(|e| format!("锁定失败: {e}"))?;
    let store = global
        .as_ref()
        .ok_or_else(|| "信任列表存储未初始化".to_string())?;

    let manager = TrustListManager::new(&store.conn);
    let device = TrustedDevice {
        peer_id,
        device_name,
        device_type,
        paired_at,
        last_seen,
    };

    manager
        .add_device(&device)
        .map_err(|e| format!("添加设备失败: {e}"))?;

    Ok(())
}

/// 移除信任设备
///
/// # 参数
///
/// - `peer_id`: 设备 PeerId
///
/// # 示例
///
/// ```dart
/// await removeTrustedDevice(peerId: '12D3KooW...');
/// ```
#[flutter_rust_bridge::frb(sync)]
pub fn remove_trusted_device(peer_id: String) -> Result<(), String> {
    let global = TRUST_STORE.lock().map_err(|e| format!("锁定失败: {e}"))?;
    let store = global
        .as_ref()
        .ok_or_else(|| "信任列表存储未初始化".to_string())?;

    let manager = TrustListManager::new(&store.conn);
    manager
        .remove_device(&peer_id)
        .map_err(|e| format!("移除设备失败: {e}"))?;

    Ok(())
}

/// 查询所有信任设备
///
/// 按最后在线时间倒序排列。
///
/// # 返回
///
/// 返回信任设备列表的 JSON 字符串
///
/// # 示例
///
/// ```dart
/// final devicesJson = await getAllTrustedDevices();
/// final devices = jsonDecode(devicesJson) as List;
/// ```
#[flutter_rust_bridge::frb(sync)]
pub fn get_all_trusted_devices() -> Result<String, String> {
    let global = TRUST_STORE.lock().map_err(|e| format!("锁定失败: {e}"))?;
    let store = global
        .as_ref()
        .ok_or_else(|| "信任列表存储未初始化".to_string())?;

    let manager = TrustListManager::new(&store.conn);
    let devices = manager
        .get_all_devices()
        .map_err(|e| format!("查询设备失败: {e}"))?;

    let json = serde_json::to_string(&devices).map_err(|e| format!("序列化失败: {e}"))?;
    Ok(json)
}

/// 检查设备是否在信任列表中
///
/// # 参数
///
/// - `peer_id`: 设备 PeerId
///
/// # 示例
///
/// ```dart
/// final isTrusted = await isTrustedDevice(peerId: '12D3KooW...');
/// if (isTrusted) {
///   print('设备已信任');
/// }
/// ```
#[flutter_rust_bridge::frb(sync)]
pub fn is_trusted_device(peer_id: String) -> Result<bool, String> {
    let global = TRUST_STORE.lock().map_err(|e| format!("锁定失败: {e}"))?;
    let store = global
        .as_ref()
        .ok_or_else(|| "信任列表存储未初始化".to_string())?;

    let manager = TrustListManager::new(&store.conn);
    manager
        .is_trusted(&peer_id)
        .map_err(|e| format!("查询失败: {e}"))
}

/// 获取单个信任设备信息
///
/// # 参数
///
/// - `peer_id`: 设备 PeerId
///
/// # 返回
///
/// 返回设备信息的 JSON 字符串
///
/// # 示例
///
/// ```dart
/// final deviceJson = await getTrustedDevice(peerId: '12D3KooW...');
/// final device = jsonDecode(deviceJson);
/// ```
#[flutter_rust_bridge::frb(sync)]
pub fn get_trusted_device(peer_id: String) -> Result<String, String> {
    let global = TRUST_STORE.lock().map_err(|e| format!("锁定失败: {e}"))?;
    let store = global
        .as_ref()
        .ok_or_else(|| "信任列表存储未初始化".to_string())?;

    let manager = TrustListManager::new(&store.conn);
    let device = manager
        .get_device(&peer_id)
        .map_err(|e| format!("查询设备失败: {e}"))?;

    let json = serde_json::to_string(&device).map_err(|e| format!("序列化失败: {e}"))?;
    Ok(json)
}

/// 更新设备最后在线时间
///
/// # 参数
///
/// - `peer_id`: 设备 PeerId
/// - `last_seen`: 最后在线时间（Unix 毫秒时间戳）
///
/// # 示例
///
/// ```dart
/// await updateDeviceLastSeen(
///   peerId: '12D3KooW...',
///   lastSeen: DateTime.now().millisecondsSinceEpoch,
/// );
/// ```
#[flutter_rust_bridge::frb(sync)]
pub fn update_device_last_seen(peer_id: String, last_seen: i64) -> Result<(), String> {
    let global = TRUST_STORE.lock().map_err(|e| format!("锁定失败: {e}"))?;
    let store = global
        .as_ref()
        .ok_or_else(|| "信任列表存储未初始化".to_string())?;

    let manager = TrustListManager::new(&store.conn);
    manager
        .update_last_seen(&peer_id, last_seen)
        .map_err(|e| format!("更新失败: {e}"))?;

    Ok(())
}

/// 获取信任设备数量
///
/// # 示例
///
/// ```dart
/// final count = await getTrustedDeviceCount();
/// print('已配对 $count 个设备');
/// ```
#[flutter_rust_bridge::frb(sync)]
#[allow(clippy::cast_possible_truncation, clippy::cast_possible_wrap)]
pub fn get_trusted_device_count() -> Result<i32, String> {
    let global = TRUST_STORE.lock().map_err(|e| format!("锁定失败: {e}"))?;
    let store = global
        .as_ref()
        .ok_or_else(|| "信任列表存储未初始化".to_string())?;

    let manager = TrustListManager::new(&store.conn);
    let count = manager.count().map_err(|e| format!("查询失败: {e}"))?;

    Ok(count as i32)
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn it_should_init_and_add_device() {
        let temp_dir = TempDir::new().unwrap();
        let db_path = temp_dir.path().join("test.db");
        let db_path_str = db_path.to_string_lossy().to_string();

        init_trust_list_store(db_path_str).unwrap();

        add_trusted_device(
            "peer1".to_string(),
            "Device 1".to_string(),
            "laptop".to_string(),
            1000,
            2000,
        )
        .unwrap();

        assert!(is_trusted_device("peer1".to_string()).unwrap());
    }

    #[test]
    fn it_should_get_all_devices() {
        let temp_dir = TempDir::new().unwrap();
        let db_path = temp_dir.path().join("test.db");
        let db_path_str = db_path.to_string_lossy().to_string();

        init_trust_list_store(db_path_str).unwrap();

        add_trusted_device(
            "peer1".to_string(),
            "Device 1".to_string(),
            "laptop".to_string(),
            1000,
            2000,
        )
        .unwrap();

        add_trusted_device(
            "peer2".to_string(),
            "Device 2".to_string(),
            "phone".to_string(),
            1500,
            3000,
        )
        .unwrap();

        let json = get_all_trusted_devices().unwrap();
        let devices: Vec<TrustedDevice> = serde_json::from_str(&json).unwrap();
        assert_eq!(devices.len(), 2);
    }

    #[test]
    fn it_should_remove_device() {
        let temp_dir = TempDir::new().unwrap();
        let db_path = temp_dir.path().join("test.db");
        let db_path_str = db_path.to_string_lossy().to_string();

        init_trust_list_store(db_path_str).unwrap();

        add_trusted_device(
            "peer1".to_string(),
            "Device 1".to_string(),
            "laptop".to_string(),
            1000,
            2000,
        )
        .unwrap();

        assert!(is_trusted_device("peer1".to_string()).unwrap());

        remove_trusted_device("peer1".to_string()).unwrap();

        assert!(!is_trusted_device("peer1".to_string()).unwrap());
    }

    #[test]
    fn it_should_update_last_seen() {
        let temp_dir = TempDir::new().unwrap();
        let db_path = temp_dir.path().join("test.db");
        let db_path_str = db_path.to_string_lossy().to_string();

        init_trust_list_store(db_path_str).unwrap();

        add_trusted_device(
            "peer1".to_string(),
            "Device 1".to_string(),
            "laptop".to_string(),
            1000,
            2000,
        )
        .unwrap();

        update_device_last_seen("peer1".to_string(), 5000).unwrap();

        let json = get_trusted_device("peer1".to_string()).unwrap();
        let device: TrustedDevice = serde_json::from_str(&json).unwrap();
        assert_eq!(device.last_seen, 5000);
    }

    #[test]
    fn it_should_get_count() {
        let temp_dir = TempDir::new().unwrap();
        let db_path = temp_dir.path().join("test.db");
        let db_path_str = db_path.to_string_lossy().to_string();

        init_trust_list_store(db_path_str).unwrap();

        assert_eq!(get_trusted_device_count().unwrap(), 0);

        add_trusted_device(
            "peer1".to_string(),
            "Device 1".to_string(),
            "laptop".to_string(),
            1000,
            2000,
        )
        .unwrap();

        assert_eq!(get_trusted_device_count().unwrap(), 1);
    }
}
