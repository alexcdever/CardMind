use std::collections::HashMap;
use std::net::IpAddr;
use std::time::Duration;

use anyhow::{Context, Result};
use mdns_sd::{ServiceDaemon, ServiceEvent, ServiceInfo};

/// mDNS 服务类型
const SERVICE_TYPE: &str = "_cardmind._tcp.local.";

/// 局域网内发现的对端设备信息
#[derive(Debug, Clone)]
pub struct PeerInfo {
    pub device_id: String,
    pub ip: String,
    pub port: u16,
}

/// mDNS 设备发现服务
///
/// 负责在局域网广播本设备的存在，并扫描发现其他 CardMind 对端。
pub struct DiscoveryService {
    daemon: ServiceDaemon,
    /// 已注册的实例全名（用于取消注册）
    registered_fullname: Option<String>,
}

impl DiscoveryService {
    /// 创建 mDNS 发现服务
    pub fn new() -> Result<Self> {
        let daemon = ServiceDaemon::new()
            .map_err(|e| anyhow::anyhow!("Failed to create mDNS daemon: {e}"))?;
        Ok(Self {
            daemon,
            registered_fullname: None,
        })
    }

    /// 在局域网广播本设备的存在
    ///
    /// `device_id`: iroh EndpointId 字符串（放 TXT 记录）
    /// `port`: iroh 监听端口
    pub fn start_advertising(&mut self, device_id: &str, port: u16) -> Result<()> {
        // 停止之前的广播（如有）
        self.stop_advertising()?;

        let instance_name = format!("cardmind-{}", &device_id[..device_id.len().min(8)]);
        let hostname = format!("{}.local.", instance_name);

        // TXT 记录
        let mut properties = HashMap::new();
        properties.insert("device_id".to_string(), device_id.to_string());
        properties.insert("port".to_string(), port.to_string());

        let service_info = ServiceInfo::new(
            SERVICE_TYPE,
            &instance_name,
            &hostname,
            (), // 不放固定 IP，让 daemon 自动检测
            port,
            properties,
        )?
        .enable_addr_auto();

        let fullname = service_info.get_fullname().to_string();
        self.daemon
            .register(service_info)
            .context("Failed to register mDNS service")?;

        self.registered_fullname = Some(fullname);
        Ok(())
    }

    /// 停止广播
    pub fn stop_advertising(&mut self) -> Result<()> {
        if let Some(fullname) = self.registered_fullname.take() {
            self.daemon
                .unregister(&fullname)
                .context("Failed to unregister mDNS service")?;
        }
        Ok(())
    }

    /// 扫描局域网内的 CardMind 设备（阻塞，超时 3 秒）
    ///
    /// 使用 `recv_async()` + `tokio::time::timeout` 实现超时扫描。
    pub async fn discover_peers(&self) -> Result<Vec<PeerInfo>> {
        let receiver = self
            .daemon
            .browse(SERVICE_TYPE)
            .context("Failed to browse mDNS service")?;

        let mut peers = Vec::new();

        loop {
            match tokio::time::timeout(Duration::from_secs(3), receiver.recv_async()).await {
                Ok(Ok(ServiceEvent::ServiceResolved(service))) => {
                    // 从 TXT 记录提取 device_id
                    let device_id = service
                        .get_property_val_str("device_id")
                        .unwrap_or_default()
                        .to_string();

                    // 没有 device_id 的忽略
                    if device_id.is_empty() {
                        continue;
                    }

                    // 提取 IPv4 地址
                    let ip = service
                        .get_addresses_v4()
                        .iter()
                        .next()
                        .map(|a| IpAddr::V4(*a))
                        .or_else(|| {
                            // fallback: 取第一个可用地址
                            service
                                .get_addresses()
                                .iter()
                                .next()
                                .map(|scoped| scoped.to_ip_addr())
                        })
                        .map(|addr| addr.to_string())
                        .unwrap_or_default();

                    let port = service.get_port();

                    peers.push(PeerInfo {
                        device_id,
                        ip,
                        port,
                    });
                }
                Ok(Ok(
                    ServiceEvent::SearchStarted(_)
                    | ServiceEvent::ServiceFound(..)
                    | ServiceEvent::ServiceRemoved(..)
                    | ServiceEvent::SearchStopped(_),
                )) => {
                    // 这些事件不需要处理
                    continue;
                }
                Ok(Err(_)) | Err(_) => {
                    // 通道断开或超时，结束扫描
                    break;
                }
                _ => continue,
            }
        }

        Ok(peers)
    }
}

impl Drop for DiscoveryService {
    fn drop(&mut self) {
        // 析构时停止广播
        let _ = self.stop_advertising();
    }
}
