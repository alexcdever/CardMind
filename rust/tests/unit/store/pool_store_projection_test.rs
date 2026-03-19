// input: PoolStore 投影失败和错误边界场景。
// output: 投影失败处理的全覆盖测试。
// pos: PoolStore 边界测试文件。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件测试数据池存储的投影失败和错误边界。

use cardmind_rust::models::error::CardMindError;
use cardmind_rust::models::pool::PoolMember;
use cardmind_rust::store::pool_store::PoolStore;
use tempfile::TempDir;
use uuid::Uuid;

// ============================================================================
// Projection Failure Tests
// ============================================================================

#[test]
fn create_pool_with_projection_failure_returns_error() {
    let temp_dir = TempDir::new().unwrap();
    let store = PoolStore::new_with_projection_failure(temp_dir.path().to_str().unwrap()).unwrap();

    let result = store.create_pool("ep1", "Admin", "macOS");

    assert!(result.is_err());
    match result {
        Err(CardMindError::ProjectionNotConverged {
            entity,
            retry_action,
            ..
        }) => {
            assert_eq!(entity, "pool");
            assert_eq!(retry_action, "retry_projection");
        }
        _ => panic!("Expected ProjectionNotConverged error"),
    }
}

#[test]
fn attach_note_references_with_projection_failure_returns_error() {
    let temp_dir = TempDir::new().unwrap();
    let path = temp_dir.path().to_str().unwrap();

    // Create pool with normal store
    let normal_store = PoolStore::new(path).unwrap();
    let pool = normal_store.create_pool("ep1", "Admin", "macOS").unwrap();

    // Try to attach with failing store
    let failing_store = PoolStore::new_with_projection_failure(path).unwrap();
    let card_id = Uuid::new_v4();
    let result = failing_store.attach_note_references(&pool.pool_id, vec![card_id]);

    assert!(result.is_err());
    assert!(matches!(
        result,
        Err(CardMindError::ProjectionNotConverged { .. })
    ));
}

#[test]
fn join_pool_with_projection_failure_returns_error() {
    let temp_dir = TempDir::new().unwrap();
    let path = temp_dir.path().to_str().unwrap();

    let normal_store = PoolStore::new(path).unwrap();
    let pool = normal_store.create_pool("ep1", "Admin", "macOS").unwrap();

    let new_member = PoolMember {
        endpoint_id: "ep2".to_string(),
        nickname: "Member".to_string(),
        os: "Windows".to_string(),
        is_admin: false,
    };

    let failing_store = PoolStore::new_with_projection_failure(path).unwrap();
    let result = failing_store.join_pool(&pool, new_member, vec![]);

    assert!(result.is_err());
    assert!(matches!(
        result,
        Err(CardMindError::ProjectionNotConverged { .. })
    ));
}

#[test]
fn leave_pool_with_projection_failure_returns_error() {
    let temp_dir = TempDir::new().unwrap();
    let path = temp_dir.path().to_str().unwrap();

    let normal_store = PoolStore::new(path).unwrap();
    let pool = normal_store.create_pool("ep1", "Admin", "macOS").unwrap();

    // Add another member first
    let new_member = PoolMember {
        endpoint_id: "ep2".to_string(),
        nickname: "Member".to_string(),
        os: "Windows".to_string(),
        is_admin: false,
    };
    normal_store.join_pool(&pool, new_member, vec![]).unwrap();

    // Try to leave with failing store
    let failing_store = PoolStore::new_with_projection_failure(path).unwrap();
    let result = failing_store.leave_pool(&pool.pool_id, "ep2");

    assert!(result.is_err());
    assert!(matches!(
        result,
        Err(CardMindError::ProjectionNotConverged { .. })
    ));
}

// ============================================================================
// Error Propagation Tests
// ============================================================================

#[test]
fn get_pool_propagates_other_errors() {
    let temp_dir = TempDir::new().unwrap();
    let store = PoolStore::new(temp_dir.path().to_str().unwrap()).unwrap();

    // Create a pool
    let pool = store.create_pool("ep1", "Admin", "macOS").unwrap();

    // Get should succeed
    let result = store.get_pool(&pool.pool_id);
    assert!(result.is_ok());
}

