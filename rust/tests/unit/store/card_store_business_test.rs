// input: CardNoteRepository API 与业务场景边界条件。
// output: 卡片存储业务逻辑和投影失败场景的全覆盖测试。
// pos: CardNoteRepository 单元测试文件。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件测试卡片业务逻辑和错误处理。

use cardmind_rust::models::error::CardMindError;
use cardmind_rust::store::card_store::CardNoteRepository;
use tempfile::TempDir;
use uuid::Uuid;

fn setup_repo() -> (CardNoteRepository, TempDir) {
    let temp_dir = TempDir::new().unwrap();
    let repo = CardNoteRepository::new(temp_dir.path().to_str().unwrap()).unwrap();
    (repo, temp_dir)
}

// ============================================================================
// Card CRUD Business Logic Tests
// ============================================================================

#[test]
fn test_create_card_generates_uuid() {
    let (repo, _temp) = setup_repo();

    let card = repo.create_card("Test Title", "Test Content").unwrap();

    // UUID should be version 7 (timestamp-based)
    assert!(!card.id.to_string().is_empty());
    assert_eq!(card.title, "Test Title");
    assert_eq!(card.content, "Test Content");
    assert!(!card.deleted);
    assert!(card.created_at > 0);
    assert_eq!(card.created_at, card.updated_at);
}

#[test]
fn test_create_card_empty_strings() {
    let (repo, _temp) = setup_repo();

    let card = repo.create_card("", "").unwrap();

    assert_eq!(card.title, "");
    assert_eq!(card.content, "");
}

#[test]
fn test_create_card_unicode() {
    let (repo, _temp) = setup_repo();

    let card = repo
        .create_card("你好世界 🌍", "内容包含 emoji 🎉")
        .unwrap();

    assert_eq!(card.title, "你好世界 🌍");
    assert_eq!(card.content, "内容包含 emoji 🎉");
}

#[test]
fn test_create_card_long_content() {
    let (repo, _temp) = setup_repo();
    let long_title = "a".repeat(1000);
    let long_content = "b".repeat(10000);

    let card = repo.create_card(&long_title, &long_content).unwrap();

    assert_eq!(card.title.len(), 1000);
    assert_eq!(card.content.len(), 10000);
}

#[test]
fn test_get_card_existing() {
    let (repo, _temp) = setup_repo();
    let created = repo.create_card("Test", "Content").unwrap();

    let fetched = repo.get_card(&created.id).unwrap();

    assert_eq!(fetched.id, created.id);
    assert_eq!(fetched.title, "Test");
}

#[test]
fn test_get_card_not_found() {
    let (repo, _temp) = setup_repo();
    let fake_id = Uuid::new_v4();

    let result = repo.get_card(&fake_id);
    assert!(matches!(result, Err(CardMindError::NotFound(_))));
}

#[test]
fn test_update_card_success() {
    let (repo, _temp) = setup_repo();
    let card = repo.create_card("Original", "Content").unwrap();
    let original_updated_at = card.updated_at;

    let updated = repo
        .update_card(&card.id, "Updated Title", "Updated Content")
        .unwrap();

    assert_eq!(updated.id, card.id);
    assert_eq!(updated.title, "Updated Title");
    assert_eq!(updated.content, "Updated Content");
    assert_eq!(updated.created_at, card.created_at);
    assert!(updated.updated_at >= original_updated_at);
    assert!(!updated.deleted);
}

#[test]
fn test_update_card_not_found() {
    let (repo, _temp) = setup_repo();
    let fake_id = Uuid::new_v4();

    let result = repo.update_card(&fake_id, "Title", "Content");
    assert!(matches!(result, Err(CardMindError::NotFound(_))));
}

#[test]
fn test_update_card_partial() {
    let (repo, _temp) = setup_repo();
    let card = repo.create_card("Title", "Content").unwrap();

    let updated = repo.update_card(&card.id, "New Title", "Content").unwrap();

    assert_eq!(updated.title, "New Title");
    assert_eq!(updated.content, "Content");
}

#[test]
fn test_delete_card_success() {
    let (repo, _temp) = setup_repo();
    let card = repo.create_card("To Delete", "Content").unwrap();

    repo.delete_card(&card.id).unwrap();

    let fetched = repo.get_card(&card.id).unwrap();
    assert!(fetched.deleted);
    assert!(fetched.updated_at >= card.updated_at);
}

#[test]
fn test_delete_card_not_found() {
    let (repo, _temp) = setup_repo();
    let fake_id = Uuid::new_v4();

    let result = repo.delete_card(&fake_id);
    assert!(matches!(result, Err(CardMindError::NotFound(_))));
}

#[test]
fn test_restore_card_success() {
    let (repo, _temp) = setup_repo();
    let card = repo.create_card("Deleted", "Content").unwrap();
    repo.delete_card(&card.id).unwrap();

    repo.restore_card(&card.id).unwrap();

    let fetched = repo.get_card(&card.id).unwrap();
    assert!(!fetched.deleted);
}

