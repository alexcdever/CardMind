//! Pool API functions for Flutter
//!
//! This module contains all flutter_rust_bridge-exposed functions
//! for data pool operations.

use crate::models::error::Result;
use crate::models::pool::Pool;
use crate::security::password::{hash_secretkey, verify_secretkey_hash};
use crate::store::pool_store::PoolStore;
use std::cell::RefCell;

thread_local! {
    /// Thread-local `PoolStore` instance
    /// SQLite connections are not thread-safe, so we use thread_local storage
    static POOL_STORE: RefCell<Option<PoolStore>> = const { RefCell::new(None) };
}

/// Initialize the PoolStore with the given storage path
///
/// Must be called before any other pool API functions.
/// Note: Must be called from the same thread that will use the pool API functions.
///
/// # Arguments
///
/// * `path` - Storage root directory path
///
/// # Example (Dart)
///
/// ```dart
/// await initPoolStore(path: '/path/to/storage');
/// ```
#[flutter_rust_bridge::frb]
pub fn init_pool_store(path: String) -> Result<()> {
    let store = PoolStore::new(&path)?;
    POOL_STORE.with(|s| {
        *s.borrow_mut() = Some(store);
    });
    Ok(())
}

/// Execute a function with access to the `PoolStore` (internal helper)
fn with_pool_store<F, R>(f: F) -> Result<R>
where
    F: FnOnce(&mut PoolStore) -> Result<R>,
{
    POOL_STORE.with(|s| {
        let mut store_ref = s.borrow_mut();
        let store = store_ref.as_mut().ok_or_else(|| {
            crate::models::error::CardMindError::DatabaseError(
                "PoolStore not initialized. Call init_pool_store first.".to_string(),
            )
        })?;
        f(store)
    })
}

// ==================== Pool CRUD APIs ====================

/// Create a new data pool
///
/// # Arguments
///
/// * `name` - Pool name (max 128 characters)
/// * `secretkey` - Pool secretkey (plaintext)
///
/// # Returns
///
/// The created Pool
///
/// # Example (Dart)
///
/// ```dart
/// final pool = await createPool(name: '工作笔记', secretkey: 'mysecretkey');
/// ```
#[flutter_rust_bridge::frb]
pub fn create_pool(name: String, secretkey: String) -> Result<Pool> {
    use crate::models::pool::Pool as PoolModel;
    use crate::utils::uuid_v7::generate_uuid_v7;

    // Create pool object
    let pool_id = generate_uuid_v7();
    let pool = PoolModel::new(&pool_id, &name, &secretkey);

    // Store it
    with_pool_store(|store| {
        store.create_pool(&pool)?;
        Ok(pool)
    })
}

/// Get all pools
///
/// # Returns
///
/// List of all pools, ordered by creation time (newest first)
///
/// # Example (Dart)
///
/// ```dart
/// final pools = await getAllPools();
/// ```
#[flutter_rust_bridge::frb]
pub fn get_all_pools() -> Result<Vec<Pool>> {
    with_pool_store(|store| store.get_all_pools())
}

/// Get a pool by ID
///
/// # Arguments
///
/// * `pool_id` - Pool ID
///
/// # Returns
///
/// The pool if found
///
/// # Errors
///
/// Returns error if the pool doesn't exist
///
/// # Example (Dart)
///
/// ```dart
/// final pool = await getPoolById(poolId: poolId);
/// ```
#[flutter_rust_bridge::frb]
pub fn get_pool_by_id(pool_id: String) -> Result<Pool> {
    with_pool_store(|store| store.get_pool_by_id(&pool_id))
}

/// Update a pool's name
///
/// # Arguments
///
/// * `pool_id` - Pool ID
/// * `name` - New name (max 128 characters)
///
/// # Example (Dart)
///
/// ```dart
/// await updatePool(poolId: poolId, name: 'New Name');
/// ```
#[flutter_rust_bridge::frb]
pub fn update_pool(pool_id: String, name: String) -> Result<()> {
    with_pool_store(|store| {
        let mut pool = store.get_pool_by_id(&pool_id)?;
        pool.name = name;
        pool.updated_at = chrono::Utc::now().timestamp_millis();
        store.update_pool(&pool)
    })
}

