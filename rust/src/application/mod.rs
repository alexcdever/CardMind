//! 应用服务层 - 核心业务用例编排
//!
//! 核心职责：
//! - 协调存储层、网络层与领域模型
//! - 实现高层业务逻辑与用例编排
//! - 处理跨模块事务与一致性
//!
//! # 组件
//! - `BackendService` - 后端服务核心，协调各层组件
//!
//! # 架构说明
//! 应用服务层作为业务逻辑的核心编排者，不直接处理 FFI 或网络协议，
//! 而是通过调用存储层和网络层的抽象接口来实现功能。
//!
//! # Examples
//! ```rust,ignore
//! use cardmind_rust::application::backend_service::BackendService;
//!
//! // 创建服务实例
//! let service = BackendService::new("/data").unwrap();
//!
//! // 查询运行时状态
//! let status = service.get_runtime_entry_status().unwrap();
//! println!("入口状态: {:?}", status);
//! ```

// 应用服务模块

pub mod backend_service;
