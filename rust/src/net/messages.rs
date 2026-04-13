//! # 网络消息模块
//!
//! 定义 CardMind 池网络同步的协议消息类型。
//!
//! ## 消息分类
//!
//! ### 握手消息
//! - `Hello`: 建立连接时的初始问候
//!
//! ### 成员管理
//! - `JoinRequest`: 请求加入池
//! - `JoinForward`: 转发加入请求给其他成员
//! - `JoinDecision`: 对加入请求的审批决定
//!
//! ### 数据同步
//! - `PoolSnapshot`: 池的完整状态快照
//! - `PoolUpdates`: 池的增量更新
//! - `CardSnapshot`: 卡片的完整状态快照
//! - `CardUpdates`: 卡片的增量更新
//!
//! ## 序列化
//!
//! 所有消息使用 postcard 格式序列化，支持：
//! - 紧凑的二进制编码
//! - 无模式（schema-free）序列化
//! - 跨语言兼容
//!
//! ## 协议版本
//!
//! 当前消息格式对应协议版本 `cardmind/pool/1`，
//! 由 `crate::net::endpoint::POOL_ALPN` 标识。
//!
//! ## 示例
//!
//! ```rust,ignore
//! use cardmind_rust::net::messages::PoolMessage;
//! use uuid::Uuid;
//!
//! let hello = PoolMessage::Hello {
//!     pool_id: Uuid::new_v4(),
//!     endpoint_id: "node-1".to_string(),
//!     nickname: "Alice".to_string(),
//!     os: "macOS".to_string(),
//! };
//! ```

use crate::models::pool::PoolMember;
use iroh::EndpointAddr;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// 池网络消息枚举。
///
/// 定义池成员之间同步时交换的所有消息类型。
/// 使用 Postcard 进行序列化，支持紧凑的二进制编码。
///
/// ## 变体说明
///
/// ### 握手
/// - `Hello`: 连接建立时的身份声明
///
/// ### 成员管理
/// - `JoinRequest`: 新成员请求加入池
/// - `JoinForward`: 管理员转发加入请求
/// - `JoinDecision`: 审批结果（批准/拒绝）
///
/// ### 数据同步
/// - `PoolSnapshot`: 完整的池状态（用于首次同步）
/// - `PoolUpdates`: 池的增量更改
/// - `CardSnapshot`: 完整的卡片状态
/// - `CardUpdates`: 卡片的增量更改
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum PoolMessage {
    /// 问候消息，在连接建立时发送。
    ///
    /// 用于标识发送方身份和所属池。
    Hello {
        /// 池的唯一标识符。
        pool_id: Uuid,
        /// 发送方的端点 ID。
        endpoint_id: String,
        /// 发送方的显示名称。
        nickname: String,
        /// 发送方的操作系统。
        os: String,
    },

    /// 加入池的请求。
    ///
    /// 由希望加入池的新成员发送给池管理员。
    JoinRequest {
        /// 目标池 ID。
        pool_id: Uuid,
        /// 申请加入的成员信息。
        applicant: PoolMember,
        /// 申请方的 iroh 端点地址。
        applicant_addr: EndpointAddr,
    },

    /// 转发加入请求。
    ///
    /// 由管理员发送给其他成员，通知有新成员申请加入。
    JoinForward {
        /// 目标池 ID。
        pool_id: Uuid,
        /// 申请加入的成员信息。
        applicant: PoolMember,
    },

    /// 加入审批决定。
    ///
    /// 通知申请人审批结果。
    JoinDecision {
        /// 目标池 ID。
        pool_id: Uuid,
        /// 是否批准加入。
        approved: bool,
        /// 拒绝原因（如果被拒绝）。
        reason: Option<String>,
    },

    /// 池快照。
    ///
    /// 包含池的完整状态，使用 Loro 快照格式编码。
    /// 用于首次同步或完整状态恢复。
    PoolSnapshot {
        /// 池 ID。
        pool_id: Uuid,
        /// Loro 快照字节数据。
        bytes: Vec<u8>,
    },

    /// 池增量更新。
    ///
    /// 包含池状态的增量更改，使用 Loro 更新格式编码。
    /// 用于高效的增量同步。
    PoolUpdates {
        /// 池 ID。
        pool_id: Uuid,
        /// Loro 更新字节数据。
        bytes: Vec<u8>,
    },

    /// 卡片快照。
    ///
    /// 包含卡片的完整状态，使用 Loro 快照格式编码。
    CardSnapshot {
        /// 卡片 ID。
        card_id: Uuid,
        /// Loro 快照字节数据。
        bytes: Vec<u8>,
    },

    /// 卡片增量更新。
    ///
    /// 包含卡片状态的增量更改，使用 Loro 更新格式编码。
    CardUpdates {
        /// 卡片 ID。
        card_id: Uuid,
        /// Loro 更新字节数据。
        bytes: Vec<u8>,
    },
}
