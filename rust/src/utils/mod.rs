//! 通用工具模块 - 跨领域辅助函数
//!
//! 核心职责：
//! - 提供跨模块复用的基础工具函数
//! - 实现平台无关的通用算法与数据结构
//!
//! # 子模块
//! - `uuid_v7` - UUID v7 实现，提供按时间排序的唯一标识符
//!
//! # UUID v7 特性
//! UUID v7 结合了时间戳与随机数，具有以下优势：
//! - 按时间顺序排列（可用于排序）
//! - 比 UUID v4 更好的数据库索引性能
//! - 包含毫秒级时间戳信息
//!
//! # Examples
//! ```rust,ignore
//! use cardmind_rust::utils::uuid_v7::generate_uuid_v7;
//!
//! let uuid = generate_uuid_v7();
//! println!("生成的 UUID: {}", uuid);
//! // 输出类似：018f...（时间戳前缀）
//! ```

/// UUID v7 生成工具 - 时间排序唯一标识符
pub mod uuid_v7;
