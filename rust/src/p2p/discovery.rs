//! mDNS 设备发现实现
//!
//! 本模块实现基于 mDNS 的局域网设备发现功能。
//!
//! # 隐私保护
//!
//! 仅使用 libp2p 默认 mDNS 广播，不携带任何自定义字段。

use libp2p::{
    core::upgrade,
    futures::StreamExt,
    identity, mdns, noise,
    swarm::{NetworkBehaviour, SwarmEvent},
    tcp, yamux, Multiaddr, PeerId, Swarm, Transport,
};
use tracing::{info, warn};

/// 是否启用自定义 mDNS 广播负载
pub const CUSTOM_MDNS_PAYLOAD_ENABLED: bool = false;

/// mDNS 网络行为
#[derive(NetworkBehaviour)]
#[behaviour(to_swarm = "MdnsEvent")]
struct MdnsNetworkBehaviour {
    /// mDNS 协议
    mdns: mdns::tokio::Behaviour,
}

/// mDNS 事件
#[derive(Debug)]
#[allow(clippy::enum_variant_names)]
pub enum MdnsEvent {
    /// mDNS 事件
    Mdns(mdns::Event),
}

impl From<mdns::Event> for MdnsEvent {
    fn from(event: mdns::Event) -> Self {
        Self::Mdns(event)
    }
}

/// mDNS 设备发现管理器
///
/// 负责在局域网内发现其他 CardMind 设备
///
/// # 示例
///
/// ```no_run
/// use cardmind_rust::p2p::MdnsDiscovery;
///
/// # async fn example() -> Result<(), Box<dyn std::error::Error>> {
/// let mut discovery = MdnsDiscovery::new().await?;
/// let peer_id = discovery.local_peer_id();
/// println!("本地 Peer ID: {}", peer_id);
///
/// // 启动发现
/// discovery.start_discovery().await?;
/// # Ok(())
/// # }
/// ```
pub struct MdnsDiscovery {
    /// libp2p Swarm
    swarm: Swarm<MdnsNetworkBehaviour>,
}

impl MdnsDiscovery {
    /// 创建新的 mDNS 发现实例
    ///
    /// # Errors
    ///
    /// 如果 mDNS 初始化失败，返回错误
    #[allow(clippy::unused_async)]
    pub async fn new() -> Result<Self, String> {
        info!("初始化 mDNS 设备发现...");

        // 1. 生成身份密钥对
        let local_key = identity::Keypair::generate_ed25519();
        let local_peer_id = PeerId::from(local_key.public());
        info!("mDNS 本地 Peer ID: {}", local_peer_id);

        // 2. 创建 mDNS 行为
        let mdns_behaviour = mdns::tokio::Behaviour::new(mdns::Config::default(), local_peer_id)
            .map_err(|e| e.to_string())?;

        let behaviour = MdnsNetworkBehaviour {
            mdns: mdns_behaviour,
        };

        // 3. 创建传输层（mDNS 不需要加密，因为仅用于发现）
        let transport = tcp::tokio::Transport::default()
            .upgrade(upgrade::Version::V1)
            .authenticate(noise::Config::new(&local_key).map_err(|e| e.to_string())?)
            .multiplex(yamux::Config::default())
            .boxed();

        // 4. 创建 Swarm（使用 tokio executor）
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

    /// 启动设备发现
    ///
    /// 开始监听 mDNS 广播并发现其他设备
    ///
    /// # Errors
    ///
    /// 如果发现失败，返回错误
    pub async fn start_discovery(&mut self) -> Result<(), String> {
        info!("开始 mDNS 设备发现...");

        // 监听所有接口
        self.swarm
            .listen_on("/ip4/0.0.0.0/tcp/0".parse().unwrap())
            .map_err(|e| e.to_string())?;

        // 处理事件
        loop {
            if let Some(event) = self.swarm.next().await {
                match event {
                    SwarmEvent::NewListenAddr { address, .. } => {
                        info!("mDNS 监听地址: {}", address);
                    }
                    SwarmEvent::Behaviour(MdnsEvent::Mdns(mdns::Event::Discovered(list))) => {
                        for (peer_id, multiaddr) in list {
                            info!("发现设备: {} at {}", peer_id, multiaddr);
                        }
                    }
                    SwarmEvent::Behaviour(MdnsEvent::Mdns(mdns::Event::Expired(list))) => {
                        for (peer_id, multiaddr) in list {
                            warn!("设备离线: {} at {}", peer_id, multiaddr);
                        }
                    }
                    _ => {}
                }
            }
        }
    }

    /// 获取已发现的对等节点列表
    #[must_use]
    pub fn discovered_peers(&self) -> Vec<(&PeerId, Vec<Multiaddr>)> {
        self.swarm
            .behaviour()
            .mdns
            .discovered_nodes()
            .map(|peer_id| {
                // 简化实现：返回 peer_id 和空地址列表
                // 完整实现需要从 mDNS 获取实际地址
                (peer_id, Vec::new())
            })
            .collect()
    }

    /// 处理下一个 Swarm 事件
    ///
    /// 这个方法用于在外部事件循环中处理单个事件
    ///
    /// # 返回
    ///
    /// 返回下一个 Swarm 事件，如果没有事件则返回 None
    pub async fn poll_next(&mut self) -> Option<SwarmEvent<MdnsEvent>> {
        use libp2p::futures::StreamExt;
        self.swarm.next().await
    }

    /// 在指定地址上开始监听
    ///
    /// # 参数
    ///
    /// - `addr`: 要监听的地址
    ///
    /// # 返回
    ///
    /// 成功返回 Ok(())，失败返回错误
    pub fn listen(&mut self, addr: &str) -> Result<(), String> {
        self.swarm
            .listen_on(
                addr.parse()
                    .map_err(|e: libp2p::multiaddr::Error| e.to_string())?,
            )
            .map_err(|e| e.to_string())?;
        Ok(())
    }

}

#[cfg(test)]
mod tests {
    use super::*;
    use std::error::Error;

