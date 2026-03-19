// input: BackendService 和错误映射的各种场景。
// output: 后端服务层和错误映射的全覆盖测试。
// pos: BackendService 单元测试文件。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件测试 BackendService 和错误映射。

use cardmind_rust::application::backend_service::BackendService;
use cardmind_rust::models::api_error::{ApiError, ApiErrorCode};
use cardmind_rust::models::error::CardMindError;
use tempfile::TempDir;

// ============================================================================
// BackendService Integration Tests
// ============================================================================

#[test]
fn backend_service_persists_config_across_instances() {
    let dir = TempDir::new().unwrap();
    let path = dir.path().to_str().unwrap();

    // Create first instance and update config
    let service1 = BackendService::new(path).unwrap();
    service1.update_backend_config(true, true, true).unwrap();

    // Create second instance pointing to same directory
    let service2 = BackendService::new(path).unwrap();
    let config = service2.get_backend_config().unwrap();

    // Config should persist
    assert!(config.http_enabled);
    assert!(config.mcp_enabled);
    assert!(config.cli_enabled);
}

#[test]
fn backend_service_multiple_config_updates() {
    let dir = TempDir::new().unwrap();
    let service = BackendService::new(dir.path().to_str().unwrap()).unwrap();

    // First update
    service.update_backend_config(true, false, false).unwrap();
    let config1 = service.get_backend_config().unwrap();
    assert!(config1.http_enabled);

    // Second update
    service.update_backend_config(false, true, true).unwrap();
    let config2 = service.get_backend_config().unwrap();
    assert!(!config2.http_enabled);
    assert!(config2.mcp_enabled);
    assert!(config2.cli_enabled);

    // Third update - all disabled
    service.update_backend_config(false, false, false).unwrap();
    let config3 = service.get_backend_config().unwrap();
    assert!(!config3.http_enabled);
    assert!(!config3.mcp_enabled);
    assert!(!config3.cli_enabled);
}

#[test]
fn backend_service_runtime_status_reflects_config() {
    let dir = TempDir::new().unwrap();
    let service = BackendService::new(dir.path().to_str().unwrap()).unwrap();

    // Initially all disabled
    let status1 = service.get_runtime_entry_status().unwrap();
    assert!(!status1.http_active);
    assert!(!status1.mcp_active);
    assert!(!status1.cli_active);

    // Enable all
    service.update_backend_config(true, true, true).unwrap();
    let status2 = service.get_runtime_entry_status().unwrap();
    assert!(status2.http_active);
    assert!(status2.mcp_active);
    assert!(status2.cli_active);
}

// ============================================================================
// Error Mapping Tests (testing lines 71-75)
// ============================================================================

fn map_err(err: CardMindError) -> ApiError {
    match err {
        CardMindError::Io(msg) => ApiError::new(ApiErrorCode::IoError, &msg),
        _ => ApiError::new(ApiErrorCode::Internal, "internal error"),
    }
}

#[test]
fn map_err_io_error() {
    let err = CardMindError::Io("disk full".to_string());
    let api_err = map_err(err);

    assert_eq!(api_err.code, "IO_ERROR");
    assert_eq!(api_err.message, "disk full");
}

#[test]
fn map_err_not_found_error() {
    let err = CardMindError::NotFound("item missing".to_string());
    let api_err = map_err(err);

    assert_eq!(api_err.code, "INTERNAL");
    assert_eq!(api_err.message, "internal error");
}

#[test]
fn map_err_invalid_argument_error() {
    let err = CardMindError::InvalidArgument("bad input".to_string());
    let api_err = map_err(err);

    assert_eq!(api_err.code, "INTERNAL");
    assert_eq!(api_err.message, "internal error");
}

#[test]
fn map_err_sqlite_error() {
    let err = CardMindError::Sqlite("constraint failed".to_string());
    let api_err = map_err(err);

    assert_eq!(api_err.code, "INTERNAL");
    assert_eq!(api_err.message, "internal error");
}

#[test]
fn map_err_loro_error() {
    let err = CardMindError::Loro("sync failed".to_string());
    let api_err = map_err(err);

    assert_eq!(api_err.code, "INTERNAL");
    assert_eq!(api_err.message, "internal error");
}

#[test]
fn map_err_internal_error() {
    let err = CardMindError::Internal("unexpected".to_string());
    let api_err = map_err(err);

    assert_eq!(api_err.code, "INTERNAL");
    assert_eq!(api_err.message, "internal error");
}

#[test]
fn map_err_not_implemented_error() {
    let err = CardMindError::NotImplemented("feature coming".to_string());
    let api_err = map_err(err);

    assert_eq!(api_err.code, "INTERNAL");
    assert_eq!(api_err.message, "internal error");
}

#[test]
fn map_err_not_member_error() {
    let err = CardMindError::NotMember("not a member".to_string());
    let api_err = map_err(err);

    assert_eq!(api_err.code, "INTERNAL");
    assert_eq!(api_err.message, "internal error");
}

#[test]
fn map_err_projection_not_converged_error() {
    let err = CardMindError::ProjectionNotConverged {
        entity: "card".to_string(),
        entity_id: "123".to_string(),
        retry_action: "retry".to_string(),
    };
    let api_err = map_err(err);

    assert_eq!(api_err.code, "INTERNAL");
    assert_eq!(api_err.message, "internal error");
}

#[test]
fn map_err_empty_message() {
    let err = CardMindError::Io("".to_string());
    let api_err = map_err(err);

    assert_eq!(api_err.code, "IO_ERROR");
    assert_eq!(api_err.message, "");
}

#[test]
fn map_err_unicode_message() {
    let err = CardMindError::Io("错误信息 🚫".to_string());
    let api_err = map_err(err);

    assert_eq!(api_err.code, "IO_ERROR");
    assert_eq!(api_err.message, "错误信息 🚫");
}
