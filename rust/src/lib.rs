//! CardMind Rust 核心库 - 分布式卡片笔记系统的后端引擎
//!
//! 核心职责：
//! - 提供跨平台 FFI 接口（通过 flutter_rust_bridge）供 Flutter 前端调用
//! - 管理数据池（Pool）生命周期、成员同步与冲突解决
//! - 实现本地 SQLite + Loro CRDT 双存储引擎
//! - 提供 P2P 网络发现与数据同步能力
//!
//! 上下文依赖：
//! - 使用前必须调用 `api::init_app_config` 初始化应用数据目录
//! - 依赖 Tokio 运行时进行异步网络操作
//! - 需要平台特定的网络权限（UDP/TCP）
//!
//! 警告/注意：
//! - `frb_generated` 模块由 flutter_rust_bridge 自动生成，手动修改会被覆盖
//! - 存储层使用 `OnceLock` 进行全局状态管理，不支持多实例并发
//! - P2P 同步功能需要正确处理网络状态转换（见 `net::pool_network`）

/// FRB 接口层 - 前端交互的唯一入口
///
/// 包含所有暴露给 Flutter 的 API 函数，负责参数校验、错误转换与 DTO 组装。
/// 任何跨 FFI 边界的数据交换都应通过此模块。
///
/// # Examples
/// ```rust,ignore
/// // 初始化应用配置（必须在其他操作前调用）
/// api::init_app_config("/path/to/app/data".to_string()).expect("初始化失败");
///
/// // 创建卡片
/// let card = api::create_card_note("标题".to_string(), "内容".to_string()).unwrap();
/// ```
pub mod api;
/// 应用服务层 - 核心业务用例编排
///
/// 负责协调存储层、网络层与领域模型，实现高层业务逻辑。
/// 主要组件：`BackendService`（见 `application::backend_service`）
pub mod application;
/// CLI 入口适配器 - 命令行调试接口
///
/// 提供开发调试用的命令行工具，非生产环境使用。
/// 包含诊断命令、数据检查与状态查询功能。
pub mod cli;
mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */
// ⚠️ 警告：此模块由 flutter_rust_bridge_codegen 自动生成
// - 包含所有 FFI 绑定代码与序列化逻辑
// - 手动修改将被下次代码生成覆盖
// - 如需定制行为，修改 flutter_rust_bridge.yaml 配置
/// HTTP 入口适配器 - REST API 服务端
///
/// 提供可选的 HTTP REST API 接口，供外部系统集成。
/// 由后端配置控制是否启用（见 `runtime::config`）。
pub mod http;
/// MCP 入口适配器 - Model Context Protocol 接口
///
/// 实现 MCP 协议，支持与 AI 助手（如 Claude）进行结构化数据交换。
/// 用于 AI 辅助的卡片创建、查询与知识管理。
pub mod mcp;
/// 领域模型与错误类型 - 核心数据结构定义
///
/// 定义跨层共享的数据结构与错误枚举：
/// - `Card` - 卡片笔记实体（见 `models::card`）
/// - `Pool` - 数据池实体（见 `models::pool`）
/// - `CardMindError` - 统一错误类型（见 `models::error`）
/// - `ApiError` - FFI 错误封装（见 `models::api_error`）
///
/// # Panics
/// 所有模型构造函数在输入参数无效时返回 `CardMindError`，不会 panic。
pub mod models;
/// 组网与同步模块 - P2P 网络与 CRDT 数据同步
///
/// 实现局域网/公网设备发现、连接管理与 CRDT 数据同步：
/// - `PoolNetwork` - 网络管理核心（见 `net::pool_network`）
/// - `PoolEndpoint` - QUIC 连接端点（见 `net::endpoint`）
/// - `SyncSession` - 同步会话管理（见 `net::session`）
/// - `PoolMessage` - 同步协议消息（见 `net::messages`）
///
/// # Safety
/// 网络操作涉及异步 I/O 与并发状态管理，需确保 Tokio 运行时正确初始化。
/// 见 `api::init_pool_network` 的实现。
pub mod net;
/// 运行时与配置管理 - 启动与生命周期管理
///
/// 管理应用运行时状态、配置持久化与入口适配器生命周期：
/// - `RuntimeEntryManager` - 运行时入口管理（见 `runtime::entry_manager`）
/// - `BackendConfigDto` - 后端配置 DTO（见 `runtime::config`）
///
/// # Examples
/// 检查运行时状态：
/// ```rust,ignore
/// let status = api::get_runtime_entry_status()?;
/// println!("HTTP 服务启用: {}", status.http_enabled);
/// ```
pub mod runtime;
/// 存储与缓存层 - 本地持久化与缓存策略
///
/// 提供双存储引擎架构：
/// - SQLite - 关系型查询与投影缓存（见 `store::sqlite_store`）
/// - Loro CRDT - 分布式数据与版本控制（见 `store::loro_store`）
///
/// # 架构说明
/// 写操作优先写入 CRDT，通过投影器异步同步到 SQLite 用于查询。
/// 这种分离实现了分布式一致性与查询性能的平衡。
///
/// # Panics
/// 存储路径无效或权限不足时返回错误，不会 panic。
pub mod store;
/// 通用工具模块 - 跨领域辅助函数
///
/// 包含 UUID 生成、时间戳处理、序列化辅助等工具函数。
/// 其中 `uuid_v7`（见 `utils::uuid_v7`）实现了按时间排序的 UUID v7 算法。
pub mod utils;
