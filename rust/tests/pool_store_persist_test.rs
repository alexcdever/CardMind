// input: 
// output: 
// pos: 
use cardmind_rust::store::pool_store::PoolStore;
use tempfile::tempdir;

#[test]
fn it_should_create_and_read_pool() -> Result<(), Box<dyn std::error::Error>> {
    let dir = tempdir()?;
    let store = PoolStore::new(dir.path().to_string_lossy().as_ref())?;
    let pool = store.create_pool("key", "peer", "pk", "addr", "os", "host")?;
    let loaded = store.get_pool(&pool.pool_id)?;
    assert_eq!(loaded.pool_key, "key");
    Ok(())
}