    /// 测试 mDNS 发现初始化
    #[tokio::test]
    async fn it_should_mdns_discovery_creation() {
        let discovery = MdnsDiscovery::new().await;
        if let Err(err) = discovery {
            let msg = err.clone();
            if msg.contains("Permission denied") || msg.contains("Operation not permitted") {
                println!("跳过 mDNS 初始化测试：{err}");
                return;
            }
            panic!("mDNS 发现初始化应该成功: {err}");
        }
    }

    /// 测试两个节点相互发现
    ///
    /// 创建两个 mDNS 节点，验证它们能够相互发现
    #[tokio::test]
    #[allow(clippy::similar_names)]
    async fn it_should_mdns_peer_discovery() {
        use std::time::Duration;
        use tokio::time::timeout;

        // 1. 创建节点 A
        let discovery_a = MdnsDiscovery::new().await;
        let mut discovery_a = match discovery_a {
            Ok(discovery) => discovery,
            Err(err) => {
                let msg = err.clone();
                if msg.contains("Permission denied") || msg.contains("Operation not permitted") {
                    println!("跳过 mDNS 互发现测试：{err}");
                    return;
                }
                panic!("节点 A 初始化失败: {err}");
            }
        };
        let peer_a_id = *discovery_a.local_peer_id();

        // 2. 创建节点 B
        let discovery_b = MdnsDiscovery::new().await;
        let mut discovery_b = match discovery_b {
            Ok(discovery) => discovery,
            Err(err) => {
                let msg = err.clone();
                if msg.contains("Permission denied") || msg.contains("Operation not permitted") {
                    println!("跳过 mDNS 互发现测试：{err}");
                    return;
                }
                panic!("节点 B 初始化失败: {err}");
            }
        };
        let peer_b_id = *discovery_b.local_peer_id();

        println!("节点 A Peer ID: {peer_a_id}");
        println!("节点 B Peer ID: {peer_b_id}");

        // 3. 启动监听
        discovery_a
            .swarm
            .listen_on("/ip4/0.0.0.0/tcp/0".parse().unwrap())
            .expect("节点 A 监听失败");
        discovery_b
            .swarm
            .listen_on("/ip4/0.0.0.0/tcp/0".parse().unwrap())
            .expect("节点 B 监听失败");

        // 4. 等待相互发现（超时 30 秒，mDNS 发现可能较慢）
        let result = timeout(Duration::from_secs(30), async {
            let mut a_discovered_b = false;
            let mut b_discovered_a = false;

            loop {
                tokio::select! {
                    event = discovery_a.swarm.next() => {
                        if let Some(SwarmEvent::Behaviour(MdnsEvent::Mdns(mdns::Event::Discovered(list)))) = event {
                            for (peer_id, addr) in list {
                                if peer_id == peer_b_id {
                                    println!("✅ 节点 A 发现了节点 B: {addr}");
                                    a_discovered_b = true;
                                }
                            }
                        }
                    }
                    event = discovery_b.swarm.next() => {
                        if let Some(SwarmEvent::Behaviour(MdnsEvent::Mdns(mdns::Event::Discovered(list)))) = event {
                            for (peer_id, addr) in list {
                                if peer_id == peer_a_id {
                                    println!("✅ 节点 B 发现了节点 A: {addr}");
                                    b_discovered_a = true;
                                }
                            }
                        }
                    }
                }

                // 两个节点都相互发现，测试成功
                if a_discovered_b && b_discovered_a {
                    return Ok::<_, Box<dyn Error>>(());
                }
            }
        })
        .await;

        match result {
            Ok(Ok(())) => {
                println!("✅ mDNS 发现测试成功: 两个节点相互发现");
            }
            Ok(Err(e)) => {
                panic!("❌ mDNS 发现测试失败: {e}");
            }
            Err(e) => {
                panic!("❌ mDNS 发现测试超时（30秒）: {e}");
            }
        }
    }
}
