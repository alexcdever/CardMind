//! Device Configuration API functions for Flutter
//!
//! This module contains all flutter_rust_bridge-exposed functions
//! for device configuration management.

use crate::models::device_config::DeviceConfig;
use crate::models::error::CardMindError;
use crate::models::error::Result;
use std::cell::RefCell;
use std::path::PathBuf;

thread_local! {
    /// Thread-local `DeviceConfig` instance
    static DEVICE_CONFIG: RefCell<Option<DeviceConfig>> = const { RefCell::new(None) };
    static CONFIG_PATH: RefCell<Option<PathBuf>> = const { RefCell::new(None) };
}

/// Initialize or load device configuration
///
/// If a config file exists at the path, it will be loaded.
/// Otherwise, a new config will be created with default values.
///
/// # Arguments
///
/// * `base_path` - Storage root directory path
///
/// # Example (Dart)
///
/// ```dart
/// await initDeviceConfig(basePath: '/path/to/storage');
/// ```
#[flutter_rust_bridge::frb]
pub fn init_device_config(base_path: String) -> Result<DeviceConfig> {
    let base_path_buf = PathBuf::from(base_path);
    let config_path = DeviceConfig::default_path(&base_path_buf);

    let config = DeviceConfig::get_or_create(&config_path)?;

    // Store in thread-local
    DEVICE_CONFIG.with(|c| {
        *c.borrow_mut() = Some(config.clone());
    });

    CONFIG_PATH.with(|p| {
        *p.borrow_mut() = Some(config_path);
    });

    Ok(config)
}

/// Execute a function with access to the `DeviceConfig` (internal helper)
fn with_device_config<F, R>(f: F) -> Result<R>
where
    F: FnOnce(&mut DeviceConfig) -> Result<R>,
{
    DEVICE_CONFIG.with(|c| {
        let mut config_ref = c.borrow_mut();
        let config = config_ref.as_mut().ok_or_else(|| {
            crate::models::error::CardMindError::DatabaseError(
                "DeviceConfig not initialized. Call init_device_config first.".to_string(),
            )
        })?;
        f(config)
    })
}

/// Save the current device configuration to disk
fn save_config() -> Result<()> {
    CONFIG_PATH.with(|p| {
        let path_ref = p.borrow();
        let path = path_ref.as_ref().ok_or_else(|| {
            crate::models::error::CardMindError::DatabaseError(
                "Config path not initialized".to_string(),
            )
        })?;

        DEVICE_CONFIG.with(|c| {
            let config_ref = c.borrow();
            let config = config_ref.as_ref().ok_or_else(|| {
                crate::models::error::CardMindError::DatabaseError(
                    "DeviceConfig not initialized".to_string(),
                )
            })?;

            config.save(path).map_err(|e| {
                crate::models::error::CardMindError::DatabaseError(format!(
                    "Failed to save config: {e}"
                ))
            })
        })
    })
}

// ==================== Device Config APIs ====================

/// Get the current device configuration
///
/// # Returns
///
/// The current device configuration
///
/// # Example (Dart)
///
/// ```dart
/// final config = await getDeviceConfig();
/// print('Peer ID: ${config.peerId}');
/// ```
#[flutter_rust_bridge::frb]
pub fn get_device_config() -> Result<DeviceConfig> {
    with_device_config(|config| Ok(config.clone()))
}

/// Join a data pool
///
/// Adds the pool ID to the joined_pools list.
///
/// # Arguments
///
/// * `pool_id` - Pool ID to join
///
/// # Example (Dart)
///
/// ```dart
/// await joinPool(poolId: poolId);
/// ```
#[flutter_rust_bridge::frb]
pub fn join_pool(pool_id: String) -> Result<()> {
    with_device_config(|config| {
        config
            .join_pool(&pool_id)
            .map_err(|e| CardMindError::DatabaseError(e.to_string()))?;
        Ok(())
    })?;
    save_config()?;
    Ok(())
}

/// Leave a data pool
///
/// Removes the pool ID from joined_pools and resident_pools.
///
/// # Arguments
///
/// * `pool_id` - Pool ID to leave
///
/// # Returns
///
/// true if the pool was found and removed, false otherwise
///
/// # Example (Dart)
///
/// ```dart
/// final left = await leavePool(poolId: poolId);
/// ```
#[flutter_rust_bridge::frb]
pub fn leave_pool(pool_id: String) -> Result<()> {
    with_device_config(|config| {
        config
            .leave_pool(&pool_id)
            .map_err(|e| CardMindError::DatabaseError(e.to_string()))
    })?;
    save_config()?;
    Ok(())
}

/// Set or unset a pool as resident
///
/// Resident pools are pools that new cards automatically bind to.
///
/// # Arguments
///
/// * `pool_id` - Pool ID
/// * `is_resident` - true to set as resident, false to unset
///
/// # Example (Dart)
///
/// ```dart
/// await setResidentPool(poolId: poolId, isResident: true);
/// ```
#[flutter_rust_bridge::frb]
pub fn set_resident_pool(_pool_id: String, _is_resident: bool) -> Result<()> {
    Err(CardMindError::NotAuthorized(
        "单池模型下不支持此操作".to_string(),
    ))
}

