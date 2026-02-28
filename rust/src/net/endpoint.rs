// input: iroh 端点构建参数、目标 EndpointAddr 与地址观察超时配置。
// output: PoolEndpoint 包装器、连接结果与可用端点地址等待能力。
// pos: 底层端点适配文件，负责封装 iroh Endpoint 的创建与连接接口。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：本文件封装 iroh 端点构建与连接。
use crate::models::error::CardMindError;
use iroh::address_lookup::mdns::MdnsAddressLookup;
use iroh::endpoint::Connection;
use iroh::{Endpoint, EndpointAddr, EndpointId, Watcher};
use std::time::Duration;
use tokio::time::sleep;

pub const POOL_ALPN: &[u8] = b"cardmind/pool/1";

#[derive(Debug)]
pub struct PoolEndpoint {
    endpoint: Endpoint,
}

impl PoolEndpoint {
    pub fn new(endpoint: Endpoint) -> Self {
        Self { endpoint }
    }

    pub fn endpoint_id(&self) -> EndpointId {
        self.endpoint.id()
    }

    pub fn endpoint_addr(&self) -> EndpointAddr {
        self.endpoint.addr()
    }

    pub async fn connect(
        &self,
        peer: impl Into<EndpointAddr>,
    ) -> Result<Connection, CardMindError> {
        self.endpoint
            .connect(peer.into(), POOL_ALPN)
            .await
            .map_err(|e| CardMindError::Internal(e.to_string()))
    }

    pub fn inner(&self) -> &Endpoint {
        &self.endpoint
    }

    pub async fn wait_for_addr(
        &self,
        timeout: Duration,
    ) -> Result<EndpointAddr, CardMindError> {
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

pub async fn build_endpoint() -> Result<Endpoint, CardMindError> {
    let mdns = MdnsAddressLookup::builder();
    Endpoint::builder()
        .alpns(vec![POOL_ALPN.to_vec()])
        .address_lookup(mdns)
        .bind()
        .await
        .map_err(|e| CardMindError::Internal(e.to_string()))
}

pub async fn build_test_endpoints() -> Result<(PoolEndpoint, PoolEndpoint), CardMindError> {
    let a = build_endpoint().await?;
    let b = build_endpoint().await?;
    Ok((PoolEndpoint::new(a), PoolEndpoint::new(b)))
}
