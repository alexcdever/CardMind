use crate::models::error::{CardMindError, Result, ValidationError};
use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// Card owner type
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
#[frb(dart_metadata=("freezed"))]
pub enum OwnerType {
    Local,
    Pool,
}

impl OwnerType {
    #[must_use]
    pub const fn as_str(&self) -> &'static str {
        match self {
            Self::Local => "local",
            Self::Pool => "pool",
        }
    }
}

impl TryFrom<&str> for OwnerType {
    type Error = CardMindError;

    fn try_from(value: &str) -> std::result::Result<Self, Self::Error> {
        match value {
            "local" => Ok(Self::Local),
            "pool" => Ok(Self::Pool),
            _ => Err(CardMindError::SerializationError(format!(
                "Invalid owner_type: {value}"
            ))),
        }
    }
}

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

    /// Owner type (local or pool)
    pub owner_type: OwnerType,

    /// Pool ID when owner type is pool
    pub pool_id: Option<String>,

    /// Last peer that edited this card
    pub last_edit_peer: String,
}

impl Card {
    /// Creates a new Card with the given ID, title, and content.
    ///
    /// # Arguments
    ///
    /// * `id` - UUID v7 identifier
    /// * `title` - Card title
    /// * `content` - Card content in Markdown format
    /// * `owner_type` - Card owner type (local or pool)
    /// * `pool_id` - Pool ID (required when owner_type is pool)
    /// * `last_edit_peer` - Peer ID of the editor
    ///
    /// # Returns
    ///
    /// A new Card instance with timestamps set to current time
    pub fn new(
        id: String,
        title: String,
        content: String,
        owner_type: OwnerType,
        pool_id: Option<String>,
        last_edit_peer: String,
    ) -> Result<Self> {
        Self::validate_id(&id)?;
        Self::validate_title(&title)?;
        Self::validate_content(&content)?;
        Self::validate_owner(&owner_type, pool_id.as_deref())?;
        Self::validate_peer_id(&last_edit_peer)?;
        let now = chrono::Utc::now().timestamp_millis();
        Ok(Self {
            id,
            title,
            content,
            created_at: now,
            updated_at: now,
            deleted: false,
            owner_type,
            pool_id,
            last_edit_peer,
        })
    }

    /// Updates the card's title and/or content
    pub fn update(
        &mut self,
        title: Option<String>,
        content: Option<String>,
        last_edit_peer: String,
    ) -> Result<()> {
        let title_changed = if let Some(t) = title {
            Self::validate_title(&t)?;
            if t != self.title {
                self.title = t;
                true
            } else {
                false
            }
        } else {
            false
        };
        let content_changed = if let Some(c) = content {
            Self::validate_content(&c)?;
            if c != self.content {
                self.content = c;
                true
            } else {
                false
            }
        } else {
            false
        };
        if title_changed || content_changed {
            Self::validate_peer_id(&last_edit_peer)?;
            self.last_edit_peer = last_edit_peer;
            self.updated_at = chrono::Utc::now().timestamp_millis();
        }
        Ok(())
    }

