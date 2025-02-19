use poem_openapi::{
    payload::Json,
    OpenApi,
    param::Path,
    Object,
    Tags,
    ApiResponse,
};
use sea_orm::{DatabaseConnection, EntityTrait, ActiveModelTrait, Set, QueryOrder};
use chrono::Utc;
use uuid::Uuid;
use crate::entity::{self, card};

#[derive(Debug, Object)]
pub struct CreateCard {
    pub title: String,
    pub content: String,
}

#[derive(Debug, Object)]
pub struct UpdateCard {
    pub title: Option<String>,
    pub content: Option<String>,
}

#[derive(Debug, Object)]
pub struct Card {
    pub id: String,
    pub title: String,
    pub content: String,
    pub created_at: String,
    pub updated_at: String,
    pub sync_version: i64,
    pub device_id: String,
}

#[derive(ApiResponse)]
pub enum CardResponse {
    /// Card found successfully
    #[oai(status = 200)]
    Ok(Json<Card>),
    /// Card not found
    #[oai(status = 404)]
    NotFound(Json<String>),
}

#[derive(ApiResponse)]
pub enum CardsResponse {
    /// Cards found successfully
    #[oai(status = 200)]
    Ok(Json<Vec<Card>>),
}

#[derive(ApiResponse)]
pub enum DeleteResponse {
    /// Card deleted successfully
    #[oai(status = 200)]
    Ok(Json<String>),
    /// Card not found
    #[oai(status = 404)]
    NotFound(Json<String>),
}

impl From<card::Model> for Card {
    fn from(model: card::Model) -> Self {
        Self {
            id: model.id,
            title: model.title,
            content: model.content,
            created_at: model.created_at.to_string(),
            updated_at: model.updated_at.to_string(),
            sync_version: model.sync_version,
            device_id: model.device_id,
        }
    }
}

#[derive(Tags)]
enum ApiTags {
    /// Operations about cards
    Cards,
}

pub struct CardApi {
    db: DatabaseConnection,
}

#[OpenApi]
impl CardApi {
    pub fn new(db: DatabaseConnection) -> Self {
        Self { db }
    }

    /// Get all cards
    #[oai(path = "/cards", method = "get", tag = "ApiTags::Cards")]
    async fn get_cards(&self) -> Result<CardsResponse, poem::Error> {
        let cards = entity::Card::find()
            .order_by_desc(card::Column::CreatedAt)
            .all(&self.db)
            .await
            .map_err(|e| poem::Error::new(e, poem::http::StatusCode::INTERNAL_SERVER_ERROR))?
            .into_iter()
            .map(Card::from)
            .collect();
        Ok(CardsResponse::Ok(Json(cards)))
    }

    /// Get a card by ID
    #[oai(path = "/cards/:id", method = "get", tag = "ApiTags::Cards")]
    async fn get_card(&self, id: Path<String>) -> Result<CardResponse, poem::Error> {
        match entity::Card::find_by_id(id.0)
            .one(&self.db)
            .await
            .map_err(|e| poem::Error::new(e, poem::http::StatusCode::INTERNAL_SERVER_ERROR))? {
            Some(card) => Ok(CardResponse::Ok(Json(Card::from(card)))),
            None => Ok(CardResponse::NotFound(Json("Card not found".to_string()))),
        }
    }

    /// Create a new card
    #[oai(path = "/cards", method = "post", tag = "ApiTags::Cards")]
    async fn create_card(&self, card: Json<CreateCard>) -> Result<CardResponse, poem::Error> {
        let now = Utc::now().naive_utc();
        let card = card::ActiveModel {
            id: Set(Uuid::new_v4().to_string()),
            title: Set(card.0.title),
            content: Set(card.0.content),
            created_at: Set(now),
            updated_at: Set(now),
            sync_version: Set(1),
            device_id: Set(String::new()),
        }
        .insert(&self.db)
        .await
        .map_err(|e| poem::Error::new(e, poem::http::StatusCode::INTERNAL_SERVER_ERROR))
        .map(Card::from)?;

        Ok(CardResponse::Ok(Json(card)))
    }

    /// Update a card
    #[oai(path = "/cards/:id", method = "patch", tag = "ApiTags::Cards")]
    async fn update_card(&self, id: Path<String>, card: Json<UpdateCard>) -> Result<CardResponse, poem::Error> {
        let card_model = match entity::Card::find_by_id(id.0.clone())
            .one(&self.db)
            .await
            .map_err(|e| poem::Error::new(e, poem::http::StatusCode::INTERNAL_SERVER_ERROR))? {
            Some(card) => card,
            None => return Ok(CardResponse::NotFound(Json("Card not found".to_string()))),
        };

        let mut card_active: card::ActiveModel = card_model.clone().into();

        if let Some(title) = card.0.title {
            card_active.title = Set(title);
        }
        if let Some(content) = card.0.content {
            card_active.content = Set(content);
        }
        card_active.updated_at = Set(Utc::now().naive_utc());
        card_active.sync_version = Set(card_model.sync_version + 1);

        let updated_card = card_active.update(&self.db)
            .await
            .map_err(|e| poem::Error::new(e, poem::http::StatusCode::INTERNAL_SERVER_ERROR))
            .map(Card::from)?;
        Ok(CardResponse::Ok(Json(updated_card)))
    }

    /// Delete a card
    #[oai(path = "/cards/:id", method = "delete", tag = "ApiTags::Cards")]
    async fn delete_card(&self, id: Path<String>) -> Result<DeleteResponse, poem::Error> {
        let id_str = id.0.clone();
        match entity::Card::find_by_id(id.0)
            .one(&self.db)
            .await
            .map_err(|e| poem::Error::new(e, poem::http::StatusCode::INTERNAL_SERVER_ERROR))? {
            Some(_) => {
                entity::Card::delete_by_id(id_str)
                    .exec(&self.db)
                    .await
                    .map_err(|e| poem::Error::new(e, poem::http::StatusCode::INTERNAL_SERVER_ERROR))?;
                Ok(DeleteResponse::Ok(Json("Card deleted successfully".to_string())))
            }
            None => Ok(DeleteResponse::NotFound(Json("Card not found".to_string()))),
        }
    }
}
