// CLI 入口模块
// 调试/运维命令接口适配器

use crate::application::backend_service::BackendService;
use crate::models::api_error::ApiError;
use std::sync::Arc;

/// 调试控制台
pub struct DebugConsole {
    service: Arc<BackendService>,
}

impl DebugConsole {
    /// 创建新的调试控制台实例
    pub fn new(service: Arc<BackendService>) -> Self {
        Self { service }
    }

    /// 运行 JSON 命令并返回 JSON 响应
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
                serde_json::to_string(&config).map_err(|e| {
                    ApiError::new(
                        crate::models::api_error::ApiErrorCode::Internal,
                        &format!("Serialization error: {}", e),
                    )
                })
            }
            "get_runtime_entry_status" => {
                let status = self.service.get_runtime_entry_status()?;
                serde_json::to_string(&status).map_err(|e| {
                    ApiError::new(
                        crate::models::api_error::ApiErrorCode::Internal,
                        &format!("Serialization error: {}", e),
                    )
                })
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
}
