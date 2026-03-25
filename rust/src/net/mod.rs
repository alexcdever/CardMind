//! 组网与同步模块 - P2P 网络与 CRDT 数据同步
//!
//! 核心职责：
//! - 实现局域网/公网设备发现与连接管理
//! - 提供 QUIC-based 可靠传输通道
//! - 实现 CRDT 数据同步协议
//! - 处理网络分区与恢复场景
//!
//! # 架构组件
//! - `PoolNetwork` - 网络管理核心，协调连接与会话
//! - `PoolEndpoint` - QUIC 连接端点，处理传输层
//! - `SyncSession` - 同步会话管理，维护同步状态
//! - `PoolMessage` - 同步协议消息类型
//! - `PoolSession` - 持久化连接会话
//!
//! # Safety
//! 网络操作涉及异步 I/O 与并发状态管理。所有公开 API 通过 `PoolNetwork`
//! 封装，确保 Tokio 运行时正确初始化与生命周期管理。
//!
//! # Examples
//! ```rust,ignore
//! use cardmind_rust::net::pool_network::{PoolNetwork, PoolEndpoint};
//! use cardmind_rust::net::endpoint::build_endpoint;
//!
//! // 创建网络实例（通常在 api::init_pool_network 中完成）
//! let endpoint = build_endpoint().await.unwrap();
//! let network = PoolNetwork::new(PoolEndpoint::new(endpoint), pool_store, card_repo);
//!
//! // 连接并同步
//! network.sync_connect("192.168.1.100:8080".to_string()).unwrap();
//! network.sync_push().unwrap();
//! ```

/// 消息编解码器 - 二进制序列化协议
pub mod codec;
/// QUIC 端点管理 - 连接建立与传输层
pub mod endpoint;
/// 消息类型定义 - 同步协议数据结构
pub mod messages;
/// 网络管理核心 - Pool 组网与状态管理
pub mod pool_network;
/// 会话管理 - 持久化连接与会话状态
pub mod session;
/// 同步协议实现 - CRDT 数据交换逻辑
pub mod sync;