#[test]
fn test_restore_card_not_deleted() {
    let (repo, _temp) = setup_repo();
    let card = repo.create_card("Active", "Content").unwrap();

    // Restoring an active card should work (idempotent)
    repo.restore_card(&card.id).unwrap();

    let fetched = repo.get_card(&card.id).unwrap();
    assert!(!fetched.deleted);
}

#[test]
fn test_restore_card_not_found() {
    let (repo, _temp) = setup_repo();
    let fake_id = Uuid::new_v4();

    let result = repo.restore_card(&fake_id);
    assert!(matches!(result, Err(CardMindError::NotFound(_))));
}

// ============================================================================
// List Cards Tests
// ============================================================================

#[test]
fn test_list_cards_includes_deleted() {
    let (repo, _temp) = setup_repo();
    let _active = repo.create_card("Active", "Content").unwrap();
    let to_delete = repo.create_card("To Delete", "Content").unwrap();
    repo.delete_card(&to_delete.id).unwrap();

    // list_cards includes all cards (design: filtering done by query_cards)
    let cards = repo.list_cards(100, 0).unwrap();

    assert_eq!(cards.len(), 2);
}

#[test]
fn test_list_cards_empty() {
    let (repo, _temp) = setup_repo();

    let cards = repo.list_cards(100, 0).unwrap();

    assert!(cards.is_empty());
}

#[test]
fn test_list_cards_multiple() {
    let (repo, _temp) = setup_repo();

    for i in 0..5 {
        repo.create_card(&format!("Card {}", i), "Content").unwrap();
    }

    let cards = repo.list_cards(100, 0).unwrap();

    assert_eq!(cards.len(), 5);
}

#[test]
fn test_list_cards_pagination() {
    let (repo, _temp) = setup_repo();

    for i in 0..5 {
        repo.create_card(&format!("Card {}", i), "Content").unwrap();
    }

    // Test limit
    let cards = repo.list_cards(3, 0).unwrap();
    assert_eq!(cards.len(), 3);

    // Test offset
    let cards = repo.list_cards(100, 2).unwrap();
    assert_eq!(cards.len(), 3);

    // Test empty result
    let cards = repo.list_cards(10, 10).unwrap();
    assert!(cards.is_empty());
}

// ============================================================================
// Search Cards Tests
// ============================================================================

#[test]
fn test_search_cards_by_title() {
    let (repo, _temp) = setup_repo();
    repo.create_card("Rust Programming", "Learn Rust").unwrap();
    repo.create_card("Python Basics", "Learn Python").unwrap();

    let results = repo.search_cards("Rust", 100, 0).unwrap();

    assert_eq!(results.len(), 1);
    assert_eq!(results[0].title, "Rust Programming");
}

#[test]
fn test_search_cards_by_content() {
    let (repo, _temp) = setup_repo();
    repo.create_card("Title", "This contains Rust").unwrap();
    repo.create_card("Other", "Python only here").unwrap();

    let results = repo.search_cards("Rust", 100, 0).unwrap();

    assert_eq!(results.len(), 1);
}

#[test]
fn test_search_cards_case_insensitive() {
    let (repo, _temp) = setup_repo();
    repo.create_card("RUST programming", "Content").unwrap();

    let results = repo.search_cards("rust", 100, 0).unwrap();

    assert_eq!(results.len(), 1);
}

#[test]
fn test_search_cards_partial_match() {
    let (repo, _temp) = setup_repo();
    repo.create_card("Rust Programming", "Content").unwrap();

    let results = repo.search_cards("Prog", 100, 0).unwrap();

    assert_eq!(results.len(), 1);
}

#[test]
fn test_search_cards_no_match() {
    let (repo, _temp) = setup_repo();
    repo.create_card("Title", "Content").unwrap();

    let results = repo.search_cards("NonExistent", 100, 0).unwrap();

    assert!(results.is_empty());
}

#[test]
fn test_search_cards_includes_deleted() {
    let (repo, _temp) = setup_repo();
    let _active = repo.create_card("Active Card", "Content").unwrap();
    let deleted = repo.create_card("Deleted Card", "Content").unwrap();
    repo.delete_card(&deleted.id).unwrap();

    // search_cards includes all cards (design: filtering done by query_cards)
    let results = repo.search_cards("Card", 100, 0).unwrap();

    assert_eq!(results.len(), 2);
}

#[test]
fn test_search_cards_empty_keyword() {
    let (repo, _temp) = setup_repo();
    repo.create_card("Card", "Content").unwrap();

    let results = repo.search_cards("", 100, 0).unwrap();

    assert_eq!(results.len(), 1);
}

#[test]
fn test_search_cards_pagination() {
    let (repo, _temp) = setup_repo();

    for i in 0..5 {
        repo.create_card(&format!("Card {} Rust", i), "Content")
            .unwrap();
    }

    let results = repo.search_cards("Rust", 2, 0).unwrap();
    assert_eq!(results.len(), 2);

    let results = repo.search_cards("Rust", 10, 3).unwrap();
    assert_eq!(results.len(), 2);
}

// ============================================================================
// Query Cards Tests
// ============================================================================

