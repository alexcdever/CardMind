#![allow(clippy::unreadable_literal)]

/// Loro CRDT Integration Tests
///
/// This test suite validates the Loro CRDT integration following Phase 1.3 requirements.
/// Tests are written in TDD style (Red-Green-Refactor).
use loro::{ExportMode, LoroDoc};
use std::sync::{Arc, Mutex};

/// Test 1: Create a `LoroDoc` instance
///
/// Validates that we can create a new Loro document successfully.
/// This is the foundation for all subsequent Loro operations.
#[test]
fn it_should_create_loro_doc() {
    // Given: 无需前置条件

    // When: 创建一个新的 Loro 文档
    let doc = LoroDoc::new();

    // Then: 文档应该成功初始化，具有有效的 peer ID
    let peer_id = doc.peer_id();
    assert!(peer_id > 0, "Peer ID should be a positive number");
}

/// Test 2: Insert data into `LoroMap`
///
/// Validates that we can create a `LoroMap` container and insert key-value pairs.
/// This tests basic write operation needed for card storage.
#[test]
fn it_should_loro_insert_data_to_map() {
    // Given: 一个 Loro 文档
    let doc = LoroDoc::new();

    // When: 创建 LoroMap 容器并插入卡片字段
    let map = doc.get_map("card");
    map.insert("id", "test-uuid-123").unwrap();
    map.insert("title", "Test Card Title").unwrap();
    map.insert("content", "Test card content in Markdown")
        .unwrap();
    map.insert("created_at", 1704067200000i64).unwrap(); // 2024-01-01 00:00:00 UTC
    doc.commit();

    // Then: 应该能够正确读取插入的数据
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
/// This is critical for file persistence (`loro_doc.loro`).
#[test]
fn it_should_loro_export_and_import_snapshot() {
    // Given: 一个包含数据的 Loro 文档
    let doc1 = LoroDoc::new();
    let map = doc1.get_map("card");
    map.insert("id", "card-001").unwrap();
    map.insert("title", "Original Card").unwrap();
    map.insert("content", "Original content").unwrap();
    doc1.commit();

    // When: 导出为快照字节数组并从快照创建新文档
    let snapshot_bytes = doc1.export(ExportMode::Snapshot).unwrap();
    assert!(!snapshot_bytes.is_empty(), "Snapshot should not be empty");

    let doc2 = LoroDoc::from_snapshot(&snapshot_bytes).unwrap();

    // Then: 导入的数据应该与原始数据匹配
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
    // Given: 一个包含数据的 Loro 文档
    let doc1 = LoroDoc::new();
    let map = doc1.get_map("card");
    map.insert("id", "card-002").unwrap();
    map.insert("title", "Update Test").unwrap();
    doc1.commit();

    // When: 导出所有更新并导入到新文档
    let updates = doc1.export(ExportMode::all_updates()).unwrap();
    assert!(!updates.is_empty(), "Updates should not be empty");

    let doc2 = LoroDoc::new();
    let status = doc2.import(&updates).unwrap();

    // Then: 导入应该成功，数据应该匹配，且没有待处理的更新
    assert!(
        status.pending.is_none(),
        "Import should have no pending updates"
    );

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
    // Given: 一个 Loro 文档和订阅回调计数器
    let doc = LoroDoc::new();
    let callback_count = Arc::new(Mutex::new(0));
    let callback_count_clone = callback_count.clone();

    // When: 订阅文档的所有更改并提交多次
    let _subscription = doc.subscribe_root(Arc::new(move |_event| {
        let mut count = callback_count_clone.lock().unwrap();
        *count += 1;
    }));

    let map = doc.get_map("card");
    map.insert("title", "First Title").unwrap();
    doc.commit();

    map.insert("content", "First Content").unwrap();
    doc.commit();

    map.insert("title", "Updated Title").unwrap();
    doc.commit();

    // Then: 订阅应该被触发 3 次（每次 commit 一次）
    let final_count = *callback_count.lock().unwrap();
    assert_eq!(
        final_count, 3,
        "Subscription should be triggered 3 times (one per commit)"
    );
}

/// Test 6: File persistence integration
///
/// Validates complete cycle: create data → export to file → import from file.
/// This simulates real-world persistence scenario.
#[test]
fn it_should_loro_file_persistence() {
    use std::fs;
    use tempfile::TempDir;

    // Given: 一个临时目录和文件路径
    let temp_dir = TempDir::new().unwrap();
    let file_path = temp_dir.path().join("test_card.loro");

    // When: 创建文档并导出到文件，然后从文件加载
    let doc1 = LoroDoc::new();
    let map = doc1.get_map("card");
    map.insert("id", "persistent-card-001").unwrap();
    map.insert("title", "Persistent Card").unwrap();
    map.insert("content", "This card should survive file save/load")
        .unwrap();
    map.insert("created_at", 1704153600000i64).unwrap();
    doc1.commit();

    let snapshot = doc1.export(ExportMode::Snapshot).unwrap();
    fs::write(&file_path, snapshot).unwrap();
    assert!(file_path.exists(), "Loro file should be created");

    let loaded_bytes = fs::read(&file_path).unwrap();
    let doc2 = LoroDoc::from_snapshot(&loaded_bytes).unwrap();

    // Then: 从文件加载的数据应该保持完整性
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
/// Validates that we can store multiple cards in separate `LoroMap` containers.
/// Note: Based on architecture decision, each card will have its own `LoroDoc` file,
/// but this test validates that approach works.
#[test]
fn it_should_multiple_cards_in_document() {
    // Given: 一个 Loro 文档
    let doc = LoroDoc::new();

    // When: 创建两个独立的 LoroMap 容器存储不同卡片
    let card1 = doc.get_map("card_1");
    card1.insert("id", "card-001").unwrap();
    card1.insert("title", "First Card").unwrap();
    card1.insert("content", "First content").unwrap();

    let card2 = doc.get_map("card_2");
    card2.insert("id", "card-002").unwrap();
    card2.insert("title", "Second Card").unwrap();
    card2.insert("content", "Second content").unwrap();

    doc.commit();

    // Then: 应该能够读取所有卡片，并且能够导出导入
    let c1_title = card1.get("title").unwrap().into_value().unwrap();
    assert_eq!(c1_title.as_string().unwrap().to_string(), "First Card");

    let c2_title = card2.get("title").unwrap().into_value().unwrap();
    assert_eq!(c2_title.as_string().unwrap().to_string(), "Second Card");

    let snapshot = doc.export(ExportMode::Snapshot).unwrap();
    let doc2 = LoroDoc::from_snapshot(&snapshot).unwrap();

    let loaded_card1 = doc2.get_map("card_1");
    let loaded_title = loaded_card1.get("title").unwrap().into_value().unwrap();
    assert_eq!(loaded_title.as_string().unwrap().to_string(), "First Card");
}
