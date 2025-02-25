// 导入必要的数据库相关模块
use sea_orm::{
    Database, DatabaseConnection, DbErr,
    ConnectionTrait, Statement,
};
use std::path::PathBuf;
use std::fs;

// 迁移文件所在的目录常量
const MIGRATIONS_DIR: &str = "migrations";

// 数据库连接池结构体
#[derive(Clone)]
pub struct DatabasePool {
    connection: DatabaseConnection,
}

impl DatabasePool {
    // 创建新的数据库连接池
    // deployment_mode: 部署模式（desktop或web）
    // data_dir: 数据目录路径（仅desktop模式需要）
    pub async fn new(deployment_mode: &str, data_dir: Option<PathBuf>) -> Result<Self, DbErr> {
        let database_url = match deployment_mode {
            // desktop模式：使用SQLite数据库，存储在指定目录
            "desktop" => {
                let data_dir = data_dir.expect("Data directory is required for desktop mode");
                fs::create_dir_all(&data_dir).map_err(|e| DbErr::Custom(e.to_string()))?;
                let database_path = data_dir.join("cardmind.db");
                format!("sqlite:{}", database_path.display())
            }
            // web模式：使用环境变量中配置的数据库URL
            "web" => {
                std::env::var("DATABASE_URL")
                    .expect("DATABASE_URL must be set in web mode")
            }
            _ => panic!("Invalid deployment mode"),
        };

        let connection = Database::connect(&database_url).await?;
        Ok(Self { connection })
    }

    /// 获取当前数据库版本
    async fn get_current_version(&self) -> Result<u32, DbErr> {
        // 创建版本表（如果不存在）
        let create_version_table = r#"
        CREATE TABLE IF NOT EXISTS schema_version (
            version INTEGER PRIMARY KEY
        )
        "#;
        let stmt = Statement::from_string(
            self.connection.get_database_backend(),
            create_version_table.to_owned(),
        );
        self.connection.execute(stmt).await?;

        // 获取当前版本号（如果没有则返回0）
        let get_version = r#"
        SELECT version FROM schema_version ORDER BY version DESC LIMIT 1
        "#;
        let stmt = Statement::from_string(
            self.connection.get_database_backend(),
            get_version.to_owned(),
        );
        let version = self.connection
            .query_one(stmt)
            .await?
            .map(|row| row.try_get::<i32>("", "version").unwrap_or(0))
            .unwrap_or(0);

        Ok(version as u32)
    }

    /// 更新数据库版本号
    async fn update_version(&self, version: u32) -> Result<(), DbErr> {
        let update_version = format!(
            r#"INSERT OR REPLACE INTO schema_version (version) VALUES ({})"#,
            version
        );
        let stmt = Statement::from_string(
            self.connection.get_database_backend(),
            update_version,
        );
        self.connection.execute(stmt).await?;
        Ok(())
    }

    /// 根据版本号获取目标迁移文件的路径
    fn get_target_file(version: u32) -> String {
        format!("{}/V{:0>4}__", MIGRATIONS_DIR, version)
    }

    /// 从文件名中提取版本号
    /// 文件名格式：V0001__xxx.sql
    fn get_file_version(path: &std::path::Path) -> Option<u32> {
        path.file_name()
            .and_then(|name| name.to_str())
            .and_then(|name| {
                if name.starts_with('V') {
                    name[1..].split('_').next()
                        .and_then(|v| v.parse().ok())
                } else {
                    None
                }
            })
    }

    /// 执行数据库迁移
    /// 将数据库升级到最新版本
    pub async fn migrate(&self) -> Result<(), DbErr> {
        // 获取当前数据库版本
        let current_version = self.get_current_version().await?;

        // 获取所有迁移文件
        let migration_pattern = format!("{}/V[0-9]*__*.sql", MIGRATIONS_DIR);
        let mut migration_files: Vec<_> = glob::glob(&migration_pattern)
            .map_err(|e| DbErr::Custom(e.to_string()))?
            .filter_map(Result::ok)
            .collect();
        
        // 按版本号对迁移文件进行排序
        migration_files.sort();

        // 获取最新的版本号
        let latest_version = migration_files.last()
            .and_then(|path| Self::get_file_version(&path))
            .unwrap_or(0);

        // 如果当前版本低于最新版本，执行升级
        if current_version < latest_version {
            for path in &migration_files {
                // 只执行比当前版本新的迁移
                if let Some(version) = Self::get_file_version(&path) {
                    if version > current_version {
                        let content = fs::read_to_string(&path)
                            .map_err(|e| DbErr::Custom(e.to_string()))?;

                        // 分割SQL文件并执行UP部分的SQL语句
                        if let Some(up_sql) = content.split("-- DOWN").next() {
                            if let Some(sql) = up_sql.split("-- UP").nth(1) {
                                let stmt = Statement::from_string(
                                    self.connection.get_database_backend(),
                                    sql.trim().to_owned(),
                                );
                                self.connection.execute(stmt).await?;
                                self.update_version(version).await?;
                            }
                        }
                    }
                }
            }
        }

        Ok(())
    }

    /// 回滚数据库到指定版本
    pub async fn rollback_to(&self, target_version: u32) -> Result<(), DbErr> {
        // 获取当前版本
        let current_version = self.get_current_version().await?;

        // 如果目标版本大于等于当前版本，无需回滚
        if target_version >= current_version {
            return Ok(());
        }

        // 获取所有迁移文件
        let migration_pattern = format!("{}/V[0-9]*__*.sql", MIGRATIONS_DIR);
        let mut migration_files: Vec<_> = glob::glob(&migration_pattern)
            .map_err(|e| DbErr::Custom(e.to_string()))?
            .filter_map(Result::ok)
            .collect();
        
        // 按版本号排序迁移文件
        migration_files.sort();

        // 找出需要回滚的文件（版本号在目标版本和当前版本之间的文件）
        let rollback_files: Vec<_> = migration_files
            .into_iter()
            .filter(|path| {
                if let Some(version) = Self::get_file_version(path) {
                    version > target_version && version <= current_version
                } else {
                    false
                }
            })
            .rev() // 反序，从最新版本开始回滚
            .collect();

        // 执行回滚操作
        for path in rollback_files {
            let content = fs::read_to_string(&path)
                .map_err(|e| DbErr::Custom(e.to_string()))?;

            // 分割并执行DOWN部分的SQL语句
            if let Some(down_sql) = content.split("-- DOWN").nth(1) {
                let stmt = Statement::from_string(
                    self.connection.get_database_backend(),
                    down_sql.trim().to_owned(),
                );
                self.connection.execute(stmt).await?;

                // 更新版本号为目标版本
                if let Some(version) = Self::get_file_version(&path) {
                    if version > target_version {
                        self.update_version(target_version).await?;
                    }
                }
            }
        }

        Ok(())
    }

    /// 获取数据库连接
    pub fn get_connection(&self) -> &DatabaseConnection {
        &self.connection
    }
}
