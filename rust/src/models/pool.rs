//! 数据池模型定义
//!
//! 本模块定义数据池（Pool）和设备（Device）的数据结构。
//!
//! # 数据池设计
//!
//! 根据 `docs/architecture/data_contract.md` 2.1 节的定义：
//! - **pool_id**: 数据池唯一标识（UUID v7）
//! - **name**: 数据池名称（最大 128 字符）
//! - **password_hash**: bcrypt 加密哈希（不可逆）
//! - **members**: 成员设备列表（至少 1 个成员）
//! - **created_at**: 创建时间（毫秒级时间戳）
//! - **updated_at**: 最后更新时间（毫秒级时间戳）
//!
//! # 安全特性
//!
//! - 密码使用 bcrypt 哈希（工作因子 12）
//! - 明文密码存储在系统 Keyring，不在 Pool 结构中
//! - 设备昵称支持数据池特定自定义

use chrono::Utc;
use serde::{Deserialize, Serialize};
use thiserror::Error;

/// 数据池错误类型
#[derive(Error, Debug)]
pub enum PoolError {
    /// 密码验证失败
    #[error("密码验证失败")]
    InvalidPassword,

    /// 数据池未找到
    #[error("数据池未找到: {0}")]
    PoolNotFound(String),

    /// 设备未找到
    #[error("设备未找到: {0}")]
    DeviceNotFound(String),

    /// 数据池名称无效
    #[error("数据池名称无效: {0}")]
    InvalidPoolName(String),

    /// 密码强度不足
    #[error("密码强度不足: {0}")]
    WeakPassword(String),

    /// bcrypt 错误
    #[error("bcrypt 错误: {0}")]
    BcryptError(String),

    /// 其他错误
    #[error("数据池错误: {0}")]
    Other(String),
}

/// 数据池成员设备
///
/// # 字段说明
///
/// - `device_id`: 设备唯一标识（UUID v7）
/// - `device_name`: 设备在此数据池中的昵称（可修改，最大 64 字符）
/// - `joined_at`: 加入数据池的时间（毫秒级时间戳）
///
/// # 示例
///
/// ```
/// use cardmind_rust::models::pool::Device;
///
/// let device = Device {
///     device_id: "device-001".to_string(),
///     device_name: "iPhone-018c8".to_string(),
///     joined_at: 1704067200000,
/// };
/// ```
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Device {
    /// 设备唯一标识
    pub device_id: String,

    /// 设备昵称（数据池特定，可修改）
    ///
    /// 注意：同一设备在不同数据池中可以有不同昵称
    pub device_name: String,

    /// 加入数据池的时间（Unix 毫秒时间戳）
    pub joined_at: i64,
}

impl Device {
    /// 创建新设备
    ///
    /// # 参数
    ///
    /// - `device_id`: 设备 UUID
    /// - `device_name`: 设备昵称
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::models::pool::Device;
    ///
    /// let device = Device::new("device-001", "My iPhone");
    /// assert_eq!(device.device_id, "device-001");
    /// assert_eq!(device.device_name, "My iPhone");
    /// ```
    #[must_use]
    pub fn new(device_id: &str, device_name: &str) -> Self {
        Self {
            device_id: device_id.to_string(),
            device_name: device_name.to_string(),
            joined_at: Utc::now().timestamp_millis(),
        }
    }

    /// 生成默认设备昵称
    ///
    /// # 格式
    ///
    /// `{设备型号}-{UUID前5位}`
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::models::pool::Device;
    ///
    /// let device_id = "018c8a1b2c3d4e5f";
    /// let name = Device::generate_default_name(device_id);
    /// assert_eq!(name, "Unknown-018c8");
    /// ```
    #[must_use]
    pub fn generate_default_name(device_id: &str) -> String {
        let short_id = &device_id[..5.min(device_id.len())];
        format!("Unknown-{short_id}")
    }
}

