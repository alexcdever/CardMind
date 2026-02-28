// input: 无效 network handle 传入 sync_status API 的调用请求。
// output: 断言 API 返回结构化错误且 code/message 字段非空。
// pos: 覆盖同步 API 错误契约一致性场景的回归测试。修改本文件需同步更新文件头与所属 DIR.md。
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
