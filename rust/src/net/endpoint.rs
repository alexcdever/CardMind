//! # 池端点模块
//!
//! 封装 iroh 网络端点，提供 CardMind 池网络所需的连接管理能力。
//!
//! ## 功能
//!
//! 该模块提供：
//!
//! - **端点创建**: 使用 mDNS 发现构建可用于池通信的端点
//! - **连接管理**: 建立到对等节点的 QUIC 连接
//! - **地址等待**: 等待端点获得可用的网络地址
//!
//! ## ALPN 协议
//!
//! 使用 `cardmind/pool/1` 作为应用层协议标识符，确保只与兼容的节点通信。
//!
//! ## 示例
//!
//! ```rust,ignore
//! use cardmind_rust::net::endpoint::{build_endpoint, PoolEndpoint};
//!
//! // 创建端点
//! let endpoint = build_endpoint().await?;
//! let pool_endpoint = PoolEndpoint::new(endpoint);
//!
//! // 等待地址可用
//! let addr = pool_endpoint.wait_for_addr(Duration::from_secs(5)).await?;
//!
//! // 连接到对等节点
//! let conn = pool_endpoint.connect(peer_addr).await?;
//! ```

use crate::models::error::CardMindError;
use iroh::address_lookup::mdns::MdnsAddressLookup;
use iroh::endpoint::{Connection, presets};
use iroh::{Endpoint, EndpointAddr, EndpointId, Watcher};
use std::time::Duration;
use tokio::time::sleep;

/// CardMind 池网络的应用层协议标识符（ALPN）。
///
/// 用于在 QUIC 握手时标识这是一个 CardMind 池连接。
/// 格式: `cardmind/pool/1`
pub const POOL_ALPN: &[u8] = b"cardmind/pool/1";

/// 池端点包装器。
///
/// 封装 iroh [`Endpoint`]，提供 CardMind 池网络特定的连接功能。
///
/// ## 用途
///
/// - 管理底层 QUIC 端点的生命周期
/// - 提供池特定的连接接口
/// - 处理地址发现和连接建立
///
/// ## 创建
///
/// 使用 [`build_endpoint`] 创建底层端点，然后用 [`PoolEndpoint::new`] 包装：
///
/// ```rust,ignore
/// let endpoint = build_endpoint().await?;
/// let pool_endpoint = PoolEndpoint::new(endpoint);
/// ```
#[derive(Debug)]
pub struct PoolEndpoint {
    /// 底层 iroh 端点。
    endpoint: Endpoint,
}

impl PoolEndpoint {
    /// 从现有端点创建新的 [`PoolEndpoint`]。
    ///
    /// # 参数
    /// * `endpoint` - 已配置的 iroh [`Endpoint`]
    ///
    /// # 返回
    /// 返回包装后的 [`PoolEndpoint`] 实例。
    pub fn new(endpoint: Endpoint) -> Self {
        Self { endpoint }
    }

    /// 获取端点 ID。
    ///
    /// # 返回
    /// 返回此端点的唯一标识符 ([`EndpointId`]),
    /// 可用于在池成员列表中标识此节点。
    pub fn endpoint_id(&self) -> EndpointId {
        self.endpoint.id()
    }

    /// 获取端点地址。
    ///
    /// # 返回
    /// 返回此端点的当前网络地址 ([`EndpointAddr`]),
    /// 包含可用于其他节点连接的地址信息。
    pub fn endpoint_addr(&self) -> EndpointAddr {
        self.endpoint.addr()
    }

    /// 连接到对等节点。
    ///
    /// 使用 [`POOL_ALPN`] 协议建立 QUIC 连接。
    ///
    /// # 参数
    /// * `peer` - 目标端点地址，可以是 [`EndpointAddr`] 或任何可转换为它的类型
    ///
    /// # 返回
    /// - `Ok(Connection)`: 成功建立的连接
    /// - `Err(CardMindError::Internal)`: 连接失败
    ///
    /// # 示例
    ///
    /// ```rust,ignore
    /// let conn = endpoint.connect(peer_addr).await?;
    /// ```
    pub async fn connect(
        &self,
        peer: impl Into<EndpointAddr>,
    ) -> Result<Connection, CardMindError> {
        self.endpoint
            .connect(peer.into(), POOL_ALPN)
            .await
            .map_err(|e| CardMindError::Internal(e.to_string()))
    }

    /// 获取底层端点的引用。
    ///
    /// # 返回
    /// 返回内部 [`Endpoint`] 的引用，用于需要直接访问底层功能的场景。
    pub fn inner(&self) -> &Endpoint {
        &self.endpoint
    }

    /// 等待端点获得可用地址。
    ///
    /// 在端点启动后，可能需要等待一段时间才能获得可用的网络地址
    /// （特别是使用 mDNS 等发现机制时）。此方法会轮询检查地址状态。
    ///
    /// # 参数
    /// * `timeout` - 最大等待时间
    ///
    /// # 返回
    /// - `Ok(EndpointAddr)`: 可用的端点地址
    /// - `Err(CardMindError::Internal)`: 超时
    ///
    /// # 示例
    ///
    /// ```rust,ignore
    /// let addr = endpoint.wait_for_addr(Duration::from_secs(5)).await?;
    /// println!("Endpoint ready: {}", addr);
    /// ```
    pub async fn wait_for_addr(&self, timeout: Duration) -> Result<EndpointAddr, CardMindError> {
        let mut watcher = self.endpoint.watch_addr();
        let start = tokio::time::Instant::now();
        loop {
            let addr = watcher.get();
            if !addr.is_empty() {
                return Ok(addr);
            }
            if tokio::time::Instant::now().duration_since(start) >= timeout {
                return Err(CardMindError::Internal("endpoint addr timeout".to_string()));
            }
            sleep(Duration::from_millis(200)).await;
        }
    }
}

/// 构建新的池端点。
///
/// 使用 mDNS 地址查找和 [`POOL_ALPN`] 协议配置创建 iroh 端点。
///
/// # 返回
/// - `Ok(Endpoint)`: 成功创建的端点
/// - `Err(CardMindError::Internal)`: 绑定失败
///
/// # 示例
///
/// ```rust,ignore
/// let endpoint = build_endpoint().await?;
/// let pool_endpoint = PoolEndpoint::new(endpoint);
/// ```
pub async fn build_endpoint() -> Result<Endpoint, CardMindError> {
    let mdns = MdnsAddressLookup::builder();
    Endpoint::builder(presets::Minimal)
        .alpns(vec![POOL_ALPN.to_vec()])
        .address_lookup(mdns)
        .bind()
        .await
        .map_err(|e| CardMindError::Internal(e.to_string()))
}

/// 构建两个测试端点。
///
/// 用于测试场景，创建一对可以相互通信的端点。
///
/// # 返回
/// - `Ok((PoolEndpoint, PoolEndpoint))`: 两个独立的端点
/// - `Err(CardMindError::Internal)`: 创建失败
///
/// # 注意
/// 此方法在测试中很有用，可以快速建立两个节点进行端到端测试。
pub async fn build_test_endpoints() -> Result<(PoolEndpoint, PoolEndpoint), CardMindError> {
    let a = build_endpoint().await?;
    let b = build_endpoint().await?;
    Ok((PoolEndpoint::new(a), PoolEndpoint::new(b)))
}
