/// Loro CRDT Integration Tests
///
/// This test suite validates the Loro CRDT integration following Phase 1.3 requirements.
/// Tests are written in TDD style (Red-Green-Refactor).
use loro::{ExportMode, LoroDoc};
use std::sync::{Arc, Mutex};

/// Test 1: Create a LoroDoc instance
///
/// Validates that we can create a new Loro document successfully.
/// This is the foundation for all subsequent Loro operations.
#[test]
fn it_should_create_loro_doc() {
    // Create a new document
    let doc = LoroDoc::new();

    // Verify we can get peer ID (proves document is initialized)
    let peer_id = doc.peer_id();
    assert!(peer_id > 0, "Peer ID should be a positive number");
}

/// Test 2: Insert data into LoroMap
///
/// Validates that we can create a LoroMap container and insert key-value pairs.
/// This tests the basic write operation needed for card storage.
#[test]
fn it_should_loro_insert_data_to_map() {
    let doc = LoroDoc::new();

    // Create a LoroMap container for storing card data
    let map = doc.get_map("card");

    // Insert card fields
    map.insert("id", "test-uuid-123").unwrap();
    map.insert("title", "Test Card Title").unwrap();
    map.insert("content", "Test card content in Markdown")
        .unwrap();
    map.insert("created_at", 1704067200000i64).unwrap(); // 2024-01-01 00:00:00 UTC

    // Commit to finalize the transaction
    doc.commit();

    // Verify data was inserted correctly
    let value = map.get("id").unwrap().into_value().unwrap();
    assert_eq!(value.as_string().unwrap().to_string(), "test-uuid-123");

    let title = map.get("title").unwrap().into_value().unwrap();
    assert_eq!(title.as_string().unwrap().to_string(), "Test Card Title");

    let content = map.get("content").unwrap().into_value().unwrap();
    assert_eq!(
        content.as_string().unwrap().to_string(),
        "Test card content in Markdown"
    );

    let created_at = map.get("created_at").unwrap().into_value().unwrap();
    assert_eq!(*created_at.as_i64().unwrap(), 1704067200000i64);
}

/// Test 3: Export and import snapshot
///
/// Validates that we can export a Loro document to bytes and reconstruct it.
/// This is critical for file persistence (loro_doc.loro).
#[test]
fn it_should_loro_export_and_import_snapshot() {
    // Create original document with data
    let doc1 = LoroDoc::new();
    let map = doc1.get_map("card");
    map.insert("id", "card-001").unwrap();
    map.insert("title", "Original Card").unwrap();
    map.insert("content", "Original content").unwrap();
    doc1.commit();

    // Export to snapshot bytes
    let snapshot_bytes = doc1.export(ExportMode::Snapshot).unwrap();
    assert!(!snapshot_bytes.is_empty(), "Snapshot should not be empty");

    // Create new document from snapshot
    let doc2 = LoroDoc::from_snapshot(&snapshot_bytes).unwrap();

    // Verify imported data matches original
    let imported_map = doc2.get_map("card");
    let id = imported_map.get("id").unwrap().into_value().unwrap();
    assert_eq!(id.as_string().unwrap().to_string(), "card-001");

    let title = imported_map.get("title").unwrap().into_value().unwrap();
    assert_eq!(title.as_string().unwrap().to_string(), "Original Card");

    let content = imported_map.get("content").unwrap().into_value().unwrap();
    assert_eq!(content.as_string().unwrap().to_string(), "Original content");
}

/// Test 4: Export updates and import
///
/// Validates incremental updates export/import (for P2P sync in Phase 2).
#[test]
fn it_should_loro_export_and_import_updates() {
    // Create original document with data
    let doc1 = LoroDoc::new();
    let map = doc1.get_map("card");
    map.insert("id", "card-002").unwrap();
    map.insert("title", "Update Test").unwrap();
    doc1.commit();

    // Export all updates
    let updates = doc1.export(ExportMode::all_updates()).unwrap();
    assert!(!updates.is_empty(), "Updates should not be empty");

    // Create new document and import updates
    let doc2 = LoroDoc::new();
    let status = doc2.import(&updates).unwrap();

    // Verify import was successful (no pending updates)
    assert!(
        status.pending.is_none(),
        "Import should have no pending updates"
    );

    // Verify data matches
    let imported_map = doc2.get_map("card");
    let id = imported_map.get("id").unwrap().into_value().unwrap();
    assert_eq!(id.as_string().unwrap().to_string(), "card-002");

    let title = imported_map.get("title").unwrap().into_value().unwrap();
    assert_eq!(title.as_string().unwrap().to_string(), "Update Test");
}