/// Get list of joined pool IDs
///
/// # Returns
///
/// List of pool IDs the device has joined
///
/// # Example (Dart)
///
/// ```dart
/// final joinedPools = await getJoinedPools();
/// ```
#[flutter_rust_bridge::frb]
pub fn get_joined_pools() -> Result<Vec<String>> {
    with_device_config(|config| {
        Ok(config
            .get_pool_id()
            .map(|id| vec![id.to_string()])
            .unwrap_or_default())
    })
}

/// Get list of resident pool IDs
///
/// # Returns
///
/// List of pool IDs marked as resident
///
/// # Example (Dart)
///
/// ```dart
/// final residentPools = await getResidentPools();
/// ```
#[flutter_rust_bridge::frb]
pub fn get_resident_pools() -> Result<Vec<String>> {
    with_device_config(|config| {
        Ok(config
            .get_pool_id()
            .map(|id| vec![id.to_string()])
            .unwrap_or_default())
    })
}

/// Check if the device has joined a pool
///
/// # Arguments
///
/// * `pool_id` - Pool ID to check
///
/// # Returns
///
/// true if joined, false otherwise
///
/// # Example (Dart)
///
/// ```dart
/// final hasJoined = await isPoolJoined(poolId: poolId);
/// ```
#[flutter_rust_bridge::frb]
pub fn is_pool_joined(pool_id: String) -> Result<bool> {
    with_device_config(|config| Ok(config.is_joined(&pool_id)))
}

/// Check if a pool is marked as resident
///
/// # Arguments
///
/// * `pool_id` - Pool ID to check
///
/// # Returns
///
/// true if resident, false otherwise
///
/// # Example (Dart)
///
/// ```dart
/// final isResident = await isPoolResident(poolId: poolId);
/// ```
#[flutter_rust_bridge::frb]
pub fn is_pool_resident(pool_id: String) -> Result<bool> {
    with_device_config(|config| Ok(config.is_joined(&pool_id)))
}

#[cfg(test)]
mod tests {
    use super::*;
    use serial_test::serial;
    use tempfile::tempdir;

    /// Clean up thread-local storage after test
    fn cleanup_device_config() {
        DEVICE_CONFIG.with(|c| {
            *c.borrow_mut() = None;
        });
        CONFIG_PATH.with(|p| {
            *p.borrow_mut() = None;
        });
    }

    #[test]
    #[serial]
    fn test_init_device_config() {
        let dir = tempdir().unwrap();
        let path = dir.path().to_str().unwrap().to_string();

        let config = init_device_config(path).unwrap();
        assert!(config.peer_id.is_none());
        assert!(!config.device_name.is_empty());
        assert!(config.pool_id.is_none());

        cleanup_device_config();
    }

    #[test]
    #[serial]
    fn test_join_and_leave_pool_api() {
        let dir = tempdir().unwrap();
        let path = dir.path().to_str().unwrap().to_string();

        init_device_config(path).unwrap();

        // Join pool
        join_pool("pool-001".to_string()).unwrap();

        let joined = get_joined_pools().unwrap();
        assert_eq!(joined.len(), 1);
        assert_eq!(joined[0], "pool-001");

        // Check if joined
        let is_joined = is_pool_joined("pool-001".to_string()).unwrap();
        assert!(is_joined);

        // Check if resident (same as joined in single-pool model)
        let is_resident = is_pool_resident("pool-001".to_string()).unwrap();
        assert!(is_resident);

        // Leave pool
        leave_pool("pool-001".to_string()).unwrap();

        let joined = get_joined_pools().unwrap();
        assert_eq!(joined.len(), 0);

        cleanup_device_config();
    }

    #[test]
    #[serial]
    fn test_resident_pool_api() {
        let dir = tempdir().unwrap();
        let path = dir.path().to_str().unwrap().to_string();

        init_device_config(path).unwrap();

        // Join pool (automatically resident in single-pool model)
        join_pool("pool-001".to_string()).unwrap();

        // Check resident pools (should return joined pool)
        let resident_pools = get_resident_pools().unwrap();
        assert_eq!(resident_pools.len(), 1);
        assert_eq!(resident_pools[0], "pool-001");

        let is_resident = is_pool_resident("pool-001".to_string()).unwrap();
        assert!(is_resident);

        // is_pool_resident for different pool should return false
        let is_resident = is_pool_resident("pool-002".to_string()).unwrap();
        assert!(!is_resident);

        // Leave pool (removes from resident in single-pool model)
        leave_pool("pool-001".to_string()).unwrap();

        let resident_pools = get_resident_pools().unwrap();
        assert_eq!(resident_pools.len(), 0);

        let is_resident = is_pool_resident("pool-001".to_string()).unwrap();
        assert!(!is_resident);

        cleanup_device_config();
    }

    #[test]
    #[serial]
    fn test_persistence() {
        let dir = tempdir().unwrap();
        let path = dir.path().to_str().unwrap().to_string();

        // Initialize and join pool
        init_device_config(path.clone()).unwrap();
        with_device_config(|config| {
            config.peer_id = Some("peer-001".to_string());
            Ok(())
        })
        .unwrap();
        join_pool("pool-001".to_string()).unwrap();

        cleanup_device_config();

        // Reload and check persistence
        let config = init_device_config(path).unwrap();
        assert_eq!(config.peer_id.as_deref(), Some("peer-001"));
        assert!(config.pool_id.is_some());

        cleanup_device_config();
    }
}
