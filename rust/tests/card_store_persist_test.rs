use cardmind_rust::store::card_store::CardStore;
use tempfile::tempdir;

#[test]
fn it_should_create_and_read_card_from_sqlite() -> Result<(), Box<dyn std::error::Error>> {
    let dir = tempdir()?;
    let store = CardStore::new(dir.path().to_string_lossy().as_ref())?;
    let card = store.create_card("t", "c")?;
    let loaded = store.get_card(&card.id)?;
    assert_eq!(loaded.title, "t");
    Ok(())
}
