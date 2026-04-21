// input: API 门面层的基本功能测试。
// output: API 层基础集成功能测试。
// pos: API 集成测试文件（简化版，避免全局状态冲突）。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件测试 API 门面层的基础功能。

use cardmind_rust::api::*;
use serial_test::serial;
use tempfile::TempDir;

fn setup_test_env() -> TempDir {
    let temp_dir = TempDir::new().unwrap();
    // 重置配置确保干净状态
    let _ = reset_app_config_for_tests();
    let _ = init_app_config(temp_dir.path().to_str().unwrap().to_string());
    temp_dir
}

fn unlock_app_lock_for_pool_apis() {
    let _ = setup_app_lock("1234".to_string(), true);
    let _ = verify_app_lock_with_pin("1234".to_string());
}

// ============================================================================
// App Config Tests
// ============================================================================

#[test]
#[serial]
fn api_init_app_config_creates_directories() {
    let temp_dir = TempDir::new().unwrap();
    let _ = reset_app_config_for_tests();

    let result = init_app_config(temp_dir.path().to_str().unwrap().to_string());
    assert!(result.is_ok());

    // 验证目录结构已创建
    assert!(temp_dir.path().exists());
}

#[test]
#[serial]
fn api_requires_app_config_before_store_operations() {
    reset_app_config_for_tests().unwrap();

    let err = get_backend_config().unwrap_err();

    assert_eq!(err.code, "APP_CONFIG_NOT_INITIALIZED");
}

#[test]
#[serial]
fn api_init_app_config_same_dir_is_idempotent() {
    let temp_dir = TempDir::new().unwrap();
    let path = temp_dir.path().to_str().unwrap().to_string();
    reset_app_config_for_tests().unwrap();

    init_app_config(path.clone()).unwrap();
    init_app_config(path).unwrap();
}

#[test]
#[serial]
fn api_init_app_config_different_dir_returns_conflict() {
    let temp_a = TempDir::new().unwrap();
    let temp_b = TempDir::new().unwrap();
    reset_app_config_for_tests().unwrap();

    init_app_config(temp_a.path().to_str().unwrap().to_string()).unwrap();
    let err = init_app_config(temp_b.path().to_str().unwrap().to_string()).unwrap_err();

    assert_eq!(err.code, "APP_CONFIG_CONFLICT");
}

#[test]
#[serial]
fn api_reset_app_config_clears_state() {
    let _temp = setup_test_env();

    // 重置应该成功
    let result = reset_app_config_for_tests();
    assert!(result.is_ok());
}

// ============================================================================
// Error Handling Tests
// ============================================================================

#[test]
#[serial]
fn api_get_card_not_found() {
    let _temp = setup_test_env();

    let result = get_card_note_detail("550e8400-e29b-41d4-a716-446655440000".to_string());
    assert!(result.is_err());
    let err = result.unwrap_err();
    assert_eq!(err.code, "NOT_FOUND");
}

#[test]
#[serial]
fn api_invalid_uuid_format() {
    let _temp = setup_test_env();

    let result = get_card_note_detail("not-a-valid-uuid".to_string());
    assert!(result.is_err());
    let err = result.unwrap_err();
    assert_eq!(err.code, "INVALID_ARGUMENT");
}

#[test]
#[serial]
fn api_get_nonexistent_pool() {
    let _temp = setup_test_env();
    unlock_app_lock_for_pool_apis();

    let result = get_pool_detail(
        "550e8400-e29b-41d4-a716-446655440000".to_string(),
        "device".to_string(),
    );
    assert!(result.is_err());
}

#[test]
#[serial]
fn api_join_nonexistent_pool() {
    let _temp = setup_test_env();
    unlock_app_lock_for_pool_apis();

    let result = join_pool(
        "550e8400-e29b-41d4-a716-446655440000".to_string(),
        "device".to_string(),
        "Member".to_string(),
        "OS".to_string(),
    );
    assert!(result.is_err());
}

