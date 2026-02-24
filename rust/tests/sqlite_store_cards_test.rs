use cardmind_rust::models::card::Card;
use cardmind_rust::store::sqlite_store::SqliteStore;
use tempfile::tempdir;
use uuid::Uuid;

#[test]
fn it_should_upsert_and_get_card() -> Result<(), Box<dyn std::error::Error>> {
    let dir = tempdir()?;
    let path = dir.path().join("cardmind.sqlite");
    let store = SqliteStore::new(&path)?;
    let card = Card {
        id: Uuid::now_v7(),
        title: "t".to_string(),
        content: "c".to_string(),
        created_at: 1,
        updated_at: 2,
        deleted: false,
    };
    store.upsert_card(&card)?;
    let loaded = store.get_card(&card.id)?;
    assert_eq!(loaded.title, "t");
    Ok(())
}
