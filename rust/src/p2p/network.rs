//! P2P 网络层实现
//!
//! 本模块实现基于 libp2p 的 P2P 网络连接功能。
//!
//! # 安全特性
//!
//! - **强制 TLS**: 使用 Noise 协议加密所有连接
//! - **多路复用**: 使用 Yamux 在单一连接上多路复用
//! - **心跳检测**: 使用 Ping 协议检测连接状态
//! - **密钥持久化**: 使用 `IdentityManager` 管理密钥对
//!
//! # 设计原则
//!
//! 根据 `docs/architecture/sync_mechanism.md` 2.3.1 节的设计：
//! - 传输层强制 TLS 加密（AES-256-GCM）
//! - 使用 libp2p 自签名证书（本地网络信任模型）
//! - 禁用明文连接

use crate::models::error::{CardMindError, MdnsError};
use crate::p2p::identity::IdentityManager;
use crate::p2p::sync::{SyncRequest, SyncResponse};
use libp2p::{
    core::upgrade,
    futures::StreamExt,
    identity, mdns, noise,
    ping::{self, Behaviour as PingBehaviour},
    request_response::{self, ProtocolSupport},
    swarm::{behaviour::toggle::Toggle, NetworkBehaviour, SwarmEvent},
    tcp, yamux, Multiaddr, PeerId, StreamProtocol, Swarm, Transport,
};
use std::error::Error;
use tracing::{debug, info, warn};

/// P2P 网络行为
///
/// 组合了 Ping 协议、Request/Response 协议和可选的 mDNS 发现
#[derive(NetworkBehaviour)]
#[behaviour(to_swarm = "P2PEvent")]
pub struct P2PBehaviour {
    /// Ping 协议，用于心跳检测
    pub ping: PingBehaviour,

    /// Request/Response 协议，用于同步消息
    pub sync: request_response::json::Behaviour<SyncRequest, SyncResponse>,

    /// mDNS 设备发现（可选）
    pub mdns: Toggle<mdns::tokio::Behaviour>,
}

/// P2P 网络事件
#[derive(Debug)]
#[allow(clippy::enum_variant_names)]
pub enum P2PEvent {
    /// Ping 事件
    Ping(ping::Event),

    /// 同步请求/响应事件
    Sync(request_response::Event<SyncRequest, SyncResponse>),

    /// mDNS 发现事件
    Mdns(mdns::Event),
}

impl From<ping::Event> for P2PEvent {
    fn from(event: ping::Event) -> Self {
        Self::Ping(event)
    }
}

impl From<request_response::Event<SyncRequest, SyncResponse>> for P2PEvent {
    fn from(event: request_response::Event<SyncRequest, SyncResponse>) -> Self {
        Self::Sync(event)
    }
}

impl From<mdns::Event> for P2PEvent {
    fn from(event: mdns::Event) -> Self {
        Self::Mdns(event)
    }
}

/// P2P 网络管理器
///
/// 负责管理 libp2p Swarm 和网络连接
///
/// # 示例
///
/// ```no_run
/// use cardmind_rust::p2p::P2PNetwork;
///
/// # async fn example() -> Result<(), Box<dyn std::error::Error>> {
/// let mut network = P2PNetwork::new(false)?;
/// let peer_id = network.local_peer_id();
/// println!("本地 Peer ID: {}", peer_id);
///
/// // 启动监听
/// network.listen_on("/ip4/0.0.0.0/tcp/0").await?;
/// # Ok(())
/// # }
/// ```
pub struct P2PNetwork {
    /// libp2p Swarm
    swarm: Swarm<P2PBehaviour>,
}

