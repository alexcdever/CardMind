//! Card API functions for Flutter
//!
//! This module contains all flutter_rust_bridge-exposed functions
//! for card operations.

use crate::models::card::Card;
use crate::models::error::Result;
use crate::store::card_store::CardStore;
use std::sync::{Arc, Mutex};

/// Global CardStore instance
static CARD_STORE: Mutex<Option<Arc<Mutex<CardStore>>>> = Mutex::new(None);

/// Initialize the CardStore with the given storage path
///
/// Must be called before any other API functions.
///
/// # Arguments
///
/// * `path` - Storage root directory path
///
/// # Example (Dart)
///
/// ```dart
/// await initCardStore(path: '/path/to/storage');
/// ```
#[flutter_rust_bridge::frb]
pub fn init_card_store(path: String) -> Result<()> {
    let store = CardStore::new(&path)?;
    let mut global_store = CARD_STORE.lock().unwrap();
    *global_store = Some(Arc::new(Mutex::new(store)));
    Ok(())
}

/// Get the global CardStore instance (internal helper)
fn get_store() -> Result<Arc<Mutex<CardStore>>> {
    let global_store = CARD_STORE.lock().unwrap();
    global_store.clone().ok_or_else(|| {
        crate::models::error::CardMindError::DatabaseError(
            "CardStore not initialized. Call init_card_store first.".to_string(),
        )
    })
}

/// Get the global CardStore Arc (for internal use by other modules)
///
/// This function is used internally by other Rust modules (e.g., P2P sync)
/// that need direct access to the CardStore.
///
/// # Returns
///
/// Arc<Mutex<CardStore>> instance
///
/// # Errors
///
/// Returns error if CardStore is not initialized
pub(crate) fn get_card_store_arc() -> Result<Arc<Mutex<CardStore>>> {
    get_store()
}

// ==================== Card CRUD APIs ====================

/// Create a new card
///
/// # Arguments
///
/// * `title` - Card title
/// * `content` - Card content (Markdown format)
///
/// # Returns
///
/// The created Card
///
/// # Notes
///
/// If resident pools are configured, the card will be automatically bound to them.
///
/// # Example (Dart)
///
/// ```dart
/// final card = await createCard(title: 'My Note', content: '# Hello');
/// ```
#[flutter_rust_bridge::frb]
pub fn create_card(title: String, content: String) -> Result<Card> {
    let store = get_store()?;
    let mut store = store.lock().unwrap();

    // Create the card
    let card = store.create_card(title, content)?;

    Ok(card)
}

/// Get all cards (including deleted ones)
///
/// # Returns
///
/// List of all cards, ordered by creation time (newest first)
///
/// # Example (Dart)
///
/// ```dart
/// final cards = await getAllCards();
/// ```
#[flutter_rust_bridge::frb]
pub fn get_all_cards() -> Result<Vec<Card>> {
    let store = get_store()?;
    let store = store.lock().unwrap();
    store.get_all_cards()
}

/// Get all active cards (excluding deleted ones)
///
/// # Returns
///
/// List of active cards, ordered by creation time (newest first)
///
/// # Example (Dart)
///
/// ```dart
/// final cards = await getActiveCards();
/// ```
#[flutter_rust_bridge::frb]
pub fn get_active_cards() -> Result<Vec<Card>> {
    let store = get_store()?;
    let store = store.lock().unwrap();
    store.get_active_cards()
}

/// Get a card by ID
///
/// # Arguments
///
/// * `id` - Card ID
///
/// # Returns
///
/// The card if found
///
/// # Errors
///
/// Returns `CardNotFound` error if the card doesn't exist
///
/// # Example (Dart)
///
/// ```dart
/// final card = await getCardById(id: cardId);
/// ```
#[flutter_rust_bridge::frb]
pub fn get_card_by_id(id: String) -> Result<Card> {
    let store = get_store()?;
    let store = store.lock().unwrap();
    store.get_card_by_id(&id)
}

/// Update a card
///
/// # Arguments
///
/// * `id` - Card ID
/// * `title` - New title (optional)
/// * `content` - New content (optional)
///
/// # Example (Dart)
///
/// ```dart
/// await updateCard(id: cardId, title: 'New Title', content: null);
/// ```
#[flutter_rust_bridge::frb]
pub fn update_card(id: String, title: Option<String>, content: Option<String>) -> Result<()> {
    let store = get_store()?;
    let mut store = store.lock().unwrap();
    store.update_card(&id, title, content)
}

