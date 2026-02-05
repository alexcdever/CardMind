//! 设备配置管理
//!
//! 本模块管理本地设备配置，包括 `peer_id`、设备名称与当前加入的数据池。

use crate::utils::uuid_v7::generate_uuid_v7;
use chrono::Utc;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};
use thiserror::Error;

/// 设备配置错误
#[derive(Error, Debug)]
pub enum DeviceConfigError {
    #[error("配置文件未找到: {0}")]
    ConfigNotFound(String),

    #[error("配置文件读取错误: {0}")]
    ReadError(String),

    #[error("配置文件写入错误: {0}")]
    WriteError(String),

    #[error("JSON 解析错误: {0}")]
    JsonError(String),

    #[error("IO 错误: {0}")]
    IoError(#[from] std::io::Error),

    #[error("无效操作: {0}")]
    InvalidOperationError(String),
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct DeviceConfig {
    pub peer_id: Option<String>,
    pub device_name: String,
    pub pool_id: Option<String>,
    pub updated_at: i64,
}

impl Default for DeviceConfig {
    fn default() -> Self {
        Self::new()
    }
}

impl DeviceConfig {
    #[must_use]
    pub fn new() -> Self {
        Self {
            peer_id: None,
            device_name: Self::default_device_name(),
            pool_id: None,
            updated_at: Self::now_ms(),
        }
    }

    #[must_use]
    fn now_ms() -> i64 {
        Utc::now().timestamp_millis()
    }

    #[must_use]
    fn default_device_name() -> String {
        let suffix = generate_uuid_v7()
            .chars()
            .rev()
            .take(5)
            .collect::<String>()
            .chars()
            .rev()
            .collect::<String>();
        format!("Device-{suffix}")
    }

    pub fn join_pool(&mut self, pool_id: &str) -> Result<(), DeviceConfigError> {
        if let Some(current_pool) = &self.pool_id {
            if current_pool != pool_id {
                return Err(DeviceConfigError::InvalidOperationError(format!(
                    "设备已加入数据池: {current_pool}, 无法加入新的数据池: {pool_id}"
                )));
            }
        }
        self.pool_id = Some(pool_id.to_string());
        self.updated_at = Self::now_ms();
        Ok(())
    }

    pub fn leave_pool(&mut self, pool_id: &str) -> Result<(), DeviceConfigError> {
        match &self.pool_id {
            Some(current_pool_id) if current_pool_id == pool_id => {
                self.pool_id = None;
                self.updated_at = Self::now_ms();
                Ok(())
            }
            Some(current_pool_id) => Err(DeviceConfigError::InvalidOperationError(format!(
                "设备的当前池: {current_pool_id}, 无法退出指定池: {pool_id}"
            ))),
            None => Err(DeviceConfigError::InvalidOperationError(
                "设备未加入任何数据池".to_string(),
            )),
        }
    }

    #[must_use]
    pub fn is_joined(&self, pool_id: &str) -> bool {
        self.pool_id == Some(pool_id.to_string())
    }

    #[must_use]
    pub const fn is_joined_any(&self) -> bool {
        self.pool_id.is_some()
    }

    #[must_use]
    pub fn get_pool_id(&self) -> Option<&str> {
        self.pool_id.as_deref()
    }

    pub fn load(path: &Path) -> Result<Self, DeviceConfigError> {
        let content = fs::read_to_string(path)
            .map_err(|e| DeviceConfigError::ReadError(format!("无法读取配置文件: {e}")))?;

        serde_json::from_str(&content)
            .map_err(|e| DeviceConfigError::JsonError(format!("JSON 解析失败: {e}")))
    }

    pub fn save(&self, path: &Path) -> Result<(), DeviceConfigError> {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)?;
        }

        let json = serde_json::to_string_pretty(self)
            .map_err(|e| DeviceConfigError::JsonError(format!("JSON 序列化失败: {e}")))?;

        fs::write(path, json)
            .map_err(|e| DeviceConfigError::WriteError(format!("无法写入配置文件: {e}")))?;

        Ok(())
    }

