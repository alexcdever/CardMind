//! # 后端应用服务模块
//!
//! 提供统一的后端业务接口，协调配置管理与运行时状态。
//!
//! ## 职责范围
//! - 后端配置（HTTP/MCP/CLI 启用状态）的持久化管理
//! - 运行时入口（HTTP/MCP/CLI）的生命周期管理
//! - 配置变更的同步应用
//!
//! ## 架构说明
//! 本层作为应用服务层，介于 API 层和运行时层之间：
//! - 向上：为 API 层提供业务接口
//! - 向下：管理 `BackendConfigStore` 和 `RuntimeEntryManager`
//!
//! ## 修改注意
//! 修改本文件需同步更新所属 DIR.md。

use crate::models::api_error::{ApiError, ApiErrorCode};
use crate::models::error::CardMindError;
use crate::runtime::config::{BackendConfigDto, BackendConfigStore};
use crate::runtime::entry_manager::{RuntimeEntryManager, RuntimeEntryStatusDto};
use crate::security::app_lock::AppLock;
use std::path::Path;
use std::sync::Arc;

/// 后端应用服务。
///
/// 管理后端配置和运行时入口的统一服务。
pub struct BackendService {
    config_store: BackendConfigStore,
    runtime_manager: Arc<RuntimeEntryManager>,
    app_lock: AppLock,
}

impl BackendService {
    /// 创建新的后端服务实例。
    ///
    /// 初始化时会加载配置文件并应用到运行时管理器。
    ///
    /// # 参数
    /// * `app_data_dir` - 应用数据目录路径，用于存储配置文件。
    ///
    /// # 返回
    /// - `Ok(BackendService)` - 服务实例创建成功。
    /// - `Err(CardMindError)` - 配置加载或运行时初始化失败。
    ///
    /// # Examples
    /// ```rust,ignore
    /// use cardmind_rust::application::backend_service::BackendService;
    ///
    /// let service = BackendService::new("/path/to/app_data").unwrap();
    /// ```
    pub fn new(app_data_dir: &str) -> Result<Self, CardMindError> {
        let config_store = BackendConfigStore::new(Path::new(app_data_dir));
        let runtime_manager = Arc::new(RuntimeEntryManager::new());
        let app_lock = AppLock::new();

        // 加载配置并应用到运行时
        let config = config_store.load()?;
        runtime_manager.apply_config(
            config.http_enabled,
            config.mcp_enabled,
            config.cli_enabled,
        )?;
        runtime_manager.set_app_lock_state(
            app_lock.state().is_configured(),
            !app_lock.state().is_configured() || !app_lock.state().is_locked(),
        )?;

        Ok(Self {
            config_store,
            runtime_manager,
            app_lock,
        })
    }

    /// 获取后端配置。
    ///
    /// 从配置存储中加载当前配置。
    ///
    /// # 返回
    /// - `Ok(BackendConfigDto)` - 当前配置。
    /// - `Err(ApiError)` - 配置读取失败。
    ///
    /// # Examples
    /// ```rust,ignore
    /// use cardmind_rust::application::backend_service::BackendService;
    ///
    /// // let service = BackendService::new(...).unwrap();
    /// // let config = service.get_backend_config().unwrap();
    /// // println!("HTTP enabled: {}", config.http_enabled);
    /// ```
    pub fn get_backend_config(&self) -> Result<BackendConfigDto, ApiError> {
        self.config_store.load().map_err(map_err)
    }

    /// 更新后端配置。
    ///
    /// 保存新配置到持久化存储，并同步更新运行时状态。
    ///
    /// # 参数
    /// * `http_enabled` - 是否启用 HTTP 入口。
    /// * `mcp_enabled` - 是否启用 MCP 入口。
    /// * `cli_enabled` - 是否启用 CLI 入口。
    ///
    /// # 返回
    /// - `Ok(BackendConfigDto)` - 更新后的配置。
    /// - `Err(ApiError)` - 保存或应用失败。
    ///
    /// # Examples
    /// ```rust,ignore
    /// use cardmind_rust::application::backend_service::BackendService;
    ///
    /// // let service = BackendService::new(...).unwrap();
    /// // let config = service.update_backend_config(true, false, true).unwrap();
    /// ```
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

