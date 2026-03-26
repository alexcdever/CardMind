//! MCP 入口适配器 - Model Context Protocol 接口
//!
//! 核心职责：
//! - 实现 Model Context Protocol (MCP)，支持与 AI 助手结构化交互
//! - 暴露 CardMind 核心功能给 AI Agent（如 Claude）
//! - 提供工具（Tool）定义与调用接口
//!
//! # 什么是 MCP？
//! Model Context Protocol 是一种用于 AI 与外部工具交互的标准协议，
//! 允许 AI 助手安全地调用应用程序功能。
//!
//! # 支持的工具
//! 当前暴露以下核心工具：
//! - `create_pool` - 创建新数据池
//! - `create_card_note` - 创建卡片笔记
//! - `run_sync_now` - 触发同步
//!
//! # 配置
//! 通过后端配置启用/禁用（`mcp_enabled`）：
//! - 启用后 AI 助手可以通过 MCP 接口管理卡片
//!
//! # Examples
//! ```rust,ignore
//! use cardmind_rust::mcp::McpServer;
//! use cardmind_rust::application::backend_service::BackendService;
//! use std::sync::Arc;
//!
//! let service = Arc::new(BackendService::new("/data").unwrap());
//! let server = McpServer::new(service);
//!
//! // 列出可用工具
//! for tool in server.list_tools() {
//!     println!("工具: {} - {}", tool.name, tool.description);
//! }
//! ```

use crate::application::backend_service::BackendService;
use std::sync::Arc;

/// MCP Tool 定义
///
/// 描述一个 AI 可调用的工具，包含名称与描述。
/// AI 根据描述理解何时使用该工具。
pub struct McpTool {
    /// 工具唯一标识符（snake_case）
    pub name: String,
    /// 工具功能描述，用于 AI 决策
    pub description: String,
}

/// MCP 服务器
///
/// 提供 AI 可调用工具的接口。
/// 目前仅支持工具列表查询，实际调用逻辑待实现。
pub struct McpServer {
    _service: Arc<BackendService>,
}

impl McpServer {
    /// 创建新的 MCP 服务器实例。
    ///
    /// # 参数
    /// * `service` - 后端服务实例，用于处理工具调用请求。
    ///
    /// # 示例
    /// ```rust,ignore
    /// use cardmind_rust::mcp::McpServer;
    /// use cardmind_rust::application::backend_service::BackendService;
    /// use std::sync::Arc;
    ///
    /// let service = Arc::new(BackendService::new("/data").unwrap());
    /// let server = McpServer::new(service);
    /// ```
    pub fn new(service: Arc<BackendService>) -> Self {
        Self { _service: service }
    }

    /// 列出可用的工具。
    ///
    /// 返回 AI 可调用的工具列表。AI 根据工具描述决定何时调用哪个工具。
    ///
    /// # 返回
    /// 包含所有可用工具的向量，每个工具包含名称和功能描述。
    ///
    /// # 示例
    /// ```rust,ignore
    /// use cardmind_rust::mcp::McpServer;
    /// use cardmind_rust::application::backend_service::BackendService;
    /// use std::sync::Arc;
    ///
    /// let service = Arc::new(BackendService::new("/data").unwrap());
    /// let server = McpServer::new(service);
    ///
    /// let tools = server.list_tools();
    /// assert!(!tools.is_empty());
    /// ```
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

    /// 测试 MCP 工具目录是否正确暴露了核心用例工具。
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
