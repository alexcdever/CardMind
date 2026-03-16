// 应用服务层
// 提供统一的后端业务接口

use crate::models::api_error::{ApiError, ApiErrorCode};
use crate::models::error::CardMindError;
use crate::runtime::config::{BackendConfigDto, BackendConfigStore};
use crate::runtime::entry_manager::{RuntimeEntryManager, RuntimeEntryStatusDto};
use std::path::Path;
use std::sync::Arc;

/// 后端应用服务
pub struct BackendService {
    config_store: BackendConfigStore,
    runtime_manager: Arc<RuntimeEntryManager>,
}

impl BackendService {
    /// 创建新的后端服务实例
    pub fn new(app_data_dir: &str) -> Result<Self, CardMindError> {
        let config_store = BackendConfigStore::new(Path::new(app_data_dir));
        let runtime_manager = Arc::new(RuntimeEntryManager::new());

        // 加载配置并应用到运行时
        let config = config_store.load()?;
        runtime_manager.apply_config(
            config.http_enabled,
            config.mcp_enabled,
            config.cli_enabled,
        )?;

        Ok(Self {
            config_store,
            runtime_manager,
        })
    }

    /// 获取后端配置
    pub fn get_backend_config(&self) -> Result<BackendConfigDto, ApiError> {
        self.config_store.load().map_err(map_err)
    }

    /// 更新后端配置
    pub fn update_backend_config(
        &self,
        http_enabled: bool,
        mcp_enabled: bool,
        cli_enabled: bool,
    ) -> Result<BackendConfigDto, ApiError> {
        let config = BackendConfigDto {
            http_enabled,
            mcp_enabled,
            cli_enabled,
        };

        self.config_store.save(&config).map_err(map_err)?;

        // 同步更新运行时状态
        self.runtime_manager
            .apply_config(http_enabled, mcp_enabled, cli_enabled)
            .map_err(map_err)?;

        Ok(config)
    }

    /// 获取运行时入口状态
    pub fn get_runtime_entry_status(&self) -> Result<RuntimeEntryStatusDto, ApiError> {
        self.runtime_manager.status().map_err(map_err)
    }
}

fn map_err(err: CardMindError) -> ApiError {
    match err {
        CardMindError::Io(msg) => ApiError::new(ApiErrorCode::IoError, &msg),
        _ => ApiError::new(ApiErrorCode::Internal, "internal error"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn backend_service_reads_config_and_runtime_status() {
        let dir = TempDir::new().unwrap();
        let service = BackendService::new(dir.path().to_str().unwrap()).unwrap();

        let config = service.get_backend_config().unwrap();
        let runtime = service.get_runtime_entry_status().unwrap();

        assert!(!config.http_enabled);
        assert!(!runtime.http_active);
    }

    #[test]
    fn backend_service_updates_config_and_runtime() {
        let dir = TempDir::new().unwrap();
        let service = BackendService::new(dir.path().to_str().unwrap()).unwrap();

        // 更新配置
        service.update_backend_config(true, false, true).unwrap();

        // 验证配置已更新
        let config = service.get_backend_config().unwrap();
        let runtime = service.get_runtime_entry_status().unwrap();

        assert!(config.http_enabled);
        assert!(runtime.http_active);
        assert!(!config.mcp_enabled);
        assert!(!runtime.mcp_active);
        assert!(config.cli_enabled);
        assert!(runtime.cli_active);
    }
}
