use sea_orm::entity::prelude::*;
use chrono::{DateTime, Utc};
use serde::{Serialize, Deserialize};

// 卡片实体
#[derive(Clone, Debug, PartialEq, DeriveEntityModel, Serialize, Deserialize)]
#[sea_orm(table_name = "cards")]
pub struct Model {
    // 卡片唯一标识符
    #[sea_orm(primary_key)]
    pub id: i32,
    
    // 卡片标题
    pub title: String,
    
    // 卡片内容
    #[sea_orm(column_type = "Text")]
    pub content: String,
    
    // 创建时间
    pub created_at: DateTime<Utc>,
    
    // 修改时间
    pub updated_at: DateTime<Utc>,
}

// 实体关系
#[derive(Copy, Clone, Debug, EnumIter)]
pub enum Relation {}

// 查询相关
impl RelationTrait for Relation {
    fn def(&self) -> RelationDef {
        panic!("No relations defined")
    }
}

// 活动模型相关
impl ActiveModelBehavior for ActiveModel {}