/// Delete a card (soft delete)
///
/// # Arguments
///
/// * `id` - Card ID
///
/// # Example (Dart)
///
/// ```dart
/// await deleteCard(id: cardId);
/// ```
#[flutter_rust_bridge::frb]
pub fn delete_card(id: String) -> Result<()> {
    let store = get_store()?;
    let mut store = store.lock().unwrap();
    store.delete_card(&id)
}

/// Get card count statistics
///
/// # Returns
///
/// Tuple of (total_count, active_count, deleted_count)
///
/// # Example (Dart)
///
/// ```dart
/// final (total, active, deleted) = await getCardCount();
/// ```
#[flutter_rust_bridge::frb]
pub fn get_card_count() -> Result<(i64, i64, i64)> {
    let store = get_store()?;
    let store = store.lock().unwrap();
    store.get_card_count()
}

// ==================== Pool Binding APIs (Phase 6) ====================

/// Add card to a data pool
///
/// # Arguments
///
/// * `card_id` - Card ID
/// * `pool_id` - Pool ID
///
/// # Example (Dart)
///
/// ```dart
/// await addCardToPool(cardId: cardId, poolId: poolId);
/// ```
#[flutter_rust_bridge::frb]
/// DEPRECATED: Single-pool model
/*
pub fn add_card_to_pool(card_id: String, pool_id: String) -> Result<()> {
    let store = get_store()?;
    let mut store = store.lock().unwrap();
    store.add_card_to_pool(&card_id, &pool_id)
}
*/

/// Remove card from a data pool
///
/// # Arguments
///
/// * `card_id` - Card ID
/// * `pool_id` - Pool ID
///
/// # Example (Dart)
///
/// ```dart
/// await removeCardFromPool(cardId: cardId, poolId: poolId);
/// ```
#[flutter_rust_bridge::frb]
/// DEPRECATED: Single-pool model
/*
pub fn remove_card_from_pool(card_id: String, pool_id: String) -> Result<()> {
    let store = get_store()?;
    let mut store = store.lock().unwrap();
    store.remove_card_from_pool(&card_id, &pool_id)
}
*/

/// Get all pool IDs that a card belongs to
///
/// # Arguments
///
/// * `card_id` - Card ID
///
/// # Returns
///
/// List of pool IDs
///
/// # Example (Dart)
///
/// ```dart
/// final pools = await getCardPools(cardId: cardId);
/// ```
#[flutter_rust_bridge::frb]
pub fn get_card_pools(card_id: String) -> Result<Vec<String>> {
    let store = get_store()?;
    let store = store.lock().unwrap();
    store.get_card_pools(&card_id)
}

/// Get all cards in specified pools
///
/// # Arguments
///
/// * `pool_ids` - List of pool IDs
///
/// # Returns
///
/// List of cards (excluding deleted cards)
///
/// # Example (Dart)
///
/// ```dart
/// final cards = await getCardsInPools(poolIds: ['pool1', 'pool2']);
/// ```
#[flutter_rust_bridge::frb]
pub fn get_cards_in_pools(pool_ids: Vec<String>) -> Result<Vec<Card>> {
    let store = get_store()?;
    let store = store.lock().unwrap();
    store.get_cards_in_pools(&pool_ids)
}

/// Clear all pool bindings for a card
///
/// # Arguments
///
/// * `card_id` - Card ID
///
/// # Example (Dart)
///
/// ```dart
/// await clearCardPools(cardId: cardId);
/// ```
#[flutter_rust_bridge::frb]
/// DEPRECATED: Single-pool model
/*
pub fn clear_card_pools(card_id: String) -> Result<()> {
    let store = get_store()?;
    let mut store = store.lock().unwrap();
    store.clear_card_pools(&card_id)
}
*/
// ==================== Test Functions ====================

/// Test function to verify Flutter-Rust bridge is working
///
/// Returns a greeting message.
#[flutter_rust_bridge::frb(sync)]
pub fn hello_cardmind() -> String {
    "Hello from CardMind Rust! 🎉".to_string()
}

/// Add two numbers (simple test)
#[flutter_rust_bridge::frb(sync)]
pub fn add_numbers(a: i32, b: i32) -> i32 {
    a + b
}

#[cfg(test)]
mod tests {
    use super::*;
    use serial_test::serial;
    use tempfile::TempDir;

    /// Helper: Initialize a temporary CardStore for testing
    fn init_test_store() -> TempDir {
        let temp_dir = TempDir::new().unwrap();
        let path = temp_dir.path().to_str().unwrap().to_string();
        init_card_store(path).unwrap();
        temp_dir
    }

    /// Helper: Clean up the global store after test
    fn cleanup_store() {
        let mut global_store = CARD_STORE.lock().unwrap();
        *global_store = None;
    }

