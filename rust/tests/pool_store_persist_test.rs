// input: rust/tests/pool_store_persist_test.rs 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Rust 测试模块，验证关键行为、边界条件与错误路径。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Rust 测试模块，验证关键行为、边界条件与错误路径。
use cardmind_rust::store::pool_store::PoolStore;
use tempfile::tempdir;

#[test]
fn it_should_create_and_read_pool() -> Result<(), Box<dyn std::error::Error>> {
    let dir = tempdir()?;
    let store = PoolStore::new(dir.path().to_string_lossy().as_ref())?;
    let pool = store.create_pool("endpoint", "nickname", "os")?;
    let loaded = store.get_pool(&pool.pool_id)?;
    assert_eq!(loaded.members.len(), 1);
    assert_eq!(loaded.members[0].endpoint_id, "endpoint");
    assert_eq!(loaded.members[0].nickname, "nickname");
    assert_eq!(loaded.members[0].os, "os");
    assert!(loaded.members[0].is_admin);
    Ok(())
}
