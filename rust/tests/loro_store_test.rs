// input: rust/tests/loro_store_test.rs 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Rust 测试模块，验证关键行为、边界条件与错误路径。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Rust 测试模块，验证关键行为、边界条件与错误路径。
use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use base64::Engine;
use cardmind_rust::store::loro_store::{note_doc_path, pool_doc_path};
use std::path::Path;
use uuid::Uuid;

#[test]
fn it_should_build_note_path() {
    let id = Uuid::now_v7();
    let path = note_doc_path(&id);
    let expected = Path::new("data")
        .join("loro")
        .join("note")
        .join(URL_SAFE_NO_PAD.encode(id.as_bytes()));
    assert!(path.ends_with(expected));
}

#[test]
fn it_should_build_pool_path() {
    let id = Uuid::now_v7();
    let path = pool_doc_path(&id);
    let expected = Path::new("data")
        .join("loro")
        .join("pool")
        .join(URL_SAFE_NO_PAD.encode(id.as_bytes()));
    assert!(path.ends_with(expected));
}
