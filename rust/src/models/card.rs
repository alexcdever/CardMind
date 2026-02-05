use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

/// Card data model
///
/// Represents a single card with title, content, and metadata.
/// IDs are UUID v7 (time-ordered).
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
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
    #[must_use]
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

    /// 检查卡片是否包含指定标签
    ///
    /// # 参数
    ///
    /// * `tag` - 要检查的标签
    ///
    /// # Returns
    ///
    /// 如果卡片包含该标签返回 true，否则返回 false
    #[must_use]
    pub fn has_tag(&self, tag: &str) -> bool {
        self.tags.contains(&tag.to_string())
    }

    /// 获取卡片的所有标签
    ///
    /// # Returns
    ///
    /// 标签切片的引用
    #[must_use]
    pub fn get_tags(&self) -> &[String] {
        &self.tags
    }

    /// 清空卡片的所有标签
    pub fn clear_tags(&mut self) {
        self.tags.clear();
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
    fn it_should_card_creation() {
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
    fn it_should_card_update() {
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
    fn it_should_card_soft_delete() {
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
    fn it_should_add_tag() {
        let mut card = Card::new(
            "test-id".to_string(),
            "Title".to_string(),
            "Content".to_string(),
        );

        assert!(card.tags.is_empty());

        card.add_tag("work".to_string());
        assert_eq!(card.tags.len(), 1);
        assert!(card.has_tag("work"));
    }

    #[test]
    fn it_should_add_duplicate_tag() {
        let mut card = Card::new(
            "test-id".to_string(),
            "Title".to_string(),
            "Content".to_string(),
        );

        card.add_tag("work".to_string());
        card.add_tag("work".to_string());

        assert_eq!(card.tags.len(), 1);
    }

    #[test]
    fn it_should_remove_tag() {
        let mut card = Card::new(
            "test-id".to_string(),
            "Title".to_string(),
            "Content".to_string(),
        );

        card.add_tag("work".to_string());
        card.add_tag("personal".to_string());
        assert_eq!(card.tags.len(), 2);

        card.remove_tag("work");
        assert_eq!(card.tags.len(), 1);
        assert!(!card.has_tag("work"));
        assert!(card.has_tag("personal"));
    }

    #[test]
    fn it_should_has_tag() {
        let mut card = Card::new(
            "test-id".to_string(),
            "Title".to_string(),
            "Content".to_string(),
        );

        assert!(!card.has_tag("work"));

        card.add_tag("work".to_string());
        assert!(card.has_tag("work"));
        assert!(!card.has_tag("personal"));
    }

    #[test]
    fn it_should_get_tags() {
        let mut card = Card::new(
            "test-id".to_string(),
            "Title".to_string(),
            "Content".to_string(),
        );

        assert!(card.get_tags().is_empty());

        card.add_tag("work".to_string());
        card.add_tag("personal".to_string());

        let tags = card.get_tags();
        assert_eq!(tags.len(), 2);
        assert!(tags.contains(&"work".to_string()));
        assert!(tags.contains(&"personal".to_string()));
    }

    #[test]
    fn it_should_clear_tags() {
        let mut card = Card::new(
            "test-id".to_string(),
            "Title".to_string(),
            "Content".to_string(),
        );

        card.add_tag("work".to_string());
        card.add_tag("personal".to_string());
        assert_eq!(card.tags.len(), 2);

        card.clear_tags();
        assert!(card.tags.is_empty());
        assert!(!card.has_tag("work"));
        assert!(!card.has_tag("personal"));
    }
}
