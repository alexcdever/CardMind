//! P2P 网络层集成测试
//!
//! 这些测试验证 Phase 5 中声明的 libp2p 网络基础能力：
//! - 初始化网络
//! - 监听/拨号并建立连接
//! - 证明加密信道可用（Noise 握手成功即证明）

use cardmind_rust::p2p::P2PNetwork;
use futures::StreamExt;
use libp2p::{multiaddr::Protocol, swarm::SwarmEvent, Multiaddr};
use tokio::time::{timeout, Duration};

/// 验证网络可以初始化并监听随机端口
#[tokio::test]
async fn it_should_p2p_network_listen() {
    let mut network = P2PNetwork::new(false).expect("network should initialize");
    let addr = match network.listen_on("/ip4/127.0.0.1/tcp/0").await {
        Ok(addr) => addr,
        Err(err) => {
            let msg = err.to_string();
            if msg.contains("Permission denied")
                || msg.contains("Operation not permitted")
                || msg.is_empty()
            {
                println!("Skipping listen test due to permission: {msg}");
                return;
            }
            panic!("should start listening: {err}");
        }
    };

    // 地址应包含 tcp 端口
    assert!(
        addr.iter().any(|p| matches!(p, Protocol::Tcp(_))),
        "listen addr should contain tcp port"
    );
}

/// 验证两个节点可以建立 P2P 连接
///
/// 连接建立成功即证明 Noise 加密握手成功，加密信道可用
#[tokio::test]
async fn it_should_p2p_network_connect() {
    let mut node_a = P2PNetwork::new(false).expect("node A should initialize");
    let mut node_b = P2PNetwork::new(false).expect("node B should initialize");

    let listen_addr = match node_a.listen_on("/ip4/127.0.0.1/tcp/0").await {
        Ok(addr) => addr,
        Err(err) => {
            let msg = err.to_string();
            if msg.contains("Permission denied")
                || msg.contains("Operation not permitted")
                || msg.is_empty()
            {
                println!("Skipping connect/ping test due to permission: {msg}");
                return;
            }
            panic!("node A should listen: {err}");
        }
    };

    // node_b 拨号 node_a
    node_b.dial(&listen_addr).expect("dial should succeed");

    // 等待连接建立（最多 5 秒）
    let timeout_duration = Duration::from_secs(5);
    let result = timeout(timeout_duration, async {
        let mut got_connection = false;

        loop {
            tokio::select! {
                event = node_a.swarm_mut().next() => {
                    if let Some(SwarmEvent::ConnectionEstablished { peer_id, .. }) = event {
                        assert_eq!(peer_id, *node_b.local_peer_id());
                        got_connection = true;
                    }
                }
                event = node_b.swarm_mut().next() => {
                    if let Some(SwarmEvent::ConnectionEstablished { peer_id, .. }) = event {
                        assert_eq!(peer_id, *node_a.local_peer_id());
                        got_connection = true;
                    }
                }
            }

            if got_connection {
                break;
            }
        }
    })
    .await;

    assert!(
        result.is_ok(),
        "nodes should establish connection within 5 seconds"
    );
}

// helper to make Multiaddr printable in assertions when needed
fn _debug_addr(addr: &Multiaddr) -> String {
    addr.iter()
        .map(|p| p.to_string())
        .collect::<Vec<_>>()
        .join("/")
}
