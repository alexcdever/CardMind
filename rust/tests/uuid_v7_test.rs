// input: rust/tests/uuid_v7_test.rs 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Rust 测试模块，验证关键行为、边界条件与错误路径。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Rust 测试模块，验证关键行为、边界条件与错误路径。
use cardmind_rust::utils::uuid_v7::new_uuid_v7;

#[test]
fn it_should_generate_uuid_v7() {
    let value = new_uuid_v7();
    assert_eq!(value.get_version_num(), 7);
}