    /// 获取运行时入口状态。
    ///
    /// 查询当前运行时各入口的激活状态。
    ///
    /// # 返回
    /// - `Ok(RuntimeEntryStatusDto)` - 运行时状态。
    /// - `Err(ApiError)` - 状态查询失败。
    ///
    /// # Examples
    /// ```rust,ignore
    /// use cardmind_rust::application::backend_service::BackendService;
    ///
    /// // let service = BackendService::new(...).unwrap();
    /// // let status = service.get_runtime_entry_status().unwrap();
    /// // assert!(!status.http_active); // 默认未激活
    /// ```
    pub fn get_runtime_entry_status(&self) -> Result<RuntimeEntryStatusDto, ApiError> {
        self.runtime_manager.status().map_err(map_err)
    }

    pub fn app_lock_status(&self) -> Result<(bool, bool), ApiError> {
        Ok((
            self.app_lock.state().is_configured(),
            !self.app_lock.state().is_locked(),
        ))
    }

    pub fn setup_app_lock(&mut self, pin: &str, allow_biometric: bool) -> Result<(), ApiError> {
        self.app_lock
            .set_pin(pin, allow_biometric)
            .map_err(map_app_lock_err)?;
        self.runtime_manager
            .set_app_lock_state(true, true)
            .map_err(map_err)
    }

    pub fn verify_app_lock_with_pin(&mut self, pin: &str) -> Result<(), ApiError> {
        self.app_lock.verify_pin(pin).map_err(map_app_lock_err)?;
        self.runtime_manager
            .set_app_lock_state(true, true)
            .map_err(map_err)
    }

    pub fn mark_biometric_success(&mut self) -> Result<(), ApiError> {
        self.app_lock
            .mark_biometric_success()
            .map_err(map_app_lock_err)?;
        self.runtime_manager
            .set_app_lock_state(true, true)
            .map_err(map_err)
    }

    pub fn reset_app_lock(&mut self) -> Result<(), ApiError> {
        self.app_lock
            .reset_with_token(&crate::security::app_lock::ResetToken::privileged())
            .map_err(map_app_lock_err)?;
        self.runtime_manager
            .set_app_lock_state(false, false)
            .map_err(map_err)
    }

    pub fn require_app_lock_unlocked(&self) -> Result<(), ApiError> {
        self.runtime_manager.require_unlocked().map_err(map_err)
    }
}

/// 将 `CardMindError` 映射为 `ApiError`。
///
/// 专用于后端服务层的错误转换。
///
/// # 映射规则
/// - `Io` → `IoError`
/// - 其他 → `Internal`
fn map_err(err: CardMindError) -> ApiError {
    match err {
        CardMindError::Io(msg) => ApiError::new(ApiErrorCode::IoError, &msg),
        CardMindError::InvalidArgument(msg) if msg == "app lock required" => {
            ApiError::new(ApiErrorCode::AppLockRequired, "app lock must be configured")
        }
        CardMindError::InvalidArgument(msg) if msg == "app lock locked" => {
            ApiError::new(ApiErrorCode::AppLocked, "app lock is locked")
        }
        _ => ApiError::new(ApiErrorCode::Internal, "internal error"),
    }
}

fn map_app_lock_err(err: crate::security::app_lock::AppLockError) -> ApiError {
    match err {
        crate::security::app_lock::AppLockError::NotConfigured => {
            ApiError::new(ApiErrorCode::AppLockRequired, "app lock must be configured")
        }
        crate::security::app_lock::AppLockError::Locked => {
            ApiError::new(ApiErrorCode::AppLocked, "app lock is locked")
        }
        crate::security::app_lock::AppLockError::InvalidPin => {
            ApiError::new(ApiErrorCode::InvalidArgument, "invalid app lock pin")
        }
        crate::security::app_lock::AppLockError::InvalidResetToken => ApiError::new(
            ApiErrorCode::InvalidArgument,
            "invalid app lock reset token",
        ),
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

    #[test]
    fn backend_service_map_err_maps_io_to_io_error() {
        let err = map_err(CardMindError::Io("disk failed".to_string()));

        assert_eq!(err.code, ApiErrorCode::IoError.as_str());
        assert!(err.message.contains("disk failed"));
    }

    #[test]
    fn backend_service_map_err_maps_non_io_to_internal() {
        let err = map_err(CardMindError::NotFound("missing".to_string()));

        assert_eq!(err.code, ApiErrorCode::Internal.as_str());
        assert_eq!(err.message, "internal error");
    }
}
