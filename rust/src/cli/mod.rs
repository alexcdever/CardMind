//! CLI 入口适配器 - 命令行调试与运维接口
//!
//! 核心职责：
//! - 提供 JSON-RPC 风格的命令行接口用于调试
//! - 支持运行时配置查询与诊断
//! - 非生产环境使用，便于开发与测试
//!
//! # 安全警告
//! CLI 接口绕过正常认证与权限检查，仅在受信任的本地环境使用。
//! 生产构建应禁用 CLI 模块（通过 `cli_enabled: false` 配置）。
//!
//! # 命令格式
//! 所有命令使用 JSON 格式，包含 `command` 字段：
//! ```json
//! {"command": "get_backend_config"}
//! {"command": "get_runtime_entry_status"}
//! ```
//!
//! # Examples
//! ```rust,ignore
//! use cardmind_rust::cli::DebugConsole;
//! use cardmind_rust::application::backend_service::BackendService;
//! use std::sync::Arc;
//!
//! // 创建控制台实例
//! let service = Arc::new(BackendService::new("/data").unwrap());
//! let console = DebugConsole::new(service);
//!
//! // 执行命令
//! let response = console.run_json(r#"{"command":"get_backend_config"}"#).unwrap();
//! println!("{}", response);
//! ```

use crate::application::backend_service::BackendService;
use crate::models::api_error::ApiError;
use std::sync::Arc;

/// 调试控制台 - JSON-RPC 风格的命令处理器
///
/// 通过 JSON 字符串接收命令，执行后返回 JSON 响应。
/// 支持命令：
/// - `get_backend_config` - 获取后端配置
/// - `get_runtime_entry_status` - 获取运行时状态
pub struct DebugConsole {
    service: Arc<BackendService>,
}

impl DebugConsole {
    /// 创建新的调试控制台实例。
    ///
    /// # 参数
    /// * `service` - 后端服务实例，用于执行调试命令。
    ///
    /// # 示例
    /// ```rust,ignore
    /// use cardmind_rust::cli::DebugConsole;
    /// use cardmind_rust::application::backend_service::BackendService;
    /// use std::sync::Arc;
    ///
    /// let service = Arc::new(BackendService::new("/data").unwrap());
    /// let console = DebugConsole::new(service);
    /// ```
    pub fn new(service: Arc<BackendService>) -> Self {
        Self { service }
    }

