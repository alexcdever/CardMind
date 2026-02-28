// input: rust/tests/sqlite_store_pool_test.rs 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Rust 测试模块，验证关键行为、边界条件与错误路径。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Rust 测试模块，验证关键行为、边界条件与错误路径。
use cardmind_rust::models::pool::{Pool, PoolMember};
use cardmind_rust::store::sqlite_store::SqliteStore;
use tempfile::tempdir;
use uuid::Uuid;

#[test]
fn it_should_upsert_and_get_pool() -> Result<(), Box<dyn std::error::Error>> {
    let dir = tempdir()?;
    let path = dir.path().join("cardmind.sqlite");
    let store = SqliteStore::new(&path)?;
    let pool = Pool {
        pool_id: Uuid::now_v7(),
        members: vec![PoolMember {
            endpoint_id: "p".to_string(),
            nickname: "n".to_string(),
            os: "os".to_string(),
            is_admin: true,
        }],
        card_ids: vec![Uuid::now_v7()],
    };
    store.upsert_pool(&pool)?;
    let loaded = store.get_pool(&pool.pool_id)?;
    assert_eq!(loaded.members.len(), 1);
    Ok(())
}
