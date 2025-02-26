use sea_orm_migration::prelude::*;
// 使用entity模块中的卡片实体
use entity::card;
use entity::entities::Card;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 使用实体定义创建卡片表
        manager
            .create_table(
                sea_orm::Schema::new(manager.get_connection().get_database_backend())
                    .create_table_from_entity(Card)
                    .if_not_exists()
                    .to_owned(),
            )
            .await
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        // 删除卡片表
        manager
            .drop_table(Table::drop().table(card::Entity).to_owned())
            .await
    }
}
