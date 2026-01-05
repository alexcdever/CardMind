//! 设备配置管理
//!
//! 本模块管理本地设备配置，包括设备 ID、已加入的数据池和常驻池列表。
//!
//! # 配置文件位置
//!
//! `/data/config.json`
//!
//! # 配置内容
//!
//! 根据 `docs/architecture/data_contract.md` 3.1 节的定义：
//! - **device_id**: 设备唯一标识（UUID v7）
//! - **joined_pools**: 已加入的数据池 ID 列表
//! - **resident_pools**: 常驻池 ID 列表（用户偏好）
//!
//! # 设计原则
//!
//! - **最小化存储**: 仅存储必要的索引信息和用户偏好
//! - **避免冗余**: 数据池详细信息从 Pool CRDT 读取
//! - **性能优化**: `joined_pools` 用于快速启动

use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};
use thiserror::Error;

/// 设备配置错误类型
#[derive(Error, Debug)]
pub enum DeviceConfigError {
    /// 配置文件未找到
    #[error("配置文件未找到: {0}")]
    ConfigNotFound(String),

    /// 配置文件读取错误
    #[error("配置文件读取错误: {0}")]
    ReadError(String),

    /// 配置文件写入错误
    #[error("配置文件写入错误: {0}")]
    WriteError(String),

    /// JSON 解析错误
    #[error("JSON 解析错误: {0}")]
    JsonError(String),

    /// IO 错误
    #[error("IO 错误: {0}")]
    IoError(#[from] std::io::Error),
}

/// 设备配置
///
/// # 字段说明
///
/// - `device_id`: 设备唯一标识（UUID v7）
/// - `joined_pools`: 已加入的数据池 ID 列表
/// - `resident_pools`: 常驻池 ID 列表
///
/// # 示例
///
/// ```
/// use cardmind_rust::models::device_config::DeviceConfig;
///
/// let mut config = DeviceConfig::new("device-001");
/// config.join_pool("pool-001");
/// config.set_resident_pool("pool-001", true);
///
/// assert_eq!(config.joined_pools.len(), 1);
/// assert_eq!(config.resident_pools.len(), 1);
/// ```
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct DeviceConfig {
    /// 设备唯一标识
    pub device_id: String,

    /// 已加入的数据池 ID 列表
    #[serde(default)]
    pub joined_pools: Vec<String>,

    /// 常驻池 ID 列表（用户偏好设置）
    ///
    /// 常驻池：新建卡片时自动绑定到这些数据池
    #[serde(default)]
    pub resident_pools: Vec<String>,
}

impl DeviceConfig {
    /// 创建新的设备配置
    ///
    /// # 参数
    ///
    /// - `device_id`: 设备 UUID
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::models::device_config::DeviceConfig;
    ///
    /// let config = DeviceConfig::new("device-001");
    /// assert_eq!(config.device_id, "device-001");
    /// assert!(config.joined_pools.is_empty());
    /// assert!(config.resident_pools.is_empty());
    /// ```
    #[must_use]
    pub fn new(device_id: &str) -> Self {
        Self {
            device_id: device_id.to_string(),
            joined_pools: Vec::new(),
            resident_pools: Vec::new(),
        }
    }

    /// 加入数据池
    ///
    /// # 参数
    ///
    /// - `pool_id`: 数据池 ID
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::models::device_config::DeviceConfig;
    ///
    /// let mut config = DeviceConfig::new("device-001");
    /// config.join_pool("pool-001");
    /// assert_eq!(config.joined_pools.len(), 1);
    /// ```
    pub fn join_pool(&mut self, pool_id: &str) {
        if !self.joined_pools.contains(&pool_id.to_string()) {
            self.joined_pools.push(pool_id.to_string());
        }
    }

    /// 退出数据池
    ///
    /// # 参数
    ///
    /// - `pool_id`: 数据池 ID
    ///
    /// # Returns
    ///
    /// 如果数据池存在并成功退出，返回 true
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::models::device_config::DeviceConfig;
    ///
    /// let mut config = DeviceConfig::new("device-001");
    /// config.join_pool("pool-001");
    /// let left = config.leave_pool("pool-001");
    /// assert!(left);
    /// assert!(config.joined_pools.is_empty());
    /// ```
    pub fn leave_pool(&mut self, pool_id: &str) -> bool {
        let original_len = self.joined_pools.len();
        self.joined_pools.retain(|id| id != pool_id);

        // 同时从常驻池中移除
        if original_len > self.joined_pools.len() {
            self.resident_pools.retain(|id| id != pool_id);
            true
        } else {
            false
        }
    }

