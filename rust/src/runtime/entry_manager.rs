// 运行时入口管理器
// 负责管理 HTTP、MCP、CLI 等可选入口的生命周期

use serde::{Deserialize, Serialize};
use std::sync::Mutex;

/// 运行时入口状态 DTO
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct RuntimeEntryStatusDto {
    pub http_active: bool,
    pub mcp_active: bool,
    pub cli_active: bool,
}

/// 运行时入口管理器
pub struct RuntimeEntryManager {
    state: Mutex<RuntimeEntryStatusDto>,
}

impl RuntimeEntryManager {
    /// 创建新的管理器实例
    pub fn new() -> Self {
        Self {
            state: Mutex::new(RuntimeEntryStatusDto::default()),
        }
    }

    /// 应用配置到运行时状态
    pub fn apply_config(
        &self,
        http: bool,
        mcp: bool,
        cli: bool,
    ) -> Result<(), crate::models::error::CardMindError> {
        let mut state = self.state.lock().map_err(|_| {
            crate::models::error::CardMindError::Internal("Runtime state lock poisoned".to_string())
        })?;

        *state = RuntimeEntryStatusDto {
            http_active: http,
            mcp_active: mcp,
            cli_active: cli,
        };

        Ok(())
    }

    /// 获取当前运行时状态
    pub fn status(&self) -> Result<RuntimeEntryStatusDto, crate::models::error::CardMindError> {
        let state = self.state.lock().map_err(|_| {
            crate::models::error::CardMindError::Internal("Runtime state lock poisoned".to_string())
        })?;

        Ok(state.clone())
    }
}

impl Default for RuntimeEntryManager {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn entry_manager_reports_default_disabled_entries() {
        let manager = RuntimeEntryManager::new();
        let status = manager.status().unwrap();

        assert!(!status.http_active);
        assert!(!status.mcp_active);
        assert!(!status.cli_active);
    }

    #[test]
    fn entry_manager_applies_config_to_runtime_state() {
        let manager = RuntimeEntryManager::new();
        manager.apply_config(true, false, true).unwrap();

        let status = manager.status().unwrap();
        assert!(status.http_active);
        assert!(!status.mcp_active);
        assert!(status.cli_active);
    }
}
