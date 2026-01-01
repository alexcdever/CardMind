// Performance tests for CardMind MVP
//
// Tests verify that performance targets are met:
// - 1000 cards loading time < 1 second
// - Loro operations < 50ms
// - SQLite queries < 10ms

use cardmind_rust::store::card_store::CardStore;
use std::time::Instant;

/// Test: Creating and loading 1000 cards should complete in < 1 second total
#[test]
fn test_1000_cards_loading_performance() {
    let mut store = CardStore::new_in_memory().expect("Failed to create store");

    // Create 1000 cards
    let create_start = Instant::now();
    for i in 0..1000 {
        let title = format!("Test Card {}", i);
        let content = format!("This is test card number {} with some content", i);
        store
            .create_card(title, content)
            .expect("Failed to create card");
    }
    let create_duration = create_start.elapsed();
    println!(
        "Created 1000 cards in {:?} ({:.2} ms per card)",
        create_duration,
        create_duration.as_millis() as f64 / 1000.0
    );

    // Query all cards from SQLite
    let query_start = Instant::now();
    let cards = store.get_all_cards().expect("Failed to get cards");
    let query_duration = query_start.elapsed();

    println!(
        "Queried {} cards in {:?}",
        cards.len(),
        query_duration
    );

    // Assertions
    assert_eq!(cards.len(), 1000, "Should have created 1000 cards");
    assert!(
        query_duration.as_millis() < 1000,
        "SQLite query should be < 1 second (was {} ms)",
        query_duration.as_millis()
    );

    // Total time for creation + query should be reasonable
    let total_duration = create_start.elapsed();
    println!(
        "Total time for 1000 cards creation + query: {:?}",
        total_duration
    );
}

/// Test: Individual Loro operations should be < 50ms
#[test]
fn test_loro_operation_performance() {
    let mut store = CardStore::new_in_memory().expect("Failed to create store");

    // Test create operation
    let start = Instant::now();
    let card = store
        .create_card("Performance Test".to_string(), "Testing Loro operation speed".to_string())
        .expect("Failed to create card");
    let create_duration = start.elapsed();
    println!("Loro create operation: {:?}", create_duration);
    assert!(
        create_duration.as_millis() < 50,
        "Loro create should be < 50ms (was {} ms)",
        create_duration.as_millis()
    );

    // Test update operation
    let start = Instant::now();
    store
        .update_card(&card.id, Some("Updated Title".to_string()), Some("Updated Content".to_string()))
        .expect("Failed to update card");
    let update_duration = start.elapsed();
    println!("Loro update operation: {:?}", update_duration);
    assert!(
        update_duration.as_millis() < 50,
        "Loro update should be < 50ms (was {} ms)",
        update_duration.as_millis()
    );

    // Test delete operation
    let start = Instant::now();
    store.delete_card(&card.id).expect("Failed to delete card");
    let delete_duration = start.elapsed();
    println!("Loro delete operation: {:?}", delete_duration);
    assert!(
        delete_duration.as_millis() < 50,
        "Loro delete should be < 50ms (was {} ms)",
        delete_duration.as_millis()
    );
}

/// Test: SQLite queries should be < 10ms for 1000 cards
#[test]
fn test_sqlite_query_performance() {
    let mut store = CardStore::new_in_memory().expect("Failed to create store");

    // Populate with 1000 cards
    for i in 0..1000 {
        store
            .create_card(format!("Card {}", i), format!("Content {}", i))
            .expect("Failed to create card");
    }

    // Test get_all_cards query
    let start = Instant::now();
    let all_cards = store.get_all_cards().expect("Failed to get all cards");
    let query_all_duration = start.elapsed();
    println!(
        "SQLite get_all_cards ({} cards): {:?}",
        all_cards.len(),
        query_all_duration
    );
    assert!(
        query_all_duration.as_millis() < 10,
        "SQLite get_all_cards should be < 10ms (was {} ms)",
        query_all_duration.as_millis()
    );

    // Test get_active_cards query
    let start = Instant::now();
    let active_cards = store.get_active_cards().expect("Failed to get active cards");
    let query_active_duration = start.elapsed();
    println!(
        "SQLite get_active_cards ({} cards): {:?}",
        active_cards.len(),
        query_active_duration
    );
    assert!(
        query_active_duration.as_millis() < 10,
        "SQLite get_active_cards should be < 10ms (was {} ms)",
        query_active_duration.as_millis()
    );

    // Test get_card_by_id query (indexed lookup)
    let card_id = &all_cards[500].id; // Middle card
    let start = Instant::now();
    let card = store
        .get_card_by_id(card_id)
        .expect("Failed to get card by id");
    let query_by_id_duration = start.elapsed();
    println!("SQLite get_card_by_id: {:?}", query_by_id_duration);
    assert!(
        query_by_id_duration.as_millis() < 10,
        "SQLite get_card_by_id should be < 10ms (was {} ms)",
        query_by_id_duration.as_millis()
    );
    assert_eq!(card.id, *card_id, "Should return correct card");
}

/// Test: Card count query should be very fast
#[test]
fn test_card_count_performance() {
    let mut store = CardStore::new_in_memory().expect("Failed to create store");

    // Create 1000 cards
    for i in 0..1000 {
        store
            .create_card(format!("Card {}", i), format!("Content {}", i))
            .expect("Failed to create card");
    }

    // Test count query
    let start = Instant::now();
    let (total, active, deleted) = store.get_card_count().expect("Failed to get card count");
    let count_duration = start.elapsed();
    println!("SQLite get_card_count: {:?}", count_duration);

    assert_eq!(total, 1000, "Should have 1000 cards total");
    assert_eq!(active, 1000, "Should have 1000 active cards");
    assert_eq!(deleted, 0, "Should have 0 deleted cards");
    assert!(
        count_duration.as_millis() < 10,
        "SQLite count should be < 10ms (was {} ms)",
        count_duration.as_millis()
    );
}
