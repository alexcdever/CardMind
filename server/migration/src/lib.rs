pub use sea_orm_migration::prelude::*;

// 只保留当前使用的迁移文件
mod m20250226_082504_create_card_table;

pub struct Migrator;

#[async_trait::async_trait]
impl MigratorTrait for Migrator {
    fn migrations() -> Vec<Box<dyn MigrationTrait>> {
        vec![
            // 只保留当前使用的迁移
            Box::new(m20250226_082504_create_card_table::Migration),
        ]
    }
}
