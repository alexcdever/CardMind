// SQLite数据库的数据存储模块

use sea_orm::{Database, DatabaseConnection, DbErr, Schema, EntityTrait, ColumnTrait, QueryFilter, ConnectionTrait};
use sea_orm::Set;
use uuid::Uuid;
use argon2::{
    password_hash::{rand_core::OsRng, PasswordHash, PasswordHasher, PasswordVerifier, SaltString},
    Argon2,
};
use std::sync::Arc;
use crate::crdt::CrdtManager;

// 用于管理数据库连接和操作的存储结构体
pub struct Storage {
    pub db: DatabaseConnection,
    pub crdt_manager: Arc<CrdtManager>,
}

impl Storage {
    // 初始化数据库连接
    pub async fn new(db_path: &str) -> Result<Self, DbErr> {
        // 连接到SQLite数据库
        // 特殊处理内存数据库
        let db_url = if db_path == ":memory:" {
            "sqlite::memory:".to_string()
        } else {
            // 添加 mode=rwc 参数，如果数据库不存在则创建
            format!("sqlite://{}?mode=rwc", db_path)
        };

        // 配置连��选项以优化性能和稳定性
        let mut opt = sea_orm::ConnectOptions::new(db_url);
        opt.max_connections(1)  // SQLite 建议单连接，避免数据库锁死
            .min_connections(1)
            .connect_timeout(std::time::Duration::from_secs(8))
            .idle_timeout(std::time::Duration::from_secs(8))
            .acquire_timeout(std::time::Duration::from_secs(8))
            .sqlx_logging(true)  // 开启 SQL 日志便于调试
            .sqlx_logging_level(log::LevelFilter::Debug);

        let db = Database::connect(opt).await?;

        // 启用 WAL (Write-Ahead Logging) 模式以提高并发性能
        // WAL 模式允许读写并发，避免锁死问题
        db.execute(sea_orm::Statement::from_string(
            sea_orm::DatabaseBackend::Sqlite,
            "PRAGMA journal_mode=WAL;".to_owned(),
        )).await?;

        // 设置同步模式为 NORMAL 以平衡性能和安全性
        db.execute(sea_orm::Statement::from_string(
            sea_orm::DatabaseBackend::Sqlite,
            "PRAGMA synchronous=NORMAL;".to_owned(),
        )).await?;

        // 启用外键约束
        db.execute(sea_orm::Statement::from_string(
            sea_orm::DatabaseBackend::Sqlite,
            "PRAGMA foreign_keys=ON;".to_owned(),
        )).await?;

        log::info!("数据库连接成功，已启用 WAL 模式和外键约束");

        // 运行数据库迁移
        Self::run_migrations(&db).await?;

        // 初始化 CrdtManager
        // 从 db_path 推导 loro 根目录
        let loro_root = if db_path == ":memory:" {
            // 内存数据库情况下使用临时目录
            std::env::temp_dir().join("cardmind_loro_temp")
        } else {
            // 从数据库路径推导 loro 目录
            let db_path_buf = std::path::PathBuf::from(db_path);
            let parent = db_path_buf.parent().unwrap_or_else(|| std::path::Path::new("."));
            parent.join("loro")
        };

        let crdt_manager = Arc::new(
            CrdtManager::new(loro_root)
                .await
                .map_err(|e| DbErr::Custom(format!("初始化CrdtManager失败: {}", e)))?
        );

        log::info!("CrdtManager初始化成功");

        Ok(Self {
            db,
            crdt_manager,
        })
    }
    
