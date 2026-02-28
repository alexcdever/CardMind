// input: new_uuid_v7 生成函数调用请求。
// output: 断言返回 UUID 的版本号为 v7。
// pos: 覆盖 UUID v7 生成器输出规范场景的回归测试。修改本文件需同步更新文件头与所属 DIR.md。
use cardmind_rust::utils::uuid_v7::new_uuid_v7;

#[test]
fn it_should_generate_uuid_v7() {
    let value = new_uuid_v7();
    assert_eq!(value.get_version_num(), 7);
}
