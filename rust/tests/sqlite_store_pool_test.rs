// input: 
// output: 
// pos: 
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
            peer_id: "p".to_string(),
            public_key: "pk".to_string(),
            multiaddr: "addr".to_string(),
            os: "os".to_string(),
            hostname: "h".to_string(),
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