/// 数据池
///
/// # 字段说明
///
/// - `pool_id`: 数据池唯一标识（UUID v7）
/// - `name`: 数据池名称（最大 128 字符）
/// - `password_hash`: bcrypt 加密哈希
/// - `members`: 成员设备列表
/// - `card_ids`: 卡片 ID 列表（单池模型：池持有卡片）
/// - `created_at`: 创建时间（毫秒级时间戳）
/// - `updated_at`: 最后更新时间（毫秒级时间戳）
///
/// # 示例
///
/// ```
/// use cardmind_rust::models::pool::{Pool, Device};
///
/// let mut pool = Pool::new("pool-001", "工作笔记", "hashed_password");
/// let device = Device::new("device-001", "My iPhone");
/// pool.add_member(device);
/// pool.add_card("card-001");
///
/// assert_eq!(pool.pool_id, "pool-001");
/// assert_eq!(pool.name, "工作笔记");
/// assert_eq!(pool.members.len(), 1);
/// assert_eq!(pool.card_ids.len(), 1);
/// ```
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Pool {
    /// 数据池唯一标识
    pub pool_id: String,

    /// 数据池名称（最大 128 字符）
    pub name: String,

    /// bcrypt 密码哈希
    ///
    /// 格式：`$2b$12$...`（工作因子 12）
    pub password_hash: String,

    /// 成员设备列表
    pub members: Vec<Device>,

    /// 卡片 ID 列表（单池模型：真理源在 Pool.layer）
    #[serde(default)]
    pub card_ids: Vec<String>,

    /// 创建时间（Unix 毫秒时间戳）
    pub created_at: i64,

    /// 最后更新时间（Unix 毫秒时间戳）
    pub updated_at: i64,
}

impl Pool {
    /// 创建新数据池
    ///
    /// # 参数
    ///
    /// - `pool_id`: 数据池 UUID
    /// - `name`: 数据池名称
    /// - `password_hash`: bcrypt 加密后的密码哈希
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::models::pool::Pool;
    ///
    /// let pool = Pool::new("pool-001", "工作笔记", "hashed_password");
    /// assert_eq!(pool.pool_id, "pool-001");
    /// assert_eq!(pool.name, "工作笔记");
    /// assert!(pool.members.is_empty());
    /// ```
    #[must_use]
    pub fn new(pool_id: &str, name: &str, password_hash: &str) -> Self {
        let now = Utc::now().timestamp_millis();
        Self {
            pool_id: pool_id.to_string(),
            name: name.to_string(),
            password_hash: password_hash.to_string(),
            members: Vec::new(),
            card_ids: Vec::new(),
            created_at: now,
            updated_at: now,
        }
    }

    /// 添加成员设备
    ///
    /// # 参数
    ///
    /// - `device`: 设备信息
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::models::pool::{Pool, Device};
    ///
    /// let mut pool = Pool::new("pool-001", "工作笔记", "hashed");
    /// let device = Device::new("device-001", "My iPhone");
    /// pool.add_member(device);
    ///
    /// assert_eq!(pool.members.len(), 1);
    /// ```
    pub fn add_member(&mut self, device: Device) {
        if !self.members.iter().any(|d| d.device_id == device.device_id) {
            self.members.push(device);
            self.updated_at = Utc::now().timestamp_millis();
        }
    }

    /// 移除成员设备
    ///
    /// # 参数
    ///
    /// - `device_id`: 设备 ID
    ///
    /// # Returns
    ///
    /// 如果设备存在并成功移除，返回 true
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::models::pool::{Pool, Device};
    ///
    /// let mut pool = Pool::new("pool-001", "工作笔记", "hashed");
    /// let device = Device::new("device-001", "My iPhone");
    /// pool.add_member(device);
    ///
    /// let removed = pool.remove_member("device-001");
    /// assert!(removed);
    /// assert_eq!(pool.members.len(), 0);
    /// ```
    pub fn remove_member(&mut self, device_id: &str) -> bool {
        let original_len = self.members.len();
        self.members.retain(|d| d.device_id != device_id);

        if self.members.len() < original_len {
            self.updated_at = Utc::now().timestamp_millis();
            true
        } else {
            false
        }
    }