impl P2PNetwork {
    /// 创建新的 P2P 网络实例
    ///
    /// # 参数
    ///
    /// - `mdns_enabled`: 是否启用 mDNS 设备发现
    ///
    /// # 安全保证
    ///
    /// - 自动生成 Ed25519 密钥对
    /// - 强制使用 Noise 协议加密
    /// - 使用 Yamux 多路复用
    ///
    /// # Errors
    ///
    /// 如果网络初始化失败，返回错误
    pub fn new(mdns_enabled: bool) -> Result<Self, CardMindError> {
        info!("初始化 P2P 网络 (mDNS: {})...", mdns_enabled);

        // 1. 生成身份密钥对
        let local_key = identity::Keypair::generate_ed25519();
        let local_peer_id = PeerId::from(local_key.public());
        info!("本地 Peer ID: {}", local_peer_id);

        // 2. 创建 Noise 加密配置（强制 TLS）
        let noise_config = noise::Config::new(&local_key)
            .map_err(|e| CardMindError::IoError(format!("Noise 配置失败: {e}")))?;

        // 3. 创建传输层
        let transport = tcp::tokio::Transport::default()
            .upgrade(upgrade::Version::V1)
            .authenticate(noise_config)
            .multiplex(yamux::Config::default())
            .boxed();

        // 4. 创建网络行为
        let sync_protocol = StreamProtocol::new("/cardmind/sync/1.0.0");
        let sync_config = request_response::Config::default();
        let sync_behaviour = request_response::json::Behaviour::new(
            [(sync_protocol, ProtocolSupport::Full)],
            sync_config,
        );

        // 5. 创建可选的 mDNS 行为
        let mdns_behaviour = if mdns_enabled {
            let mdns = mdns::tokio::Behaviour::new(mdns::Config::default(), local_peer_id)
                .map_err(|e| CardMindError::Mdns(MdnsError::from_message(&e.to_string())))?;
            info!("mDNS 设备发现已启用");
            Some(mdns).into()
        } else {
            info!("mDNS 设备发现已禁用");
            None.into()
        };

        let behaviour = P2PBehaviour {
            ping: PingBehaviour::new(ping::Config::new()),
            sync: sync_behaviour,
            mdns: mdns_behaviour,
        };

        // 6. 创建 Swarm（使用 tokio executor）
        let swarm = Swarm::new(
            transport,
            behaviour,
            local_peer_id,
            libp2p::swarm::Config::with_executor(Box::new(|fut| {
                tokio::spawn(fut);
            })),
        );

        Ok(Self { swarm })
    }

    /// 使用持久化密钥对创建 P2P 网络实例
    ///
    /// # 参数
    ///
    /// - `identity_manager`: 身份管理器，用于加载或生成密钥对
    /// - `mdns_enabled`: 是否启用 mDNS 设备发现
    ///
    /// # 安全保证
    ///
    /// - 使用持久化的 Ed25519 密钥对
    /// - 强制使用 Noise 协议加密
    /// - 使用 Yamux 多路复用
    ///
    /// # Errors
    ///
    /// 如果网络初始化失败，返回错误
    pub fn new_with_identity(
        identity_manager: &IdentityManager,
        mdns_enabled: bool,
    ) -> Result<Self, CardMindError> {
        info!(
            "初始化 P2P 网络（使用持久化密钥对，mDNS: {}）...",
            mdns_enabled
        );

        // 1. 加载或生成身份密钥对
        let local_key = identity_manager
            .get_or_create_keypair()
            .map_err(|e| CardMindError::IoError(format!("加载密钥对失败: {e}")))?;
        let local_peer_id = PeerId::from(local_key.public());
        info!("本地 Peer ID: {}", local_peer_id);

        // 2. 创建 Noise 加密配置（强制 TLS）
        let noise_config = noise::Config::new(&local_key)
            .map_err(|e| CardMindError::IoError(format!("Noise 配置失败: {e}")))?;

        // 3. 创建传输层
        let transport = tcp::tokio::Transport::default()
            .upgrade(upgrade::Version::V1)
            .authenticate(noise_config)
            .multiplex(yamux::Config::default())
            .boxed();

        // 4. 创建网络行为
        let sync_protocol = StreamProtocol::new("/cardmind/sync/1.0.0");
        let sync_config = request_response::Config::default();
        let sync_behaviour = request_response::json::Behaviour::new(
            [(sync_protocol, ProtocolSupport::Full)],
            sync_config,
        );

        // 5. 创建可选的 mDNS 行为
        let mdns_behaviour = if mdns_enabled {
            let mdns = mdns::tokio::Behaviour::new(mdns::Config::default(), local_peer_id)
                .map_err(|e| CardMindError::Mdns(MdnsError::from_message(&e.to_string())))?;
            info!("mDNS 设备发现已启用");
            Some(mdns).into()
        } else {
            info!("mDNS 设备发现已禁用");
            None.into()
        };

        let behaviour = P2PBehaviour {
            ping: PingBehaviour::new(ping::Config::new()),
            sync: sync_behaviour,
            mdns: mdns_behaviour,
        };

        // 6. 创建 Swarm（使用 tokio executor）
        let swarm = Swarm::new(
            transport,
            behaviour,
            local_peer_id,
            libp2p::swarm::Config::with_executor(Box::new(|fut| {
                tokio::spawn(fut);
            })),
        );

        Ok(Self { swarm })
    }

