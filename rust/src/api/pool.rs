//! Pool API functions for Flutter
//!
//! This module contains all flutter_rust_bridge-exposed functions
//! for data pool operations.

use crate::models::error::Result;
use crate::models::pool::Pool;
use crate::security::password::PasswordManager;
use crate::store::pool_store::PoolStore;
use std::cell::RefCell;
use zeroize::Zeroizing;

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
/// * `password` - Pool password (min 8 characters)
///
/// # Returns
///
/// The created Pool
///
/// # Example (Dart)
///
/// ```dart
/// final pool = await createPool(name: '工作笔记', password: 'mypassword123');
/// ```
#[flutter_rust_bridge::frb]
pub fn create_pool(name: String, password: String) -> Result<Pool> {
    use crate::models::pool::Pool as PoolModel;
    use crate::utils::uuid_v7::generate_uuid_v7;

    // Hash password
    let password_zeroizing = Zeroizing::new(password);
    let password_hash = PasswordManager::hash_password(&password_zeroizing)?;

    // Create pool object
    let pool_id = generate_uuid_v7();
    let pool = PoolModel::new(&pool_id, &name, &password_hash);

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
/// * `device_id` - Device ID
/// * `device_name` - Device nickname in this pool
///
/// # Example (Dart)
///
/// ```dart
/// await addPoolMember(poolId: poolId, deviceId: deviceId, deviceName: 'My iPhone');
/// ```
#[flutter_rust_bridge::frb]
pub fn add_pool_member(pool_id: String, device_id: String, device_name: String) -> Result<()> {
    use crate::models::pool::Device;

    let device = Device::new(&device_id, &device_name);
    with_pool_store(|store| store.add_member(&pool_id, device))
}

/// Remove a member from a pool
///
/// # Arguments
///
/// * `pool_id` - Pool ID
/// * `device_id` - Device ID to remove
///
/// # Example (Dart)
///
/// ```dart
/// await removePoolMember(poolId: poolId, deviceId: deviceId);
/// ```
#[flutter_rust_bridge::frb]
pub fn remove_pool_member(pool_id: String, device_id: String) -> Result<()> {
    with_pool_store(|store| store.remove_member(&pool_id, &device_id))
}

/// Update a member's nickname in a pool
///
/// # Arguments
///
/// * `pool_id` - Pool ID
/// * `device_id` - Device ID
/// * `new_name` - New nickname
///
/// # Example (Dart)
///
/// ```dart
/// await updateMemberName(poolId: poolId, deviceId: deviceId, newName: '工作手机');
/// ```
#[flutter_rust_bridge::frb]
pub fn update_member_name(pool_id: String, device_id: String, new_name: String) -> Result<()> {
    with_pool_store(|store| store.update_member_name(&pool_id, &device_id, &new_name))
}

// ==================== Pool Password APIs ====================

/// Verify a pool password
///
/// Used when joining an existing pool.
///
/// # Arguments
///
/// * `pool_id` - Pool ID
/// * `password` - Password to verify
///
/// # Returns
///
/// true if password is correct, false otherwise
///
/// # Example (Dart)
///
/// ```dart
/// final isValid = await verifyPoolPassword(poolId: poolId, password: 'mypassword123');
/// ```
#[flutter_rust_bridge::frb]
pub fn verify_pool_password(pool_id: String, password: String) -> Result<bool> {
    with_pool_store(|store| {
        let pool = store.get_pool_by_id(&pool_id)?;
        let password_zeroizing = Zeroizing::new(password);

        Ok(PasswordManager::verify_password(
            &password_zeroizing,
            &pool.password_hash,
        )?)
    })
}

// ==================== Keyring Password Storage APIs ====================

/// Store pool password in system keyring
///
/// Securely stores the pool password in the operating system's credential storage.
/// This allows the password to be retrieved later without the user re-entering it.
///
/// # Arguments
///
/// * `pool_id` - Pool ID
/// * `password` - Password to store (will be securely stored)
///
/// # Example (Dart)
///
/// ```dart
/// await storePoolPasswordInKeyring(poolId: poolId, password: 'mypassword123');
/// ```
#[flutter_rust_bridge::frb]
pub fn store_pool_password_in_keyring(pool_id: String, password: String) -> Result<()> {
    use crate::security::keyring_store::KeyringStore;

    let keyring = KeyringStore::new();
    let password_zeroizing = Zeroizing::new(password);

    keyring.store_pool_password(&pool_id, &password_zeroizing)?;
    Ok(())
}

/// Get pool password from system keyring
///
/// Retrieves the stored password from the operating system's credential storage.
///
/// # Arguments
///
/// * `pool_id` - Pool ID
///
/// # Returns
///
/// The stored password
///
/// # Errors
///
/// Returns error if password not found in keyring
///
/// # Example (Dart)
///
/// ```dart
/// final password = await getPoolPasswordFromKeyring(poolId: poolId);
/// ```
#[flutter_rust_bridge::frb]
pub fn get_pool_password_from_keyring(pool_id: String) -> Result<String> {
    use crate::security::keyring_store::KeyringStore;

    let keyring = KeyringStore::new();
    let password = keyring.get_pool_password(&pool_id)?;

    Ok(password.to_string())
}

/// Delete pool password from system keyring
///
/// Removes the password from the operating system's credential storage.
/// Should be called when leaving a pool.
///
/// # Arguments
///
/// * `pool_id` - Pool ID
///
/// # Example (Dart)
///
/// ```dart
/// await deletePoolPasswordFromKeyring(poolId: poolId);
/// ```
#[flutter_rust_bridge::frb]
pub fn delete_pool_password_from_keyring(pool_id: String) -> Result<()> {
    use crate::security::keyring_store::KeyringStore;

    let keyring = KeyringStore::new();
    keyring.delete_pool_password(&pool_id)?;

    Ok(())
}

/// Check if pool password exists in keyring
///
/// # Arguments
///
/// * `pool_id` - Pool ID
///
/// # Returns
///
/// true if password is stored in keyring, false otherwise
///
/// # Example (Dart)
///
/// ```dart
/// final hasPassword = await hasPoolPasswordInKeyring(poolId: poolId);
/// ```
#[flutter_rust_bridge::frb]
pub fn has_pool_password_in_keyring(pool_id: String) -> Result<bool> {
    use crate::security::keyring_store::KeyringStore;

    let keyring = KeyringStore::new();
    Ok(keyring.has_pool_password(&pool_id))
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
    fn test_init_pool_store() {
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
    fn test_create_and_get_pool_api() {
        let dir = tempdir().expect("Failed to create temp directory");
        let path = dir
            .path()
            .to_str()
            .expect("Failed to convert path to string")
            .to_string();

        init_pool_store(path).expect("Failed to initialize pool store");

        // Create pool
        let pool = create_pool("Test Pool".to_string(), "password123".to_string())
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
    fn test_update_pool_api() {
        let dir = tempdir().expect("Failed to create temp directory");
        let path = dir
            .path()
            .to_str()
            .expect("Failed to convert path to string")
            .to_string();

        init_pool_store(path).expect("Failed to initialize pool store");

        let pool = create_pool("Original".to_string(), "password123".to_string())
            .expect("Failed to create pool");

        update_pool(pool.pool_id.clone(), "Updated".to_string()).expect("Failed to update pool");

        let updated = get_pool_by_id(pool.pool_id).expect("Failed to get pool by ID");
        assert_eq!(updated.name, "Updated");

        cleanup_pool_store();
    }

    #[test]
    #[serial]
    fn test_delete_pool_api() {
        let dir = tempdir().expect("Failed to create temp directory");
        let path = dir
            .path()
            .to_str()
            .expect("Failed to convert path to string")
            .to_string();

        init_pool_store(path).expect("Failed to initialize pool store");

        let pool = create_pool("To Delete".to_string(), "password123".to_string())
            .expect("Failed to create pool");

        delete_pool(pool.pool_id.clone()).expect("Failed to delete pool");

        // Pool should not be found after deletion (soft delete means it's still in DB but marked)
        let result = get_pool_by_id(pool.pool_id);
        assert!(result.is_err());

        cleanup_pool_store();
    }

    #[test]
    #[serial]
    fn test_member_management_api() {
        let dir = tempdir().expect("Failed to create temp directory");
        let path = dir
            .path()
            .to_str()
            .expect("Failed to convert path to string")
            .to_string();

        init_pool_store(path).expect("Failed to initialize pool store");

        let pool = create_pool("Test Pool".to_string(), "password123".to_string())
            .expect("Failed to create pool");

        // Add member
        add_pool_member(
            pool.pool_id.clone(),
            "device-001".to_string(),
            "My iPhone".to_string(),
        )
        .expect("Failed to add pool member");

        let updated = get_pool_by_id(pool.pool_id.clone()).expect("Failed to get pool by ID");
        assert_eq!(updated.members.len(), 1);
        assert_eq!(updated.members[0].device_id, "device-001");

        // Update member name
        update_member_name(
            pool.pool_id.clone(),
            "device-001".to_string(),
            "Work Phone".to_string(),
        )
        .expect("Failed to update member name");

        let updated = get_pool_by_id(pool.pool_id.clone()).expect("Failed to get pool by ID");
        assert_eq!(updated.members[0].device_name, "Work Phone");

        // Remove member
        remove_pool_member(pool.pool_id.clone(), "device-001".to_string())
            .expect("Failed to remove pool member");

        let updated = get_pool_by_id(pool.pool_id).unwrap();
        assert_eq!(updated.members.len(), 0);

        cleanup_pool_store();
    }

    #[test]
    #[serial]
    fn test_verify_password_api() {
        let dir = tempdir().unwrap();
        let path = dir.path().to_str().unwrap().to_string();

        init_pool_store(path).unwrap();

        let pool = create_pool("Test Pool".to_string(), "mypassword123".to_string()).unwrap();

        // Correct password
        let valid =
            verify_pool_password(pool.pool_id.clone(), "mypassword123".to_string()).unwrap();
        assert!(valid);

        // Wrong password
        let invalid = verify_pool_password(pool.pool_id, "wrongpassword".to_string()).unwrap();
        assert!(!invalid);

        cleanup_pool_store();
    }

    // ==================== Keyring API Tests ====================
    // Note: These tests require system keyring access and are ignored by default

    #[test]
    #[serial]
    #[ignore = "Requires system keyring"]
    fn test_store_and_retrieve_password_from_keyring() {
        let test_pool_id = "test-keyring-pool-001";
        let password = "test_keyring_password_123";

        // Store password
        let result = store_pool_password_in_keyring(test_pool_id.to_string(), password.to_string());
        assert!(result.is_ok(), "Failed to store password: {result:?}");

        // Check if exists
        let has_password = has_pool_password_in_keyring(test_pool_id.to_string()).unwrap();
        assert!(has_password);

        // Retrieve password
        let retrieved = get_pool_password_from_keyring(test_pool_id.to_string());
        assert!(
            retrieved.is_ok(),
            "Failed to retrieve password: {retrieved:?}"
        );
        assert_eq!(retrieved.unwrap(), password);

        // Cleanup
        let _ = delete_pool_password_from_keyring(test_pool_id.to_string());
    }

    #[test]
    #[serial]
    #[ignore = "Requires system keyring"]
    fn test_delete_password_from_keyring() {
        let test_pool_id = "test-keyring-pool-002";

        // Store password first
        store_pool_password_in_keyring(test_pool_id.to_string(), "delete_test".to_string())
            .unwrap();

        // Verify it exists
        let has_password = has_pool_password_in_keyring(test_pool_id.to_string()).unwrap();
        assert!(has_password);

        // Delete password
        let result = delete_pool_password_from_keyring(test_pool_id.to_string());
        assert!(result.is_ok());

        // Verify it's gone
        let has_password = has_pool_password_in_keyring(test_pool_id.to_string()).unwrap();
        assert!(!has_password);
    }

    #[test]
    #[serial]
    #[ignore = "Requires system keyring"]
    fn test_has_pool_password_in_keyring() {
        let test_pool_id = "test-keyring-pool-003";

        // Should not exist initially
        let has_password = has_pool_password_in_keyring(test_pool_id.to_string()).unwrap();
        assert!(!has_password);

        // Store password
        store_pool_password_in_keyring(test_pool_id.to_string(), "exists_test".to_string())
            .unwrap();

        // Should exist now
        let has_password = has_pool_password_in_keyring(test_pool_id.to_string()).unwrap();
        assert!(has_password);

        // Cleanup
        let _ = delete_pool_password_from_keyring(test_pool_id.to_string());
    }

    #[test]
    #[serial]
    #[ignore = "Requires system keyring"]
    fn test_keyring_password_not_found() {
        let result = get_pool_password_from_keyring("nonexistent-pool".to_string());
        assert!(result.is_err());
    }

    #[test]
    #[serial]
    #[ignore = "Requires system keyring"]
    fn test_pool_workflow_with_keyring() {
        let dir = tempdir().unwrap();
        let path = dir.path().to_str().unwrap().to_string();

        init_pool_store(path).unwrap();

        // Create pool
        let password = "workflow_test_password";
        let pool = create_pool("Keyring Test Pool".to_string(), password.to_string()).unwrap();

        // Store password in keyring
        store_pool_password_in_keyring(pool.pool_id.clone(), password.to_string()).unwrap();

        // Retrieve and verify
        let retrieved_password = get_pool_password_from_keyring(pool.pool_id.clone()).unwrap();
        assert_eq!(retrieved_password, password);

        // Verify pool password using keyring password
        let is_valid = verify_pool_password(pool.pool_id.clone(), retrieved_password).unwrap();
        assert!(is_valid);

        // Cleanup
        delete_pool_password_from_keyring(pool.pool_id).unwrap();
        cleanup_pool_store();
    }
}