/// Delete a pool (soft delete)
///
/// # Arguments
///
/// * `pool_id` - Pool ID
///
/// # Example (Dart)
///
/// ```dart
/// await deletePool(poolId: poolId);
/// ```
#[flutter_rust_bridge::frb]
pub fn delete_pool(pool_id: String) -> Result<()> {
    with_pool_store(|store| store.delete_pool(&pool_id))
}

// ==================== Pool Member Management APIs ====================

/// Add a member to a pool
///
/// # Arguments
///
/// * `pool_id` - Pool ID
/// * `peer_id` - libp2p PeerId
/// * `device_os` - Device OS
///
/// # Example (Dart)
///
/// ```dart
/// await addPoolMember(poolId: poolId, peerId: peerId, deviceOs: 'macOS');
/// ```
#[flutter_rust_bridge::frb]
pub fn add_pool_member(pool_id: String, peer_id: String, device_os: String) -> Result<()> {
    use crate::models::pool::Device;

    let device = Device::new(&peer_id, &device_os);
    with_pool_store(|store| store.add_member(&pool_id, device))
}

/// Remove a member from a pool
///
/// # Arguments
///
/// * `pool_id` - Pool ID
/// * `peer_id` - PeerId to remove
///
/// # Example (Dart)
///
/// ```dart
/// await removePoolMember(poolId: poolId, peerId: peerId);
/// ```
#[flutter_rust_bridge::frb]
pub fn remove_pool_member(pool_id: String, peer_id: String) -> Result<()> {
    with_pool_store(|store| store.remove_member(&pool_id, &peer_id))
}

/// Update a member's nickname in a pool
///
/// # Arguments
///
/// * `pool_id` - Pool ID
/// * `peer_id` - PeerId
/// * `new_name` - New nickname
///
/// # Example (Dart)
///
/// ```dart
/// await updateMemberName(poolId: poolId, peerId: peerId, newName: '工作手机');
/// ```
#[flutter_rust_bridge::frb]
pub fn update_member_name(pool_id: String, peer_id: String, new_name: String) -> Result<()> {
    with_pool_store(|store| store.update_member_name(&pool_id, &peer_id, &new_name))
}

// ==================== Pool Secretkey APIs ====================

/// Verify a pool secretkey hash
///
/// Used when joining an existing pool.
///
/// # Arguments
///
/// * `pool_id` - Pool ID
/// * `secretkey_hash` - secretkey hash to verify
///
/// # Returns
///
/// true if hash matches, false otherwise
///
/// # Example (Dart)
///
/// ```dart
/// final isValid = await verifyPoolSecretkeyHash(poolId: poolId, secretkeyHash: hash);
/// ```
#[flutter_rust_bridge::frb]
pub fn verify_pool_secretkey_hash(pool_id: String, secretkey_hash: String) -> Result<bool> {
    with_pool_store(|store| {
        let pool = store.get_pool_by_id(&pool_id)?;
        Ok(verify_secretkey_hash(&pool.secretkey, &secretkey_hash)?)
    })
}