    /// 获取本地 Peer ID
    #[must_use]
    pub fn local_peer_id(&self) -> &PeerId {
        self.swarm.local_peer_id()
    }

    /// 获取 Swarm 的可变引用（用于同步服务）
    pub const fn swarm_mut(&mut self) -> &mut Swarm<P2PBehaviour> {
        &mut self.swarm
    }

    /// 发送同步请求到对等节点
    ///
    /// # 参数
    ///
    /// - `peer_id`: 目标对等节点 ID
    /// - `request`: 同步请求
    ///
    /// # 返回
    ///
    /// 返回请求 ID，用于跟踪响应
    pub fn send_sync_request(
        &mut self,
        peer_id: PeerId,
        request: SyncRequest,
    ) -> request_response::OutboundRequestId {
        info!("发送同步请求到 {}: pool_id={}", peer_id, request.pool_id);
        self.swarm
            .behaviour_mut()
            .sync
            .send_request(&peer_id, request)
    }

    /// 监听指定地址
    ///
    /// # 参数
    ///
    /// - `addr`: 监听地址，例如 "/ip4/0.0.0.0/tcp/0"
    ///
    /// # Returns
    ///
    /// 返回实际监听的地址
    ///
    /// # Errors
    ///
    /// 如果监听失败，返回错误
    pub async fn listen_on(&mut self, addr: &str) -> Result<Multiaddr, Box<dyn Error>> {
        let listen_addr: Multiaddr = addr.parse()?;
        self.swarm.listen_on(listen_addr)?;

        // 等待监听成功事件
        loop {
            if let Some(event) = self.swarm.next().await {
                match event {
                    SwarmEvent::NewListenAddr { address, .. } => {
                        info!("开始监听: {}", address);
                        return Ok(address);
                    }
                    SwarmEvent::ListenerError { error, .. } => {
                        return Err(format!("监听失败: {error}").into());
                    }
                    _ => {}
                }
            }
        }
    }

    /// 连接到远程对等节点
    ///
    /// # 参数
    ///
    /// - `addr`: 对等节点地址
    ///
    /// # Errors
    ///
    /// 如果连接失败，返回错误
    pub fn dial(&mut self, addr: &Multiaddr) -> Result<(), Box<dyn Error>> {
        info!("连接到对等节点: {}", addr);
        self.swarm.dial(addr.clone())?;
        Ok(())
    }

