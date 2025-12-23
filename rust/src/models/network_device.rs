use sea_orm::entity::prelude::*;
use uuid::Uuid;

// 网络-设备关系模型
#[derive(Clone, Debug, PartialEq, DeriveEntityModel)]
#[sea_orm(table_name = "network_device")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = false, indexed)]
    pub network_id: Uuid,  // 添加索引用于查询网络的设备
    #[sea_orm(primary_key, auto_increment = false, indexed)]
    pub device_id: String,  // 添加索引用于查询设备的网络
    pub joined_at: i64,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(belongs_to = "super::network::Entity", from = "Column::NetworkId", to = "super::network::Column::Id")]
    Network,
    #[sea_orm(belongs_to = "super::device::Entity", from = "Column::DeviceId", to = "super::device::Column::Id")]
    Device,
}

impl Related<super::network::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::Network.def()
    }
}

impl Related<super::device::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::Device.def()
    }
}

// 为ActiveModel添加默认的行为实现
impl ActiveModelBehavior for ActiveModel {
    // 空实现，使用默认行为
}


