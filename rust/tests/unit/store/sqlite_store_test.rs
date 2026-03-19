// input: SqliteStore 边界场景和错误路径。
// output: SQLite 存储边界条件的全覆盖测试。
// pos: SqliteStore 边界测试文件。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件测试 SQLite 存储的错误处理和边界情况。

use cardmind_rust::models::card::Card;
use cardmind_rust::models::error::CardMindError;
use cardmind_rust::models::pool::{Pool, PoolMember};
use cardmind_rust::store::sqlite_store::SqliteStore;
use std::path::Path;
use tempfile::TempDir;
use uuid::Uuid;

fn setup_store() -> (SqliteStore, TempDir) {
    let temp_dir = TempDir::new().unwrap();
    let store = SqliteStore::new(&temp_dir.path().join("test.db")).unwrap();
    (store, temp_dir)
}

// ============================================================================
// is_ready Tests
// ============================================================================

#[test]
fn is_ready_returns_true_after_creation() {
    let (store, _temp) = setup_store();

    assert!(store.is_ready());
}

// ============================================================================
// Projection Failure Tests
// ============================================================================

#[test]
fn record_and_get_projection_failure() {
    let (store, _temp) = setup_store();

    // Record failure
    store
        .record_projection_failure("card", "123", "retry_sync")
        .unwrap();

    // Get action
    let action = store.get_projection_retry_action("card", "123").unwrap();
    assert_eq!(action, Some("retry_sync".to_string()));
}

#[test]
fn get_projection_retry_action_returns_none_when_not_found() {
    let (store, _temp) = setup_store();

    let action = store
        .get_projection_retry_action("card", "nonexistent")
        .unwrap();
    assert_eq!(action, None);
}

#[test]
fn clear_projection_failure_removes_record() {
    let (store, _temp) = setup_store();

    // Record then clear
    store
        .record_projection_failure("card", "123", "retry")
        .unwrap();
    store.clear_projection_failure("card", "123").unwrap();

    // Should be gone
    let action = store.get_projection_retry_action("card", "123").unwrap();
    assert_eq!(action, None);
}

#[test]
fn has_projection_failures_returns_true_when_exists() {
    let (store, _temp) = setup_store();

    // Initially false
    assert!(!store.has_projection_failures().unwrap());

    // Record failure
    store
        .record_projection_failure("card", "123", "retry")
        .unwrap();

    // Now true
    assert!(store.has_projection_failures().unwrap());
}

#[test]
fn has_projection_failures_returns_false_after_clear() {
    let (store, _temp) = setup_store();

    store
        .record_projection_failure("card", "123", "retry")
        .unwrap();
    assert!(store.has_projection_failures().unwrap());

    store.clear_projection_failure("card", "123").unwrap();
    assert!(!store.has_projection_failures().unwrap());
}

// ============================================================================
// Query Cards with Pool Filter Tests
// ============================================================================

#[test]
fn query_cards_with_pool_id_filter() {
    let (store, _temp) = setup_store();

    // Create pool and cards
    let pool_id = Uuid::new_v4();
    let card_id = Uuid::new_v4();

    let pool = Pool {
        pool_id,
        members: vec![],
        card_ids: vec![card_id],
    };
    store.upsert_pool(&pool).unwrap();

    let card = Card {
        id: card_id,
        title: "Test".to_string(),
        content: "Content".to_string(),
        created_at: 1000,
        updated_at: 1000,
        deleted: false,
    };
    store.upsert_card(&card).unwrap();

    // Query with pool_id
    let results = store
        .query_cards("", Some(&pool_id.to_string()), false, 10, 0)
        .unwrap();
    assert_eq!(results.len(), 1);
    assert_eq!(results[0].id, card_id);
}

#[test]
fn query_cards_with_nonexistent_pool_id() {
    let (store, _temp) = setup_store();

    let fake_pool_id = Uuid::new_v4();

    // Query with non-existent pool_id should return empty
    let results = store
        .query_cards("", Some(&fake_pool_id.to_string()), false, 10, 0)
        .unwrap();
    assert!(results.is_empty());
}

#[test]
fn query_cards_with_empty_keyword_and_pool_id() {
    let (store, _temp) = setup_store();

    let pool_id = Uuid::new_v4();
    let card_id = Uuid::new_v4();

    let pool = Pool {
        pool_id,
        members: vec![],
        card_ids: vec![card_id],
    };
    store.upsert_pool(&pool).unwrap();

    let card = Card {
        id: card_id,
        title: "Test".to_string(),
        content: "Content".to_string(),
        created_at: 1000,
        updated_at: 1000,
        deleted: false,
    };
    store.upsert_card(&card).unwrap();

    // Empty keyword with pool_id
    let results = store
        .query_cards("", Some(&pool_id.to_string()), false, 10, 0)
        .unwrap();
    assert_eq!(results.len(), 1);
}

