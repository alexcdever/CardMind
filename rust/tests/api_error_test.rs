// input: rust/tests/api_error_test.rs 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Rust 测试模块，验证关键行为、边界条件与错误路径。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Rust 测试模块，验证关键行为、边界条件与错误路径。
use cardmind_rust::models::api_error::{ApiError, ApiErrorCode};

#[test]
fn it_should_have_non_empty_error_code_and_message() {
    let err = ApiError::new(ApiErrorCode::InvalidArgument, "msg");
    assert!(!err.code.is_empty());
    assert!(!err.message.is_empty());
}

#[test]
fn it_should_format_not_member_error_code() {
    assert_eq!(ApiErrorCode::NotMember.as_str(), "NOT_MEMBER");
}
