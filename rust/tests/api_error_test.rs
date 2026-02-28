// input: ApiError/ApiErrorCode 构造参数与错误码枚举值。
// output: 断言错误码字符串与错误消息字段满足 API 约定。
// pos: 覆盖 API 错误结构与编码映射场景的回归测试。修改本文件需同步更新文件头与所属 DIR.md。
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
