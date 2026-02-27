// input: 同步 API 句柄参数
// output: 同步状态接口错误结构
// pos: 同步 API 合同测试（修改本文件需同步更新文件头与所属 DIR.md）
use cardmind_rust::api::*;

#[test]
fn sync_status_should_return_structured_error_when_handle_invalid() {
    let invalid = 999_999_u64;
    let result = sync_status(invalid);
    assert!(result.is_err());
    let err = result.err().unwrap();
    assert!(!err.code.is_empty());
    assert!(!err.message.is_empty());
}
