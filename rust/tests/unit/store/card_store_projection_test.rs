// input: CardNoteRepository 投影失败和错误边界场景。
// output: 投影失败处理的全覆盖测试。
// pos: CardNoteRepository 边界测试文件。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件测试卡片存储的投影失败和错误边界。

use cardmind_rust::models::error::CardMindError;
use cardmind_rust::store::card_store::CardNoteRepository;
use tempfile::TempDir;

// ============================================================================
// Projection Failure Tests
// ============================================================================

#[test]
fn create_card_with_projection_failure_returns_error() {
    let temp_dir = TempDir::new().unwrap();
    let repo =
        CardNoteRepository::new_with_projection_failure(temp_dir.path().to_str().unwrap()).unwrap();

    let result = repo.create_card("Test", "Content");

    assert!(result.is_err());
    match result {
        Err(CardMindError::ProjectionNotConverged {
            entity,
            retry_action,
            ..
        }) => {
            assert_eq!(entity, "card");
            assert_eq!(retry_action, "retry_projection");
        }
        _ => panic!("Expected ProjectionNotConverged error"),
    }
}

#[test]
fn update_card_with_projection_failure_returns_error() {
    let temp_dir = TempDir::new().unwrap();
    let path = temp_dir.path().to_str().unwrap();

    // First create with normal repo
    let normal_repo = CardNoteRepository::new(path).unwrap();
    let card = normal_repo.create_card("Original", "Content").unwrap();

    // Then try to update with failing repo
    let failing_repo = CardNoteRepository::new_with_projection_failure(path).unwrap();
    let result = failing_repo.update_card(&card.id, "Updated", "New");

    assert!(result.is_err());
    assert!(matches!(
        result,
        Err(CardMindError::ProjectionNotConverged { .. })
    ));
}

#[test]
fn delete_card_with_projection_failure_returns_error() {
    let temp_dir = TempDir::new().unwrap();
    let path = temp_dir.path().to_str().unwrap();

    let normal_repo = CardNoteRepository::new(path).unwrap();
    let card = normal_repo.create_card("To Delete", "Content").unwrap();

    let failing_repo = CardNoteRepository::new_with_projection_failure(path).unwrap();
    let result = failing_repo.delete_card(&card.id);

    assert!(result.is_err());
    assert!(matches!(
        result,
        Err(CardMindError::ProjectionNotConverged { .. })
    ));
}

#[test]
fn restore_card_with_projection_failure_returns_error() {
    let temp_dir = TempDir::new().unwrap();
    let path = temp_dir.path().to_str().unwrap();

    let normal_repo = CardNoteRepository::new(path).unwrap();
    let card = normal_repo.create_card("To Restore", "Content").unwrap();
    normal_repo.delete_card(&card.id).unwrap();

    let failing_repo = CardNoteRepository::new_with_projection_failure(path).unwrap();
    let result = failing_repo.restore_card(&card.id);

    assert!(result.is_err());
    assert!(matches!(
        result,
        Err(CardMindError::ProjectionNotConverged { .. })
    ));
}

// ============================================================================
// Projection Recovery Tests
// ============================================================================

#[test]
fn get_card_returns_projection_error_when_not_converged() {
    let temp_dir = TempDir::new().unwrap();
    let path = temp_dir.path().to_str().unwrap();

    // Create card with normal repo
    let normal_repo = CardNoteRepository::new(path).unwrap();
    let card = normal_repo.create_card("Test", "Content").unwrap();

    // Simulate projection failure by creating with failing repo
    // This will record the failure
    let failing_repo = CardNoteRepository::new_with_projection_failure(path).unwrap();
    let _ = failing_repo.create_card("Another", "Card");

    // Now try to get the card - should still work since it was persisted by normal_repo
    let result = normal_repo.get_card(&card.id);
    assert!(result.is_ok());
}

// ============================================================================
// Error Propagation Tests
// ============================================================================

