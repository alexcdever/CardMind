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
    pub nonce: String,
}

/// mDNS 设备发现服务
///
/// 负责在局域网广播本设备的存在，并扫描发现其他 CardMind 对端。
pub struct DiscoveryService {
    daemon: ServiceDaemon,
    /// 已注册的实例全名（用于取消注册）
    registered_fullname: Option<String>,
}

/// 从 device_id 派生 mDNS instance name。
///
/// **当前实现有缺陷**：只取 device_id 前 8 个字符，前 8 位相同的两个
/// device_id 会得到同名，触发 RFC 6762/6763 自动改名。见本文件 `tests` 模块。
fn service_instance_name(device_id: &str) -> String {
    format!("cardmind-{}", &device_id[..device_id.len().min(8)])
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
    /// `nonce`: 当前配对会话 nonce（hex，随 TXT 广播）
    pub fn start_advertising(&mut self, device_id: &str, port: u16, nonce: &str) -> Result<()> {
        // 停止之前的广播（如有）
        self.stop_advertising()?;

        // instance name 只用于可读性与去冲突；对端身份一律取 TXT 的 `device_id`，
        // 不从本名字反推（discover_peers 也确实是读 TXT）。
        let instance_name = service_instance_name(device_id);
        let hostname = format!("{}.local.", instance_name);

        // TXT 记录
        let mut properties = HashMap::new();
        properties.insert("device_id".to_string(), device_id.to_string());
        properties.insert("port".to_string(), port.to_string());
        properties.insert("nonce".to_string(), nonce.to_string());

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
                    let nonce = service
                        .get_property_val_str("nonce")
                        .unwrap_or_default()
                        .to_string();

                    peers.push(PeerInfo {
                        device_id,
                        ip,
                        port,
                        nonce,
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

#[cfg(test)]
mod tests {
    //! instance name 派生的单元测试（纯逻辑无网络）。
    //!
    //! 派生规则（`service_instance_name`）：`cardmind-{可读前缀}`，
    //! 可读前缀 = device_id 清洗（[a-z0-9-]、去首尾连字符）后截断 +
    //! `-` + 对**完整** device_id 的 8 位短哈希；总长度 ≤ 63（DNS label 上限）。
    //! instance name 只用于可读性与去冲突，对端身份一律取 TXT 的 device_id。
    //!
    //! 证伪锚点：把派生改回「只取 device_id 前 8 字符」时，
    //! `ids_sharing_first_eight_chars_get_distinct_instance_names` 必须变红。

    use super::service_instance_name;

    /// 断言 label 满足 mDNS/DNS 单 label 约束：≤63 字节、只含
    /// 字母数字连字符、不以连字符开头或结尾。
    fn assert_valid_label(name: &str) {
        assert!(
            name.len() <= 63,
            "instance name 超过 63 字节 DNS label 上限：{name}（{} 字节）",
            name.len()
        );
        assert!(
            name.chars().all(|c| c.is_ascii_alphanumeric() || c == '-'),
            "instance name 含非 [a-z0-9-] 字符：{name}"
        );
        assert!(
            !name.starts_with('-') && !name.ends_with('-'),
            "instance name 以连字符开头或结尾：{name}"
        );
    }

    /// 前 8 字符相同的两个 device_id 必须得到不同 instance name——
    /// 这是本缺陷的核心：同 service type 下撞名会触发 RFC 6762 自动改名。
    #[test]
    fn ids_sharing_first_eight_chars_get_distinct_instance_names() {
        let a = service_instance_name("aaaaaaaa-1111");
        let b = service_instance_name("aaaaaaaa-2222");
        assert_ne!(
            a, b,
            "device_id 前 8 位相同但 instance name 必须不同：{a} vs {b}"
        );
    }

    /// 确定性：同一 device_id 重复派生得到同一名称（否则重启广播会被视为新服务）。
    #[test]
    fn same_device_id_derives_same_instance_name() {
        let id = "probe-stop-12345678";
        assert_eq!(service_instance_name(id), service_instance_name(id));
    }

    /// 超长 device_id（远超 63 字节）也要产出合法 label：
    /// 可读段截断但唯一性由全量短哈希保证，不能硬截前 N 位回到标准 1 的缺陷。
    #[test]
    fn overlong_device_id_yields_valid_bounded_label() {
        let id = "a".repeat(200);
        let name = service_instance_name(&id);
        assert_valid_label(&name);
    }

    /// 真实形态 device_id（iroh EndpointId 为 52 字符 base32 hex 类字符串）
    /// 与测试用可读 id 都要产出合法 label。
    #[test]
    fn realistic_device_ids_yield_valid_labels() {
        for id in [
            "k51qzi5uqu5dg2yq9l7v9z7p0q1b3l5o3j3l3v5w2n0x1y2z3a4b5c6d",
            "test-device-12345678",
            "probe-stop-12345678",
        ] {
            assert_valid_label(&service_instance_name(id));
        }
    }

    /// 极端输入（空串、非法字符、连字符结尾、大小写）不得 panic 且产出合法 label。
    #[test]
    fn hostile_inputs_yield_valid_labels() {
        for id in ["", "---", "ABC_def!", "trailing-", "-leading", "with space"] {
            assert_valid_label(&service_instance_name(id));
        }
    }
}
