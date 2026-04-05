// input: PoolStore API 与数据池业务场景边界条件。
// output: 数据池存储业务逻辑的全覆盖测试。
// pos: PoolStore 单元测试文件。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件测试数据池业务逻辑。

use cardmind_rust::models::error::CardMindError;
use cardmind_rust::models::pool::{JoinRequestStatus, PoolMember};
use cardmind_rust::store::pool_store::PoolStore;
use tempfile::TempDir;
use uuid::Uuid;

fn setup_pool_store() -> (PoolStore, TempDir) {
    let temp_dir = TempDir::new().unwrap();
    let store = PoolStore::new(temp_dir.path().to_str().unwrap()).unwrap();
    (store, temp_dir)
}

// ============================================================================
// Pool Creation Tests
// ============================================================================

#[test]
fn test_create_pool() {
    let (store, _temp) = setup_pool_store();

    let pool = store.create_pool("endpoint1", "Admin", "macOS").unwrap();

    assert!(!pool.pool_id.to_string().is_empty());
    assert_eq!(pool.members.len(), 1);
    assert!(pool.members[0].is_admin);
    assert_eq!(pool.members[0].endpoint_id, "endpoint1");
    assert_eq!(pool.members[0].nickname, "Admin");
    assert_eq!(pool.members[0].os, "macOS");
    assert!(pool.card_ids.is_empty());
}

#[test]
fn test_create_pool_empty_strings() {
    let (store, _temp) = setup_pool_store();

    let pool = store.create_pool("", "", "").unwrap();

    assert_eq!(pool.members[0].endpoint_id, "");
    assert_eq!(pool.members[0].nickname, "");
    assert_eq!(pool.members[0].os, "");
}

#[test]
fn test_create_pool_unicode() {
    let (store, _temp) = setup_pool_store();

    let pool = store.create_pool("设备1 🖥️", "管理员", "macOS").unwrap();

    assert_eq!(pool.members[0].endpoint_id, "设备1 🖥️");
    assert_eq!(pool.members[0].nickname, "管理员");
}

// ============================================================================
// Get Pool Tests
// ============================================================================

#[test]
fn test_get_pool() {
    let (store, _temp) = setup_pool_store();
    let created = store.create_pool("ep1", "Admin", "macOS").unwrap();

    let fetched = store.get_pool(&created.pool_id).unwrap();

    assert_eq!(fetched.pool_id, created.pool_id);
    assert_eq!(fetched.members.len(), 1);
}

#[test]
fn test_get_pool_not_found() {
    let (store, _temp) = setup_pool_store();
    let fake_id = Uuid::new_v4();

    let result = store.get_pool(&fake_id);
    assert!(matches!(result, Err(CardMindError::NotFound(_))));
}

#[test]
fn test_get_any_pool() {
    let (store, _temp) = setup_pool_store();
    let created = store.create_pool("ep1", "Admin", "macOS").unwrap();

    let fetched = store.get_any_pool().unwrap();

    assert_eq!(fetched.pool_id, created.pool_id);
}

#[test]
fn test_get_any_pool_empty() {
    let (store, _temp) = setup_pool_store();

    let result = store.get_any_pool();
    assert!(matches!(result, Err(CardMindError::NotFound(_))));
}

// ============================================================================
// Join Pool Tests
// ============================================================================

#[test]
fn test_join_pool() {
    let (store, _temp) = setup_pool_store();
    let pool = store.create_pool("ep1", "Admin", "macOS").unwrap();

    let new_member = PoolMember {
        endpoint_id: "ep2".to_string(),
        nickname: "Member".to_string(),
        os: "Windows".to_string(),
        is_admin: false,
    };
    let card_ids = vec![Uuid::new_v4()];

    let updated = store.join_pool(&pool, new_member, card_ids).unwrap();

    assert_eq!(updated.members.len(), 2);
    let member = updated
        .members
        .iter()
        .find(|m| m.endpoint_id == "ep2")
        .unwrap();
    assert!(!member.is_admin);
    assert_eq!(updated.card_ids.len(), 1);
}

#[test]
fn test_join_pool_idempotent() {
    let (store, _temp) = setup_pool_store();
    let pool = store.create_pool("ep1", "Admin", "macOS").unwrap();

    // Try to join with same endpoint_id twice
    let new_member = PoolMember {
        endpoint_id: "ep1".to_string(),
        nickname: "Admin".to_string(),
        os: "macOS".to_string(),
        is_admin: true,
    };

    let updated = store.join_pool(&pool, new_member, vec![]).unwrap();

    // Should still have only 1 member (no duplicate)
    assert_eq!(updated.members.len(), 1);
}