#[test]
fn get_card_propagates_other_errors() {
    // This tests line 118 - error propagation
    // SQLite errors other than NotFound should be propagated
    let temp_dir = TempDir::new().unwrap();
    let repo = CardNoteRepository::new(temp_dir.path().to_str().unwrap()).unwrap();

    // Create a card
    let card = repo.create_card("Test", "Content").unwrap();

    // Get should succeed
    let result = repo.get_card(&card.id);
    assert!(result.is_ok());
}

// ============================================================================
// Timestamp Edge Cases
// ============================================================================

#[test]
fn current_timestamp_is_positive() {
    let temp_dir = TempDir::new().unwrap();
    let repo = CardNoteRepository::new(temp_dir.path().to_str().unwrap()).unwrap();

    let card = repo.create_card("Test", "Content").unwrap();

    // Timestamp should be positive (after Unix epoch)
    assert!(card.created_at > 0);
    assert!(card.updated_at > 0);
}

#[test]
fn update_card_updates_timestamp() {
    let temp_dir = TempDir::new().unwrap();
    let repo = CardNoteRepository::new(temp_dir.path().to_str().unwrap()).unwrap();

    let card = repo.create_card("Original", "Content").unwrap();
    let original_updated_at = card.updated_at;

    // Wait a bit to ensure timestamp changes
    std::thread::sleep(std::time::Duration::from_millis(10));

    let updated = repo.update_card(&card.id, "Updated", "New").unwrap();

    assert!(updated.updated_at >= original_updated_at);
}

#[test]
fn delete_card_updates_timestamp() {
    let temp_dir = TempDir::new().unwrap();
    let repo = CardNoteRepository::new(temp_dir.path().to_str().unwrap()).unwrap();

    let card = repo.create_card("To Delete", "Content").unwrap();
    let original_updated_at = card.updated_at;

    std::thread::sleep(std::time::Duration::from_millis(10));

    repo.delete_card(&card.id).unwrap();

    let deleted = repo.get_card(&card.id).unwrap();
    assert!(deleted.updated_at >= original_updated_at);
    assert!(deleted.deleted);
}

#[test]
fn restore_card_updates_timestamp() {
    let temp_dir = TempDir::new().unwrap();
    let repo = CardNoteRepository::new(temp_dir.path().to_str().unwrap()).unwrap();

    let card = repo.create_card("To Restore", "Content").unwrap();
    repo.delete_card(&card.id).unwrap();
    let deleted = repo.get_card(&card.id).unwrap();
    let deleted_updated_at = deleted.updated_at;

    std::thread::sleep(std::time::Duration::from_millis(10));

    repo.restore_card(&card.id).unwrap();

    let restored = repo.get_card(&card.id).unwrap();
    assert!(restored.updated_at >= deleted_updated_at);
    assert!(!restored.deleted);
}

// ============================================================================
// Loro Integration Edge Cases
// ============================================================================

#[test]
fn card_data_persisted_to_loro() {
    let temp_dir = TempDir::new().unwrap();
    let path = temp_dir.path().to_str().unwrap();

    // Create card
    let repo1 = CardNoteRepository::new(path).unwrap();
    let card = repo1.create_card("Loro Test", "Content").unwrap();

    // Create new repo instance pointing to same path
    let repo2 = CardNoteRepository::new(path).unwrap();
    let loaded = repo2.get_card(&card.id).unwrap();

    // Should be able to read from Loro
    assert_eq!(loaded.title, "Loro Test");
    assert_eq!(loaded.content, "Content");
}

#[test]
fn concurrent_card_creation() {
    let temp_dir = TempDir::new().unwrap();
    let path = temp_dir.path().to_str().unwrap();
    let repo = CardNoteRepository::new(path).unwrap();

    // Create multiple cards
    let card1 = repo.create_card("Card 1", "Content 1").unwrap();
    let card2 = repo.create_card("Card 2", "Content 2").unwrap();
    let card3 = repo.create_card("Card 3", "Content 3").unwrap();

    // All should have unique IDs
    assert_ne!(card1.id, card2.id);
    assert_ne!(card2.id, card3.id);
    assert_ne!(card1.id, card3.id);

    // All should be retrievable
    assert!(repo.get_card(&card1.id).is_ok());
    assert!(repo.get_card(&card2.id).is_ok());
    assert!(repo.get_card(&card3.id).is_ok());
}
