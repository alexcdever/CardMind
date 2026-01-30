//! 设备身份 API
//!
//! 提供设备身份管理的 FFI 接口，包括 `PeerId` 获取和密钥对管理。

use crate::p2p::identity::IdentityManager;
use std::path::PathBuf;
use std::sync::Mutex;

/// 全局身份管理器实例
static IDENTITY_MANAGER: Mutex<Option<IdentityManager>> = Mutex::new(None);

/// 初始化身份管理器
///
/// # 参数
///
/// - `base_path`: 应用数据目录路径
///
/// # 示例
///
/// ```dart
/// await initIdentityManager(basePath: '/path/to/app/data');
/// ```
#[flutter_rust_bridge::frb(sync)]
pub fn init_identity_manager(base_path: String) -> Result<(), String> {
    let path = PathBuf::from(base_path);
    let manager = IdentityManager::new(&path);

    let mut global = IDENTITY_MANAGER
        .lock()
        .map_err(|e| format!("锁定失败: {e}"))?;
    *global = Some(manager);

    Ok(())
}

/// 获取设备的 PeerId
///
/// 如果密钥对不存在，会自动生成并保存。
///
/// # 返回
///
/// 返回 PeerId 的字符串表示（例如：`12D3KooW...`）
///
/// # Errors
///
/// - 身份管理器未初始化
/// - 密钥对加载或生成失败
///
/// # 示例
///
/// ```dart
/// final peerId = await getPeerId();
/// print('Device Peer ID: $peerId');
/// ```
#[flutter_rust_bridge::frb(sync)]
pub fn get_peer_id() -> Result<String, String> {
    let global = IDENTITY_MANAGER
        .lock()
        .map_err(|e| format!("锁定失败: {e}"))?;

    let manager = global
        .as_ref()
        .ok_or_else(|| "身份管理器未初始化，请先调用 init_identity_manager".to_string())?;

    let peer_id = manager
        .get_peer_id()
        .map_err(|e| format!("获取 PeerId 失败: {e}"))?;

    Ok(peer_id.to_string())
}

/// 检查密钥对文件是否存在
///
/// # 返回
///
/// 如果密钥对文件存在返回 `true`，否则返回 `false`
///
/// # Errors
///
/// - 身份管理器未初始化
///
/// # 示例
///
/// ```dart
/// final exists = await keypairExists();
/// if (!exists) {
///   print('首次启动，将生成新密钥对');
/// }
/// ```
#[flutter_rust_bridge::frb(sync)]
pub fn keypair_exists() -> Result<bool, String> {
    let global = IDENTITY_MANAGER
        .lock()
        .map_err(|e| format!("锁定失败: {e}"))?;

    let manager = global
        .as_ref()
        .ok_or_else(|| "身份管理器未初始化，请先调用 init_identity_manager".to_string())?;

    Ok(manager.keypair_exists())
}

/// 删除密钥对文件
///
/// **警告**: 此操作不可逆，删除后设备将获得新的 PeerId，
/// 需要重新配对所有设备。
///
/// # Errors
///
/// - 身份管理器未初始化
/// - 文件删除失败
///
/// # 示例
///
/// ```dart
/// await deleteKeypair();
/// print('密钥对已删除，下次启动将生成新 PeerId');
/// ```
#[flutter_rust_bridge::frb(sync)]
pub fn delete_keypair() -> Result<(), String> {
    let global = IDENTITY_MANAGER
        .lock()
        .map_err(|e| format!("锁定失败: {e}"))?;

    let manager = global
        .as_ref()
        .ok_or_else(|| "身份管理器未初始化，请先调用 init_identity_manager".to_string())?;

    manager
        .delete_keypair()
        .map_err(|e| format!("删除密钥对失败: {e}"))?;

    Ok(())
}

/// 获取密钥对文件路径
///
/// # 返回
///
/// 返回密钥对文件的完整路径
///
/// # Errors
///
/// - 身份管理器未初始化
///
/// # 示例
///
/// ```dart
/// final path = await getKeypairPath();
/// print('密钥对存储路径: $path');
/// ```
#[flutter_rust_bridge::frb(sync)]
pub fn get_keypair_path() -> Result<String, String> {
    let global = IDENTITY_MANAGER
        .lock()
        .map_err(|e| format!("锁定失败: {e}"))?;

    let manager = global
        .as_ref()
        .ok_or_else(|| "身份管理器未初始化，请先调用 init_identity_manager".to_string())?;

    Ok(manager.keypair_path().to_string_lossy().to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_init_and_get_peer_id() {
        let temp_dir = TempDir::new().unwrap();
        let base_path = temp_dir.path().to_string_lossy().to_string();

        // 初始化
        init_identity_manager(base_path).unwrap();

        // 获取 PeerId
        let peer_id = get_peer_id().unwrap();
        assert!(!peer_id.is_empty());
        assert!(peer_id.starts_with("12D3KooW"));

        // 再次获取应该返回相同的 PeerId
        let peer_id2 = get_peer_id().unwrap();
        assert_eq!(peer_id, peer_id2);
    }

    #[test]
    fn test_keypair_exists() {
        let temp_dir = TempDir::new().unwrap();
        let base_path = temp_dir.path().to_string_lossy().to_string();

        init_identity_manager(base_path).unwrap();

        // 初始状态应该不存在
        assert!(!keypair_exists().unwrap());

        // 生成密钥对后应该存在
        get_peer_id().unwrap();
        assert!(keypair_exists().unwrap());
    }

    #[test]
    fn test_delete_keypair() {
        let temp_dir = TempDir::new().unwrap();
        let base_path = temp_dir.path().to_string_lossy().to_string();

        init_identity_manager(base_path).unwrap();

        // 生成密钥对
        let peer_id1 = get_peer_id().unwrap();
        assert!(keypair_exists().unwrap());

        // 删除密钥对
        delete_keypair().unwrap();
        assert!(!keypair_exists().unwrap());

        // 重新生成应该得到不同的 PeerId
        let peer_id2 = get_peer_id().unwrap();
        assert_ne!(peer_id1, peer_id2);
    }

    #[test]
    fn test_get_keypair_path() {
        let temp_dir = TempDir::new().unwrap();
        let base_path = temp_dir.path().to_string_lossy().to_string();

        init_identity_manager(base_path).unwrap();

        let path = get_keypair_path().unwrap();
        assert!(path.contains("identity"));
        assert!(path.contains("keypair.bin"));
    }
}