#[test]
fn test_join_pool_with_cards() {
    let (store, _temp) = setup_pool_store();
    let pool = store.create_pool("ep1", "Admin", "macOS").unwrap();

    let new_member = PoolMember {
        endpoint_id: "ep2".to_string(),
        nickname: "Member".to_string(),
        os: "Linux".to_string(),
        is_admin: false,
    };
    let card_ids = vec![Uuid::new_v4(), Uuid::new_v4()];

    let updated = store.join_pool(&pool, new_member, card_ids).unwrap();

    assert_eq!(updated.card_ids.len(), 2);
}

// ============================================================================
// Join By Code Tests
// ============================================================================

#[test]
fn test_join_by_code() {
    let (store, _temp) = setup_pool_store();
    let pool = store.create_pool("ep1", "Admin", "macOS").unwrap();

    let new_member = PoolMember {
        endpoint_id: "ep2".to_string(),
        nickname: "Member".to_string(),
        os: "Windows".to_string(),
        is_admin: false,
    };

    let code = pool.pool_id.to_string();
    let updated = store.join_by_code(&code, new_member, vec![]).unwrap();

    assert_eq!(updated.members.len(), 2);
}

#[test]
fn test_join_by_code_invalid() {
    let (store, _temp) = setup_pool_store();

    let new_member = PoolMember {
        endpoint_id: "ep2".to_string(),
        nickname: "Member".to_string(),
        os: "Windows".to_string(),
        is_admin: false,
    };

    let result = store.join_by_code("invalid-code", new_member, vec![]);
    assert!(matches!(result, Err(CardMindError::InvalidArgument(_))));
}

#[test]
fn test_join_by_code_not_found() {
    let (store, _temp) = setup_pool_store();

    let new_member = PoolMember {
        endpoint_id: "ep2".to_string(),
        nickname: "Member".to_string(),
        os: "Windows".to_string(),
        is_admin: false,
    };

    let fake_id = Uuid::new_v4().to_string();
    let result = store.join_by_code(&fake_id, new_member, vec![]);
    assert!(matches!(result, Err(CardMindError::NotFound(_))));
}

// ============================================================================
// Leave Pool Tests
// ============================================================================

#[test]
fn test_leave_pool() {
    let (store, _temp) = setup_pool_store();
    let pool = store.create_pool("ep1", "Admin", "macOS").unwrap();

    // First join another member
    let new_member = PoolMember {
        endpoint_id: "ep2".to_string(),
        nickname: "Member".to_string(),
        os: "Windows".to_string(),
        is_admin: false,
    };
    let pool = store.join_pool(&pool, new_member, vec![]).unwrap();

    // Then leave
    let updated = store.leave_pool(&pool.pool_id, "ep2").unwrap();

    assert_eq!(updated.members.len(), 1);
    assert!(!updated.members.iter().any(|m| m.endpoint_id == "ep2"));
}

#[test]
fn test_leave_pool_not_found() {
    let (store, _temp) = setup_pool_store();
    let fake_id = Uuid::new_v4();

    let result = store.leave_pool(&fake_id, "ep1");
    assert!(matches!(result, Err(CardMindError::NotFound(_))));
}

#[test]
fn test_leave_pool_last_member() {
    let (store, _temp) = setup_pool_store();
    let pool = store.create_pool("ep1", "Admin", "macOS").unwrap();

    let result = store.leave_pool(&pool.pool_id, "ep1");

    assert!(matches!(result, Err(CardMindError::InvalidArgument(_))));
}

#[test]
fn test_leave_pool_last_admin_rejected() {
    let (store, _temp) = setup_pool_store();
    let pool = store.create_pool("ep1", "Admin", "macOS").unwrap();

    let new_member = PoolMember {
        endpoint_id: "ep2".to_string(),
        nickname: "Member".to_string(),
        os: "Windows".to_string(),
        is_admin: false,
    };
    let pool = store.join_pool(&pool, new_member, vec![]).unwrap();

    let result = store.leave_pool(&pool.pool_id, "ep1");

    assert!(matches!(result, Err(CardMindError::InvalidArgument(_))));
}

