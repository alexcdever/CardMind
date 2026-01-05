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
//! - **多设备协调**: 支持多点对多点同步
//!
//! # 模块结构
//!
//! - `network`: P2P 网络层，处理连接和通信
//! - `discovery`: mDNS 设备发现
//! - `sync`: 卡片同步协议和过滤逻辑
//! - `sync_manager`: 同步管理器，处理 Loro 增量同步
//! - `sync_service`: P2P 同步服务，整合所有组件
//! - `multi_peer_sync`: 多设备同步协调器
//!
//! # Phase 6 实现状态
//!
//! - [x] 添加 libp2p 依赖
//! - [x] 基础模块结构
//! - [x] libp2p 基础连接测试
//! - [x] mDNS 设备发现原型
//! - [x] 同步协议和消息格式
//! - [x] 数据池过滤逻辑
//! - [x] 同步管理器实现
//! - [x] 单对单同步流程
//! - [x] 多点对多点同步

pub mod discovery;
pub mod multi_peer_sync;
pub mod network;
pub mod sync;
pub mod sync_manager;
pub mod sync_service;

pub use discovery::MdnsDiscovery;
pub use multi_peer_sync::{DeviceInfo, DeviceStats, DeviceStatus, MultiPeerSyncCoordinator};
pub use network::{P2PBehaviour, P2PEvent, P2PNetwork};
pub use sync::{SyncFilter, SyncMessage, SyncAck, SyncError, SyncRequest, SyncResponse, SyncErrorCode};
pub use sync_manager::{SyncManager, SyncData};
pub use sync_service::{P2PSyncService, SyncStatus};
