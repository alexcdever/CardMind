use cardmind_rust::store::card_store::CardStore;

#[test]
fn it_should_create_card() {
    let store = CardStore::memory();
    let card = store.create_card("t", "c");
    assert_eq!(card.title, "t");
}
