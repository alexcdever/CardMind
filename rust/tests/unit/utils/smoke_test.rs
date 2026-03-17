// input: 测试框架触发 smoke 用例的执行请求。
// output: 构造公开错误类型以验证 crate 对外符号可用且测试可执行通过。
// pos: 覆盖基础构建冒烟场景的回归测试。修改本文件需同步更新文件头与所属 DIR.md。
#[test]
fn it_should_build_crate() {
    let _ = cardmind_rust::models::error::CardMindError::Internal("smoke".to_string());
}
