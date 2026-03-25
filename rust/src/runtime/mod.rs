//! 运行时与配置管理 - 启动与生命周期管理
//!
//! 核心职责：
//! - 管理应用运行时状态与配置持久化
//! - 控制后端服务入口（HTTP/MCP/CLI）的启用/禁用
//! - 提供运行时状态查询与诊断接口
//!
//! # 子模块
//! - `config` - 后端配置管理（HTTP/MCP/CLI 启用状态）
//! - `entry_manager` - 运行时入口状态查询与管理
//!
//! # Examples
//! ```rust,ignore
//! use cardmind_rust::runtime::config::BackendConfigStore;
//! use std::path::Path;
//!
//! // 加载配置
//! let store = BackendConfigStore::new(Path::new("/data"));
//! let config = store.load().unwrap();
//!
//! println!("HTTP 服务: {}", config.http_enabled);
//! println!("MCP 服务: {}", config.mcp_enabled);
//! println!("CLI 服务: {}", config.cli_enabled);
//! ```

// 运行时模块
// 负责入口配置与运行时管理

pub mod config;
pub mod entry_manager;
