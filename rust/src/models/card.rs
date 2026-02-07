use crate::models::error::{CardMindError, Result, ValidationError};
use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

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
    pub fn new(id: String, title: String, content: String) -> Result<Self> {
        Self::validate_id(&id)?;
        Self::validate_title(&title)?;
        let now = chrono::Utc::now().timestamp_millis();
        Ok(Self {
            id,
            title,
            content,
            created_at: now,
            updated_at: now,
            deleted: false,
            tags: Vec::new(),
            last_edit_device: None,
        })
    }

    /// Updates the card's title and/or content
    pub fn update(&mut self, title: Option<String>, content: Option<String>) -> Result<()> {
        let title_changed = if let Some(t) = title {
            Self::validate_title(&t)?;
            self.title = t;
            true
        } else {
            false
        };
        let content_changed = if let Some(c) = content {
            self.content = c;
            true
        } else {
            false
        };
        if title_changed || content_changed {
            self.updated_at = chrono::Utc::now().timestamp_millis();
        }
        Ok(())
    }

    /// Adds a tag to the card
    pub fn add_tag(&mut self, tag: String) -> Result<()> {
        Self::validate_tag(&tag)?;
        if self.tags.contains(&tag) {
            return Ok(());
        }
        self.tags.push(tag);
        self.updated_at = chrono::Utc::now().timestamp_millis();
        Ok(())
    }

    /// Removes a tag from the card
    pub fn remove_tag(&mut self, tag: &str) -> Result<()> {
        Self::validate_tag(tag)?;
        if !self.tags.contains(&tag.to_string()) {
            return Ok(());
        }
        self.tags.retain(|t| t != tag);
        self.updated_at = chrono::Utc::now().timestamp_millis();
        Ok(())
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
    pub fn clear_tags(&mut self) -> Result<()> {
        Self::validate_id(&self.id)?;
        if self.tags.is_empty() {
            return Ok(());
        }
        self.tags.clear();
        self.updated_at = chrono::Utc::now().timestamp_millis();
        Ok(())
    }

    /// Sets the last edit device
    pub fn set_last_edit_device(&mut self, device: String) -> Result<()> {
        Self::validate_device_id(&device)?;
        self.last_edit_device = Some(device);
        self.updated_at = chrono::Utc::now().timestamp_millis();
        Ok(())
    }

    /// Marks the card as deleted (soft delete)
    pub fn mark_deleted(&mut self) -> Result<()> {
        Self::validate_id(&self.id)?;
        if self.deleted {
            return Ok(());
        }
        self.deleted = true;
        self.updated_at = chrono::Utc::now().timestamp_millis();
        Ok(())
    }

    /// 恢复已删除的卡片
    pub fn restore(&mut self) -> Result<()> {
        Self::validate_id(&self.id)?;
        if !self.deleted {
            return Ok(());
        }
        self.deleted = false;
        self.updated_at = chrono::Utc::now().timestamp_millis();
        Ok(())
    }

    #[must_use]
    pub const fn is_deleted(&self) -> bool {
        self.deleted
    }

    #[must_use]
    pub fn get_last_edit_device(&self) -> Option<&str> {
        self.last_edit_device.as_deref()
    }

    fn validate_id(id: &str) -> Result<()> {
        let uuid = Uuid::parse_str(id).map_err(|_| CardMindError::InvalidUuid(id.to_string()))?;
        if uuid.get_version_num() != 7 {
            return Err(CardMindError::InvalidUuid(id.to_string()));
        }
        Ok(())
    }

    fn validate_title(title: &str) -> Result<()> {
        if title.is_empty() {
            return Err(ValidationError::TitleEmpty.into());
        }
        if title.chars().count() > 200 {
            return Err(ValidationError::TitleTooLong.into());
        }
        Ok(())
    }

    fn validate_tag(tag: &str) -> Result<()> {
        if tag.is_empty() {
            return Err(ValidationError::TagEmpty.into());
        }
        if tag.chars().count() > 50 {
            return Err(ValidationError::TagTooLong.into());
        }
        Ok(())
    }

    fn validate_device_id(device_id: &str) -> Result<()> {
        if device_id.is_empty() {
            return Err(ValidationError::DeviceIdInvalid.into());
        }
        if Uuid::parse_str(device_id).is_err() {
            return Err(ValidationError::DeviceIdInvalid.into());
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::utils::uuid_v7::generate_uuid_v7;
    use uuid::Uuid;

    fn valid_uuid_v7() -> String {
        "00000000-0000-7000-8000-000000000000".to_string()
    }

    fn require_card(result: Result<Card>) -> Result<Card> {
        result
    }

    #[test]
    fn it_should_card_creation() -> Result<()> {
        let card = require_card(Card::new(
            valid_uuid_v7(),
            "Test Title".to_string(),
            "Test Content".to_string(),
        ))?;

        assert_eq!(card.id, valid_uuid_v7());
        assert_eq!(card.title, "Test Title");
        assert_eq!(card.content, "Test Content");
        assert!(!card.deleted);
        assert!(card.created_at > 0);
        assert_eq!(card.created_at, card.updated_at);
        Ok(())
    }

    #[test]
    fn it_should_card_update() -> Result<()> {
        let mut card = require_card(Card::new(
            valid_uuid_v7(),
            "Old Title".to_string(),
            "Old Content".to_string(),
        ))?;

        let old_updated_at = card.updated_at;
        std::thread::sleep(std::time::Duration::from_millis(10));

        card.update(Some("New Title".to_string()), None)?;

        assert_eq!(card.title, "New Title");
        assert_eq!(card.content, "Old Content");
        assert!(card.updated_at > old_updated_at);
        Ok(())
    }

    #[test]
    fn it_should_card_soft_delete() -> Result<()> {
        let mut card = require_card(Card::new(
            valid_uuid_v7(),
            "Title".to_string(),
            "Content".to_string(),
        ))?;

        assert!(!card.deleted);

        card.mark_deleted()?;

        assert!(card.deleted);
        Ok(())
    }

    #[test]
    fn it_should_add_tag() -> Result<()> {
        let mut card = require_card(Card::new(
            valid_uuid_v7(),
            "Title".to_string(),
            "Content".to_string(),
        ))?;

        assert!(card.tags.is_empty());

        card.add_tag("work".to_string())?;
        assert_eq!(card.tags.len(), 1);
        assert!(card.has_tag("work"));
        Ok(())
    }

    #[test]
    fn it_should_add_duplicate_tag() -> Result<()> {
        let mut card = require_card(Card::new(
            valid_uuid_v7(),
            "Title".to_string(),
            "Content".to_string(),
        ))?;

        card.add_tag("work".to_string())?;
        card.add_tag("work".to_string())?;

        assert_eq!(card.tags.len(), 1);
        Ok(())
    }

    #[test]
    fn it_should_remove_tag() -> Result<()> {
        let mut card = require_card(Card::new(
            valid_uuid_v7(),
            "Title".to_string(),
            "Content".to_string(),
        ))?;

        card.add_tag("work".to_string())?;
        card.add_tag("personal".to_string())?;
        assert_eq!(card.tags.len(), 2);

        card.remove_tag("work")?;
        assert_eq!(card.tags.len(), 1);
        assert!(!card.has_tag("work"));
        assert!(card.has_tag("personal"));
        Ok(())
    }

    #[test]
    fn it_should_has_tag() -> Result<()> {
        let mut card = require_card(Card::new(
            valid_uuid_v7(),
            "Title".to_string(),
            "Content".to_string(),
        ))?;

        assert!(!card.has_tag("work"));

        card.add_tag("work".to_string())?;
        assert!(card.has_tag("work"));
        assert!(!card.has_tag("personal"));
        Ok(())
    }

    #[test]
    fn it_should_get_tags() -> Result<()> {
        let mut card = require_card(Card::new(
            valid_uuid_v7(),
            "Title".to_string(),
            "Content".to_string(),
        ))?;

        assert!(card.get_tags().is_empty());

        card.add_tag("work".to_string())?;
        card.add_tag("personal".to_string())?;

        let tags = card.get_tags();
        assert_eq!(tags.len(), 2);
        assert!(tags.contains(&"work".to_string()));
        assert!(tags.contains(&"personal".to_string()));
        Ok(())
    }

    #[test]
    fn it_should_clear_tags() -> Result<()> {
        let mut card = require_card(Card::new(
            valid_uuid_v7(),
            "Title".to_string(),
            "Content".to_string(),
        ))?;

        card.add_tag("work".to_string())?;
        card.add_tag("personal".to_string())?;
        assert_eq!(card.tags.len(), 2);

        card.clear_tags()?;
        assert!(card.tags.is_empty());
        assert!(!card.has_tag("work"));
        assert!(!card.has_tag("personal"));
        Ok(())
    }

    #[test]
    fn it_should_reject_empty_title() {
        let id = generate_uuid_v7();
        let result = Card::new(id, String::new(), "内容".to_string());
        assert!(result.is_err());
    }

    #[test]
    fn it_should_reject_title_too_long() {
        let id = generate_uuid_v7();
        let long_title = "a".repeat(201);
        let result = Card::new(id, long_title, "内容".to_string());
        assert!(result.is_err());
    }

    #[test]
    fn it_should_allow_empty_content() -> Result<()> {
        let id = generate_uuid_v7();
        let card = Card::new(id, "标题".to_string(), String::new())?;
        assert_eq!(card.content, "");
        Ok(())
    }

    #[test]
    fn it_should_reject_invalid_uuid() {
        let result = Card::new(
            "not-a-uuid".to_string(),
            "标题".to_string(),
            "内容".to_string(),
        );
        assert!(result.is_err());
    }

    #[test]
    fn it_should_reject_empty_tag() -> Result<()> {
        let id = generate_uuid_v7();
        let mut card = Card::new(id, "标题".to_string(), "内容".to_string())?;
        let result = card.add_tag(String::new());
        assert!(result.is_err());
        Ok(())
    }

    #[test]
    fn it_should_reject_tag_too_long() -> Result<()> {
        let id = generate_uuid_v7();
        let mut card = Card::new(id, "标题".to_string(), "内容".to_string())?;
        let result = card.add_tag("a".repeat(51));
        assert!(result.is_err());
        Ok(())
    }

    #[test]
    fn it_should_not_update_timestamp_on_duplicate_tag() -> Result<()> {
        let id = generate_uuid_v7();
        let mut card = Card::new(id, "标题".to_string(), "内容".to_string())?;
        card.add_tag("work".to_string())?;
        let updated_at = card.updated_at;

        card.add_tag("work".to_string())?;

        assert_eq!(card.updated_at, updated_at);
        Ok(())
    }

    #[test]
    fn it_should_not_update_timestamp_when_remove_missing_tag() -> Result<()> {
        let id = generate_uuid_v7();
        let mut card = Card::new(id, "标题".to_string(), "内容".to_string())?;
        let updated_at = card.updated_at;

        card.remove_tag("missing")?;

        assert_eq!(card.updated_at, updated_at);
        Ok(())
    }

    #[test]
    fn it_should_not_update_timestamp_when_clear_empty_tags() -> Result<()> {
        let id = generate_uuid_v7();
        let mut card = Card::new(id, "标题".to_string(), "内容".to_string())?;
        let updated_at = card.updated_at;

        card.clear_tags()?;

        assert_eq!(card.updated_at, updated_at);
        Ok(())
    }

    #[test]
    fn it_should_restore_deleted_card() -> Result<()> {
        let id = generate_uuid_v7();
        let mut card = Card::new(id, "标题".to_string(), "内容".to_string())?;
        card.mark_deleted()?;
        assert!(card.deleted);

        card.restore()?;
        assert!(!card.deleted);
        Ok(())
    }

    #[test]
    fn it_should_mark_deleted_idempotent() -> Result<()> {
        let id = generate_uuid_v7();
        let mut card = Card::new(id, "标题".to_string(), "内容".to_string())?;
        card.mark_deleted()?;
        let updated_at = card.updated_at;

        card.mark_deleted()?;

        assert_eq!(card.updated_at, updated_at);
        Ok(())
    }

    #[test]
    fn it_should_set_last_edit_device() -> Result<()> {
        let id = generate_uuid_v7();
        let mut card = Card::new(id, "标题".to_string(), "内容".to_string())?;
        let device_id = generate_uuid_v7();

        card.set_last_edit_device(device_id.clone())?;

        assert_eq!(card.get_last_edit_device(), Some(device_id.as_str()));
        Ok(())
    }

    #[test]
    fn it_should_reject_invalid_device_id() -> Result<()> {
        let id = generate_uuid_v7();
        let mut card = Card::new(id, "标题".to_string(), "内容".to_string())?;

        let result = card.set_last_edit_device("invalid".to_string());
        assert!(result.is_err());
        Ok(())
    }

    #[test]
    fn it_should_get_last_edit_device_none_when_unset() -> Result<()> {
        let id = generate_uuid_v7();
        let card = Card::new(id, "标题".to_string(), "内容".to_string())?;
        assert_eq!(card.get_last_edit_device(), None);
        Ok(())
    }

    #[test]
    fn it_should_reject_non_v7_uuid() {
        let id = Uuid::nil().to_string();
        let result = Card::new(id, "标题".to_string(), "内容".to_string());
        assert!(result.is_err());
    }

    #[test]
    fn it_should_not_update_timestamp_when_update_with_none() -> Result<()> {
        let mut card = require_card(Card::new(
            valid_uuid_v7(),
            "标题".to_string(),
            "内容".to_string(),
        ))?;
        let updated_at = card.updated_at;

        card.update(None, None)?;

        assert_eq!(card.updated_at, updated_at);
        Ok(())
    }

    #[test]
    fn it_should_update_timestamp_when_remove_existing_tag() -> Result<()> {
        let mut card = require_card(Card::new(
            valid_uuid_v7(),
            "标题".to_string(),
            "内容".to_string(),
        ))?;
        card.add_tag("work".to_string())?;
        let updated_at = card.updated_at;
        std::thread::sleep(std::time::Duration::from_millis(1));

        card.remove_tag("work")?;
        assert!(card.updated_at > updated_at);
        Ok(())
    }

    #[test]
    fn it_should_update_timestamp_when_clear_non_empty_tags() -> Result<()> {
        let mut card = require_card(Card::new(
            valid_uuid_v7(),
            "标题".to_string(),
            "内容".to_string(),
        ))?;
        card.add_tag("work".to_string())?;
        let updated_at = card.updated_at;
        std::thread::sleep(std::time::Duration::from_millis(1));

        card.clear_tags()?;
        assert!(card.updated_at > updated_at);
        Ok(())
    }

    #[test]
    fn it_should_update_timestamp_when_set_last_edit_device() -> Result<()> {
        let mut card = require_card(Card::new(
            valid_uuid_v7(),
            "标题".to_string(),
            "内容".to_string(),
        ))?;
        let updated_at = card.updated_at;
        std::thread::sleep(std::time::Duration::from_millis(1));

        card.set_last_edit_device(generate_uuid_v7())?;
        assert!(card.updated_at > updated_at);
        Ok(())
    }

    #[test]
    fn it_should_restore_idempotent_when_not_deleted() -> Result<()> {
        let mut card = require_card(Card::new(
            valid_uuid_v7(),
            "标题".to_string(),
            "内容".to_string(),
        ))?;
        let updated_at = card.updated_at;

        card.restore()?;
        assert_eq!(card.updated_at, updated_at);
        assert!(!card.is_deleted());
        Ok(())
    }

    #[test]
    fn it_should_is_deleted_reflects_state() -> Result<()> {
        let mut card = require_card(Card::new(
            valid_uuid_v7(),
            "标题".to_string(),
            "内容".to_string(),
        ))?;
        assert!(!card.is_deleted());

        card.mark_deleted()?;
        assert!(card.is_deleted());
        Ok(())
    }
}
