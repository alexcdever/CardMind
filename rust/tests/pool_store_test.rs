use cardmind_rust::store::pool_store::PoolStore;
use tempfile::tempdir;

#[test]
fn it_should_create_pool_store() -> Result<(), Box<dyn std::error::Error>> {
    let dir = tempdir()?;
    let _store = PoolStore::new(dir.path().to_string_lossy().as_ref())?;
    Ok(())
}
