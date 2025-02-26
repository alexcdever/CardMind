use sea_orm::{
    Database, DatabaseConnection, DbErr,
};
use std::fs;
use crate::config::Config;
use std::fmt;
use std::error::Error as StdError;
use migration::MigratorTrait;

/// 数据库错误类型
#[derive(Debug)]
pub enum DatabaseError {
    Migration(String),
    Connection(String),
}

impl fmt::Display for DatabaseError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            DatabaseError::Migration(msg) => write!(f, "迁移错误: {}", msg),
            DatabaseError::Connection(msg) => write!(f, "连接错误: {}", msg),
        }
    }
}

impl StdError for DatabaseError {}

impl From<DbErr> for DatabaseError {
    fn from(err: DbErr) -> Self {
        DatabaseError::Connection(err.to_string())
    }
}

/// 数据库连接池结构体
#[derive(Clone)]
pub struct DatabasePool {
    connection: DatabaseConnection,
}

impl DatabasePool {
    /// 创建新的数据库连接池
    pub async fn new() -> Result<Self, DatabaseError> {
        // 从全局配置获取数据库连接信息
        let config = Config::global();
        let database_url = if config.is_center_server() {
            config.postgres_url()
                .expect("POSTGRES_URL must be set in center server mode")
                .to_string()
        } else {
            let data_dir = config.data_dir();
            // 确保数据目录存在，如果不存在则创建
            if let Err(e) = fs::create_dir_all(&data_dir) {
                return Err(DatabaseError::Connection(format!("无法创建数据目录：{}", e)));
            }
            
            // 构建数据库文件路径
            let database_path = data_dir.join("cardmind.db");
            // 使用带mode=rwc参数的SQLite连接字符串，确保数据库文件不存在时会自动创建
            format!("sqlite:{}?mode=rwc", database_path.display())
        };

        println!("尝试连接数据库: {}", database_url);
        
        // 尝试连接数据库
        match Database::connect(&database_url).await {
            Ok(conn) => Ok(Self { connection: conn }),
            Err(e) => {
                Err(DatabaseError::Connection(format!(
                    "无法连接到数据库（{}）：{}", 
                    database_url,
                    e
                )))
            }
        }
    }

    /// 获取数据库连接
    pub fn connection(&self) -> &DatabaseConnection {
        &self.connection
    }

    /// 执行数据库迁移
    pub async fn migrate(&self) -> Result<(), DatabaseError> {
        println!("正在应用数据库迁移...");
        migration::Migrator::up(self.connection(), None)
            .await
            .map_err(|e| DatabaseError::Migration(e.to_string()))?;
        println!("数据库迁移完成");
        Ok(())
    }
}
