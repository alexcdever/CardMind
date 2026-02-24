use cardmind_rust::api::{close_card_store, init_card_store};

#[test]
fn it_should_init_and_close_card_store() -> Result<(), Box<dyn std::error::Error>> {
    let store_id = init_card_store("/tmp/cardmind".to_string())?;
    close_card_store(store_id)?;
    Ok(())
}
