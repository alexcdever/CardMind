//! 设备配置管理
//!
//! 本模块管理本地设备配置，包括设备 ID、当前加入的数据池，以及 mDNS 临时启用状态。

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

/// mDNS 临时启用配置
///
/// 5 分钟倒计时模式，用于临时启用 mDNS 设备发现功能。
/// 计时器状态**不会持久化**，应用重启后会自动重置为关闭状态（隐私保护）。
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq, Default)]
pub struct MDnsTimerConfig {
    /// 计时器结束时间戳（毫秒），None 表示未启用
    /// `skip_serializing`: 不持久化到存储（重启后重置）
    #[serde(default, skip_serializing)]
    pub timer_end_ms: Option<i64>,
}

impl MDnsTimerConfig {
    /// 创建新的计时器配置（默认关闭）
    #[must_use]
    pub const fn new() -> Self {
        Self { timer_end_ms: None }
    }

    /// 启用 mDNS 5 分钟倒计时
    pub fn start_timer(&mut self) {
        self.timer_end_ms = Some(Utc::now().timestamp_millis() + Self::DURATION_MS);
    }

    /// 取消计时器
    pub const fn cancel_timer(&mut self) {
        self.timer_end_ms = None;
    }

    /// 检查 mDNS 是否处于活跃状态
    #[must_use]
    pub fn is_active(&self) -> bool {
        self.timer_end_ms
            .is_some_and(|end| Utc::now().timestamp_millis() < end)
    }

    /// 获取剩余时间（毫秒），0 表示未激活或已过期
    #[must_use]
    pub fn remaining_ms(&self) -> i64 {
        self.timer_end_ms
            .map_or(0, |end| (end - Utc::now().timestamp_millis()).max(0))
    }

    /// mDNS 临时启用时长（5 分钟）
    pub const DURATION_MS: i64 = 5 * 60 * 1000;
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct DeviceConfig {
    pub device_id: String,
    pub pool_id: Option<String>,
    /// mDNS 临时启用计时器（不持久化，重启后重置）
    #[serde(default)]
    pub mdns_timer: MDnsTimerConfig,
}

impl DeviceConfig {
    /// 临时 mDNS 启用时长（5 分钟）
    pub const MDNS_TEMP_DURATION_MS: i64 = 5 * 60 * 1000;

    #[must_use]
    pub fn new(device_id: &str) -> Self {
        Self {
            device_id: device_id.to_string(),
            pool_id: None,
            mdns_timer: MDnsTimerConfig::new(),
        }
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
        Ok(())
    }

    pub fn leave_pool(&mut self, pool_id: &str) -> Result<(), DeviceConfigError> {
        match &self.pool_id {
            Some(current_pool_id) if current_pool_id == pool_id => {
                self.pool_id = None;
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

    #[must_use]
    pub fn default_path(base_path: &Path) -> PathBuf {
        base_path.join("config.json")
    }

    // === mDNS 临时启用相关方法 ===

    /// 检查 mDNS 是否处于活跃状态（5 分钟倒计时内）
    #[must_use]
    pub fn is_mdns_active(&self) -> bool {
        self.mdns_timer.is_active()
    }

    /// 启用 mDNS 临时发现功能（5 分钟）
    pub fn enable_mdns_temporary(&mut self) {
        self.mdns_timer.start_timer();
    }

    /// 取消 mDNS 临时启用计时器
    pub const fn cancel_mdns_timer(&mut self) {
        self.mdns_timer.cancel_timer();
    }

    /// 获取 mDNS 剩余时间（毫秒）
    #[must_use]
    pub fn get_mdns_remaining_ms(&self) -> i64 {
        self.mdns_timer.remaining_ms()
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

    // === mDNS 临时启用测试 ===

    #[test]
    fn test_mdns_inactive_by_default() {
        let config = DeviceConfig::new("device-001");
        assert!(!config.is_mdns_active());
        assert_eq!(config.get_mdns_remaining_ms(), 0);
    }

    #[test]
    fn test_enable_mdns_temporary() {
        let mut config = DeviceConfig::new("device-001");
        assert!(!config.is_mdns_active());

        config.enable_mdns_temporary();

        assert!(config.is_mdns_active());
        let remaining = config.get_mdns_remaining_ms();
        // Should have close to 5 minutes remaining
        assert!(
            remaining > 4 * 60 * 1000,
            "Expected > 4 minutes, got {remaining}ms"
        );
        assert!(
            remaining <= 5 * 60 * 1000,
            "Expected <= 5 minutes, got {remaining}ms"
        );
    }

    #[test]
    fn test_cancel_mdns_timer() {
        let mut config = DeviceConfig::new("device-001");
        config.enable_mdns_temporary();
        assert!(config.is_mdns_active());

        config.cancel_mdns_timer();

        assert!(!config.is_mdns_active());
        assert_eq!(config.get_mdns_remaining_ms(), 0);
    }

    #[test]
    fn test_mdns_timer_not_persisted() {
        let temp_dir = TempDir::new().unwrap();
        let config_path = temp_dir.path().join("config.json");

        // Enable mDNS and save
        let mut config = DeviceConfig::new("device-001");
        config.enable_mdns_temporary();
        assert!(config.mdns_timer.timer_end_ms.is_some());
        config.save(&config_path).unwrap();

        // Load in a new config (simulating app restart)
        let loaded = DeviceConfig::load(&config_path).unwrap();

        // Timer should be None because mdns_timer is marked with #[serde(default)]
        assert!(!loaded.is_mdns_active());
        assert_eq!(loaded.get_mdns_remaining_ms(), 0);
    }
}
