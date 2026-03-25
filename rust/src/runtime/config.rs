//! # 后端运行时配置管理模块
//!
//! 负责入口启用配置的持久化存储。
//!
//! ## 职责范围
//! - 后端配置（HTTP/MCP/CLI 启用状态）的 JSON 文件存储
//! - 配置的加载与保存
//! - 配置文件不存在时的默认值处理
//!
//! ## 配置位置
//! 配置文件存储在应用数据目录下，文件名为 `backend_config.json`。
//!
//! ## 默认值
//! 所有入口默认禁用（`false`）。
//!
//! ## 修改注意
//! 修改本文件需同步更新所属 DIR.md。

use crate::models::error::CardMindError;
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};

/// 后端配置 DTO。
///
/// 表示各可选入口的启用状态。
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct BackendConfigDto {
    /// 是否启用 HTTP 入口。
    pub http_enabled: bool,
    /// 是否启用 MCP 入口。
    pub mcp_enabled: bool,
    /// 是否启用 CLI 入口。
    pub cli_enabled: bool,
}

/// 后端配置存储。
///
/// 管理后端配置的持久化存储。
pub struct BackendConfigStore {
    config_path: PathBuf,
}

impl BackendConfigStore {
    /// 创建新的配置存储实例。
    ///
    /// 配置文件路径为 `base_dir/backend_config.json`。
    ///
    /// # 参数
    /// * `base_dir` - 配置文件所在的基础目录。
    ///
    /// # Examples
    /// ```rust,ignore
    /// use std::path::Path;
    /// use cardmind_rust::runtime::config::BackendConfigStore;
    ///
    /// let store = BackendConfigStore::new(Path::new("/app/data"));
    /// ```
    pub fn new(base_dir: &Path) -> Self {
        Self {
            config_path: base_dir.join("backend_config.json"),
        }
    }

    /// 加载配置。
    ///
    /// 如果配置文件不存在，返回默认值并自动创建文件。
    ///
    /// # 返回
    /// - `Ok(BackendConfigDto)` - 加载的配置或默认值。
    /// - `Err(CardMindError)` - 文件读取或解析失败。
    ///
    /// # Examples
    /// ```rust,ignore
    /// use cardmind_rust::runtime::config::BackendConfigStore;
    ///
    /// let config = store.load().unwrap();
    /// println!("HTTP enabled: {}", config.http_enabled);
    /// ```
    pub fn load(&self) -> Result<BackendConfigDto, CardMindError> {
        if !self.config_path.exists() {
            // 配置文件不存在，返回默认值并创建文件
            let config = BackendConfigDto::default();
            self.save(&config)?;
            return Ok(config);
        }

        let content = std::fs::read_to_string(&self.config_path)
            .map_err(|e| CardMindError::Io(format!("Failed to read config: {}", e)))?;

        let config: BackendConfigDto = serde_json::from_str(&content)
            .map_err(|e| CardMindError::Io(format!("Failed to parse config: {}", e)))?;

        Ok(config)
    }

    /// 保存配置到文件。
    ///
    /// 将配置序列化为 JSON 并写入文件。
    ///
    /// # 参数
    /// * `config` - 要保存的配置。
    ///
    /// # 返回
    /// - `Ok(())` - 保存成功。
    /// - `Err(CardMindError)` - 序列化或文件写入失败。
    ///
    /// # Examples
    /// ```rust,ignore
    /// use cardmind_rust::runtime::config::{BackendConfigDto, BackendConfigStore};
    ///
    /// let config = BackendConfigDto {
    ///     http_enabled: true,
    ///     mcp_enabled: false,
    ///     cli_enabled: true,
    /// };
    /// store.save(&config).unwrap();
    /// ```
    pub fn save(&self, config: &BackendConfigDto) -> Result<(), CardMindError> {
        let content = serde_json::to_string_pretty(config)
            .map_err(|e| CardMindError::Io(format!("Failed to serialize config: {}", e)))?;

        std::fs::write(&self.config_path, content)
            .map_err(|e| CardMindError::Io(format!("Failed to write config: {}", e)))?;

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn backend_config_store_creates_default_file_when_missing() {
        let dir = TempDir::new().unwrap();
        let store = BackendConfigStore::new(dir.path());

        let config = store.load().unwrap();

        assert!(!config.http_enabled);
        assert!(!config.mcp_enabled);
        assert!(!config.cli_enabled);
        assert!(dir.path().join("backend_config.json").exists());
    }

    #[test]
    fn backend_config_store_persists_changes() {
        let dir = TempDir::new().unwrap();
        let store = BackendConfigStore::new(dir.path());

        // 先加载默认值
        let _ = store.load().unwrap();

        // 保存新配置
        let new_config = BackendConfigDto {
            http_enabled: true,
            mcp_enabled: false,
            cli_enabled: true,
        };
        store.save(&new_config).unwrap();

        // 重新加载验证
        let reloaded = store.load().unwrap();
        assert!(reloaded.http_enabled);
        assert!(!reloaded.mcp_enabled);
        assert!(reloaded.cli_enabled);
    }
}