    // 运行数据库迁移
    async fn run_migrations(db: &DatabaseConnection) -> Result<(), DbErr> {
        // 创建数据库表
        let schema = Schema::new(sea_orm::DbBackend::Sqlite);

        // 按照依赖顺序创建表
        // 先创建没有外键依赖的表
        let device_table = schema.create_table_from_entity(super::models::device::Entity).if_not_exists().to_owned();
        let network_table = schema.create_table_from_entity(super::models::network::Entity).if_not_exists().to_owned();
        let card_table = schema.create_table_from_entity(super::models::card::Entity).if_not_exists().to_owned();

        // 执行表创建SQL
        db.execute(db.get_database_backend().build(&device_table)).await.map_err(|e| {
            log::error!("创建设备表失败: {}", e);
            e
        })?;
        db.execute(db.get_database_backend().build(&network_table)).await.map_err(|e| {
            log::error!("创建网络表失败: {}", e);
            e
        })?;
        db.execute(db.get_database_backend().build(&card_table)).await.map_err(|e| {
            log::error!("创建卡片表失败: {}", e);
            e
        })?;

        // 再创建有外键依赖的表
        let network_device_table = schema.create_table_from_entity(super::models::network_device::Entity).if_not_exists().to_owned();
        let card_network_table = schema.create_table_from_entity(super::models::card_network::Entity).if_not_exists().to_owned();
        let resident_network_table = schema.create_table_from_entity(super::models::resident_network::Entity).if_not_exists().to_owned();

        // 执行表创建SQL
        db.execute(db.get_database_backend().build(&network_device_table)).await.map_err(|e| {
            log::error!("创建网络设备表失败: {}", e);
            e
        })?;
        db.execute(db.get_database_backend().build(&card_network_table)).await.map_err(|e| {
            log::error!("创建卡片网络表失败: {}", e);
            e
        })?;
        db.execute(db.get_database_backend().build(&resident_network_table)).await.map_err(|e| {
            log::error!("创建常驻网络表失败: {}", e);
            e
        })?;

        log::info!("数据库表创建成功");
        Ok(())
    }
    
    // 卡片管理操作
    
    // 创建一张新卡片
    pub async fn create_card(&self, card: super::models::card::ActiveModel) -> Result<super::models::card::Model, DbErr> {
        // 保存卡片ID用于后续查询
        let card_id = card.id.clone().unwrap();
        
        // 插入卡片到数据库
        super::models::card::Entity::insert(card)
            .exec(&self.db)
            .await?;
        
        // 获取刚刚插入的卡片
        let card = super::models::card::Entity::find()
            .filter(super::models::card::Column::Id.eq(card_id))
            .one(&self.db)
            .await?
            .unwrap();
        
        Ok(card)
    }
    
    // 更新现有卡片
    pub async fn update_card(&self, card: super::models::card::ActiveModel) -> Result<super::models::card::Model, DbErr> {
        // 保存卡片ID用于后续查询
        let card_id = card.id.clone().unwrap();
        
        // 更新卡片
        super::models::card::Entity::update(card)
            .exec(&self.db)
            .await?;
        
        // 获取更新后的卡片
        let card = super::models::card::Entity::find()
            .filter(super::models::card::Column::Id.eq(card_id))
            .one(&self.db)
            .await?
            .unwrap();
        
        Ok(card)
    }
    
    // 删除卡片
    pub async fn delete_card(&self, id: Uuid) -> Result<(), DbErr> {
        // 删除卡片
        super::models::card::Entity::delete_many()
            .filter(super::models::card::Column::Id.eq(id))
            .exec(&self.db)
            .await?;

        Ok(())
    }
    
    // 获取所有卡片
    pub async fn get_cards(&self) -> Result<Vec<super::models::card::Model>, DbErr> {
        // 查询所有卡片
        let cards = super::models::card::Entity::find()
            .all(&self.db)
            .await?;
        
        Ok(cards)
    }
    
    // 通过ID获取单个卡片
    pub async fn get_card(&self, id: Uuid) -> Result<Option<super::models::card::Model>, DbErr> {
        // 查询单个卡片
        let card = super::models::card::Entity::find()
            .filter(super::models::card::Column::Id.eq(id))
            .one(&self.db)
            .await?;

        Ok(card)
    }
    
    // 网络管理操作
    
    // 创建新网络
    pub async fn create_network(&self, network: super::models::network::ActiveModel) -> Result<super::models::network::Model, DbErr> {
        // 保存网络ID用于后续查询
        let network_id = network.id.clone().unwrap();
        
        // 插入网络到数据库
        super::models::network::Entity::insert(network)
            .exec(&self.db)
            .await?;
        
        // 获取刚刚插入的网络
        let network = super::models::network::Entity::find()
            .filter(super::models::network::Column::Id.eq(network_id))
            .one(&self.db)
            .await?
            .unwrap();
        
        Ok(network)
    }
    
    // 通过ID获取网络
    pub async fn get_network(&self, id: Uuid) -> Result<Option<super::models::network::Model>, DbErr> {
        // 查询单个网络
        let network = super::models::network::Entity::find()
            .filter(super::models::network::Column::Id.eq(id))
            .one(&self.db)
            .await?;

        Ok(network)
    }
    
