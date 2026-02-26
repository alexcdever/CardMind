// input: 
// output: 
// pos: 
use cardmind_rust::models::card::Card;
use uuid::Uuid;

#[test]
fn it_should_do_something() {
    let card = Card {
        id: Uuid::nil(),
        title: "title".to_string(),
        content: "content".to_string(),
        created_at: 1,
        updated_at: 2,
        deleted: false,
    };

    assert_eq!(card.title, "title");
    assert_eq!(card.content, "content");
}
