use poem_openapi::{
    payload::Json,
    OpenApi,
    param::Path,
    Tags,
    ApiResponse,
    Object,
};
use sea_orm::DatabaseConnection;
use chrono::Utc;
use poem::error::InternalServerError;
use log::info;

// 使用entity模块中的卡片实体
use entity::card::Model;
use crate::service::card_service::CardService;

/// API标签
#[derive(Tags)]
pub enum ApiTags {
    /// 卡片管理
    #[oai(rename = "cards")]
    Cards
}

/// 卡片数据传输对象
#[derive(Debug, Object)]
pub struct CardDto {
    /// 卡片ID
    pub id: i32,
    /// 卡片标题
    pub title: String,
    /// 卡片内容
    pub content: String,
    /// 创建时间
    pub created_at: String,
    /// 更新时间
    pub updated_at: String,
}

/// 卡片列表响应
#[derive(ApiResponse)]
pub enum CardsResponse {
    /// 成功获取卡片列表
    #[oai(status = 200)]
    Ok(Json<Vec<CardDto>>)
}

/// 卡片响应
#[derive(ApiResponse)]
pub enum CardResponse {
    /// 成功获取卡片
    #[oai(status = 200)]
    Ok(Json<CardDto>),
    /// 卡片不存在
    #[oai(status = 404)]
    NotFound(Json<String>)
}

/// 创建卡片请求
#[derive(Debug, Object)]
pub struct CreateCardRequest {
    /// 卡片标题
    pub title: String,
    /// 卡片内容
    pub content: String,
}

/// 卡片处理器
#[derive(Clone)]
pub struct CardHandler {
    db: DatabaseConnection,
}

impl CardHandler {
    /// 创建新的卡片处理器实例
    pub fn new(db: DatabaseConnection) -> Self {
        Self { db }
    }
    
    /// 将Model转换为DTO
    fn to_dto(model: Model) -> CardDto {
        CardDto {
            id: model.id,
            title: model.title,
            content: model.content,
            created_at: model.created_at.to_rfc3339(),
            updated_at: model.updated_at.to_rfc3339(),
        }
    }
}

#[OpenApi]
impl CardHandler {
    /// 获取所有卡片
    #[oai(path = "/cards", method = "get", tag = "ApiTags::Cards")]
    pub async fn get_cards(&self) -> Result<CardsResponse, poem::Error> {
        info!("收到获取所有卡片的请求");
        let service = CardService::new(self.db.clone());
        let cards = service.find_all()
            .await
            .map_err(InternalServerError)?;
        
        // 将模型转换为DTO
        let dtos = cards.into_iter()
            .map(Self::to_dto)
            .collect();
        
        info!("成功获取所有卡片");
        Ok(CardsResponse::Ok(Json(dtos)))
    }

    /// 创建新卡片
    #[oai(path = "/cards", method = "post", tag = "ApiTags::Cards")]
    pub async fn create_card(&self, card: Json<CreateCardRequest>) -> Result<CardResponse, poem::Error> {
        let service = CardService::new(self.db.clone());
        
        let card = service.create(
            card.0.title,
            card.0.content,
        )
        .await
        .map_err(InternalServerError)?;
        
        Ok(CardResponse::Ok(Json(Self::to_dto(card))))
    }

    /// 获取单个卡片
    #[oai(path = "/cards/:id", method = "get", tag = "ApiTags::Cards")]
    pub async fn get_card(&self, id: Path<i32>) -> Result<CardResponse, poem::Error> {
        let service = CardService::new(self.db.clone());
        
        match service.find_by_id(id.0).await.map_err(InternalServerError)? {
            Some(card) => Ok(CardResponse::Ok(Json(Self::to_dto(card)))),
            None => Ok(CardResponse::NotFound(Json(format!("Card with id {} not found", id.0))))
        }
    }

    /// 删除卡片
    #[oai(path = "/cards/:id", method = "delete", tag = "ApiTags::Cards")]
    pub async fn delete_card(&self, id: Path<i32>) -> Result<CardResponse, poem::Error> {
        let service = CardService::new(self.db.clone());
        
        let result = service.delete(id.0)
            .await
            .map_err(InternalServerError)?;
        
        if result {
            // 创建一个删除成功的DTO
            let dto = CardDto {
                id: id.0,
                title: "Deleted".to_string(),
                content: "This card has been deleted".to_string(),
                created_at: Utc::now().to_rfc3339(),
                updated_at: Utc::now().to_rfc3339(),
            };
            
            Ok(CardResponse::Ok(Json(dto)))
        } else {
            Ok(CardResponse::NotFound(Json(format!("Card with id {} not found", id.0))))
        }
    }
}
