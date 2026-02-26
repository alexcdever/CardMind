// input: 临时 SQLite 数据库与 Pool 数据
// output: SQLite 数据池读写校验
// pos: SQLite 数据池测试（修改本文件需同步更新文件头与所属 DIR.md）
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
        pool_key: "k".to_string(),
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
    assert_eq!(loaded.pool_key, "k");
    assert_eq!(loaded.members.len(), 1);
    Ok(())
}
