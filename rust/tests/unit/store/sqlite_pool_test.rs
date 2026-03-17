// input: 构造的 Pool/PoolMember 数据与 SQLite upsert/get_pool 查询参数。
// output: 断言池信息可持久化并读取回包含预期成员数量。
// pos: 覆盖 SQLite 数据池持久化写入读取场景的回归测试。修改本文件需同步更新文件头与所属 DIR.md。
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
