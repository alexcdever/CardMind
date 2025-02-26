use sea_orm::{
    ActiveModelTrait, DatabaseConnection, EntityTrait, ModelTrait,
    QueryOrder, Set, ActiveValue::NotSet,
};
use chrono::Utc;
// 使用entity模块中的卡片实体
use entity::card::{Entity as Card, Model as CardModel, ActiveModel as CardActiveModel};

/// 卡片服务，提供卡片实体的增删改查方法
pub struct CardService {
    db: DatabaseConnection,
}

impl CardService {
    /// 创建新的卡片服务实例
    pub fn new(db: DatabaseConnection) -> Self {
        Self { db }
    }

    /// 获取所有卡片
    /// 
    /// # 返回
    /// 
    /// 所有卡片的列表
    pub async fn find_all(&self) -> Result<Vec<CardModel>, sea_orm::DbErr> {
        Card::find()
            .order_by_asc(entity::card::Column::Id)
            .all(&self.db)
            .await
    }

    /// 根据ID查找卡片
    /// 
    /// # 参数
    /// 
    /// * `id` - 卡片ID
    /// 
    /// # 返回
    /// 
    /// 找到的卡片，如果不存在则返回None
    pub async fn find_by_id(&self, id: i32) -> Result<Option<CardModel>, sea_orm::DbErr> {
        Card::find_by_id(id).one(&self.db).await
    }

    /// 创建新卡片
    /// 
    /// # 参数
    /// 
    /// * `title` - 卡片标题
    /// * `content` - 卡片内容
    /// 
    /// # 返回
    /// 
    /// 创建的卡片
    pub async fn create(&self, title: String, content: String) -> Result<CardModel, sea_orm::DbErr> {
        let now = Utc::now();
        
        let card = CardActiveModel {
            id: NotSet, // 使用数据库自增ID
            title: Set(title),
            content: Set(content),
            created_at: Set(now),
            updated_at: Set(now),
        };

        card.insert(&self.db).await
    }

    /// 删除卡片
    /// 
    /// # 参数
    /// 
    /// * `id` - 要删除的卡片ID
    /// 
    /// # 返回
    /// 
    /// 删除结果，true表示成功删除，false表示卡片不存在
    pub async fn delete(&self, id: i32) -> Result<bool, sea_orm::DbErr> {
        let card = self.find_by_id(id).await?;
        
        if let Some(card) = card {
            let res = card.delete(&self.db).await?;
            Ok(res.rows_affected > 0)
        } else {
            Ok(false)
        }
    }
}
