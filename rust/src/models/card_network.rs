use sea_orm::entity::prelude::*;
use uuid::Uuid;

// 卡片-网络关系模型
#[derive(Clone, Debug, PartialEq, DeriveEntityModel)]
#[sea_orm(table_name = "card_network")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false, indexed)]
    pub card_id: Uuid,  // 添加索引用于查询卡片的网络
    #[sea_orm(primary_key, auto_increment = false, indexed)]
    pub network_id: Uuid,  // 添加索引用于查询网络的卡片
    pub added_at: i64,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(belongs_to = "super::card::Entity", from = "Column::CardId", to = "super::card::Column::Id")]
    Card,
    #[sea_orm(belongs_to = "super::network::Entity", from = "Column::NetworkId", to = "super::network::Column::Id")]
    Network,
}

impl Related<super::card::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::Card.def()
    }
}

impl Related<super::network::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::Network.def()
    }
}

// 为ActiveModel添加默认的行为实现
impl ActiveModelBehavior for ActiveModel {
    // 空实现，使用默认行为
}