    /// 设置或取消常驻池
    ///
    /// # 参数
    ///
    /// - `pool_id`: 数据池 ID
    /// - `is_resident`: true 设置为常驻池，false 取消常驻
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::models::device_config::DeviceConfig;
    ///
    /// let mut config = DeviceConfig::new("device-001");
    /// config.join_pool("pool-001");
    /// config.set_resident_pool("pool-001", true);
    /// assert_eq!(config.resident_pools.len(), 1);
    ///
    /// config.set_resident_pool("pool-001", false);
    /// assert!(config.resident_pools.is_empty());
    /// ```
    pub fn set_resident_pool(&mut self, pool_id: &str, is_resident: bool) {
        if is_resident {
            // 设置为常驻池（必须先加入）
            if self.joined_pools.contains(&pool_id.to_string())
                && !self.resident_pools.contains(&pool_id.to_string())
            {
                self.resident_pools.push(pool_id.to_string());
            }
        } else {
            // 取消常驻池
            self.resident_pools.retain(|id| id != pool_id);
        }
    }

    /// 检查是否已加入数据池
    ///
    /// # 参数
    ///
    /// - `pool_id`: 数据池 ID
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::models::device_config::DeviceConfig;
    ///
    /// let mut config = DeviceConfig::new("device-001");
    /// config.join_pool("pool-001");
    /// assert!(config.is_joined("pool-001"));
    /// assert!(!config.is_joined("pool-002"));
    /// ```
    #[must_use]
    pub fn is_joined(&self, pool_id: &str) -> bool {
        self.joined_pools.contains(&pool_id.to_string())
    }

    /// 检查是否为常驻池
    ///
    /// # 参数
    ///
    /// - `pool_id`: 数据池 ID
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::models::device_config::DeviceConfig;
    ///
    /// let mut config = DeviceConfig::new("device-001");
    /// config.join_pool("pool-001");
    /// config.set_resident_pool("pool-001", true);
    /// assert!(config.is_resident("pool-001"));
    /// ```
    #[must_use]
    pub fn is_resident(&self, pool_id: &str) -> bool {
        self.resident_pools.contains(&pool_id.to_string())
    }

    /// 从文件加载配置
    ///
    /// # 参数
    ///
    /// - `path`: 配置文件路径
    ///
    /// # Errors
    ///
    /// 如果文件不存在或读取失败，返回错误
    ///
    /// # 示例
    ///
    /// ```no_run
    /// use cardmind_rust::models::device_config::DeviceConfig;
    /// use std::path::Path;
    ///
    /// let config = DeviceConfig::load(Path::new("data/config.json")).unwrap();
    /// println!("Device ID: {}", config.device_id);
    /// ```
    pub fn load(path: &Path) -> Result<Self, DeviceConfigError> {
        let content = fs::read_to_string(path)
            .map_err(|e| DeviceConfigError::ReadError(format!("无法读取配置文件: {e}")))?;

        serde_json::from_str(&content)
            .map_err(|e| DeviceConfigError::JsonError(format!("JSON 解析失败: {e}")))
    }

    /// 保存配置到文件
    ///
    /// # 参数
    ///
    /// - `path`: 配置文件路径
    ///
    /// # Errors
    ///
    /// 如果写入失败，返回错误
    ///
    /// # 示例
    ///
    /// ```no_run
    /// use cardmind_rust::models::device_config::DeviceConfig;
    /// use std::path::Path;
    ///
    /// let config = DeviceConfig::new("device-001");
    /// config.save(Path::new("data/config.json")).unwrap();
    /// ```
    pub fn save(&self, path: &Path) -> Result<(), DeviceConfigError> {
        // 确保父目录存在
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)?;
        }

        let json = serde_json::to_string_pretty(self)
            .map_err(|e| DeviceConfigError::JsonError(format!("JSON 序列化失败: {e}")))?;

        fs::write(path, json)
            .map_err(|e| DeviceConfigError::WriteError(format!("无法写入配置文件: {e}")))?;