    pub fn get_or_create(path: &Path) -> Result<Self, DeviceConfigError> {
        match Self::load(path) {
            Ok(config) => Ok(config),
            Err(DeviceConfigError::ReadError(_) | DeviceConfigError::ConfigNotFound(_)) => {
                let config = Self::new();
                config.save(path)?;
                Ok(config)
            }
            Err(e) => Err(e),
        }
    }

    #[must_use]
    pub fn default_path(base_path: &Path) -> PathBuf {
        base_path.join("config.json")
    }

    // === mDNS 临时启用相关方法已移除 ===
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn it_should_new_device_config() {
        let config = DeviceConfig::new();
        assert!(config.peer_id.is_none());
        assert!(!config.device_name.is_empty());
        assert!(config.pool_id.is_none());
        assert!(config.updated_at > 0);
    }

    #[test]
    fn it_should_join_pool() {
        let mut config = DeviceConfig::new();
        let before = config.updated_at;
        std::thread::sleep(std::time::Duration::from_millis(1));
        assert!(config.join_pool("pool-001").is_ok());
        assert_eq!(config.pool_id, Some("pool-001".to_string()));
        assert!(config.updated_at >= before);
    }

    #[test]
    fn it_should_join_pool_with_same_pool() {
        let mut config = DeviceConfig::new();
        config.join_pool("pool-001").unwrap();
        assert!(config.join_pool("pool-001").is_ok());
        assert_eq!(config.pool_id, Some("pool-001".to_string()));
    }

    #[test]
    fn it_should_cannot_join_multiple_pools() {
        let mut config = DeviceConfig::new();
        config.join_pool("pool-001").unwrap();
        let result = config.join_pool("pool-002");
        assert!(result.is_err());
        assert_eq!(config.pool_id, Some("pool-001".to_string()));
    }

    #[test]
    fn it_should_is_joined() {
        let mut config = DeviceConfig::new();
        config.join_pool("pool-001").unwrap();
        assert!(config.is_joined("pool-001"));
        assert!(!config.is_joined("pool-002"));
    }

    #[test]
    fn it_should_leave_pool() {
        let mut config = DeviceConfig::new();
        config.join_pool("pool-001").unwrap();
        assert!(config.leave_pool("pool-001").is_ok());
        assert!(config.pool_id.is_none());
    }

    #[test]
    fn it_should_cannot_leave_wrong_pool() {
        let mut config = DeviceConfig::new();
        config.join_pool("pool-001").unwrap();
        let result = config.leave_pool("pool-002");
        assert!(result.is_err());
        assert_eq!(config.pool_id, Some("pool-001".to_string()));
    }

    #[test]
    fn it_should_save_and_load() {
        let temp_dir = TempDir::new().unwrap();
        let config_path = temp_dir.path().join("config.json");
        let mut config = DeviceConfig::new();
        config.join_pool("pool-001").unwrap();
        config.save(&config_path).unwrap();

        let loaded = DeviceConfig::load(&config_path).unwrap();
        assert_eq!(loaded.peer_id, config.peer_id);
        assert_eq!(loaded.device_name, config.device_name);
        assert_eq!(loaded.pool_id, Some("pool-001".to_string()));
        assert!(loaded.is_joined("pool-001"));
    }

    #[test]
    fn it_should_get_or_create_new() {
        let temp_dir = TempDir::new().unwrap();
        let config_path = temp_dir.path().join("config.json");
        let config = DeviceConfig::get_or_create(&config_path).unwrap();
        assert!(config.peer_id.is_none());
    }

    #[test]
    fn it_should_get_or_create_existing() {
        let temp_dir = TempDir::new().unwrap();
        let config_path = temp_dir.path().join("config.json");
        let mut config1 = DeviceConfig::get_or_create(&config_path).unwrap();
        config1.peer_id = Some("peer-001".to_string());
        config1.save(&config_path).unwrap();

        let config2 = DeviceConfig::get_or_create(&config_path).unwrap();
        assert_eq!(config2.peer_id.as_deref(), Some("peer-001"));
    }
}
