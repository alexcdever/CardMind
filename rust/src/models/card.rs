use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

/// Card data model
///
/// Represents a single card with title, content, and metadata.
/// IDs are UUID v7 (time-ordered).
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[frb(dart_metadata=("freezed"))]
pub struct Card {
    /// Unique identifier (UUID v7)
    pub id: String,

    /// Card title
    pub title: String,

    /// Card content (Markdown format)
    pub content: String,

    /// Creation timestamp (Unix milliseconds)
    pub created_at: i64,

    /// Last modification timestamp (Unix milliseconds)
    pub updated_at: i64,

    /// Deletion flag (soft delete)
    pub deleted: bool,

    /// Pool IDs this card belongs to (for P2P sync)
    pub pool_ids: Vec<String>,
}

impl Card {
    /// Creates a new Card with the given ID, title, and content.
    ///
    /// # Arguments
    ///
    /// * `id` - UUID v7 identifier
    /// * `title` - Card title
    /// * `content` - Card content in Markdown format
    ///
    /// # Returns
    ///
    /// A new Card instance with timestamps set to current time
    pub fn new(id: String, title: String, content: String) -> Self {
        let now = chrono::Utc::now().timestamp_millis();
        Self {
            id,
            title,
            content,
            created_at: now,
            updated_at: now,
            deleted: false,
            pool_ids: Vec::new(),
        }
    }

    /// Adds a pool to this card
    ///
    /// # Arguments
    ///
    /// * `pool_id` - Pool ID to add
    pub fn add_pool(&mut self, pool_id: String) {
        if !self.pool_ids.contains(&pool_id) {
            self.pool_ids.push(pool_id);
            self.updated_at = chrono::Utc::now().timestamp_millis();
        }
    }

    /// Removes a pool from this card
    ///
    /// # Arguments
    ///
    /// * `pool_id` - Pool ID to remove
    pub fn remove_pool(&mut self, pool_id: &str) {
        if let Some(pos) = self.pool_ids.iter().position(|id| id == pool_id) {
            self.pool_ids.remove(pos);
            self.updated_at = chrono::Utc::now().timestamp_millis();
        }
    }

    /// Checks if card belongs to a pool
    ///
    /// # Arguments
    ///
    /// * `pool_id` - Pool ID to check
    ///
    /// # Returns
    ///
    /// true if card belongs to the pool, false otherwise
    pub fn has_pool(&self, pool_id: &str) -> bool {
        self.pool_ids.contains(&pool_id.to_string())
    }

    /// Updates the card's title and/or content
    pub fn update(&mut self, title: Option<String>, content: Option<String>) {
        if let Some(t) = title {
            self.title = t;
        }
        if let Some(c) = content {
            self.content = c;
        }
        self.updated_at = chrono::Utc::now().timestamp_millis();
    }

    /// Marks the card as deleted (soft delete)
    pub fn mark_deleted(&mut self) {
        self.deleted = true;
        self.updated_at = chrono::Utc::now().timestamp_millis();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_card_creation() {
        let card = Card::new(
            "test-id".to_string(),
            "Test Title".to_string(),
            "Test Content".to_string(),
        );

        assert_eq!(card.id, "test-id");
        assert_eq!(card.title, "Test Title");
        assert_eq!(card.content, "Test Content");
        assert!(!card.deleted);
        assert!(card.created_at > 0);
        assert_eq!(card.created_at, card.updated_at);
    }

    #[test]
    fn test_card_update() {
        let mut card = Card::new(
            "test-id".to_string(),
            "Old Title".to_string(),
            "Old Content".to_string(),
        );

        let old_updated_at = card.updated_at;
        std::thread::sleep(std::time::Duration::from_millis(10));

        card.update(Some("New Title".to_string()), None);

        assert_eq!(card.title, "New Title");
        assert_eq!(card.content, "Old Content");
        assert!(card.updated_at > old_updated_at);
    }

    #[test]
    fn test_card_soft_delete() {
        let mut card = Card::new(
            "test-id".to_string(),
            "Title".to_string(),
            "Content".to_string(),
        );

        assert!(!card.deleted);

        card.mark_deleted();

        assert!(card.deleted);
    }

    #[test]
    fn test_card_pool_management() {
        let mut card = Card::new(
            "test-id".to_string(),
            "Title".to_string(),
            "Content".to_string(),
        );

        // Initially no pools
        assert_eq!(card.pool_ids.len(), 0);
        assert!(!card.has_pool("pool-1"));

        // Add a pool
        card.add_pool("pool-1".to_string());
        assert_eq!(card.pool_ids.len(), 1);
        assert!(card.has_pool("pool-1"));

        // Adding same pool again should not duplicate
        card.add_pool("pool-1".to_string());
        assert_eq!(card.pool_ids.len(), 1);

        // Add another pool
        card.add_pool("pool-2".to_string());
        assert_eq!(card.pool_ids.len(), 2);
        assert!(card.has_pool("pool-2"));

        // Remove a pool
        card.remove_pool("pool-1");
        assert_eq!(card.pool_ids.len(), 1);
        assert!(!card.has_pool("pool-1"));
        assert!(card.has_pool("pool-2"));

        // Remove non-existent pool should be safe
        card.remove_pool("pool-3");
        assert_eq!(card.pool_ids.len(), 1);
    }

    #[test]
    fn test_card_creation_with_empty_pools() {
        let card = Card::new(
            "test-id".to_string(),
            "Title".to_string(),
            "Content".to_string(),
        );

        assert_eq!(card.pool_ids.len(), 0);
        assert!(card.pool_ids.is_empty());
    }
}
