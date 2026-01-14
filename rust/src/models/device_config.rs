//! 设备配置管理
//!
//! 本模块管理本地设备配置，包括设备 ID 和当前加入的数据池。

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

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct DeviceConfig {
    pub device_id: String,
    pub pool_id: Option<String>,
}

impl DeviceConfig {
    pub fn new(device_id: &str) -> Self {
        Self {
            device_id: device_id.to_string(),
            pool_id: None,
        }
    }

    pub fn join_pool(&mut self, pool_id: &str) -> Result<(), DeviceConfigError> {
        if let Some(current_pool) = &self.pool_id {
            if current_pool != pool_id {
                return Err(DeviceConfigError::InvalidOperationError(format!(
                    "设备已加入数据池: {}, 无法加入新的数据池: {}",
                    current_pool, pool_id
                )));
            }
        }
        self.pool_id = Some(pool_id.to_string());
        Ok(())
    }

    pub fn leave_pool(&mut self, pool_id: &str) -> Result<(), DeviceConfigError> {
        match &self.pool_id {
            Some(current_pool_id) if current_pool_id == pool_id => {
                self.pool_id = None;
                Ok(())
            }
            Some(current_pool_id) => Err(DeviceConfigError::InvalidOperationError(format!(
                "设备的当前池: {}, 无法退出指定池: {}",
                current_pool_id, pool_id
            ))),
            None => Err(DeviceConfigError::InvalidOperationError(
                "设备未加入任何数据池".to_string(),
            )),
        }
    }

    pub fn is_joined(&self, pool_id: &str) -> bool {
        self.pool_id == Some(pool_id.to_string())
    }

    pub fn is_joined_any(&self) -> bool {
        self.pool_id.is_some()
    }

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

    pub fn get_or_create(path: &Path, device_id: &str) -> Result<Self, DeviceConfigError> {
        match Self::load(path) {
            Ok(config) => Ok(config),
            Err(DeviceConfigError::ReadError(_) | DeviceConfigError::ConfigNotFound(_)) => {
                let config = Self::new(device_id);
                config.save(path)?;
                Ok(config)
            }
            Err(e) => Err(e),
        }
    }

    pub fn default_path(base_path: &Path) -> PathBuf {
        base_path.join("config.json")
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_new_device_config() {
        let config = DeviceConfig::new("device-001");
        assert_eq!(config.device_id, "device-001");
        assert!(config.pool_id.is_none());
    }

    #[test]
    fn test_join_pool() {
        let mut config = DeviceConfig::new("device-001");
        assert!(config.join_pool("pool-001").is_ok());
        assert_eq!(config.pool_id, Some("pool-001".to_string()));
    }

    #[test]
    fn test_join_pool_with_same_pool() {
        let mut config = DeviceConfig::new("device-001");
        config.join_pool("pool-001").unwrap();
        assert!(config.join_pool("pool-001").is_ok());
        assert_eq!(config.pool_id, Some("pool-001".to_string()));
    }

    #[test]
    fn test_cannot_join_multiple_pools() {
        let mut config = DeviceConfig::new("device-001");
        config.join_pool("pool-001").unwrap();
        let result = config.join_pool("pool-002");
        assert!(result.is_err());
        assert_eq!(config.pool_id, Some("pool-001".to_string()));
    }

    #[test]
    fn test_is_joined() {
        let mut config = DeviceConfig::new("device-001");
        config.join_pool("pool-001").unwrap();
        assert!(config.is_joined("pool-001"));
        assert!(!config.is_joined("pool-002"));
    }

    #[test]
    fn test_leave_pool() {
        let mut config = DeviceConfig::new("device-001");
        config.join_pool("pool-001").unwrap();
        assert!(config.leave_pool("pool-001").is_ok());
        assert!(config.pool_id.is_none());
    }

    #[test]
    fn test_cannot_leave_wrong_pool() {
        let mut config = DeviceConfig::new("device-001");
        config.join_pool("pool-001").unwrap();
        let result = config.leave_pool("pool-002");
        assert!(result.is_err());
        assert_eq!(config.pool_id, Some("pool-001".to_string()));
    }

    #[test]
    fn test_save_and_load() {
        let temp_dir = TempDir::new().unwrap();
        let config_path = temp_dir.path().join("config.json");
        let mut config = DeviceConfig::new("device-001");
        config.join_pool("pool-001").unwrap();
        config.save(&config_path).unwrap();

        let loaded = DeviceConfig::load(&config_path).unwrap();
        assert_eq!(loaded.device_id, "device-001");
        assert_eq!(loaded.pool_id, Some("pool-001".to_string()));
        assert!(loaded.is_joined("pool-001"));
    }

    #[test]
    fn test_get_or_create_new() {
        let temp_dir = TempDir::new().unwrap();
        let config_path = temp_dir.path().join("config.json");
        let config = DeviceConfig::get_or_create(&config_path, "device-001").unwrap();
        assert_eq!(config.device_id, "device-001");
    }

    #[test]
    fn test_get_or_create_existing() {
        let temp_dir = TempDir::new().unwrap();
        let config_path = temp_dir.path().join("config.json");
        let config1 = DeviceConfig::get_or_create(&config_path, "device-001").unwrap();
        config1.save(&config_path).unwrap();

        let config2 = DeviceConfig::get_or_create(&config_path, "device-002").unwrap();
        assert_eq!(config2.device_id, "device-001");
    }
}