    /// 处理网络事件（用于测试和调试）
    ///
    /// # Errors
    ///
    /// 如果事件处理失败，返回错误
    pub async fn handle_events(&mut self) -> Result<(), Box<dyn Error>> {
        loop {
            if let Some(event) = self.swarm.next().await {
                match event {
                    SwarmEvent::NewListenAddr { address, .. } => {
                        info!("监听地址: {}", address);
                    }
                    SwarmEvent::ConnectionEstablished {
                        peer_id, endpoint, ..
                    } => {
                        info!("连接建立: {} at {}", peer_id, endpoint.get_remote_address());
                    }
                    SwarmEvent::ConnectionClosed { peer_id, cause, .. } => {
                        warn!("连接关闭: {} (原因: {:?})", peer_id, cause);
                    }
                    SwarmEvent::Behaviour(P2PEvent::Ping(ping::Event { peer, result, .. })) => {
                        match result {
                            Ok(duration) => {
                                debug!("Ping 成功: {} (延迟: {:?})", peer, duration);
                            }
                            Err(e) => {
                                warn!("Ping 失败: {} (错误: {})", peer, e);
                            }
                        }
                    }
                    _ => {}
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// 测试网络初始化（不启用 mDNS）
    #[test]
    fn test_network_creation() {
        let network = P2PNetwork::new(false);
        assert!(network.is_ok(), "网络初始化应该成功");
    }

    /// 测试网络初始化（启用 mDNS）
    #[tokio::test]
    async fn test_network_creation_with_mdns() {
        let network = P2PNetwork::new(true);
        match network {
            Ok(_) => {}
            Err(CardMindError::Mdns(_)) => {}
            Err(err) => panic!("网络初始化失败: {err}"),
        }
    }

    /// 测试 Peer ID 生成
    #[test]
    fn test_peer_id_generation() {
        let network = P2PNetwork::new(false).unwrap();
        let peer_id = network.local_peer_id();
        assert!(!peer_id.to_string().is_empty(), "Peer ID 不应为空");
    }

    /// 测试监听和连接
    ///
    /// 创建两个节点，一个监听，一个连接，验证 Ping 协议工作
    #[tokio::test]
    #[allow(clippy::similar_names)]
    async fn test_basic_connection() {
        use std::time::Duration;
        use tokio::time::timeout;

        // 1. 创建节点 A（监听者，不启用 mDNS）
        let mut network_a = P2PNetwork::new(false).expect("节点 A 初始化失败");
        let peer_a_id = *network_a.local_peer_id();

        let listen_addr = network_a
            .listen_on("/ip4/127.0.0.1/tcp/0")
            .await
            .unwrap_or_else(|err| {
                let msg = err.to_string();
                if msg.contains("Permission denied")
                    || msg.contains("Operation not permitted")
                    || msg.is_empty()
                {
                    println!("跳过网络连接测试：{msg}");
                    "/ip4/127.0.0.1/tcp/0".parse().unwrap()
                } else {
                    panic!("节点 A 监听失败: {err}");
                }
            });

        println!("节点 A 监听地址: {listen_addr}");
        println!("节点 A Peer ID: {peer_a_id}");

        // 3. 创建节点 B（连接者，不启用 mDNS）
        let mut network_b = P2PNetwork::new(false).expect("节点 B 初始化失败");
        let peer_b_id = *network_b.local_peer_id();

        println!("节点 B Peer ID: {peer_b_id}");

        // 4. 节点 B 连接到节点 A
        let dial_addr = format!("{listen_addr}/p2p/{peer_a_id}");
        let dial_multiaddr: Multiaddr = dial_addr.parse().expect("地址解析失败");

        network_b.dial(&dial_multiaddr).expect("节点 B 拨号失败");

        // 5. 等待连接建立（超时 5 秒，只验证连接建立即可）
        let result = timeout(Duration::from_secs(5), async {
            let mut a_connected = false;
            let mut b_connected = false;

            loop {
                tokio::select! {
                    event = network_a.swarm.next() => {
                        if let Some(event) = event {
                            match event {
                                SwarmEvent::ConnectionEstablished { peer_id, .. } => {
                                    println!("节点 A: 连接建立 from {peer_id}");
                                    a_connected = true;
                                }
                                SwarmEvent::Behaviour(P2PEvent::Ping(ping::Event { peer, result: Ok(rtt), .. })) => {
                                    println!("节点 A: 收到 Ping from {peer} (RTT: {rtt:?})");
                                }
                                _ => {}
                            }
                        }
                    }
                    event = network_b.swarm.next() => {
                        if let Some(event) = event {
                            match event {
                                SwarmEvent::ConnectionEstablished { peer_id, .. } => {
                                    println!("节点 B: 连接建立 to {peer_id}");
                                    b_connected = true;
                                }
                                SwarmEvent::Behaviour(P2PEvent::Ping(ping::Event { peer, result: Ok(rtt), .. })) => {
                                    println!("节点 B: 收到 Ping from {peer} (RTT: {rtt:?})");
                                }
                                _ => {}
                            }
                        }
                    }
                }

                // 两个节点都建立连接，测试成功
                if a_connected && b_connected {
                    return Ok::<_, Box<dyn Error>>(());
                }
            }
        })
        .await;

        match result {
            Ok(Ok(())) => {
                println!("✅ 连接测试成功: 双向连接建立");
            }
            Ok(Err(e)) => {
                panic!("❌ 连接测试失败: {e}");
            }
            Err(e) => {
                panic!("❌ 连接测试超时: {e}");
            }
        }
    }
}