#[test]
fn test_leave_pool_when_other_admin_exists() {
    let (store, _temp) = setup_pool_store();
    let pool = store.create_pool("ep1", "Admin", "macOS").unwrap();

    let admin2 = PoolMember {
        endpoint_id: "ep2".to_string(),
        nickname: "Admin2".to_string(),
        os: "Windows".to_string(),
        is_admin: true,
    };
    let pool = store.join_pool(&pool, admin2, vec![]).unwrap();

    let updated = store.leave_pool(&pool.pool_id, "ep1").unwrap();

    assert_eq!(updated.members.len(), 1);
    assert_eq!(updated.members[0].endpoint_id, "ep2");
    assert!(updated.members[0].is_admin);
}

#[test]
fn test_dissolve_pool_single_admin_success() {
    let (store, _temp) = setup_pool_store();
    let pool = store.create_pool("ep1", "Admin", "macOS").unwrap();

    let dissolved = store.dissolve_pool(&pool.pool_id, "ep1").unwrap();

    assert!(dissolved.is_dissolved);
}

#[test]
fn test_dissolve_pool_rejects_non_admin() {
    let (store, _temp) = setup_pool_store();
    let pool = store.create_pool("ep1", "Admin", "macOS").unwrap();
    let pool = store
        .join_pool(
            &pool,
            PoolMember {
                endpoint_id: "ep2".to_string(),
                nickname: "Member".to_string(),
                os: "Windows".to_string(),
                is_admin: false,
            },
            vec![],
        )
        .unwrap();

    let result = store.dissolve_pool(&pool.pool_id, "ep2");

    assert!(matches!(result, Err(CardMindError::InvalidArgument(_))));
}

#[test]
fn test_dissolve_pool_rejects_when_other_members_exist() {
    let (store, _temp) = setup_pool_store();
    let pool = store.create_pool("ep1", "Admin", "macOS").unwrap();
    let pool = store
        .join_pool(
            &pool,
            PoolMember {
                endpoint_id: "ep2".to_string(),
                nickname: "Member".to_string(),
                os: "Windows".to_string(),
                is_admin: false,
            },
            vec![],
        )
        .unwrap();

    let result = store.dissolve_pool(&pool.pool_id, "ep1");

    assert!(matches!(result, Err(CardMindError::InvalidArgument(_))));
}

#[test]
fn test_dissolved_pool_rejects_modification() {
    let (store, _temp) = setup_pool_store();
    let pool = store.create_pool("ep1", "Admin", "macOS").unwrap();
    let dissolved = store.dissolve_pool(&pool.pool_id, "ep1").unwrap();

    let join_result = store.join_pool(
        &dissolved,
        PoolMember {
            endpoint_id: "ep2".to_string(),
            nickname: "Member".to_string(),
            os: "Windows".to_string(),
            is_admin: false,
        },
        vec![],
    );
    let attach_result = store.attach_note_references(&dissolved.pool_id, vec![Uuid::new_v4()]);

    assert!(matches!(
        join_result,
        Err(CardMindError::InvalidArgument(_))
    ));
    assert!(matches!(
        attach_result,
        Err(CardMindError::InvalidArgument(_))
    ));
}

// ============================================================================
// Attach Note References Tests
// ============================================================================

#[test]
fn test_attach_note_references() {
    let (store, _temp) = setup_pool_store();
    let pool = store.create_pool("ep1", "Admin", "macOS").unwrap();

    let card_ids = vec![Uuid::new_v4(), Uuid::new_v4()];
    let updated = store
        .attach_note_references(&pool.pool_id, card_ids)
        .unwrap();

    assert_eq!(updated.card_ids.len(), 2);
}

#[test]
fn test_attach_note_references_deduplication() {
    let (store, _temp) = setup_pool_store();
    let pool = store.create_pool("ep1", "Admin", "macOS").unwrap();

    let card_id = Uuid::new_v4();

    // Attach first time
    store
        .attach_note_references(&pool.pool_id, vec![card_id])
        .unwrap();

    // Attach same card again
    let updated = store
        .attach_note_references(&pool.pool_id, vec![card_id])
        .unwrap();

    // Should have only 1 card (deduplication)
    assert_eq!(updated.card_ids.len(), 1);
}