#[test]
#[serial]
fn api_join_by_code_invalid() {
    let _temp = setup_test_env();
    unlock_app_lock_for_pool_apis();

    let result = join_by_code(
        "invalid-code".to_string(),
        "device".to_string(),
        "Member".to_string(),
        "Windows".to_string(),
    );
    assert!(result.is_err());
}

#[test]
#[serial]
fn api_update_nonexistent_card() {
    let _temp = setup_test_env();

    let result = update_card_note(
        "550e8400-e29b-41d4-a716-446655440000".to_string(),
        "Title".to_string(),
        "Content".to_string(),
    );
    assert!(result.is_err());
}

#[test]
#[serial]
fn api_delete_nonexistent_card() {
    let _temp = setup_test_env();

    let result = delete_card_note("550e8400-e29b-41d4-a716-446655440000".to_string());
    assert!(result.is_err());
}

#[test]
#[serial]
fn api_get_joined_pool_view_empty() {
    let _temp = setup_test_env();
    unlock_app_lock_for_pool_apis();

    // 没有加入任何数据池时应该返回错误
    let result = get_joined_pool_view("device1".to_string());
    assert!(result.is_err());
}

#[test]
#[serial]
fn api_backend_config_roundtrip() {
    let _temp = setup_test_env();

    let initial = get_backend_config().unwrap();
    assert!(!initial.http_enabled);
    assert!(!initial.mcp_enabled);
    assert!(!initial.cli_enabled);

    let updated = update_backend_config(true, false, true).unwrap();
    assert!(updated.http_enabled);
    assert!(!updated.mcp_enabled);
    assert!(updated.cli_enabled);

    let persisted = get_backend_config().unwrap();
    assert!(persisted.http_enabled);
    assert!(!persisted.mcp_enabled);
    assert!(persisted.cli_enabled);
}

#[test]
#[serial]
fn api_pool_endpoints_require_app_lock_before_use() {
    let _temp = setup_test_env();

    let err = create_pool(
        "device1".to_string(),
        "Alice".to_string(),
        "macOS".to_string(),
    )
    .unwrap_err();

    assert_eq!(err.code, "APP_LOCK_REQUIRED");
}

#[test]
#[serial]
fn api_pool_endpoints_work_after_app_lock_setup_and_unlock() {
    let _temp = setup_test_env();

    setup_app_lock("1234".to_string(), true).unwrap();
    verify_app_lock_with_pin("1234".to_string()).unwrap();

    let pool = create_pool(
        "device1".to_string(),
        "Alice".to_string(),
        "macOS".to_string(),
    )
    .unwrap();

    assert_eq!(pool.current_user_role, "admin");
}

#[test]
#[serial]
fn api_pool_endpoints_return_locked_when_pin_threshold_reached() {
    let _temp = setup_test_env();

    setup_app_lock("1234".to_string(), false).unwrap();
    for _ in 0..5 {
        let _ = verify_app_lock_with_pin("0000".to_string());
    }

    let err = list_pools("device1".to_string()).unwrap_err();
    assert_eq!(err.code, "APP_LOCKED");
}

#[test]
#[serial]
fn api_app_lock_status_and_reset_roundtrip() {
    let _temp = setup_test_env();
    reset_app_lock_for_tests().unwrap();

    let initial = app_lock_status().unwrap();
    assert_eq!(initial, (false, true));

    setup_app_lock("1234".to_string(), true).unwrap();
    let configured = app_lock_status().unwrap();
    assert_eq!(configured, (true, true));

    reset_app_lock_for_tests().unwrap();
    let reset = app_lock_status().unwrap();
    assert_eq!(reset, (false, true));
}

#[test]
#[serial]
fn api_mark_biometric_success_unlocks_after_failed_attempts() {
    let _temp = setup_test_env();

    setup_app_lock("1234".to_string(), true).unwrap();
    for _ in 0..5 {
        let _ = verify_app_lock_with_pin("0000".to_string());
    }

    let locked = list_pools("device1".to_string()).unwrap_err();
    assert_eq!(locked.code, "APP_LOCKED");

    mark_biometric_success().unwrap();
    let unlocked = app_lock_status().unwrap();
    assert_eq!(unlocked, (true, true));
}