    /// Marks the card as deleted (soft delete)
    pub fn mark_deleted(&mut self, last_edit_peer: String) -> Result<()> {
        Self::validate_id(&self.id)?;
        if self.deleted {
            return Ok(());
        }
        self.deleted = true;
        Self::validate_peer_id(&last_edit_peer)?;
        self.last_edit_peer = last_edit_peer;
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
    pub fn get_last_edit_peer(&self) -> &str {
        &self.last_edit_peer
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

    fn validate_content(content: &str) -> Result<()> {
        if content.trim().is_empty() {
            return Err(ValidationError::ContentEmpty.into());
        }
        Ok(())
    }

    fn validate_peer_id(peer_id: &str) -> Result<()> {
        if peer_id.trim().is_empty() {
            return Err(ValidationError::PeerIdInvalid.into());
        }
        Ok(())
    }

    fn validate_owner(owner_type: &OwnerType, pool_id: Option<&str>) -> Result<()> {
        match owner_type {
            OwnerType::Local => {
                if pool_id.is_some() {
                    return Err(ValidationError::PoolIdInvalid.into());
                }
            }
            OwnerType::Pool => match pool_id {
                Some(id) if !id.trim().is_empty() => {}
                _ => return Err(ValidationError::PoolIdEmpty.into()),
            },
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

    fn valid_peer_id() -> String {
        "12D3KooWTestPeerId".to_string()
    }

    fn require_card(result: Result<Card>) -> Result<Card> {
        result
    }

    #[test]
    fn it_should_create_card_with_required_fields() -> Result<()> {
        let card = require_card(Card::new(
            valid_uuid_v7(),
            "Test Title".to_string(),
            "Test Content".to_string(),
            OwnerType::Local,
            None,
            valid_peer_id(),
        ))?;

        assert_eq!(card.id, valid_uuid_v7());
        assert_eq!(card.title, "Test Title");
        assert_eq!(card.content, "Test Content");
        assert!(!card.deleted);
        assert_eq!(card.owner_type, OwnerType::Local);
        assert!(card.pool_id.is_none());
        assert_eq!(card.last_edit_peer, "12D3KooWTestPeerId");
        assert!(card.created_at > 0);
        assert_eq!(card.created_at, card.updated_at);
        Ok(())
    }

    #[test]
    fn it_should_update_card_and_last_edit_peer() -> Result<()> {
        let mut card = require_card(Card::new(
            valid_uuid_v7(),
            "Old Title".to_string(),
            "Old Content".to_string(),
            OwnerType::Local,
            None,
            valid_peer_id(),
        ))?;

        let old_updated_at = card.updated_at;
        std::thread::sleep(std::time::Duration::from_millis(10));

        card.update(
            Some("New Title".to_string()),
            None,
            "12D3KooWNewPeer".to_string(),
        )?;

        assert_eq!(card.title, "New Title");
        assert_eq!(card.content, "Old Content");
        assert!(card.updated_at > old_updated_at);
        assert_eq!(card.last_edit_peer, "12D3KooWNewPeer");
        Ok(())
    }

    #[test]
    fn it_should_mark_deleted_updates_last_edit_peer() -> Result<()> {
        let mut card = require_card(Card::new(
            valid_uuid_v7(),
            "Title".to_string(),
            "Content".to_string(),
            OwnerType::Local,
            None,
            valid_peer_id(),
        ))?;

        assert!(!card.deleted);

        card.mark_deleted("12D3KooWDeletePeer".to_string())?;

        assert!(card.deleted);
        assert_eq!(card.last_edit_peer, "12D3KooWDeletePeer");
        Ok(())
    }

    #[test]
    fn it_should_reject_empty_title() {
        let id = generate_uuid_v7();
        let result = Card::new(
            id,
            String::new(),
            "内容".to_string(),
            OwnerType::Local,
            None,
            valid_peer_id(),
        );
        assert!(result.is_err());
    }

    #[test]
    fn it_should_reject_title_too_long() {
        let id = generate_uuid_v7();
        let long_title = "a".repeat(201);
        let result = Card::new(
            id,
            long_title,
            "内容".to_string(),
            OwnerType::Local,
            None,
            valid_peer_id(),
        );
        assert!(result.is_err());
    }

    #[test]
    fn it_should_reject_empty_content() {
        let id = generate_uuid_v7();
        let result = Card::new(
            id,
            "标题".to_string(),
            String::new(),
            OwnerType::Local,
            None,
            valid_peer_id(),
        );
        assert!(result.is_err());
    }

    #[test]
    fn it_should_reject_whitespace_content() {
        let id = generate_uuid_v7();
        let result = Card::new(
            id,
            "标题".to_string(),
            "   ".to_string(),
            OwnerType::Local,
            None,
            valid_peer_id(),
        );
        assert!(result.is_err());
    }

    #[test]
    fn it_should_reject_invalid_uuid() {
        let result = Card::new(
            "not-a-uuid".to_string(),
            "标题".to_string(),
            "内容".to_string(),
            OwnerType::Local,
            None,
            valid_peer_id(),
        );
        assert!(result.is_err());
    }

    #[test]
    fn it_should_reject_missing_pool_id_for_pool_owner() {
        let id = generate_uuid_v7();
        let result = Card::new(
            id,
            "标题".to_string(),
            "内容".to_string(),
            OwnerType::Pool,
            None,
            valid_peer_id(),
        );
        assert!(result.is_err());
    }

    #[test]
    fn it_should_reject_pool_id_for_local_owner() {
        let id = generate_uuid_v7();
        let result = Card::new(
            id,
            "标题".to_string(),
            "内容".to_string(),
            OwnerType::Local,
            Some("pool-001".to_string()),
            valid_peer_id(),
        );
        assert!(result.is_err());
    }

    #[test]
    fn it_should_restore_deleted_card() -> Result<()> {
        let id = generate_uuid_v7();
        let mut card = Card::new(
            id,
            "标题".to_string(),
            "内容".to_string(),
            OwnerType::Local,
            None,
            valid_peer_id(),
        )?;
        card.mark_deleted("12D3KooWDeletePeer".to_string())?;
        assert!(card.deleted);

        card.restore()?;
        assert!(!card.deleted);
        Ok(())
    }

    #[test]
    fn it_should_mark_deleted_idempotent() -> Result<()> {
        let id = generate_uuid_v7();
        let mut card = Card::new(
            id,
            "标题".to_string(),
            "内容".to_string(),
            OwnerType::Local,
            None,
            valid_peer_id(),
        )?;
        card.mark_deleted("12D3KooWDeletePeer".to_string())?;
        let updated_at = card.updated_at;

        card.mark_deleted("12D3KooWDeletePeer".to_string())?;

        assert_eq!(card.updated_at, updated_at);
        Ok(())
    }

    #[test]
    fn it_should_reject_empty_last_edit_peer() {
        let id = generate_uuid_v7();
        let result = Card::new(
            id,
            "标题".to_string(),
            "内容".to_string(),
            OwnerType::Local,
            None,
            String::new(),
        );
        assert!(result.is_err());
    }

    #[test]
    fn it_should_reject_non_v7_uuid() {
        let id = Uuid::nil().to_string();
        let result = Card::new(
            id,
            "标题".to_string(),
            "内容".to_string(),
            OwnerType::Local,
            None,
            valid_peer_id(),
        );
        assert!(result.is_err());
    }

    #[test]
    fn it_should_not_update_timestamp_when_update_with_none() -> Result<()> {
        let mut card = require_card(Card::new(
            valid_uuid_v7(),
            "标题".to_string(),
            "内容".to_string(),
            OwnerType::Local,
            None,
            valid_peer_id(),
        ))?;
        let updated_at = card.updated_at;

        card.update(None, None, "12D3KooWNewPeer".to_string())?;

        assert_eq!(card.updated_at, updated_at);
        assert_eq!(card.last_edit_peer, "12D3KooWTestPeerId");
        Ok(())
    }

    #[test]
    fn it_should_update_timestamp_when_update_with_changes() -> Result<()> {
        let mut card = require_card(Card::new(
            valid_uuid_v7(),
            "标题".to_string(),
            "内容".to_string(),
            OwnerType::Local,
            None,
            valid_peer_id(),
        ))?;
        let updated_at = card.updated_at;
        std::thread::sleep(std::time::Duration::from_millis(1));

        card.update(
            Some("新标题".to_string()),
            None,
            "12D3KooWNewPeer".to_string(),
        )?;
        assert!(card.updated_at > updated_at);
        assert_eq!(card.last_edit_peer, "12D3KooWNewPeer");
        Ok(())
    }

    #[test]
    fn it_should_restore_idempotent_when_not_deleted() -> Result<()> {
        let mut card = require_card(Card::new(
            valid_uuid_v7(),
            "标题".to_string(),
            "内容".to_string(),
            OwnerType::Local,
            None,
            valid_peer_id(),
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
            OwnerType::Local,
            None,
            valid_peer_id(),
        ))?;
        assert!(!card.is_deleted());

        card.mark_deleted("12D3KooWDeletePeer".to_string())?;
        assert!(card.is_deleted());
        Ok(())
    }
}
