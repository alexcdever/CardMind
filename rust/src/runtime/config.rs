// 后端运行时配置管理
// 负责入口启用配置的持久化存储

use crate::models::error::CardMindError;
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};

/// 后端配置 DTO
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct BackendConfigDto {
    pub http_enabled: bool,
    pub mcp_enabled: bool,
    pub cli_enabled: bool,
}

/// 后端配置存储
pub struct BackendConfigStore {
    config_path: PathBuf,
}

impl BackendConfigStore {
    /// 创建新的配置存储实例
    pub fn new(base_dir: &Path) -> Self {
        Self {
            config_path: base_dir.join("backend_config.json"),
        }
    }

    /// 加载配置，如果不存在则返回默认值
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

    /// 保存配置到文件
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