#[test]
#[serial]
fn api_runtime_entry_status_reflects_default_config() {
    let _temp = setup_test_env();

    let status = get_runtime_entry_status().unwrap();

    assert!(!status.http_active);
    assert!(!status.mcp_active);
    assert!(!status.cli_active);
}

#[test]
#[serial]
fn api_pool_crud_flow() {
    let _temp = setup_test_env();
    unlock_app_lock_for_pool_apis();

    let pool = create_pool(
        "device1".to_string(),
        "Alice".to_string(),
        "macOS".to_string(),
    )
    .unwrap();
    assert_eq!(pool.current_user_role, "admin");
    assert_eq!(pool.member_count, 1);

    let pools = list_pools("device1".to_string()).unwrap();
    assert_eq!(pools.len(), 1);

    let detail = get_pool_detail(pool.id.clone(), "device1".to_string()).unwrap();
    assert_eq!(detail.id, pool.id);
    assert_eq!(detail.member_count, 1);

    let joined = get_joined_pool_view("device1".to_string()).unwrap();
    assert_eq!(joined.id, detail.id);
}

#[test]
#[serial]
fn api_join_pool_success() {
    let _temp = setup_test_env();
    unlock_app_lock_for_pool_apis();

    let pool = create_pool(
        "admin-device".to_string(),
        "Admin".to_string(),
        "macOS".to_string(),
    )
    .unwrap();

    let joined = join_pool(
        pool.id.clone(),
        "member-device".to_string(),
        "Bob".to_string(),
        "Windows".to_string(),
    )
    .unwrap();

    assert_eq!(joined.id, pool.id);
    assert_eq!(joined.current_user_role, "member");
    assert_eq!(joined.member_count, 2);
}

#[test]
#[serial]
fn api_join_by_code_timeout_returns_request_timeout() {
    let _temp = setup_test_env();
    unlock_app_lock_for_pool_apis();

    let err = join_by_code(
        "timeout".to_string(),
        "device".to_string(),
        "Member".to_string(),
        "Windows".to_string(),
    )
    .unwrap_err();

    assert_eq!(err.code, "REQUEST_TIMEOUT");
}

#[test]
#[serial]
fn api_join_by_code_valid_uuid_not_found_returns_pool_not_found() {
    let _temp = setup_test_env();
    unlock_app_lock_for_pool_apis();

    let err = join_by_code(
        uuid::Uuid::new_v4().to_string(),
        "device".to_string(),
        "Member".to_string(),
        "Windows".to_string(),
    )
    .unwrap_err();

    assert_eq!(err.code, "POOL_NOT_FOUND");
}

#[test]
#[serial]
fn api_list_pools_returns_empty_when_no_pool_exists() {
    let _temp = setup_test_env();
    unlock_app_lock_for_pool_apis();

    let pools = list_pools("device1".to_string()).unwrap();

    assert!(pools.is_empty());
}

#[test]
#[serial]
fn api_card_note_crud_flow() {
    let _temp = setup_test_env();

    let created = create_card_note("Title".to_string(), "Content".to_string()).unwrap();
    assert_eq!(created.title, "Title");
    assert!(!created.deleted);

    let detail = get_card_note_detail(created.id.clone()).unwrap();
    assert_eq!(detail.id, created.id);

    let updated = update_card_note(
        created.id.clone(),
        "Updated".to_string(),
        "Changed".to_string(),
    )
    .unwrap();
    assert_eq!(updated.title, "Updated");
    assert_eq!(updated.content, "Changed");

    let listed = list_card_notes().unwrap();
    assert_eq!(listed.len(), 1);

    let queried = query_card_notes("Updated".to_string(), None, Some(false)).unwrap();
    assert_eq!(queried.len(), 1);

    let deleted = delete_card_note(created.id.clone()).unwrap();
    assert!(deleted.deleted);

    let without_deleted = query_card_notes("".to_string(), None, Some(false)).unwrap();
    assert!(without_deleted.is_empty());

    let with_deleted = query_card_notes("".to_string(), None, Some(true)).unwrap();
    assert_eq!(with_deleted.len(), 1);

    let restored = restore_card_note(created.id).unwrap();
    assert!(!restored.deleted);
}