    /// 更新成员昵称
    ///
    /// # 参数
    ///
    /// - `device_id`: 设备 ID
    /// - `new_name`: 新昵称
    ///
    /// # Returns
    ///
    /// 成功返回 Ok(()), 设备未找到返回 Err
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::models::pool::{Pool, Device};
    ///
    /// let mut pool = Pool::new("pool-001", "工作笔记", "hashed");
    /// let device = Device::new("device-001", "My iPhone");
    /// pool.add_member(device);
    ///
    /// pool.update_member_name("device-001", "工作手机").unwrap();
    /// assert_eq!(pool.members[0].device_name, "工作手机");
    /// ```
    pub fn update_member_name(&mut self, device_id: &str, new_name: &str) -> Result<(), PoolError> {
        if let Some(device) = self.members.iter_mut().find(|d| d.device_id == device_id) {
            device.device_name = new_name.to_string();
            self.updated_at = Utc::now().timestamp_millis();
            Ok(())
        } else {
            Err(PoolError::DeviceNotFound(device_id.to_string()))
        }
    }

    /// 验证数据池名称
    ///
    /// # 规则
    ///
    /// - 非空
    /// - 最大 128 字符
    ///
    /// # Errors
    ///
    /// 名称无效时返回错误
    pub fn validate_name(name: &str) -> Result<(), PoolError> {
        if name.is_empty() {
            return Err(PoolError::InvalidPoolName("名称不能为空".to_string()));
        }

        if name.chars().count() > 128 {
            return Err(PoolError::InvalidPoolName(
                "名称不能超过 128 字符".to_string(),
            ));
        }

        Ok(())
    }

    /// 验证密码强度
    ///
    /// # 规则
    ///
    /// - 最少 8 位字符
    /// - 建议包含字母和数字（可选，不强制）
    ///
    /// # Errors
    ///
    /// 密码强度不足时返回错误
    pub fn validate_password(password: &str) -> Result<(), PoolError> {
        if password.len() < 8 {
            return Err(PoolError::WeakPassword("密码至少 8 位字符".to_string()));
        }

        Ok(())
    }

    /// 添加卡片到数据池
    ///
    /// # 参数
    ///
    /// - `card_id`: 卡片唯一标识
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::models::pool::Pool;
    ///
    /// let mut pool = Pool::new("pool-001", "工作笔记", "hashed");
    /// pool.add_card("card-001");
    /// assert_eq!(pool.card_ids.len(), 1);
    /// assert!(pool.has_card("card-001"));
    /// ```
    pub fn add_card(&mut self, card_id: &str) {
        if !self.card_ids.contains(&card_id.to_string()) {
            self.card_ids.push(card_id.to_string());
            self.updated_at = Utc::now().timestamp_millis();
        }
    }

    /// 从数据池移除卡片
    ///
    /// # 参数
    ///
    /// - `card_id`: 卡片唯一标识
    ///
    /// # Returns
    ///
    /// 如果卡片存在并成功移除，返回 true
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::models::pool::Pool;
    ///
    /// let mut pool = Pool::new("pool-001", "工作笔记", "hashed");
    /// pool.add_card("card-001");
    ///
    /// let removed = pool.remove_card("card-001");
    /// assert!(removed);
    /// assert_eq!(pool.card_ids.len(), 0);
    /// ```
    pub fn remove_card(&mut self, card_id: &str) -> bool {
        let original_len = self.card_ids.len();
        self.card_ids.retain(|id| id != card_id);

        if self.card_ids.len() < original_len {
            self.updated_at = Utc::now().timestamp_millis();
            true
        } else {
            false
        }
    }

    /// 检查数据池是否包含指定卡片
    ///
    /// # 参数
    ///
    /// - `card_id`: 卡片唯一标识
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::models::pool::Pool;
    ///
    /// let mut pool = Pool::new("pool-001", "工作笔记", "hashed");
    /// pool.add_card("card-001");
    ///
    /// assert!(pool.has_card("card-001"));
    /// assert!(!pool.has_card("card-002"));
    /// ```
    #[must_use]
    pub fn has_card(&self, card_id: &str) -> bool {
        self.card_ids.contains(&card_id.to_string())
    }

