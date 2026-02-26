// input: 
// output: 
// pos: 
use cardmind_rust::store::sqlite_store::SqliteStore;
use tempfile::tempdir;

#[test]
fn it_should_init_schema() -> Result<(), Box<dyn std::error::Error>> {
    let dir = tempdir()?;
    let db_path = dir.path().join("cardmind.sqlite");
    let store = SqliteStore::new(&db_path)?;
    assert!(store.is_ready());
    Ok(())
}