/// Hash pool secretkey (SHA-256 hex)
///
/// # Arguments
///
/// * `secretkey` - Pool secretkey
///
/// # Example (Dart)
///
/// ```dart
/// final hash = await hashPoolSecretkey(secretkey: 'mysecretkey');
/// ```
#[flutter_rust_bridge::frb]
pub fn hash_pool_secretkey(secretkey: String) -> Result<String> {
    Ok(hash_secretkey(&secretkey)?)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serial_test::serial;
    use tempfile::tempdir;

    /// Clean up thread-local storage after test
    fn cleanup_pool_store() {
        POOL_STORE.with(|s| {
            *s.borrow_mut() = None;
        });
    }

    #[test]
    #[serial]
    fn it_should_init_pool_store() {
        let dir = tempdir().expect("Failed to create temp directory");
        let path = dir
            .path()
            .to_str()
            .expect("Failed to convert path to string")
            .to_string();

        let result = init_pool_store(path);
        assert!(result.is_ok());

        cleanup_pool_store();
    }

    #[test]
    #[serial]
    fn it_should_create_and_get_pool_api() {
        let dir = tempdir().expect("Failed to create temp directory");
        let path = dir
            .path()
            .to_str()
            .expect("Failed to convert path to string")
            .to_string();

        init_pool_store(path).expect("Failed to initialize pool store");

        // Create pool
        let pool = create_pool("Test Pool".to_string(), "secretkey123".to_string())
            .expect("Failed to create pool");
        assert_eq!(pool.name, "Test Pool");

        // Get pool by ID
        let retrieved = get_pool_by_id(pool.pool_id.clone()).expect("Failed to get pool by ID");
        assert_eq!(retrieved.pool_id, pool.pool_id);
        assert_eq!(retrieved.name, "Test Pool");

        // Get all pools
        let all_pools = get_all_pools().expect("Failed to get all pools");
        assert_eq!(all_pools.len(), 1);

        cleanup_pool_store();
    }

    #[test]
    #[serial]
    fn it_should_update_pool_api() {
        let dir = tempdir().expect("Failed to create temp directory");
        let path = dir
            .path()
            .to_str()
            .expect("Failed to convert path to string")
            .to_string();

        init_pool_store(path).expect("Failed to initialize pool store");

        let pool = create_pool("Original".to_string(), "secretkey123".to_string())
            .expect("Failed to create pool");

        update_pool(pool.pool_id.clone(), "Updated".to_string()).expect("Failed to update pool");

        let updated = get_pool_by_id(pool.pool_id).expect("Failed to get pool by ID");
        assert_eq!(updated.name, "Updated");

        cleanup_pool_store();
    }

    #[test]
    #[serial]
    fn it_should_delete_pool_api() {
        let dir = tempdir().expect("Failed to create temp directory");
        let path = dir
            .path()
            .to_str()
            .expect("Failed to convert path to string")
            .to_string();

        init_pool_store(path).expect("Failed to initialize pool store");

        let pool = create_pool("To Delete".to_string(), "secretkey123".to_string())
            .expect("Failed to create pool");

        delete_pool(pool.pool_id.clone()).expect("Failed to delete pool");

        // Pool should not be found after deletion (soft delete means it's still in DB but marked)
        let result = get_pool_by_id(pool.pool_id);
        assert!(result.is_err());

        cleanup_pool_store();
    }

    #[test]
    #[serial]
    fn it_should_member_management_api() {
        let dir = tempdir().expect("Failed to create temp directory");
        let path = dir
            .path()
            .to_str()
            .expect("Failed to convert path to string")
            .to_string();

        init_pool_store(path).expect("Failed to initialize pool store");

        let pool = create_pool("Test Pool".to_string(), "secretkey123".to_string())
            .expect("Failed to create pool");

        // Add member
        add_pool_member(
            pool.pool_id.clone(),
            "12D3KooWDevice001".to_string(),
            "macOS".to_string(),
        )
        .expect("Failed to add pool member");

        let updated = get_pool_by_id(pool.pool_id.clone()).expect("Failed to get pool by ID");
        assert_eq!(updated.members.len(), 1);
        assert_eq!(updated.members[0].peer_id, "12D3KooWDevice001");

        // Update member name
        update_member_name(
            pool.pool_id.clone(),
            "12D3KooWDevice001".to_string(),
            "Work Phone".to_string(),
        )
        .expect("Failed to update member name");

        let updated = get_pool_by_id(pool.pool_id.clone()).expect("Failed to get pool by ID");
        assert_eq!(updated.members[0].nickname, "Work Phone");

        // Remove member
        remove_pool_member(pool.pool_id.clone(), "12D3KooWDevice001".to_string())
            .expect("Failed to remove pool member");

        let updated = get_pool_by_id(pool.pool_id).unwrap();
        assert_eq!(updated.members.len(), 0);

        cleanup_pool_store();
    }

    #[test]
    #[serial]
    fn it_should_verify_secretkey_hash_api() {
        let dir = tempdir().unwrap();
        let path = dir.path().to_str().unwrap().to_string();

        init_pool_store(path).unwrap();

        let secretkey = "mysecretkey123";
        let pool = create_pool("Test Pool".to_string(), secretkey.to_string()).unwrap();
        let hash = hash_pool_secretkey(secretkey.to_string()).unwrap();

        // Correct hash
        let valid = verify_pool_secretkey_hash(pool.pool_id.clone(), hash.clone()).unwrap();
        assert!(valid);

        // Wrong hash
        let invalid = verify_pool_secretkey_hash(pool.pool_id, "wronghash".to_string()).unwrap();
        assert!(!invalid);

        cleanup_pool_store();
    }
}
