// input: rust/tests/sync_api_contract_test.rs 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Rust 测试模块，验证关键行为、边界条件与错误路径。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Rust 测试模块，验证关键行为、边界条件与错误路径。
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