#[test]
fn test_attach_note_references_merge() {
    let (store, _temp) = setup_pool_store();
    let pool = store.create_pool("ep1", "Admin", "macOS").unwrap();

    let card1 = Uuid::new_v4();
    let card2 = Uuid::new_v4();
    let card3 = Uuid::new_v4();

    // Attach first batch
    store
        .attach_note_references(&pool.pool_id, vec![card1, card2])
        .unwrap();

    // Attach second batch
    let updated = store
        .attach_note_references(&pool.pool_id, vec![card2, card3])
        .unwrap();

    // Should have 3 unique cards
    assert_eq!(updated.card_ids.len(), 3);
}

#[test]
fn test_attach_note_references_not_found() {
    let (store, _temp) = setup_pool_store();
    let fake_id = Uuid::new_v4();

    let result = store.attach_note_references(&fake_id, vec![]);
    assert!(matches!(result, Err(CardMindError::NotFound(_))));
}

// ============================================================================
// Persistence Tests
// ============================================================================

#[test]
fn test_pool_persistence() {
    let temp_dir = TempDir::new().unwrap();
    let path_str = temp_dir.path().to_str().unwrap();

    // Create pool with first instance
    let store1 = PoolStore::new(path_str).unwrap();
    let pool = store1.create_pool("ep1", "Admin", "macOS").unwrap();

    // Read with second instance
    let store2 = PoolStore::new(path_str).unwrap();
    let fetched = store2.get_pool(&pool.pool_id).unwrap();

    assert_eq!(fetched.pool_id, pool.pool_id);
    assert_eq!(fetched.members.len(), 1);
}

#[test]
fn test_join_persistence() {
    let temp_dir = TempDir::new().unwrap();
    let path_str = temp_dir.path().to_str().unwrap();

    let store1 = PoolStore::new(path_str).unwrap();
    let pool = store1.create_pool("ep1", "Admin", "macOS").unwrap();

    let new_member = PoolMember {
        endpoint_id: "ep2".to_string(),
        nickname: "Member".to_string(),
        os: "Windows".to_string(),
        is_admin: false,
    };
    store1.join_pool(&pool, new_member, vec![]).unwrap();

    let store2 = PoolStore::new(path_str).unwrap();
    let fetched = store2.get_pool(&pool.pool_id).unwrap();

    assert_eq!(fetched.members.len(), 2);
}

// ============================================================================
// Base Path Tests
// ============================================================================

#[test]
fn test_base_path() {
    let temp_dir = TempDir::new().unwrap();
    let path_str = temp_dir.path().to_str().unwrap();
    let store = PoolStore::new(path_str).unwrap();

    let base_path = store.base_path();
    assert_eq!(base_path.to_str().unwrap(), path_str);
}

// ============================================================================
// Pool Lifecycle Tests
// ============================================================================

#[test]
fn test_pool_full_lifecycle() {
    let (store, _temp) = setup_pool_store();

    // Create
    let pool = store.create_pool("ep1", "Admin", "macOS").unwrap();
    assert_eq!(pool.members.len(), 1);
    assert!(pool.card_ids.is_empty());

    // Attach cards
    let card1 = Uuid::new_v4();
    let pool = store
        .attach_note_references(&pool.pool_id, vec![card1])
        .unwrap();
    assert_eq!(pool.card_ids.len(), 1);

    // Join another member
    let new_member = PoolMember {
        endpoint_id: "ep2".to_string(),
        nickname: "Member".to_string(),
        os: "Windows".to_string(),
        is_admin: false,
    };
    let pool = store.join_pool(&pool, new_member, vec![]).unwrap();
    assert_eq!(pool.members.len(), 2);

    // Leave
    let pool = store.leave_pool(&pool.pool_id, "ep2").unwrap();
    assert_eq!(pool.members.len(), 1);

    // Verify cards still attached
    assert_eq!(pool.card_ids.len(), 1);
}

// ============================================================================
// Edge Cases Tests
// ============================================================================

#[test]
fn test_join_pool_with_empty_card_list() {
    let (store, _temp) = setup_pool_store();
    let pool = store.create_pool("ep1", "Admin", "macOS").unwrap();

    let new_member = PoolMember {
        endpoint_id: "ep2".to_string(),
        nickname: "Member".to_string(),
        os: "Linux".to_string(),
        is_admin: false,
    };

    let updated = store.join_pool(&pool, new_member, vec![]).unwrap();

    assert_eq!(updated.members.len(), 2);
    assert!(updated.card_ids.is_empty());
}

#[test]
fn test_attach_empty_note_list() {
    let (store, _temp) = setup_pool_store();
    let pool = store.create_pool("ep1", "Admin", "macOS").unwrap();

    let updated = store.attach_note_references(&pool.pool_id, vec![]).unwrap();

    assert!(updated.card_ids.is_empty());
}