// ============================================================================
// Error Propagation Tests
// ============================================================================

#[test]
fn get_card_not_found_error() {
    let (store, _temp) = setup_store();

    let fake_id = Uuid::new_v4();
    let result = store.get_card(&fake_id);

    assert!(matches!(result, Err(CardMindError::NotFound(_))));
}

#[test]
fn get_pool_not_found_error() {
    let (store, _temp) = setup_store();

    let fake_id = Uuid::new_v4();
    let result = store.get_pool(&fake_id);

    assert!(matches!(result, Err(CardMindError::NotFound(_))));
}

// ============================================================================
// Pool Edge Cases
// ============================================================================

#[test]
fn list_pool_ids_returns_empty_when_no_pools() {
    let (store, _temp) = setup_store();

    let ids = store.list_pool_ids().unwrap();
    assert!(ids.is_empty());
}

#[test]
fn list_pool_ids_returns_all_pools() {
    let (store, _temp) = setup_store();

    let pool1_id = Uuid::new_v4();
    let pool2_id = Uuid::new_v4();

    let pool1 = Pool {
        pool_id: pool1_id,
        members: vec![],
        card_ids: vec![],
    };
    let pool2 = Pool {
        pool_id: pool2_id,
        members: vec![],
        card_ids: vec![],
    };

    store.upsert_pool(&pool1).unwrap();
    store.upsert_pool(&pool2).unwrap();

    let ids = store.list_pool_ids().unwrap();
    assert_eq!(ids.len(), 2);
}

#[test]
fn upsert_pool_replaces_existing() {
    let (store, _temp) = setup_store();

    let pool_id = Uuid::new_v4();

    // Create pool with members
    let pool1 = Pool {
        pool_id,
        members: vec![PoolMember {
            endpoint_id: "ep1".to_string(),
            nickname: "User1".to_string(),
            os: "macOS".to_string(),
            is_admin: true,
        }],
        card_ids: vec![],
    };
    store.upsert_pool(&pool1).unwrap();

    // Replace with different members
    let pool2 = Pool {
        pool_id,
        members: vec![PoolMember {
            endpoint_id: "ep2".to_string(),
            nickname: "User2".to_string(),
            os: "Windows".to_string(),
            is_admin: false,
        }],
        card_ids: vec![],
    };
    store.upsert_pool(&pool2).unwrap();

    // Verify replacement
    let loaded = store.get_pool(&pool_id).unwrap();
    assert_eq!(loaded.members.len(), 1);
    assert_eq!(loaded.members[0].endpoint_id, "ep2");
}

// ============================================================================
// Complex Query Tests
// ============================================================================

#[test]
fn query_cards_with_keyword_and_pool_id() {
    let (store, _temp) = setup_store();

    let pool_id = Uuid::new_v4();
    let card_id = Uuid::new_v4();

    let pool = Pool {
        pool_id,
        members: vec![],
        card_ids: vec![card_id],
    };
    store.upsert_pool(&pool).unwrap();

    let card = Card {
        id: card_id,
        title: "Rust Programming".to_string(),
        content: "Learn Rust".to_string(),
        created_at: 1000,
        updated_at: 1000,
        deleted: false,
    };
    store.upsert_card(&card).unwrap();

    // Query with both keyword and pool_id
    let results = store
        .query_cards("rust", Some(&pool_id.to_string()), false, 10, 0)
        .unwrap();
    assert_eq!(results.len(), 1);

    // Query with non-matching keyword
    let results = store
        .query_cards("python", Some(&pool_id.to_string()), false, 10, 0)
        .unwrap();
    assert!(results.is_empty());
}

#[test]
fn query_cards_with_include_deleted() {
    let (store, _temp) = setup_store();

    let active_card = Card {
        id: Uuid::new_v4(),
        title: "Active".to_string(),
        content: "Content".to_string(),
        created_at: 1000,
        updated_at: 1000,
        deleted: false,
    };
    let deleted_card = Card {
        id: Uuid::new_v4(),
        title: "Deleted".to_string(),
        content: "Content".to_string(),
        created_at: 2000,
        updated_at: 2000,
        deleted: true,
    };

    store.upsert_card(&active_card).unwrap();
    store.upsert_card(&deleted_card).unwrap();

    // Without include_deleted
    let results = store.query_cards("", None, false, 10, 0).unwrap();
    assert_eq!(results.len(), 1);

    // With include_deleted
    let results = store.query_cards("", None, true, 10, 0).unwrap();
    assert_eq!(results.len(), 2);
}

// ============================================================================
// Database Initialization Error Tests
// ============================================================================

#[test]
fn new_fails_on_invalid_path() {
    let result = SqliteStore::new(Path::new("/nonexistent/directory/test.db"));

    assert!(result.is_err());
}
