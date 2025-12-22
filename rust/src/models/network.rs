use sea_orm::entity::prelude::*;
use uuid::Uuid;

// 网络模型
#[derive(Clone, Debug, PartialEq, DeriveEntityModel)]
#[sea_orm(table_name = "networks")]
pub struct Model {
    #[sea_orm(primary_key)]
    pub id: Uuid,
    pub name: String,
    pub password: String,
    pub created_at: i64,
    pub updated_at: i64,
    pub loro_doc: Vec<u8>,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(has_many = "super::network_device::Entity")]
    NetworkDevices,
    #[sea_orm(has_many = "super::card_network::Entity")]
    CardNetworks,
    #[sea_orm(has_many = "super::resident_network::Entity")]
    ResidentNetworks,
}

impl Related<super::network_device::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::NetworkDevices.def()
    }
}

impl Related<super::card_network::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::CardNetworks.def()
    }
}

impl Related<super::resident_network::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::ResidentNetworks.def()
    }
}

// 为ActiveModel添加默认的行为实现
impl ActiveModelBehavior for ActiveModel {
    // 空实现，使用默认行为
}


