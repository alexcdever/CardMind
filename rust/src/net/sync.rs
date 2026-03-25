//! # 同步工具模块
//!
//! 提供 Loro CRDT 文档同步功能的统一导出。
//!
//! ## 目的
//!
//! 该模块是 [`crate::store::loro_store`] 中同步相关函数的重新导出，
//! 为 `net` 模块提供统一的同步接口访问点。
//!
//! ## 导出函数
//!
//! - `export_snapshot`: 导出 Loro 文档的完整快照
//! - `export_updates`: 导出自指定版本以来的增量更新
//! - `import_updates`: 将增量更新导入到 Loro 文档
//!
//! ## 使用示例
//!
//! ```rust,ignore
//! use cardmind_rust::net::sync::{export_snapshot, export_updates, import_updates};
//!
//! // 导出完整快照
//! let snapshot = export_snapshot(&doc)?;
//!
//! // 导出自特定版本以来的更新
//! let updates = export_updates(&doc, &old_version)?;
//!
//! // 导入更新到另一个文档
//! import_updates(&other_doc, &updates)?;
//! ```
//!
//! ## 实现说明
//!
//! 实际实现位于 [`crate::store::loro_store`] 模块。
//! 本模块仅作为便捷的重新导出层，使网络层代码不需要直接依赖存储层。

pub use crate::store::loro_store::{export_snapshot, export_updates, import_updates};