    // 获取所有网络
    pub async fn get_networks(&self) -> Result<Vec<super::models::network::Model>, DbErr> {
        // 查询所有网络
        let networks = super::models::network::Entity::find()
            .all(&self.db)
            .await?;
        
        Ok(networks)
    }
    
    // 更新网络
    pub async fn update_network(&self, network: super::models::network::ActiveModel) -> Result<super::models::network::Model, DbErr> {
        // 保存网络ID用于后续查询
        let network_id = network.id.clone().unwrap();
        
        // 更新网络
        super::models::network::Entity::update(network)
            .exec(&self.db)
            .await?;
        
        // 获取更新后的网络
        let network = super::models::network::Entity::find()
            .filter(super::models::network::Column::Id.eq(network_id))
            .one(&self.db)
            .await?
            .unwrap();
        
        Ok(network)
    }
    
    // 删除网络
    pub async fn delete_network(&self, id: Uuid) -> Result<(), DbErr> {
        // 删除网络
        super::models::network::Entity::delete_many()
            .filter(super::models::network::Column::Id.eq(id))
            .exec(&self.db)
            .await?;

        Ok(())
    }
    
    // 将卡片添加到网络
    pub async fn add_card_to_network(&self, card_id: Uuid, network_id: Uuid) -> Result<(), DbErr> {
        // 创建卡片-网络关系
        let now = chrono::Utc::now().timestamp_millis();
        let card_network = super::models::card_network::ActiveModel {
            card_id: Set(card_id),
            network_id: Set(network_id),
            added_at: Set(now),
        };

        // 插入到数据库
        super::models::card_network::Entity::insert(card_network)
            .exec(&self.db)
            .await?;

        Ok(())
    }
    
    // 将卡片从网络中移除
    pub async fn remove_card_from_network(&self, card_id: Uuid, network_id: Uuid) -> Result<(), DbErr> {
        // 删除卡片-网络关系
        super::models::card_network::Entity::delete_many()
            .filter(super::models::card_network::Column::CardId.eq(card_id))
            .filter(super::models::card_network::Column::NetworkId.eq(network_id))
            .exec(&self.db)
            .await?;

        Ok(())
    }
    
    // 设备管理操作
    
    // 创建设备
    pub async fn create_device(&self, device: super::models::device::ActiveModel) -> Result<super::models::device::Model, DbErr> {
        // 保存设备ID用于后续查询
        let device_id = device.id.clone().unwrap();
        
        // 插入设备到数据库
        super::models::device::Entity::insert(device)
            .exec(&self.db)
            .await?;
        
        // 获取刚刚插入的设备
        let device = super::models::device::Entity::find()
            .filter(super::models::device::Column::Id.eq(device_id))
            .one(&self.db)
            .await?
            .unwrap();
        
        Ok(device)
    }
    
    // 通过ID获取设备
    pub async fn get_device(&self, id: String) -> Result<Option<super::models::device::Model>, DbErr> {
        // 查询单个设备
        let device = super::models::device::Entity::find()
            .filter(super::models::device::Column::Id.eq(id))
            .one(&self.db)
            .await?;
        
        Ok(device)
    }
    
    // 获取所有设备
    pub async fn get_devices(&self) -> Result<Vec<super::models::device::Model>, DbErr> {
        // 查询所有设备
        let devices = super::models::device::Entity::find()
            .all(&self.db)
            .await?;
        
        Ok(devices)
    }
    
    // 更新设备名称
    pub async fn update_device(&self, device: super::models::device::ActiveModel) -> Result<super::models::device::Model, DbErr> {
        // 保存设备ID用于后续查询
        let device_id = device.id.clone().unwrap();
        
        // 更新设备
        super::models::device::Entity::update(device)
            .exec(&self.db)
            .await?;
        
        // 获取更新后的设备
        let device = super::models::device::Entity::find()
            .filter(super::models::device::Column::Id.eq(device_id))
            .one(&self.db)
            .await?
            .unwrap();
        
        Ok(device)
    }
    