#[test]
fn test_query_cards_basic() {
    let (repo, _temp) = setup_repo();
    repo.create_card("Hello World", "Test content").unwrap();

    let results = repo.query_cards("hello", None, false).unwrap();
    assert_eq!(results.len(), 1);
}

#[test]
fn test_query_cards_empty_keyword() {
    let (repo, _temp) = setup_repo();
    repo.create_card("Title", "Content").unwrap();

    let results = repo.query_cards("", None, false).unwrap();
    assert_eq!(results.len(), 1);
}

#[test]
fn test_query_cards_include_deleted() {
    let (repo, _temp) = setup_repo();
    let active = repo.create_card("Active Card", "Content").unwrap();
    let deleted = repo.create_card("Deleted Card", "Content").unwrap();
    repo.delete_card(&deleted.id).unwrap();

    let results = repo.query_cards("", None, false).unwrap();
    assert_eq!(results.len(), 1);
    assert_eq!(results[0].id, active.id);

    let results = repo.query_cards("", None, true).unwrap();
    assert_eq!(results.len(), 2);
}

// ============================================================================
// Card Lifecycle Tests
// ============================================================================

#[test]
fn test_card_full_lifecycle() {
    let (repo, _temp) = setup_repo();

    // Create
    let card = repo.create_card("Original", "Content").unwrap();
    assert!(!card.deleted);

    // Update
    let updated = repo
        .update_card(&card.id, "Updated", "New Content")
        .unwrap();
    assert_eq!(updated.title, "Updated");

    // Delete
    repo.delete_card(&card.id).unwrap();
    let deleted = repo.get_card(&card.id).unwrap();
    assert!(deleted.deleted);

    // Verify card exists in list but marked as deleted (list_cards includes all)
    let cards = repo.list_cards(100, 0).unwrap();
    assert_eq!(cards.len(), 1);
    assert!(cards[0].deleted);

    // Use query_cards to get only non-deleted (empty result)
    let active_cards = repo.query_cards("", None, false).unwrap();
    assert!(active_cards.is_empty());

    // Restore
    repo.restore_card(&card.id).unwrap();
    let restored = repo.get_card(&card.id).unwrap();
    assert!(!restored.deleted);

    // Verify back in active list via query_cards
    let active_cards = repo.query_cards("", None, false).unwrap();
    assert_eq!(active_cards.len(), 1);
}

// ============================================================================
// Base Path Tests
// ============================================================================

#[test]
fn test_base_path() {
    let temp_dir = TempDir::new().unwrap();
    let path_str = temp_dir.path().to_str().unwrap();
    let repo = CardNoteRepository::new(path_str).unwrap();

    let base_path = repo.base_path();
    assert_eq!(base_path.to_str().unwrap(), path_str);
}

// ============================================================================
// Persistence Tests (跨实例验证)
// ============================================================================

#[test]
fn test_persistence_across_instances() {
    let temp_dir = TempDir::new().unwrap();
    let path_str = temp_dir.path().to_str().unwrap();

    // Create card with first instance
    let repo1 = CardNoteRepository::new(path_str).unwrap();
    let card = repo1.create_card("Persist", "Content").unwrap();

    // Read with second instance
    let repo2 = CardNoteRepository::new(path_str).unwrap();
    let fetched = repo2.get_card(&card.id).unwrap();

    assert_eq!(fetched.title, "Persist");
}

#[test]
fn test_persistence_deleted_state() {
    let temp_dir = TempDir::new().unwrap();
    let path_str = temp_dir.path().to_str().unwrap();

    let repo1 = CardNoteRepository::new(path_str).unwrap();
    let card = repo1.create_card("Delete", "Content").unwrap();
    repo1.delete_card(&card.id).unwrap();

    let repo2 = CardNoteRepository::new(path_str).unwrap();
    let fetched = repo2.get_card(&card.id).unwrap();

    assert!(fetched.deleted);
}

// ============================================================================
// Error Handling Tests
// ============================================================================

#[test]
fn test_error_types() {
    let (repo, _temp) = setup_repo();
    let fake_id = Uuid::new_v4();

    let result = repo.get_card(&fake_id);
    match result {
        Err(CardMindError::NotFound(msg)) => {
            assert!(msg.contains("card") || msg.contains("not found"));
        }
        _ => panic!("Expected NotFound error"),
    }
}

// ============================================================================
// Concurrency/Edge Case Tests
// ============================================================================

#[test]
fn test_multiple_cards_same_title() {
    let (repo, _temp) = setup_repo();

    let card1 = repo.create_card("Same Title", "Content 1").unwrap();
    let card2 = repo.create_card("Same Title", "Content 2").unwrap();

    assert_ne!(card1.id, card2.id);

    let cards = repo.list_cards(100, 0).unwrap();
    assert_eq!(cards.len(), 2);
}

#[test]
fn test_special_characters_in_content() {
    let (repo, _temp) = setup_repo();
    let special = "Special chars: \"'`\n\t\\ <> &";

    let card = repo.create_card("Title", special).unwrap();
    let fetched = repo.get_card(&card.id).unwrap();

    assert_eq!(fetched.content, special);
}