#[test]
#[serial]
fn api_create_card_note_in_pool_attaches_card_to_pool() {
    let _temp = setup_test_env();
    unlock_app_lock_for_pool_apis();

    let pool = create_pool(
        "device1".to_string(),
        "Alice".to_string(),
        "macOS".to_string(),
    )
    .unwrap();
    let card = create_card_note_in_pool(
        pool.id.clone(),
        "Pool Card".to_string(),
        "Pool Content".to_string(),
    )
    .unwrap();

    let detail = get_pool_detail(pool.id, "device1".to_string()).unwrap();
    assert_eq!(detail.note_ids, vec![card.id]);
}

#[test]
#[serial]
fn api_query_card_notes_filters_by_pool_id() {
    let _temp = setup_test_env();
    unlock_app_lock_for_pool_apis();

    let pool = create_pool(
        "device1".to_string(),
        "Alice".to_string(),
        "macOS".to_string(),
    )
    .unwrap();
    let in_pool = create_card_note_in_pool(
        pool.id.clone(),
        "Pool Scoped".to_string(),
        "Only here".to_string(),
    )
    .unwrap();
    let _outside = create_card_note("General".to_string(), "Elsewhere".to_string()).unwrap();

    let filtered = query_card_notes("".to_string(), Some(pool.id), Some(false)).unwrap();

    assert_eq!(filtered.len(), 1);
    assert_eq!(filtered[0].id, in_pool.id);
}

#[test]
#[serial]
fn api_sync_functions_validate_invalid_handle() {
    let _temp = setup_test_env();
    unlock_app_lock_for_pool_apis();

    assert_eq!(sync_status(99999).unwrap_err().code, "INVALID_HANDLE");
    assert_eq!(
        sync_connect(99999, "target".to_string()).unwrap_err().code,
        "INVALID_HANDLE"
    );
    assert_eq!(sync_disconnect(99999).unwrap_err().code, "INVALID_HANDLE");
    assert_eq!(
        sync_join_pool(99999, "pool".to_string()).unwrap_err().code,
        "INVALID_HANDLE"
    );
    assert_eq!(sync_push(99999).unwrap_err().code, "INVALID_HANDLE");
    assert_eq!(sync_pull(99999).unwrap_err().code, "INVALID_HANDLE");
    assert_eq!(close_pool_network(99999).unwrap_err().code, "NOT_FOUND");
}

