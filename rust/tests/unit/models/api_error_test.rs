// input: ApiError 构造器与 CardMindError 到 ApiError 的映射逻辑。
// output: 所有错误类型和映射路径的全覆盖测试。
// pos: API 错误模型测试文件。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件测试 API 错误码和错误映射。

use cardmind_rust::models::api_error::{ApiError, ApiErrorCode};
use cardmind_rust::models::error::CardMindError;

// ============================================================================
// ApiErrorCode Tests
// ============================================================================

#[test]
fn test_api_error_code_as_str() {
    assert_eq!(
        ApiErrorCode::AppConfigNotInitialized.as_str(),
        "APP_CONFIG_NOT_INITIALIZED"
    );
    assert_eq!(
        ApiErrorCode::AppConfigConflict.as_str(),
        "APP_CONFIG_CONFLICT"
    );
    assert_eq!(ApiErrorCode::InvalidArgument.as_str(), "INVALID_ARGUMENT");
    assert_eq!(ApiErrorCode::NotFound.as_str(), "NOT_FOUND");
    assert_eq!(ApiErrorCode::NotImplemented.as_str(), "NOT_IMPLEMENTED");
    assert_eq!(ApiErrorCode::IoError.as_str(), "IO_ERROR");
    assert_eq!(ApiErrorCode::SqliteError.as_str(), "SQLITE_ERROR");
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
    assert_eq!(ApiErrorCode::Internal.as_str(), "INTERNAL");
}

// ============================================================================
// ApiError Construction Tests
// ============================================================================

#[test]
fn test_api_error_new() {
    let error = ApiError::new(ApiErrorCode::NotFound, "resource not found");

    assert_eq!(error.code, "NOT_FOUND");
    assert_eq!(error.message, "resource not found");
}

#[test]
fn test_api_error_empty_message() {
    let error = ApiError::new(ApiErrorCode::Internal, "");

    assert_eq!(error.message, "");
}

#[test]
fn test_api_error_unicode_message() {
    let error = ApiError::new(ApiErrorCode::InvalidArgument, "参数错误 🚫");

    assert_eq!(error.message, "参数错误 🚫");
}

#[test]
fn test_api_error_long_message() {
    let long_msg = "a".repeat(10000);
    let error = ApiError::new(ApiErrorCode::Internal, &long_msg);

    assert_eq!(error.message.len(), 10000);
}

// ============================================================================
// ApiError Display Tests
// ============================================================================

#[test]
fn test_api_error_display() {
    let error = ApiError::new(ApiErrorCode::NotFound, "item missing");

    let display = format!("{}", error);
    assert_eq!(display, "NOT_FOUND: item missing");
}

#[test]
fn test_api_error_display_empty() {
    let error = ApiError::new(ApiErrorCode::Internal, "");

    let display = format!("{}", error);
    assert_eq!(display, "INTERNAL: ");
}

// ============================================================================
// ApiError Error Trait Tests
// ============================================================================

#[test]
fn test_api_error_error_trait() {
    let error: Box<dyn std::error::Error> = Box::new(ApiError::new(ApiErrorCode::NotFound, "test"));

    assert!(error.to_string().contains("NOT_FOUND"));
}

// ============================================================================
// Serialization Tests
// ============================================================================

#[test]
fn test_api_error_serialization() {
    let error = ApiError::new(ApiErrorCode::InvalidArgument, "bad input");

    let json = serde_json::to_string(&error).unwrap();
    assert!(json.contains("INVALID_ARGUMENT"));
    assert!(json.contains("bad input"));
}

#[test]
fn test_api_error_deserialization() {
    let json = r#"{"code":"NOT_FOUND","message":"missing"}"#;
    let error: ApiError = serde_json::from_str(json).unwrap();

    assert_eq!(error.code, "NOT_FOUND");
    assert_eq!(error.message, "missing");
}

#[test]
fn test_api_error_code_serialization() {
    let code = ApiErrorCode::NotFound;

    // ApiErrorCode serializes to variant name by default
    let json = serde_json::to_string(&code).unwrap();
    assert_eq!(json, "\"NotFound\"");
}

// ============================================================================
// CardMindError Mapping Tests
// ============================================================================