    #[test]
    fn test_hello_cardmind() {
        let result = hello_cardmind();
        assert!(result.contains("CardMind"));
    }

    #[test]
    fn test_add_numbers() {
        assert_eq!(add_numbers(2, 3), 5);
        assert_eq!(add_numbers(-1, 1), 0);
    }

    #[test]
    #[serial]
    fn test_init_card_store() {
        let temp_dir = TempDir::new().unwrap();
        let path = temp_dir.path().to_str().unwrap().to_string();

        let result = init_card_store(path);
        assert!(result.is_ok(), "Should initialize CardStore successfully");

        cleanup_store();
    }

    #[test]
    #[serial]
    fn test_create_card_api() {
        let _temp = init_test_store();

        let result = create_card("Test Title".to_string(), "Test Content".to_string());
        assert!(result.is_ok(), "Should create card successfully");

        let card = result.unwrap();
        assert_eq!(card.title, "Test Title");
        assert_eq!(card.content, "Test Content");
        assert!(!card.id.is_empty());

        cleanup_store();
    }

    #[test]
    #[serial]
    fn test_get_all_cards_api() {
        let _temp = init_test_store();

        // Create some cards
        create_card("Card 1".to_string(), "Content 1".to_string()).unwrap();
        create_card("Card 2".to_string(), "Content 2".to_string()).unwrap();

        let result = get_all_cards();
        assert!(result.is_ok(), "Should get all cards successfully");

        let cards = result.unwrap();
        assert_eq!(cards.len(), 2);

        cleanup_store();
    }

    #[test]
    #[serial]
    fn test_get_active_cards_api() {
        let _temp = init_test_store();

        let card1 = create_card("Card 1".to_string(), "Content 1".to_string()).unwrap();
        create_card("Card 2".to_string(), "Content 2".to_string()).unwrap();

        // Delete card1
        delete_card(card1.id).unwrap();

        let result = get_active_cards();
        assert!(result.is_ok(), "Should get active cards successfully");

        let cards = result.unwrap();
        assert_eq!(cards.len(), 1, "Should only have 1 active card");

        cleanup_store();
    }

    #[test]
    #[serial]
    fn test_get_card_by_id_api() {
        let _temp = init_test_store();

        let card = create_card("Test".to_string(), "Content".to_string()).unwrap();
        let card_id = card.id.clone();

        let result = get_card_by_id(card_id);
        assert!(result.is_ok(), "Should get card by ID successfully");

        let retrieved = result.unwrap();
        assert_eq!(retrieved.title, "Test");

        cleanup_store();
    }

    #[test]
    #[serial]
    fn test_update_card_api() {
        let _temp = init_test_store();

        let card = create_card("Old Title".to_string(), "Old Content".to_string()).unwrap();
        let card_id = card.id.clone();

        let result = update_card(card_id.clone(), Some("New Title".to_string()), None);
        assert!(result.is_ok(), "Should update card successfully");

        let updated = get_card_by_id(card_id).unwrap();
        assert_eq!(updated.title, "New Title");
        assert_eq!(updated.content, "Old Content");

        cleanup_store();
    }

    #[test]
    #[serial]
    fn test_delete_card_api() {
        let _temp = init_test_store();

        let card = create_card("Test".to_string(), "Content".to_string()).unwrap();
        let card_id = card.id.clone();

        let result = delete_card(card_id.clone());
        assert!(result.is_ok(), "Should delete card successfully");

        let deleted = get_card_by_id(card_id).unwrap();
        assert!(deleted.deleted, "Card should be marked as deleted");

        cleanup_store();
    }

    #[test]
    #[serial]
    fn test_get_card_count_api() {
        let _temp = init_test_store();

        let card1 = create_card("Card 1".to_string(), "Content 1".to_string()).unwrap();
        create_card("Card 2".to_string(), "Content 2".to_string()).unwrap();
        create_card("Card 3".to_string(), "Content 3".to_string()).unwrap();

        delete_card(card1.id).unwrap();

        let result = get_card_count();
        assert!(result.is_ok(), "Should get card count successfully");

        let (total, active, deleted) = result.unwrap();
        assert_eq!(total, 3);
        assert_eq!(active, 2);
        assert_eq!(deleted, 1);

        cleanup_store();
    }

    #[test]
    #[serial]
    fn test_api_without_init_fails() {
        cleanup_store(); // Ensure no store is initialized

        let result = create_card("Test".to_string(), "Content".to_string());
        assert!(
            result.is_err(),
            "Should fail when CardStore not initialized"
        );
    }
}
