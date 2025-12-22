use sea_orm::entity::prelude::*;
use uuid::Uuid;

// 常驻网络模型
#[derive(Clone, Debug, PartialEq, DeriveEntityModel)]
#[sea_orm(table_name = "resident_network")]
pub struct Model {
    #[sea_orm(primary_key)]
    pub device_id: String,
    #[sea_orm(primary_key)]
    pub network_id: Uuid,
    pub set_at: i64,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(belongs_to = "super::device::Entity", from = "Column::DeviceId", to = "super::device::Column::Id")]
    Device,
    #[sea_orm(belongs_to = "super::network::Entity", from = "Column::NetworkId", to = "super::network::Column::Id")]
    Network,
}

impl Related<super::device::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::Device.def()
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