/// Test 5: Subscription mechanism
///
/// Validates that we can subscribe to Loro document changes.
/// This is the foundation for Loro → SQLite automatic sync.
#[test]
fn it_should_loro_subscription_mechanism() {
    let doc = LoroDoc::new();

    // Shared state to track subscription callbacks
    let callback_count = Arc::new(Mutex::new(0));
    let callback_count_clone = callback_count.clone();

    // Subscribe to all changes
    let _subscription = doc.subscribe_root(Arc::new(move |_event| {
        let mut count = callback_count_clone.lock().unwrap();
        *count += 1;
    }));

    // Make changes to the document
    let map = doc.get_map("card");
    map.insert("title", "First Title").unwrap();
    doc.commit();

    map.insert("content", "First Content").unwrap();
    doc.commit();

    map.insert("title", "Updated Title").unwrap();
    doc.commit();

    // Verify subscription was triggered for each commit
    let final_count = *callback_count.lock().unwrap();
    assert_eq!(
        final_count, 3,
        "Subscription should be triggered 3 times (one per commit)"
    );
}

/// Test 6: File persistence integration
///
/// Validates the complete cycle: create data → export to file → import from file.
/// This simulates the real-world persistence scenario.
#[test]
fn it_should_loro_file_persistence() {
    use std::fs;
    use tempfile::TempDir;

    // Create temporary directory for test files
    let temp_dir = TempDir::new().unwrap();
    let file_path = temp_dir.path().join("test_card.loro");

    // Step 1: Create document with data
    let doc1 = LoroDoc::new();
    let map = doc1.get_map("card");
    map.insert("id", "persistent-card-001").unwrap();
    map.insert("title", "Persistent Card").unwrap();
    map.insert("content", "This card should survive file save/load")
        .unwrap();
    map.insert("created_at", 1704153600000i64).unwrap();
    doc1.commit();

    // Step 2: Export to file
    let snapshot = doc1.export(ExportMode::Snapshot).unwrap();
    fs::write(&file_path, snapshot).unwrap();

    // Verify file was created
    assert!(file_path.exists(), "Loro file should be created");

    // Step 3: Load from file
    let loaded_bytes = fs::read(&file_path).unwrap();
    let doc2 = LoroDoc::from_snapshot(&loaded_bytes).unwrap();

    // Step 4: Verify data integrity
    let loaded_map = doc2.get_map("card");
    let id = loaded_map.get("id").unwrap().into_value().unwrap();
    assert_eq!(id.as_string().unwrap().to_string(), "persistent-card-001");

    let title = loaded_map.get("title").unwrap().into_value().unwrap();
    assert_eq!(title.as_string().unwrap().to_string(), "Persistent Card");

    let content = loaded_map.get("content").unwrap().into_value().unwrap();
    assert_eq!(
        content.as_string().unwrap().to_string(),
        "This card should survive file save/load"
    );

    let created_at = loaded_map.get("created_at").unwrap().into_value().unwrap();
    assert_eq!(*created_at.as_i64().unwrap(), 1704153600000i64);

    // Cleanup is automatic (TempDir drop)
}

/// Test 7: Multiple cards in document
///
/// Validates that we can store multiple cards in separate LoroMap containers.
/// Note: Based on architecture decision, each card will have its own LoroDoc file,
/// but this test validates that the approach works.
#[test]
fn it_should_multiple_cards_in_document() {
    let doc = LoroDoc::new();

    // Create first card
    let card1 = doc.get_map("card_1");
    card1.insert("id", "card-001").unwrap();
    card1.insert("title", "First Card").unwrap();
    card1.insert("content", "First content").unwrap();

    // Create second card
    let card2 = doc.get_map("card_2");
    card2.insert("id", "card-002").unwrap();
    card2.insert("title", "Second Card").unwrap();
    card2.insert("content", "Second content").unwrap();

    doc.commit();

    // Verify both cards exist
    let c1_title = card1.get("title").unwrap().into_value().unwrap();
    assert_eq!(c1_title.as_string().unwrap().to_string(), "First Card");

    let c2_title = card2.get("title").unwrap().into_value().unwrap();
    assert_eq!(c2_title.as_string().unwrap().to_string(), "Second Card");

    // Verify we can export and import
    let snapshot = doc.export(ExportMode::Snapshot).unwrap();
    let doc2 = LoroDoc::from_snapshot(&snapshot).unwrap();

    let loaded_card1 = doc2.get_map("card_1");
    let loaded_title = loaded_card1.get("title").unwrap().into_value().unwrap();
    assert_eq!(loaded_title.as_string().unwrap().to_string(), "First Card");
}
