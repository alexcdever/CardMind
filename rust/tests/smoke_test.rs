// input: 测试框架触发 smoke 用例的执行请求。
// output: 断言占位 smoke 断言（assert!(true)）可执行通过。
// pos: 覆盖基础构建冒烟场景的回归测试。修改本文件需同步更新文件头与所属 DIR.md。
#[test]
fn it_should_build_crate() {
    assert!(true);
}
