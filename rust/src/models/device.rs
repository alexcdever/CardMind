use sea_orm::entity::prelude::*;

// 设备模型
#[derive(Clone, Debug, PartialEq, DeriveEntityModel)]
#[sea_orm(table_name = "devices")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false)]
    pub id: String,
    pub name: String,
    pub created_at: i64,
    pub updated_at: i64,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(has_many = "super::network_device::Entity")]
    NetworkDevices,
    #[sea_orm(has_many = "super::resident_network::Entity")]
    ResidentNetworks,
}

impl Related<super::network_device::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::NetworkDevices.def()
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


