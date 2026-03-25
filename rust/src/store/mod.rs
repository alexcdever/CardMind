//! 存储与缓存层 - 本地持久化与双引擎架构
//!
//! 核心职责：
//! - 提供 SQLite + Loro CRDT 双存储引擎
//! - SQLite 用于关系型查询与投影缓存
//! - Loro 用于分布式数据与版本控制
//!
//! 架构说明：
//! 写操作优先写入 CRDT，通过投影器异步同步到 SQLite。
//! 这种分离实现了分布式一致性与查询性能的平衡。
//!
//! # 子模块
//! - `card_store` - 卡片笔记存储与查询
//! - `pool_store` - 数据池生命周期管理
//! - `loro_store` - CRDT 文档存储
//! - `sqlite_store` - SQLite 关系型存储
//! - `path_resolver` - 存储路径解析

/// 卡片笔记存储组件 - SQLite-based 查询与 CRDT 投影
pub mod card_store;
/// Loro CRDT 文档存储 - 分布式数据版本控制
pub mod loro_store;
/// 路径解析器 - 跨平台存储路径管理
pub mod path_resolver;
/// 数据池存储组件 - Pool 生命周期与成员管理
pub mod pool_store;
/// SQLite 存储引擎 - 关系型查询与缓存
pub mod sqlite_store;
