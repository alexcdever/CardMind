use sea_orm::{
    Database, DatabaseConnection, DbErr, EntityTrait, Schema,
    sea_query::*,
};
use std::path::PathBuf;
use std::fs;
use crate::entity::card::Entity as Card;

#[derive(Clone)]
pub struct DatabasePool {
    connection: DatabaseConnection,
}

impl DatabasePool {
    pub async fn new(deployment_mode: &str, data_dir: Option<PathBuf>) -> Result<Self, DbErr> {
        let database_url = match deployment_mode {
            "desktop" => {
                let data_dir = data_dir.expect("Data directory is required for desktop mode");
                fs::create_dir_all(&data_dir).map_err(|e| DbErr::Custom(e.to_string()))?;
                let database_path = data_dir.join("cardmind.db");
                format!("sqlite:{}", database_path.display())
            }
            "web" => {
                std::env::var("DATABASE_URL")
                    .expect("DATABASE_URL must be set in web mode")
            }
            _ => panic!("Invalid deployment mode"),
        };

        let connection = Database::connect(&database_url).await?;
        Ok(Self { connection })
    }

    pub async fn new_sqlite(path: &str) -> Result<Self, DbErr> {
        let connection = Database::connect(&format!("sqlite:{}", path)).await?;
        Ok(Self { connection })
    }

    pub async fn new_postgres(url: &str) -> Result<Self, DbErr> {
        let connection = Database::connect(url).await?;
        Ok(Self { connection })
    }

    pub async fn migrate(&self) -> Result<(), DbErr> {
        let builder = self.connection.get_database_backend();
        let schema = Schema::new(builder);

        schema
            .create_table_if_not_exists(
                Table::create()
                    .table(Card::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(Card::Id)
                            .string()
                            .not_null()
                            .primary_key(),
                    )
                    .col(ColumnDef::new(Card::Title).string().not_null())
                    .col(ColumnDef::new(Card::Content).string().not_null())
                    .col(
                        ColumnDef::new(Card::CreatedAt)
                            .timestamp()
                            .not_null()
                            .default(Expr::current_timestamp()),
                    )
                    .col(
                        ColumnDef::new(Card::UpdatedAt)
                            .timestamp()
                            .not_null()
                            .default(Expr::current_timestamp()),
                    )
                    .col(
                        ColumnDef::new(Card::SyncVersion)
                            .integer()
                            .not_null()
                            .default(1),
                    )
                    .col(
                        ColumnDef::new(Card::DeviceId)
                            .string()
                            .not_null()
                            .default(""),
                    )
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    pub fn get_connection(&self) -> &DatabaseConnection {
        &self.connection
    }
}
