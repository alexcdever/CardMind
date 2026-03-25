//! # 同步会话模块
//!
//! 管理 CardMind 池同步的会话状态和成员验证。
//!
//! ## 组件
//!
//! - **SyncSession**: 管理同步连接的生命周期和状态
//! - **PoolSession**: 验证池成员身份
//!
//! ## 状态机
//!
//! `SyncSession` 维护以下状态：
//!
//! - `Idle`: 空闲状态，未连接
//! - `Connected`: 已连接到目标节点
//!
//! ## 使用场景
//!
//! 1. **主动同步**: 调用 `connect` 建立会话，然后执行同步操作
//! 2. **成员验证**: 使用 `PoolSession::validate_peer` 验证对等节点身份
//!
//! ## 示例
//!
//! ```rust,ignore
//! use cardmind_rust::net::session::SyncSession;
//!
//! let mut session = SyncSession::new();
//! session.connect("peer-address".to_string())?;
//!
//! assert_eq!(session.state(), "connected");
//!
//! session.disconnect();
//! assert_eq!(session.state(), "idle");
//! ```

use crate::models::error::CardMindError;
use crate::models::pool::PoolMember;
use std::collections::HashSet;
use uuid::Uuid;

/// 同步阶段枚举。
///
/// 表示同步会话的当前状态。
#[derive(Clone)]
pub enum SyncPhase {
    /// 空闲状态，未建立连接。
    Idle,
    /// 已连接到目标节点。
    Connected,
}

/// 同步会话管理器。
///
/// 跟踪同步连接的状态和目标地址。
///
/// ## 生命周期
///
/// 1. 创建（`new`）- 初始状态为 `Idle`
/// 2. 连接（`connect`）- 状态变为 `Connected`
/// 3. 断开（`disconnect`）- 状态重置为 `Idle`
///
/// ## 线程安全
///
/// 该类型不是线程安全的，如需跨线程使用需要外部同步。
#[derive(Clone)]
pub struct SyncSession {
    /// 当前同步阶段。
    phase: SyncPhase,
    /// 连接目标地址（如果已连接）。
    target: Option<String>,
}

impl SyncSession {
    /// 创建新的空闲会话。
    ///
    /// # 返回
    /// 返回状态为 `Idle` 的新 `SyncSession` 实例。
    ///
    /// # 示例
    ///
    /// ```rust,ignore
    /// let session = SyncSession::new();
    /// assert_eq!(session.state(), "idle");
    /// ```
    pub fn new() -> Self {
        Self {
            phase: SyncPhase::Idle,
            target: None,
        }
    }

    /// 建立同步连接。
    ///
    /// 设置目标地址并将状态改为 `Connected`。
    ///
    /// # 参数
    /// * `target` - 目标端点地址字符串
    ///
    /// # 返回
    /// - `Ok(())`: 连接成功建立
    /// - `Err(CardMindError::InvalidArgument)`: 目标地址为空
    ///
    /// # 示例
    ///
    /// ```rust,ignore
    /// let mut session = SyncSession::new();
    /// session.connect("peer-node-id".to_string())?;
    /// ```
    pub fn connect(&mut self, target: String) -> Result<(), CardMindError> {
        if target.trim().is_empty() {
            return Err(CardMindError::InvalidArgument(
                "target is empty".to_string(),
            ));
        }
        self.phase = SyncPhase::Connected;
        self.target = Some(target);
        Ok(())
    }

    /// 断开同步连接。
    ///
    /// 清除目标地址并将状态重置为 `Idle`。
    ///
    /// # 示例
    ///
    /// ```rust,ignore
    /// session.disconnect();
    /// assert_eq!(session.state(), "idle");
    /// ```
    pub fn disconnect(&mut self) {
        self.phase = SyncPhase::Idle;
        self.target = None;
    }

    /// 获取当前状态字符串。
    ///
    /// # 返回
    /// 返回以下值之一：
    /// - `"idle"`: 空闲状态
    /// - `"connected"`: 已连接
    pub fn state(&self) -> &'static str {
        match self.phase {
            SyncPhase::Idle => "idle",
            SyncPhase::Connected => "connected",
        }
    }
}

impl Default for SyncSession {
    /// 默认构造函数，创建空闲会话。
    fn default() -> Self {
        Self::new()
    }
}

/// 池会话上下文。
///
/// 用于验证池成员身份和维护会话特定的池信息。
///
/// ## 用途
///
/// 在同步过程中验证对等节点是否是池的合法成员。
/// 存储池 ID 和成员端点 ID 集合以便快速查找。
///
/// ## 示例
///
/// ```rust,ignore
/// use cardmind_rust::net::session::PoolSession;
///
/// let pool_session = PoolSession::new(pool_id, &members);
/// pool_session.validate_peer("endpoint-id")?; // 验证成功
/// pool_session.validate_peer("unknown-id")?;  // 返回 NotMember 错误
/// ```
pub struct PoolSession {
    /// 池唯一标识符。
    pool_id: Uuid,
    /// 池成员端点 ID 集合，用于快速验证。
    members: HashSet<String>,
}

impl PoolSession {
    /// 创建新的池会话。
    ///
    /// # 参数
    /// * `pool_id` - 池的唯一标识符
    /// * `members` - 池成员列表
    ///
    /// # 返回
    /// 返回包含成员验证信息的 [`PoolSession`] 实例。
    pub fn new(pool_id: Uuid, members: &[PoolMember]) -> Self {
        let members = members
            .iter()
            .map(|member| member.endpoint_id.clone())
            .collect();
        Self { pool_id, members }
    }

    /// 获取池 ID。
    ///
    /// # 返回
    /// 返回此会话关联的池 ID。
    pub fn pool_id(&self) -> &Uuid {
        &self.pool_id
    }

    /// 验证对等节点是否为池成员。
    ///
    /// # 参数
    /// * `endpoint_id` - 要验证的端点 ID
    ///
    /// # 返回
    /// - `Ok(())`: 验证通过，是合法成员
    /// - `Err(CardMindError::NotMember)`: 不是池成员
    ///
    /// # 示例
    ///
    /// ```rust,ignore
    /// match pool_session.validate_peer("some-endpoint") {
    ///     Ok(()) => println!("Member verified"),
    ///     Err(e) => println!("Not a member: {:?}", e),
    /// }
    /// ```
    pub fn validate_peer(&self, endpoint_id: &str) -> Result<(), CardMindError> {
        if self.members.contains(endpoint_id) {
            Ok(())
        } else {
            Err(CardMindError::NotMember("not member".to_string()))
        }
    }
}
