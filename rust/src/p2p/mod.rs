//! P2P 同步模块
//!
//! 本模块实现 CardMind 的点对点（P2P）设备发现和数据同步功能。
//!
//! # 功能特性
//!
//! - **设备发现**: 使用 mDNS 在局域网内自动发现其他设备
//! - **安全连接**: 使用 libp2p + TLS 建立加密连接
//! - **隐私保护**: mDNS 广播仅暴露数据池 ID，不暴露敏感信息
//! - **卡片同步**: 基于 Loro CRDT 的增量同步协议
//!
//! # 模块结构
//!
//! - `network`: P2P 网络层，处理连接和通信
//! - `discovery`: mDNS 设备发现
//! - `sync`: 卡片同步协议和过滤逻辑
//!
//! # Phase 6 实现状态
//!
//! - [x] 添加 libp2p 依赖
//! - [x] 基础模块结构
//! - [x] libp2p 基础连接测试
//! - [x] mDNS 设备发现原型
//! - [x] 同步协议和消息格式
//! - [x] 数据池过滤逻辑
//! - [ ] 同步管理器实现

pub mod discovery;
pub mod network;
pub mod sync;

pub use discovery::MdnsDiscovery;
pub use network::P2PNetwork;
pub use sync::{SyncFilter, SyncMessage};
