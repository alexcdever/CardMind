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

    /// Tags associated with the card
    pub tags: Vec<String>,

    /// Last device that edited this card
    pub last_edit_device: Option<String>,
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
            tags: Vec::new(),
            last_edit_device: None,
        }
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

    /// Adds a tag to the card
    pub fn add_tag(&mut self, tag: String) {
        if !self.tags.contains(&tag) {
            self.tags.push(tag);
            self.updated_at = chrono::Utc::now().timestamp_millis();
        }
    }

    /// Removes a tag from the card
    pub fn remove_tag(&mut self, tag: &str) {
        self.tags.retain(|t| t != tag);
        self.updated_at = chrono::Utc::now().timestamp_millis();
    }

    /// Sets the last edit device
    pub fn set_last_edit_device(&mut self, device: String) {
        self.last_edit_device = Some(device);
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
}
