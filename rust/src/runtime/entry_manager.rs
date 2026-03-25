//! # 运行时入口管理器模块
//!
//! 负责管理 HTTP、MCP、CLI 等可选入口的生命周期。
//!
//! ## 职责范围
//! - 维护各运行时入口的激活状态
//! - 提供线程安全的状态访问
//! - 支持配置的动态应用
//!
//! ## 设计说明
//! 当前实现为状态管理器，实际入口的生命周期控制（启动/停止服务）
//! 将在后续版本中实现。本模块目前专注于状态的持久化和同步。
//!
//! ## 线程安全
//! 使用 `Mutex` 保护内部状态，支持多线程并发访问。
//!
//! ## 修改注意
//! 修改本文件需同步更新所属 DIR.md。

use serde::{Deserialize, Serialize};
use std::sync::Mutex;

/// 运行时入口状态 DTO。
///
/// 表示各可选入口的当前激活状态。
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct RuntimeEntryStatusDto {
    /// HTTP 入口是否激活。
    pub http_active: bool,
    /// MCP 入口是否激活。
    pub mcp_active: bool,
    /// CLI 入口是否激活。
    pub cli_active: bool,
}

/// 运行时入口管理器。
///
/// 管理 HTTP、MCP、CLI 等入口的状态。
pub struct RuntimeEntryManager {
    state: Mutex<RuntimeEntryStatusDto>,
}

impl RuntimeEntryManager {
    /// 创建新的管理器实例。
    ///
    /// 初始状态全部为未激活（`false`）。
    ///
    /// # Examples
    /// ```rust,ignore
    /// use cardmind_rust::runtime::entry_manager::RuntimeEntryManager;
    ///
    /// let manager = RuntimeEntryManager::new();
    /// let status = manager.status().unwrap();
    /// assert!(!status.http_active);
    /// ```
    pub fn new() -> Self {
        Self {
            state: Mutex::new(RuntimeEntryStatusDto::default()),
        }
    }

    /// 应用配置到运行时状态。
    ///
    /// 根据配置更新各入口的激活状态。
    ///
    /// # 参数
    /// * `http` - 是否激活 HTTP 入口。
    /// * `mcp` - 是否激活 MCP 入口。
    /// * `cli` - 是否激活 CLI 入口。
    ///
    /// # 返回
    /// - `Ok(())` - 应用成功。
    /// - `Err(CardMindError)` - 内部状态锁定失败（poisoned mutex）。
    ///
    /// # Examples
    /// ```rust,ignore
    /// use cardmind_rust::runtime::entry_manager::RuntimeEntryManager;
    ///
    /// let manager = RuntimeEntryManager::new();
    /// manager.apply_config(true, false, true).unwrap();
    ///
    /// let status = manager.status().unwrap();
    /// assert!(status.http_active);
    /// assert!(!status.mcp_active);
    /// assert!(status.cli_active);
    /// ```
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

    /// 获取当前运行时状态。
    ///
    /// # 返回
    /// - `Ok(RuntimeEntryStatusDto)` - 当前状态。
    /// - `Err(CardMindError)` - 内部状态锁定失败（poisoned mutex）。
    ///
    /// # Examples
    /// ```rust,ignore
    /// use cardmind_rust::runtime::entry_manager::RuntimeEntryManager;
    ///
    /// let manager = RuntimeEntryManager::new();
    /// let status = manager.status().unwrap();
    /// ```
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
    use std::sync::Arc;
    use std::thread;

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

    #[test]
    fn entry_manager_apply_config_returns_internal_error_when_poisoned() {
        let manager = Arc::new(RuntimeEntryManager::new());
        let cloned = Arc::clone(&manager);
        let _ = thread::spawn(move || {
            let _guard = cloned.state.lock().unwrap();
            panic!("poison mutex");
        })
        .join();

        let result = manager.apply_config(true, true, true).unwrap_err();

        match result {
            crate::models::error::CardMindError::Internal(msg) => {
                assert!(msg.contains("lock poisoned"));
            }
            other => panic!("unexpected error: {:?}", other),
        }
    }

    #[test]
    fn entry_manager_status_returns_internal_error_when_poisoned() {
        let manager = Arc::new(RuntimeEntryManager::new());
        let cloned = Arc::clone(&manager);
        let _ = thread::spawn(move || {
            let _guard = cloned.state.lock().unwrap();
            panic!("poison mutex");
        })
        .join();

        let result = manager.status().unwrap_err();

        match result {
            crate::models::error::CardMindError::Internal(msg) => {
                assert!(msg.contains("lock poisoned"));
            }
            other => panic!("unexpected error: {:?}", other),
        }
    }
}