    /// 获取数据池中的卡片数量
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::models::pool::Pool;
    ///
    /// let mut pool = Pool::new("pool-001", "工作笔记", "hashed");
    /// pool.add_card("card-001");
    /// pool.add_card("card-002");
    ///
    /// assert_eq!(pool.card_count(), 2);
    /// ```
    #[must_use]
    pub fn card_count(&self) -> usize {
        self.card_ids.len()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_device_creation() {
        let device = Device::new("device-001", "My iPhone");
        assert_eq!(device.device_id, "device-001");
        assert_eq!(device.device_name, "My iPhone");
        assert!(device.joined_at > 0);
    }

    #[test]
    fn test_device_default_name_generation() {
        let device_id = "018c8a1b2c3d4e5f";
        let name = Device::generate_default_name(device_id);
        assert_eq!(name, "Unknown-018c8");
    }

    #[test]
    fn test_pool_creation() {
        let pool = Pool::new("pool-001", "工作笔记", "hashed_password");
        assert_eq!(pool.pool_id, "pool-001");
        assert_eq!(pool.name, "工作笔记");
        assert_eq!(pool.password_hash, "hashed_password");
        assert!(pool.members.is_empty());
        assert!(pool.created_at > 0);
        assert_eq!(pool.created_at, pool.updated_at);
    }

    #[test]
    fn test_add_member() {
        let mut pool = Pool::new("pool-001", "工作笔记", "hashed");
        let device1 = Device::new("device-001", "iPhone");
        let device2 = Device::new("device-002", "MacBook");

        pool.add_member(device1.clone());
        assert_eq!(pool.members.len(), 1);

        pool.add_member(device2.clone());
        assert_eq!(pool.members.len(), 2);

        // 重复添加相同设备应该被忽略
        pool.add_member(device1.clone());
        assert_eq!(pool.members.len(), 2);
    }

    #[test]
    fn test_remove_member() {
        let mut pool = Pool::new("pool-001", "工作笔记", "hashed");
        let device = Device::new("device-001", "iPhone");
        pool.add_member(device);

        let removed = pool.remove_member("device-001");
        assert!(removed);
        assert_eq!(pool.members.len(), 0);

        // 移除不存在的设备应该返回 false
        let removed = pool.remove_member("device-999");
        assert!(!removed);
    }

    #[test]
    fn test_update_member_name() {
        let mut pool = Pool::new("pool-001", "工作笔记", "hashed");
        let device = Device::new("device-001", "My iPhone");
        pool.add_member(device);

        let result = pool.update_member_name("device-001", "工作手机");
        assert!(result.is_ok());
        assert_eq!(pool.members[0].device_name, "工作手机");

        // 更新不存在的设备应该返回错误
        let result = pool.update_member_name("device-999", "新昵称");
        assert!(result.is_err());
    }

    #[test]
    fn test_validate_pool_name() {
        // 有效名称
        assert!(Pool::validate_name("工作笔记").is_ok());
        assert!(Pool::validate_name("a").is_ok());

        // 空名称
        assert!(Pool::validate_name("").is_err());

        // 超长名称（129 字符）
        let long_name = "a".repeat(129);
        assert!(Pool::validate_name(&long_name).is_err());

        // 128 字符应该通过
        let max_name = "a".repeat(128);
        assert!(Pool::validate_name(&max_name).is_ok());
    }

    #[test]
    fn test_validate_password() {
        // 有效密码
        assert!(Pool::validate_password("12345678").is_ok());
        assert!(Pool::validate_password("password123").is_ok());

        // 太短的密码
        assert!(Pool::validate_password("1234567").is_err());
        assert!(Pool::validate_password("").is_err());

        // 8 位正好应该通过
        assert!(Pool::validate_password("12345678").is_ok());
    }

    #[test]
    fn test_pool_serialization() {
        let mut pool = Pool::new("pool-001", "工作笔记", "hashed");
        let device = Device::new("device-001", "iPhone");
        pool.add_member(device);

        // 序列化
        let json = serde_json::to_string(&pool).unwrap();
        assert!(json.contains("pool-001"));
        assert!(json.contains("工作笔记"));

        // 反序列化
        let deserialized: Pool = serde_json::from_str(&json).unwrap();
        assert_eq!(deserialized.pool_id, pool.pool_id);
        assert_eq!(deserialized.name, pool.name);
        assert_eq!(deserialized.members.len(), 1);
    }
}