    // 加入网络
    pub async fn join_network(&self, network_id: Uuid, device_id: String) -> Result<(), DbErr> {
        // 创建网络-设备关系
        let now = chrono::Utc::now().timestamp_millis();
        let network_device = super::models::network_device::ActiveModel {
            network_id: Set(network_id),
            device_id: Set(device_id),
            joined_at: Set(now),
        };

        // 插入到数据库
        super::models::network_device::Entity::insert(network_device)
            .exec(&self.db)
            .await?;

        Ok(())
    }
    
    // 退出网络
    pub async fn leave_network(&self, network_id: Uuid, device_id: String) -> Result<(), DbErr> {
        // 删除网络-设备关系
        super::models::network_device::Entity::delete_many()
            .filter(super::models::network_device::Column::NetworkId.eq(network_id))
            .filter(super::models::network_device::Column::DeviceId.eq(device_id))
            .exec(&self.db)
            .await?;

        Ok(())
    }
    
    // 设置常驻网络
    pub async fn set_resident_network(&self, network_id: Uuid, device_id: String) -> Result<(), DbErr> {
        // 先删除该设备的所有常驻网络设置
        super::models::resident_network::Entity::delete_many()
            .filter(super::models::resident_network::Column::DeviceId.eq(device_id.clone()))
            .exec(&self.db)
            .await?;

        // 创建新的常驻网络设置
        let now = chrono::Utc::now().timestamp_millis();
        let resident_network = super::models::resident_network::ActiveModel {
            network_id: Set(network_id),
            device_id: Set(device_id),
            set_at: Set(now),
        };

        // 插入到数据库
        super::models::resident_network::Entity::insert(resident_network)
            .exec(&self.db)
            .await?;

        Ok(())
    }
    
    // 取消常驻网络
    pub async fn unset_resident_network(&self, device_id: String) -> Result<(), DbErr> {
        // 删除该设备的所有常驻网络设置
        super::models::resident_network::Entity::delete_many()
            .filter(super::models::resident_network::Column::DeviceId.eq(device_id))
            .exec(&self.db)
            .await?;

        Ok(())
    }

    // 获取设备的所有常驻网络
    pub async fn get_resident_networks(&self, device_id: String) -> Result<Vec<Uuid>, DbErr> {
        // 查询该设备的所有常驻网络
        let resident_networks = super::models::resident_network::Entity::find()
            .filter(super::models::resident_network::Column::DeviceId.eq(device_id))
            .all(&self.db)
            .await?;

        // 提取网络ID列表
        let network_ids = resident_networks
            .into_iter()
            .map(|rn| rn.network_id)
            .collect();

        Ok(network_ids)
    }

    // 统计设备在指定网络中的卡片数量
    pub async fn count_device_cards_in_network(&self, device_id: String, network_id: Uuid) -> Result<u64, DbErr> {
        use sea_orm::QuerySelect;

        // 查询该网络中的所有卡片ID
        let cards_in_network = super::models::card_network::Entity::find()
            .filter(super::models::card_network::Column::NetworkId.eq(network_id))
            .all(&self.db)
            .await?;

        // TODO: 这里需要过滤出属于该设备的卡片
        // 当前简化实现：返回网络中的总卡片数
        // 正确实现需要卡片表中有 device_id 字段，或者通过创建历史追踪
        Ok(cards_in_network.len() as u64)
    }

    // ==================== 密码处理辅助方法 ====================

    /// 公开的密码哈希方法（供 API 层调用）
    pub fn hash_password_public(&self, password: &str) -> Result<String, String> {
        self.hash_password(password)
    }

    /// 公开的密码验证方法（供 API 层调用）
    pub fn verify_password_public(&self, password: &str, password_hash: &str) -> Result<bool, String> {
        self.verify_password(password, password_hash)
    }

    /// 使用 Argon2 哈希密码
    fn hash_password(&self, password: &str) -> Result<String, String> {
        let salt = SaltString::generate(&mut OsRng);
        let argon2 = Argon2::default();

        let password_hash = argon2
            .hash_password(password.as_bytes(), &salt)
            .map_err(|e| format!("Failed to hash password: {}", e))?
            .to_string();

        Ok(password_hash)
    }

    /// 验证密码
    fn verify_password(&self, password: &str, password_hash: &str) -> Result<bool, String> {
        let parsed_hash = PasswordHash::new(password_hash)
            .map_err(|e| format!("Failed to parse password hash: {}", e))?;

        let argon2 = Argon2::default();

        Ok(argon2
            .verify_password(password.as_bytes(), &parsed_hash)
            .is_ok())
    }
}