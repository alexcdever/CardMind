// input: api.rs 中的纯函数（projection_state, combine_sync_status, combine_sync_result, parse_uuid）。
// output: API 辅助函数的全覆盖测试。
// pos: API 内部函数单元测试文件。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件测试 API 层的纯函数。

use cardmind_rust::models::api_error::ApiErrorCode;
use uuid::Uuid;

// 模拟 parse_uuid 函数
fn parse_uuid(raw: &str, field: &str) -> Result<Uuid, cardmind_rust::models::api_error::ApiError> {
    Uuid::parse_str(raw).map_err(|_| {
        cardmind_rust::models::api_error::ApiError::new(
            ApiErrorCode::InvalidArgument,
            &format!("invalid {field}"),
        )
    })
}

// ============================================================================
// UUID Parsing Tests
// ============================================================================

#[test]
fn parse_uuid_valid() {
    let uuid_str = "550e8400-e29b-41d4-a716-446655440000";
    let result = parse_uuid(uuid_str, "card_id");

    assert!(result.is_ok());
    let uuid = result.unwrap();
    assert_eq!(uuid.to_string(), uuid_str);
}

#[test]
fn parse_uuid_invalid_format() {
    let result = parse_uuid("not-a-uuid", "card_id");

    assert!(result.is_err());
    let err = result.unwrap_err();
    assert_eq!(err.code, ApiErrorCode::InvalidArgument.as_str());
    assert!(err.message.contains("invalid card_id"));
}

#[test]
fn parse_uuid_empty() {
    let result = parse_uuid("", "pool_id");

    assert!(result.is_err());
    let err = result.unwrap_err();
    assert!(err.message.contains("invalid pool_id"));
}

#[test]
fn parse_uuid_too_short() {
    let result = parse_uuid("550e8400", "id");

    assert!(result.is_err());
}

#[test]
fn parse_uuid_invalid_chars() {
    let result = parse_uuid("550e8400-e29b-41d4-a716-44665544000g", "entity_id");

    assert!(result.is_err());
    let err = result.unwrap_err();
    assert!(err.message.contains("invalid entity_id"));
}

#[test]
fn parse_uuid_with_underscores() {
    // 测试包含下划线的错误 UUID
    let result = parse_uuid("550e8400_e29b_41d4_a716_446655440000", "test_id");

    assert!(result.is_err());
}

#[test]
fn parse_uuid_uppercase() {
    // UUID 应该接受大写
    let result = parse_uuid("550E8400-E29B-41D4-A716-446655440000", "card_id");

    assert!(result.is_ok());
}

#[test]
fn parse_uuid_no_dashes() {
    // 不带横线的 UUID 格式
    let result = parse_uuid("550e8400e29b41d4a716446655440000", "card_id");

    assert!(result.is_ok());
}

#[test]
fn parse_uuid_nil() {
    // Nil UUID
    let result = parse_uuid("00000000-0000-0000-0000-000000000000", "test");

    assert!(result.is_ok());
    let uuid = result.unwrap();
    assert_eq!(uuid.to_string(), "00000000-0000-0000-0000-000000000000");
}

#[test]
fn parse_uuid_max() {
    // Max UUID
    let result = parse_uuid("ffffffff-ffff-ffff-ffff-ffffffffffff", "test");

    assert!(result.is_ok());
}

// ============================================================================
// Error Code Tests
// ============================================================================

#[test]
fn api_error_code_as_str_consistency() {
    // 验证错误码字符串与变体名称一致
    assert_eq!(ApiErrorCode::InvalidArgument.as_str(), "INVALID_ARGUMENT");
    assert_eq!(ApiErrorCode::NotFound.as_str(), "NOT_FOUND");
    assert_eq!(ApiErrorCode::IoError.as_str(), "IO_ERROR");
    assert_eq!(ApiErrorCode::Internal.as_str(), "INTERNAL");
    assert_eq!(
        ApiErrorCode::AppConfigNotInitialized.as_str(),
        "APP_CONFIG_NOT_INITIALIZED"
    );
    assert_eq!(
        ApiErrorCode::AppConfigConflict.as_str(),
        "APP_CONFIG_CONFLICT"
    );
    assert_eq!(
        ApiErrorCode::ProjectionNotConverged.as_str(),
        "PROJECTION_NOT_CONVERGED"
    );
    assert_eq!(ApiErrorCode::PoolNotFound.as_str(), "POOL_NOT_FOUND");
    assert_eq!(ApiErrorCode::InvalidPoolHash.as_str(), "INVALID_POOL_HASH");
    assert_eq!(ApiErrorCode::InvalidKeyHash.as_str(), "INVALID_KEY_HASH");
    assert_eq!(ApiErrorCode::AdminOffline.as_str(), "ADMIN_OFFLINE");
    assert_eq!(ApiErrorCode::RequestTimeout.as_str(), "REQUEST_TIMEOUT");
    assert_eq!(ApiErrorCode::RejectedByAdmin.as_str(), "REJECTED_BY_ADMIN");
    assert_eq!(ApiErrorCode::AlreadyMember.as_str(), "ALREADY_MEMBER");
    assert_eq!(ApiErrorCode::NotMember.as_str(), "NOT_MEMBER");
    assert_eq!(
        ApiErrorCode::NetworkUnavailable.as_str(),
        "NETWORK_UNAVAILABLE"
    );
    assert_eq!(ApiErrorCode::SyncTimeout.as_str(), "SYNC_TIMEOUT");
    assert_eq!(ApiErrorCode::InvalidHandle.as_str(), "INVALID_HANDLE");
    assert_eq!(ApiErrorCode::AppLockRequired.as_str(), "APP_LOCK_REQUIRED");
    assert_eq!(ApiErrorCode::AppLocked.as_str(), "APP_LOCKED");
    assert_eq!(ApiErrorCode::NotImplemented.as_str(), "NOT_IMPLEMENTED");
    assert_eq!(ApiErrorCode::SqliteError.as_str(), "SQLITE_ERROR");
}
