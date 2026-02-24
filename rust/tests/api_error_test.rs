use cardmind_rust::models::api_error::{ApiError, ApiErrorCode};

#[test]
fn it_should_have_non_empty_error_code_and_message() {
    let err = ApiError::new(ApiErrorCode::InvalidArgument, "msg");
    assert!(!err.code.is_empty());
    assert!(!err.message.is_empty());
}