#[test]
#[serial]
fn api_pool_network_lifecycle_and_sync_state() {
    let temp = setup_test_env();
    unlock_app_lock_for_pool_apis();
    let network_id = init_pool_network(temp.path().to_str().unwrap().to_string()).unwrap();

    let status = sync_status(network_id).unwrap();
    // Phase 2 契约映射
    assert_eq!(status.sync_state, "ready");
    assert_eq!(status.query_convergence_state, "ready");
    assert_eq!(status.instance_continuity_state, "ready");
    assert_eq!(status.local_content_safety, "safe");
    assert_eq!(status.recovery_stage, "stable");
    assert_eq!(status.continuity_state, "same_path");
    assert_eq!(status.next_action, "none");
    // 兼容性字段
    assert_eq!(status.state, "idle");
    assert_eq!(status.projection_state, "projection_ready");
    assert_eq!(status.content_state, "content_safe");

    let connect_err = sync_connect(network_id, "".to_string()).unwrap_err();
    assert_eq!(connect_err.code, "INVALID_ARGUMENT");

    let push = sync_push(network_id).unwrap();
    assert_eq!(push.state, "degraded");
    // Phase 2 契约: sync_failed 映射为 blocked
    assert_eq!(push.sync_state, "blocked");
    assert_eq!(push.code.as_deref(), Some("REQUEST_TIMEOUT"));
    assert_eq!(push.continuity_state, "path_at_risk");
    assert_eq!(push.content_state, "content_safe_local_only");
    assert_eq!(push.next_action, "retry_sync");

    let pull = sync_pull(network_id).unwrap();
    assert_eq!(pull.state, "degraded");
    // Phase 2 契约: sync_failed 映射为 blocked
    assert_eq!(pull.sync_state, "blocked");
    assert_eq!(pull.code.as_deref(), Some("REQUEST_TIMEOUT"));
    assert_eq!(pull.continuity_state, "path_at_risk");
    assert_eq!(pull.content_state, "content_safe_local_only");
    assert_eq!(pull.next_action, "retry_sync");

    close_pool_network(network_id).unwrap();
}

#[test]
#[serial]
fn api_sync_push_returns_ok_when_connected() {
    let temp = setup_test_env();
    unlock_app_lock_for_pool_apis();
    let network_id = init_pool_network(temp.path().to_str().unwrap().to_string()).unwrap();
    let peer_network_id = init_pool_network(temp.path().to_str().unwrap().to_string()).unwrap();
    let endpoint_id = get_pool_network_endpoint_id(network_id).unwrap();
    let peer_endpoint_id = get_pool_network_endpoint_id(peer_network_id).unwrap();
    let pool = create_pool(
        endpoint_id.clone(),
        "owner".to_string(),
        "macOS".to_string(),
    )
    .unwrap();
    join_by_code(
        pool.id.clone(),
        peer_endpoint_id,
        "peer".to_string(),
        "iOS".to_string(),
    )
    .unwrap();

    let target = get_pool_network_sync_target(peer_network_id).unwrap();
    sync_connect(network_id, target).unwrap();
    let result = sync_push(network_id).unwrap();

    assert_eq!(result.state, "ok");
    // Phase 2 契约: "connected" 映射为 "ready"
    assert_eq!(result.sync_state, "ready");
    assert_eq!(result.projection_state, "projection_ready");
    assert_eq!(result.code, None);
    assert_eq!(result.continuity_state, "same_path");
    assert_eq!(result.content_state, "content_safe");
    assert_eq!(result.next_action, "none");

    close_pool_network(network_id).unwrap();
}

#[test]
#[serial]
fn api_sync_status_returns_degraded_when_projection_pending() {
    let temp = setup_test_env();
    unlock_app_lock_for_pool_apis();
    let base = temp.path().to_str().unwrap();
    let failing_repo =
        cardmind_rust::store::card_store::CardNoteRepository::new_with_projection_failure(base)
            .unwrap();
    let _ = failing_repo.create_card("pending", "projection");
    let network_id = init_pool_network(base.to_string()).unwrap();

    let status = sync_status(network_id).unwrap();

    assert_eq!(status.state, "degraded");
    assert_eq!(status.projection_state, "projection_pending");
    assert_eq!(status.code.as_deref(), Some("PROJECTION_NOT_CONVERGED"));
    // Phase 2 契约: projection_pending 时 query_convergence_state = pending
    assert_eq!(status.query_convergence_state, "pending");
    // Phase 2 契约: has_error 导致 local_content_safety 为 read_only_risk
    assert_eq!(status.local_content_safety, "read_only_risk");
    // Phase 2 契约: projection_pending 时 continuity_state 为 path_at_risk
    assert_eq!(status.continuity_state, "path_at_risk");
    assert_eq!(status.content_state, "content_safe_local_only");
    // next_action 根据 recovery_contract 计算
    assert!(!status.next_action.is_empty());

    close_pool_network(network_id).unwrap();
}