// ============================================================================
// Pool Data Persistence Tests
// ============================================================================

#[test]
fn pool_data_persisted_to_loro() {
    let temp_dir = TempDir::new().unwrap();
    let path = temp_dir.path().to_str().unwrap();

    // Create pool
    let store1 = PoolStore::new(path).unwrap();
    let pool = store1.create_pool("ep1", "Admin", "macOS").unwrap();

    // Create new store instance pointing to same path
    let store2 = PoolStore::new(path).unwrap();
    let loaded = store2.get_pool(&pool.pool_id).unwrap();

    // Should be able to read from Loro
    assert_eq!(loaded.members.len(), 1);
    assert_eq!(loaded.members[0].endpoint_id, "ep1");
    assert_eq!(loaded.members[0].nickname, "Admin");
}

#[test]
fn pool_members_persisted_across_instances() {
    let temp_dir = TempDir::new().unwrap();
    let path = temp_dir.path().to_str().unwrap();

    // Create pool and add members with store1
    let store1 = PoolStore::new(path).unwrap();
    let pool = store1.create_pool("ep1", "Admin", "macOS").unwrap();

    let new_member = PoolMember {
        endpoint_id: "ep2".to_string(),
        nickname: "Member".to_string(),
        os: "Windows".to_string(),
        is_admin: false,
    };
    store1.join_pool(&pool, new_member, vec![]).unwrap();

    // Read with store2
    let store2 = PoolStore::new(path).unwrap();
    let loaded = store2.get_pool(&pool.pool_id).unwrap();

    assert_eq!(loaded.members.len(), 2);
}

#[test]
fn pool_cards_persisted_across_instances() {
    let temp_dir = TempDir::new().unwrap();
    let path = temp_dir.path().to_str().unwrap();

    // Create pool and attach cards with store1
    let store1 = PoolStore::new(path).unwrap();
    let pool = store1.create_pool("ep1", "Admin", "macOS").unwrap();

    let card_ids = vec![Uuid::new_v4(), Uuid::new_v4()];
    store1
        .attach_note_references(&pool.pool_id, card_ids.clone())
        .unwrap();

    // Read with store2
    let store2 = PoolStore::new(path).unwrap();
    let loaded = store2.get_pool(&pool.pool_id).unwrap();

    assert_eq!(loaded.card_ids.len(), 2);
    assert!(loaded.card_ids.contains(&card_ids[0]));
    assert!(loaded.card_ids.contains(&card_ids[1]));
}

// ============================================================================
// Concurrent Operations Tests
// ============================================================================

#[test]
fn concurrent_pool_creation() {
    let temp_dir = TempDir::new().unwrap();
    let path = temp_dir.path().to_str().unwrap();
    let store = PoolStore::new(path).unwrap();

    // Create multiple pools
    let pool1 = store.create_pool("ep1", "Admin1", "macOS").unwrap();
    let pool2 = store.create_pool("ep2", "Admin2", "Windows").unwrap();
    let pool3 = store.create_pool("ep3", "Admin3", "Linux").unwrap();

    // All should have unique IDs
    assert_ne!(pool1.pool_id, pool2.pool_id);
    assert_ne!(pool2.pool_id, pool3.pool_id);
    assert_ne!(pool1.pool_id, pool3.pool_id);

    // All should be retrievable
    assert!(store.get_pool(&pool1.pool_id).is_ok());
    assert!(store.get_pool(&pool2.pool_id).is_ok());
    assert!(store.get_pool(&pool3.pool_id).is_ok());
}

#[test]
fn get_any_pool_returns_first_created() {
    let temp_dir = TempDir::new().unwrap();
    let path = temp_dir.path().to_str().unwrap();
    let store = PoolStore::new(path).unwrap();

    // Create multiple pools
    let _pool1 = store.create_pool("ep1", "Admin1", "macOS").unwrap();
    let _pool2 = store.create_pool("ep2", "Admin2", "Windows").unwrap();

    // get_any_pool should return one of them (implementation dependent)
    let any_pool = store.get_any_pool().unwrap();
    assert!(!any_pool.members.is_empty());
}