    /// 运行 JSON 命令并返回 JSON 响应。
    ///
    /// 解析输入的 JSON 字符串，执行对应的调试命令，返回 JSON 格式的结果。
    ///
    /// # 参数
    /// * `input` - JSON 格式的命令字符串，必须包含 `command` 字段。
    ///
    /// # 返回
    /// * `Ok(String)` - 命令执行成功，返回 JSON 序列化的响应。
    /// * `Err(ApiError)` - 命令解析失败或执行失败时返回错误。
    ///
    /// # 错误
    /// 可能返回以下错误：
    /// * `ApiErrorCode::InvalidArgument` - JSON 解析失败或缺少 `command` 字段。
    /// * `ApiErrorCode::InvalidArgument` - 未知的命令名称。
    ///
    /// # 支持的命令
    /// * `get_backend_config` - 获取后端配置信息。
    /// * `get_runtime_entry_status` - 获取运行时状态信息。
    ///
    /// # 示例
    /// ```rust,ignore
    /// use cardmind_rust::cli::DebugConsole;
    /// use cardmind_rust::application::backend_service::BackendService;
    /// use std::sync::Arc;
    ///
    /// let service = Arc::new(BackendService::new("/data").unwrap());
    /// let console = DebugConsole::new(service);
    ///
    /// // 获取后端配置
    /// let response = console.run_json(r#"{"command":"get_backend_config"}"#).unwrap();
    /// println!("{}", response);
    ///
    /// // 获取运行时状态
    /// let response = console.run_json(r#"{"command":"get_runtime_entry_status"}"#).unwrap();
    /// println!("{}", response);
    /// ```
    pub fn run_json(&self, input: &str) -> Result<String, ApiError> {
        // 解析命令
        let command: serde_json::Value = serde_json::from_str(input).map_err(|e| {
            ApiError::new(
                crate::models::api_error::ApiErrorCode::InvalidArgument,
                &format!("Invalid JSON: {}", e),
            )
        })?;

        let cmd = command
            .get("command")
            .and_then(|v| v.as_str())
            .ok_or_else(|| {
                ApiError::new(
                    crate::models::api_error::ApiErrorCode::InvalidArgument,
                    "Missing 'command' field",
                )
            })?;

        // 执行命令
        match cmd {
            "get_backend_config" => {
                let config = self.service.get_backend_config()?;
                Ok(serde_json::to_string(&config)
                    .expect("backend config DTO serialization should not fail"))
            }
            "get_runtime_entry_status" => {
                let status = self.service.get_runtime_entry_status()?;
                Ok(serde_json::to_string(&status)
                    .expect("runtime status DTO serialization should not fail"))
            }
            _ => Err(ApiError::new(
                crate::models::api_error::ApiErrorCode::InvalidArgument,
                &format!("Unknown command: {}", cmd),
            )),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    /// 测试调试控制台能否正确分发后端命令。
    #[test]
    fn cli_debug_console_dispatches_backend_commands() {
        let dir = TempDir::new().unwrap();
        let service = Arc::new(BackendService::new(dir.path().to_str().unwrap()).unwrap());
        let console = DebugConsole::new(service);

        let result = console
            .run_json(r#"{"command":"get_backend_config"}"#)
            .unwrap();

        assert!(result.contains("http_enabled"));
    }

    /// 测试调试控制台能否正确返回运行时状态。
    #[test]
    fn cli_debug_console_returns_runtime_status() {
        let dir = TempDir::new().unwrap();
        let service = Arc::new(BackendService::new(dir.path().to_str().unwrap()).unwrap());
        let console = DebugConsole::new(service);

        let result = console
            .run_json(r#"{"command":"get_runtime_entry_status"}"#)
            .unwrap();

        assert!(result.contains("http_active"));
    }

    /// 测试调试控制台能否正确拒绝无效的 JSON 输入。
    #[test]
    fn cli_debug_console_rejects_invalid_json() {
        let dir = TempDir::new().unwrap();
        let service = Arc::new(BackendService::new(dir.path().to_str().unwrap()).unwrap());
        let console = DebugConsole::new(service);

        let err = console.run_json("not-json").unwrap_err();

        assert_eq!(
            err.code,
            crate::models::api_error::ApiErrorCode::InvalidArgument.as_str()
        );
        assert!(err.message.contains("Invalid JSON"));
    }

    /// 测试调试控制台能否正确拒绝缺少 command 字段的请求。
    #[test]
    fn cli_debug_console_rejects_missing_command() {
        let dir = TempDir::new().unwrap();
        let service = Arc::new(BackendService::new(dir.path().to_str().unwrap()).unwrap());
        let console = DebugConsole::new(service);

        let err = console.run_json(r#"{"foo":"bar"}"#).unwrap_err();

        assert_eq!(
            err.code,
            crate::models::api_error::ApiErrorCode::InvalidArgument.as_str()
        );
        assert!(err.message.contains("Missing 'command' field"));
    }

    /// 测试调试控制台能否正确拒绝未知的命令。
    #[test]
    fn cli_debug_console_rejects_unknown_command() {
        let dir = TempDir::new().unwrap();
        let service = Arc::new(BackendService::new(dir.path().to_str().unwrap()).unwrap());
        let console = DebugConsole::new(service);

        let err = console.run_json(r#"{"command":"unknown"}"#).unwrap_err();

        assert_eq!(
            err.code,
            crate::models::api_error::ApiErrorCode::InvalidArgument.as_str()
        );
        assert!(err.message.contains("Unknown command"));
    }
}
