// MCP 入口模块
// AI/Agent 工具接口适配器

use crate::application::backend_service::BackendService;
use std::sync::Arc;

/// MCP Tool 定义
pub struct McpTool {
    pub name: String,
    pub description: String,
}

/// MCP 服务器
pub struct McpServer {
    _service: Arc<BackendService>,
}

impl McpServer {
    /// 创建新的 MCP 服务器实例
    pub fn new(service: Arc<BackendService>) -> Self {
        Self { _service: service }
    }

    /// 列出可用的工具
    pub fn list_tools(&self) -> Vec<McpTool> {
        vec![
            McpTool {
                name: "create_pool".to_string(),
                description: "Create a new pool".to_string(),
            },
            McpTool {
                name: "create_card_note".to_string(),
                description: "Create a new card note".to_string(),
            },
            McpTool {
                name: "run_sync_now".to_string(),
                description: "Trigger synchronization".to_string(),
            },
        ]
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn mcp_tool_catalog_exposes_core_use_cases() {
        let dir = TempDir::new().unwrap();
        let service = Arc::new(BackendService::new(dir.path().to_str().unwrap()).unwrap());
        let server = McpServer::new(service);

        let tools = server.list_tools();

        assert!(tools.iter().any(|tool| tool.name == "create_pool"));
        assert!(tools.iter().any(|tool| tool.name == "create_card_note"));
        assert!(tools.iter().any(|tool| tool.name == "run_sync_now"));
    }
}