#[test]
fn test_leave_nonexistent_member() {
    let (store, _temp) = setup_pool_store();
    let pool = store.create_pool("ep1", "Admin", "macOS").unwrap();

    // Leaving a member that's not in the pool should not fail
    let updated = store.leave_pool(&pool.pool_id, "nonexistent").unwrap();

    // Pool unchanged
    assert_eq!(updated.members.len(), 1);
}

#[test]
fn test_submit_join_request_creates_pending_request() {
    let (store, _temp) = setup_pool_store();
    let pool = store.create_pool("ep1", "Admin", "macOS").unwrap();

    let updated = store
        .submit_join_request(
            &pool.pool_id,
            PoolMember {
                endpoint_id: "ep2".to_string(),
                nickname: "Applicant".to_string(),
                os: "Windows".to_string(),
                is_admin: false,
            },
        )
        .unwrap();

    assert_eq!(updated.join_requests.len(), 1);
    assert_eq!(updated.join_requests[0].status, JoinRequestStatus::Pending);
}

#[test]
fn test_approve_join_request_adds_member() {
    let (store, _temp) = setup_pool_store();
    let pool = store.create_pool("ep1", "Admin", "macOS").unwrap();
    let pool = store
        .submit_join_request(
            &pool.pool_id,
            PoolMember {
                endpoint_id: "ep2".to_string(),
                nickname: "Applicant".to_string(),
                os: "Windows".to_string(),
                is_admin: false,
            },
        )
        .unwrap();
    let request_id = pool.join_requests[0].request_id;

    let updated = store
        .approve_join_request(&pool.pool_id, &request_id, "ep1")
        .unwrap();

    assert_eq!(updated.members.len(), 2);
    assert_eq!(updated.join_requests[0].status, JoinRequestStatus::Approved);
}

#[test]
fn test_reject_join_request_marks_rejected() {
    let (store, _temp) = setup_pool_store();
    let pool = store.create_pool("ep1", "Admin", "macOS").unwrap();
    let pool = store
        .submit_join_request(
            &pool.pool_id,
            PoolMember {
                endpoint_id: "ep2".to_string(),
                nickname: "Applicant".to_string(),
                os: "Windows".to_string(),
                is_admin: false,
            },
        )
        .unwrap();
    let request_id = pool.join_requests[0].request_id;

    let updated = store
        .reject_join_request(&pool.pool_id, &request_id, "ep1")
        .unwrap();

    assert_eq!(updated.join_requests[0].status, JoinRequestStatus::Rejected);
    assert_eq!(updated.members.len(), 1);
}

#[test]
fn test_cancel_join_request_marks_cancelled() {
    let (store, _temp) = setup_pool_store();
    let pool = store.create_pool("ep1", "Admin", "macOS").unwrap();
    let pool = store
        .submit_join_request(
            &pool.pool_id,
            PoolMember {
                endpoint_id: "ep2".to_string(),
                nickname: "Applicant".to_string(),
                os: "Windows".to_string(),
                is_admin: false,
            },
        )
        .unwrap();
    let request_id = pool.join_requests[0].request_id;

    let updated = store
        .cancel_join_request(&pool.pool_id, &request_id, "ep2")
        .unwrap();

    assert_eq!(
        updated.join_requests[0].status,
        JoinRequestStatus::Cancelled
    );
}

// ============================================================================
// Error Handling Tests
// ============================================================================

#[test]
fn test_error_not_found() {
    let (store, _temp) = setup_pool_store();
    let fake_id = Uuid::new_v4();

    let result = store.get_pool(&fake_id);
    match result {
        Err(CardMindError::NotFound(msg)) => {
            assert!(msg.contains("pool") || msg.contains("not found"));
        }
        _ => panic!("Expected NotFound error"),
    }
}

#[test]
fn test_error_invalid_argument() {
    let (store, _temp) = setup_pool_store();

    let new_member = PoolMember {
        endpoint_id: "ep2".to_string(),
        nickname: "Member".to_string(),
        os: "Windows".to_string(),
        is_admin: false,
    };

    let result = store.join_by_code("not-a-uuid", new_member, vec![]);
    match result {
        Err(CardMindError::InvalidArgument(msg)) => {
            assert!(msg.contains("invalid"));
        }
        _ => panic!("Expected InvalidArgument error"),
    }
}