        Ok(())
    }

    /// 获取或创建设备配置
    ///
    /// 如果配置文件不存在，创建新的配置并保存
    ///
    /// # 参数
    ///
    /// - `path`: 配置文件路径
    /// - `device_id`: 设备 UUID（用于新配置）
    ///
    /// # Errors
    ///
    /// 如果读取或创建失败，返回错误
    pub fn get_or_create(path: &Path, device_id: &str) -> Result<Self, DeviceConfigError> {
        match Self::load(path) {
            Ok(config) => Ok(config),
            Err(DeviceConfigError::ReadError(_)) | Err(DeviceConfigError::ConfigNotFound(_)) => {
                // 配置文件不存在，创建新配置
                let config = Self::new(device_id);
                config.save(path)?;
                Ok(config)
            }
            Err(e) => Err(e),
        }
    }

    /// 获取默认配置文件路径
    ///
    /// # 参数
    ///
    /// - `base_path`: 数据目录基础路径
    ///
    /// # 示例
    ///
    /// ```
    /// use cardmind_rust::models::device_config::DeviceConfig;
    /// use std::path::Path;
    ///
    /// let path = DeviceConfig::default_path(Path::new("/data"));
    /// assert_eq!(path.to_str().unwrap(), "/data/config.json");
    /// ```
    #[must_use]
    pub fn default_path(base_path: &Path) -> PathBuf {
        base_path.join("config.json")
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_device_config_creation() {
        let config = DeviceConfig::new("device-001");
        assert_eq!(config.device_id, "device-001");
        assert!(config.joined_pools.is_empty());
        assert!(config.resident_pools.is_empty());
    }

    #[test]
    fn test_join_pool() {
        let mut config = DeviceConfig::new("device-001");
        config.join_pool("pool-001");
        config.join_pool("pool-002");

        assert_eq!(config.joined_pools.len(), 2);
        assert!(config.is_joined("pool-001"));
        assert!(config.is_joined("pool-002"));

        // 重复加入应该被忽略
        config.join_pool("pool-001");
        assert_eq!(config.joined_pools.len(), 2);
    }

    #[test]
    fn test_leave_pool() {
        let mut config = DeviceConfig::new("device-001");
        config.join_pool("pool-001");
        config.set_resident_pool("pool-001", true);

        let left = config.leave_pool("pool-001");
        assert!(left);
        assert!(!config.is_joined("pool-001"));
        assert!(!config.is_resident("pool-001")); // 应该同时从常驻池移除

        // 退出不存在的池应该返回 false
        let left = config.leave_pool("pool-999");
        assert!(!left);
    }

    #[test]
    fn test_resident_pool() {
        let mut config = DeviceConfig::new("device-001");
        config.join_pool("pool-001");

        // 设置常驻池
        config.set_resident_pool("pool-001", true);
        assert!(config.is_resident("pool-001"));

        // 取消常驻池
        config.set_resident_pool("pool-001", false);
        assert!(!config.is_resident("pool-001"));

        // 未加入的池不能设为常驻池
        config.set_resident_pool("pool-002", true);
        assert!(!config.is_resident("pool-002"));
    }

    #[test]
    fn test_save_and_load() {
        let temp_dir = TempDir::new().unwrap();
        let config_path = temp_dir.path().join("config.json");

        // 创建并保存配置
        let mut config = DeviceConfig::new("device-001");
        config.join_pool("pool-001");
        config.set_resident_pool("pool-001", true);
        config.save(&config_path).unwrap();

        // 加载配置
        let loaded = DeviceConfig::load(&config_path).unwrap();
        assert_eq!(loaded.device_id, "device-001");
        assert_eq!(loaded.joined_pools.len(), 1);
        assert_eq!(loaded.resident_pools.len(), 1);
        assert!(loaded.is_joined("pool-001"));
        assert!(loaded.is_resident("pool-001"));
    }

    #[test]
    fn test_get_or_create() {
        let temp_dir = TempDir::new().unwrap();
        let config_path = temp_dir.path().join("config.json");

        // 第一次调用应该创建新配置
        let config = DeviceConfig::get_or_create(&config_path, "device-001").unwrap();
        assert_eq!(config.device_id, "device-001");

        // 第二次调用应该加载已有配置
        let loaded = DeviceConfig::get_or_create(&config_path, "device-002").unwrap();
        assert_eq!(loaded.device_id, "device-001"); // 应该加载已有的，不是新的
    }

    #[test]
    fn test_default_path() {
        let base_path = Path::new("/data");
        let path = DeviceConfig::default_path(base_path);
        assert_eq!(path.to_str().unwrap(), "/data/config.json");
    }

    #[test]
    fn test_serialization() {
        let mut config = DeviceConfig::new("device-001");
        config.join_pool("pool-001");
        config.set_resident_pool("pool-001", true);

        // 序列化
        let json = serde_json::to_string(&config).unwrap();
        assert!(json.contains("device-001"));
        assert!(json.contains("pool-001"));

        // 反序列化
        let deserialized: DeviceConfig = serde_json::from_str(&json).unwrap();
        assert_eq!(deserialized, config);
    }
}
