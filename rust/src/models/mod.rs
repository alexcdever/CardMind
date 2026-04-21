//! 领域模型与错误类型 - 核心数据结构定义
//!
//! 核心职责：
//! - 定义跨层共享的数据结构与业务实体
//! - 提供统一的错误类型与错误码映射
//! - 实现序列化/反序列化支持（serde）
//!
//! # 数据模型
//! - `Card` - 卡片笔记实体，包含标题、内容、删除状态
//! - `Pool` - 数据池实体，管理成员、卡片引用、配置
//! - `PoolMember` - 池成员，包含端点 ID、昵称、角色
//!
//! # 错误处理
//! - `CardMindError` - 领域错误枚举，涵盖所有业务错误场景
//! - `ApiError` - FFI 错误封装，包含错误码与消息
//! - `ApiErrorCode` - 标准化错误码，用于跨语言错误识别
//!
//! # Examples
//! ```rust,ignore
//! use cardmind_rust::models::{Card, Pool, CardMindError};
//!
//! // 创建卡片
//! let card = Card::new("标题".to_string(), "内容".to_string());
//!
//! // 处理错误
//! match result {
//!     Ok(data) => println!("成功: {:?}", data),
//!     Err(CardMindError::NotFound(msg)) => println!("未找到: {}", msg),
//!     Err(e) => println!("其他错误: {:?}", e),
//! }
//! ```

/// API 错误类型 - FFI 错误封装与错误码
pub mod api_error;
/// 卡片笔记模型 - CRDT 驱动的笔记实体
pub mod card;
/// 统一错误类型 - 领域错误枚举
pub mod error;
/// 数据池模型 - Pool 与成员管理
pub mod pool;
/// 数据池运行态模型 - 成员连接/同步展示状态
pub mod pool_runtime;