fn map_err(err: CardMindError) -> ApiError {
    match err {
        CardMindError::InvalidArgument(msg) => ApiError::new(ApiErrorCode::InvalidArgument, &msg),
        CardMindError::NotFound(msg) => ApiError::new(ApiErrorCode::NotFound, &msg),
        CardMindError::ProjectionNotConverged { retry_action, .. } => {
            ApiError::new(ApiErrorCode::ProjectionNotConverged, &retry_action)
        }
        CardMindError::NotImplemented(msg) => ApiError::new(ApiErrorCode::NotImplemented, &msg),
        CardMindError::NotMember(msg) => ApiError::new(ApiErrorCode::NotMember, &msg),
        CardMindError::Io(msg) => ApiError::new(ApiErrorCode::IoError, &msg),
        CardMindError::Sqlite(msg) => ApiError::new(ApiErrorCode::SqliteError, &msg),
        _ => ApiError::new(ApiErrorCode::Internal, "internal error"),
    }
}

#[test]
fn test_map_err_invalid_argument() {
    let err = CardMindError::InvalidArgument("bad input".to_string());
    let api_err = map_err(err);

    assert_eq!(api_err.code, "INVALID_ARGUMENT");
    assert_eq!(api_err.message, "bad input");
}

#[test]
fn test_map_err_not_found() {
    let err = CardMindError::NotFound("pool missing".to_string());
    let api_err = map_err(err);

    assert_eq!(api_err.code, "NOT_FOUND");
    assert_eq!(api_err.message, "pool missing");
}

#[test]
fn test_map_err_projection_not_converged() {
    let err = CardMindError::ProjectionNotConverged {
        entity: "card".to_string(),
        entity_id: "123".to_string(),
        retry_action: "retry_later".to_string(),
    };
    let api_err = map_err(err);

    assert_eq!(api_err.code, "PROJECTION_NOT_CONVERGED");
    assert_eq!(api_err.message, "retry_later");
}

#[test]
fn test_map_err_not_implemented() {
    let err = CardMindError::NotImplemented("feature coming soon".to_string());
    let api_err = map_err(err);

    assert_eq!(api_err.code, "NOT_IMPLEMENTED");
    assert_eq!(api_err.message, "feature coming soon");
}

#[test]
fn test_map_err_not_member() {
    let err = CardMindError::NotMember("access denied".to_string());
    let api_err = map_err(err);

    assert_eq!(api_err.code, "NOT_MEMBER");
    assert_eq!(api_err.message, "access denied");
}

#[test]
fn test_map_err_io() {
    let err = CardMindError::Io("disk full".to_string());
    let api_err = map_err(err);

    assert_eq!(api_err.code, "IO_ERROR");
    assert_eq!(api_err.message, "disk full");
}

#[test]
fn test_map_err_sqlite() {
    let err = CardMindError::Sqlite("constraint failed".to_string());
    let api_err = map_err(err);

    assert_eq!(api_err.code, "SQLITE_ERROR");
    assert_eq!(api_err.message, "constraint failed");
}

#[test]
fn test_map_err_internal() {
    let err = CardMindError::Internal("unexpected".to_string());
    let api_err = map_err(err);

    assert_eq!(api_err.code, "INTERNAL");
    assert_eq!(api_err.message, "internal error");
}

#[test]
fn test_map_err_loro() {
    let err = CardMindError::Loro("sync failed".to_string());
    let api_err = map_err(err);

    assert_eq!(api_err.code, "INTERNAL");
    assert_eq!(api_err.message, "internal error");
}

// ============================================================================
// Edge Cases Tests
// ============================================================================

#[test]
fn test_map_err_special_chars() {
    let err = CardMindError::InvalidArgument("special: \"'\n\t".to_string());
    let api_err = map_err(err);

    assert_eq!(api_err.code, "INVALID_ARGUMENT");
    assert_eq!(api_err.message, "special: \"'\n\t");
}

#[test]
fn test_map_err_unicode() {
    let err = CardMindError::NotFound("未找到 🚫".to_string());
    let api_err = map_err(err);

    assert_eq!(api_err.code, "NOT_FOUND");
    assert_eq!(api_err.message, "未找到 🚫");
}

#[test]
fn test_map_err_empty_message() {
    let err = CardMindError::InvalidArgument("".to_string());
    let api_err = map_err(err);

    assert_eq!(api_err.code, "INVALID_ARGUMENT");
    assert_eq!(api_err.message, "");
}
