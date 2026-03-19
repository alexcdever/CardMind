// input: CardMindError 的各种变体和参数。
// output: 错误消息格式的验证。
// pos: 错误类型单元测试文件。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件测试错误类型的消息格式。

use cardmind_rust::models::error::CardMindError;

// ============================================================================
// Error Message Format Tests
// ============================================================================

#[test]
fn io_error_message() {
    let err = CardMindError::Io("disk full".to_string());
    let msg = format!("{}", err);
    assert!(msg.contains("io error"));
    assert!(msg.contains("disk full"));
}

#[test]
fn sqlite_error_message() {
    let err = CardMindError::Sqlite("constraint failed".to_string());
    let msg = format!("{}", err);
    assert!(msg.contains("sqlite error"));
    assert!(msg.contains("constraint failed"));
}

#[test]
fn loro_error_message() {
    let err = CardMindError::Loro("sync failed".to_string());
    let msg = format!("{}", err);
    assert!(msg.contains("loro error"));
    assert!(msg.contains("sync failed"));
}

#[test]
fn invalid_argument_error_message() {
    let err = CardMindError::InvalidArgument("bad input".to_string());
    let msg = format!("{}", err);
    assert!(msg.contains("invalid argument"));
    assert!(msg.contains("bad input"));
}

#[test]
fn not_found_error_message() {
    let err = CardMindError::NotFound("card missing".to_string());
    let msg = format!("{}", err);
    assert!(msg.contains("not found"));
    assert!(msg.contains("card missing"));
}

#[test]
fn projection_not_converged_error_message() {
    let err = CardMindError::ProjectionNotConverged {
        entity: "card".to_string(),
        entity_id: "123".to_string(),
        retry_action: "retry_sync".to_string(),
    };
    let msg = format!("{}", err);
    assert!(msg.contains("projection not converged"));
    assert!(msg.contains("card"));
    assert!(msg.contains("123"));
    assert!(msg.contains("retry_sync"));
}

#[test]
fn not_implemented_error_message() {
    let err = CardMindError::NotImplemented("feature X".to_string());
    let msg = format!("{}", err);
    assert!(msg.contains("not implemented"));
    assert!(msg.contains("feature X"));
}

#[test]
fn not_member_error_message() {
    let err = CardMindError::NotMember("access denied".to_string());
    let msg = format!("{}", err);
    assert!(msg.contains("not member"));
    assert!(msg.contains("access denied"));
}

#[test]
fn internal_error_message() {
    let err = CardMindError::Internal("unexpected".to_string());
    let msg = format!("{}", err);
    assert!(msg.contains("internal error"));
    assert!(msg.contains("unexpected"));
}

// ============================================================================
// Error Debug Format Tests
// ============================================================================

#[test]
fn error_debug_format() {
    let err = CardMindError::NotFound("test".to_string());
    let debug = format!("{:?}", err);
    assert!(debug.contains("NotFound"));
}

// ============================================================================
// Error Display vs Debug Tests
// ============================================================================

#[test]
fn display_vs_debug() {
    let err = CardMindError::Io("test".to_string());

    let display = format!("{}", err);
    let debug = format!("{:?}", err);

    // Display 应该是人类可读的
    assert!(display.contains("io error"));
    // Debug 应该包含变体名称
    assert!(debug.contains("Io"));
}
