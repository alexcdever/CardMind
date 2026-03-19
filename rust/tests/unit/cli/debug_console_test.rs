// input: DebugConsole 的各种命令输入和错误场景。
// output: CLI 命令解析和执行的全覆盖测试。
// pos: CLI 单元测试文件。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件测试 DebugConsole 命令处理。

use cardmind_rust::application::backend_service::BackendService;
use cardmind_rust::cli::DebugConsole;
use cardmind_rust::models::api_error::ApiErrorCode;
use std::sync::Arc;
use tempfile::TempDir;

fn setup_console() -> (DebugConsole, TempDir) {
    let dir = TempDir::new().unwrap();
    let service = Arc::new(BackendService::new(dir.path().to_str().unwrap()).unwrap());
    let console = DebugConsole::new(service);
    (console, dir)
}

// ============================================================================
// Valid Command Tests
// ============================================================================

#[test]
fn get_backend_config_returns_valid_json() {
    let (console, _dir) = setup_console();

    let result = console
        .run_json(r#"{"command":"get_backend_config"}"#)
        .unwrap();

    assert!(result.contains("http_enabled"));
    assert!(result.contains("mcp_enabled"));
    assert!(result.contains("cli_enabled"));
}

#[test]
fn get_runtime_entry_status_returns_valid_json() {
    let (console, _dir) = setup_console();

    let result = console
        .run_json(r#"{"command":"get_runtime_entry_status"}"#)
        .unwrap();

    assert!(result.contains("http_active"));
    assert!(result.contains("mcp_active"));
    assert!(result.contains("cli_active"));
}

// ============================================================================
// Error Handling Tests
// ============================================================================

#[test]
fn invalid_json_returns_error() {
    let (console, _dir) = setup_console();

    let result = console.run_json("not valid json");

    assert!(result.is_err());
    let err = result.unwrap_err();
    assert_eq!(err.code, ApiErrorCode::InvalidArgument.as_str());
    assert!(err.message.contains("Invalid JSON"));
}

#[test]
fn empty_string_returns_error() {
    let (console, _dir) = setup_console();

    let result = console.run_json("");

    assert!(result.is_err());
}

#[test]
fn missing_command_field_returns_error() {
    let (console, _dir) = setup_console();

    let result = console.run_json(r#"{"foo":"bar"}"#);

    assert!(result.is_err());
    let err = result.unwrap_err();
    assert_eq!(err.code, ApiErrorCode::InvalidArgument.as_str());
    assert!(err.message.contains("Missing 'command' field"));
}

#[test]
fn null_command_returns_error() {
    let (console, _dir) = setup_console();

    let result = console.run_json(r#"{"command":null}"#);

    assert!(result.is_err());
    let err = result.unwrap_err();
    assert!(err.message.contains("Missing 'command' field"));
}

#[test]
fn number_command_returns_error() {
    let (console, _dir) = setup_console();

    let result = console.run_json(r#"{"command":123}"#);

    assert!(result.is_err());
}

#[test]
fn unknown_command_returns_error() {
    let (console, _dir) = setup_console();

    let result = console.run_json(r#"{"command":"unknown_cmd"}"#);

    assert!(result.is_err());
    let err = result.unwrap_err();
    assert_eq!(err.code, ApiErrorCode::InvalidArgument.as_str());
    assert!(err.message.contains("Unknown command"));
    assert!(err.message.contains("unknown_cmd"));
}

// ============================================================================
// Edge Cases
// ============================================================================

#[test]
fn command_with_extra_params_ignored() {
    let (console, _dir) = setup_console();

    // Extra params should be ignored
    let result = console
        .run_json(r#"{"command":"get_backend_config","extra":"value","foo":123}"#)
        .unwrap();

    assert!(result.contains("http_enabled"));
}

#[test]
fn command_with_whitespace_json() {
    let (console, _dir) = setup_console();

    let result = console
        .run_json(
            r#"{
            "command": "get_backend_config"
        }"#,
        )
        .unwrap();

    assert!(result.contains("http_enabled"));
}

#[test]
fn empty_command_string_returns_error() {
    let (console, _dir) = setup_console();

    let result = console.run_json(r#"{"command":""}"#);

    assert!(result.is_err());
    let err = result.unwrap_err();
    assert!(err.message.contains("Unknown command"));
}

#[test]
fn unicode_in_command_name() {
    let (console, _dir) = setup_console();

    let result = console.run_json(r#"{"command":"命令"}"#);

    assert!(result.is_err());
}
