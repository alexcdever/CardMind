//! mDNS 发现服务集成测试。
//!
//! ## 环境语义（为什么需要真实网络接口）
//!
//! `DiscoveryService` 走 mDNS 组播：`start_advertising` 注册 `_cardmind._tcp`
//! 服务，`discover_peers` 发查询并收集 3 秒事件流。**本机自发现**（自己广播、
//! 自己应答）依赖组播回环可用：
//!
//! - 无 IPv4 接口 / 禁组播（常见于容器、受限 CI）时浏览器收不到应答；
//! - 所以两个用例都先用 `require_ipv4` 做环境前置：无 IPv4 时按环境变量
//!   `CARDMIND_REQUIRE_NETWORK_TESTS` **跳过**（=1 时直接失败，策略锚点见
//!   `net_env_policy_test.rs`），而不是靠「不报错」蒙过去。
//!
//! ## 两个用例各自断言什么
//!
//! 1. `advertising_makes_self_discoverable_via_mdns`：广播后**必须经 mDNS 发现
//!    自己**，且回读到的 port / nonce 与广播值一致、地址非空。
//! 2. `stopped_advertising_is_no_longer_discoverable`：停之前先断言「能发现」
//!    （否则否定断言无意义），`stop_advertising` 幂等，停之后**经 mDNS 有界重试
//!    到发现不到**。
//!
//! mDNS 注销（goodbye 报文）与缓存老化是**异步**的，所以第 2 条用「每轮一次真实
//! 3 秒浏览 + 30 秒总超时」的有界重试，而不是单次浏览后立刻下结论；超时仍能发现
//! 即失败（实测：把 stop 改成 no-op 会稳定失败，见提交说明）。
//!
//! ## 进程内串行
//!
//! 同一测试二进制内用例并行，而多个 `ServiceDaemon` 同时 register/browse 会互相
//! 看到对方的应答（连注销的 goodbye 也会被对方的浏览通道缓存），让第 2 条的否定
//! 断言出现假红。用一把 `tokio::sync::Mutex` 让本文件两个用例串行；只锁本文件
//! （其它测试 target 是独立进程，不受影响）。

mod common;

use std::time::{Duration, Instant};

use cardmind_backend::discovery::{DiscoveryService, PeerInfo};
use common::{require_ipv4, rt};

/// 本文件 mDNS 用例的串行闸（见模块注释「进程内串行」）。
fn mdns_gate() -> &'static tokio::sync::Mutex<()> {
    static GATE: tokio::sync::Mutex<()> = tokio::sync::Mutex::const_new(());
    &GATE
}

/// 进程内唯一的 device id 前缀。
///
/// mDNS instance name 只取前 8 字符（`cardmind-{device_id[..8]}`），所以不同用例
/// 必须有不同的**前 8 字符**，否则会触发 RFC 6762 名字冲突改名。
fn unique_device_id(tag: &str) -> String {
    static COUNTER: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);
    let seq = COUNTER.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
    format!("{tag}{seq:04x}")
}

/// 本机可广播的 IPv4 地址（`{ip}:0` 形式，仅供 `require_ipv4` 判空）。
///
/// 不引入新依赖：用 UDP connect 让内核选源地址（192.0.2.0/24 是 TEST-NET，
/// 不会真的出网），与 `SyncService::local_addrs()` 的信息来源同类。
fn local_ipv4_addrs() -> Vec<String> {
    let mut out = Vec::new();
    if let Ok(sock) = std::net::UdpSocket::bind("0.0.0.0:0") {
        if sock.connect("192.0.2.1:9").is_ok() {
            if let Ok(addr) = sock.local_addr() {
                if let std::net::IpAddr::V4(v4) = addr.ip() {
                    if !v4.is_loopback() {
                        out.push(format!("{v4}:0"));
                    }
                }
            }
        }
    }
    out
}

/// 广播后必须能从 mDNS 发现**自己的 device_id**（TXT 记录回读），
/// 而不是「注册没报错就算过」。
#[test]
fn advertising_makes_self_discoverable_via_mdns() {
    rt().block_on(async {
        let _gate = mdns_gate().lock().await;
        if !require_ipv4(&local_ipv4_addrs()) {
            return;
        }
        let mut disc = DiscoveryService::new().unwrap();
        let device_id = unique_device_id("adv0");
        let nonce = format!("{device_id}-nonce");
        let port: u16 = 45680;

        disc.start_advertising(&device_id, port, &nonce).unwrap();

        // mDNS 应答本身异步：有界重试（每轮一次真实 3 秒浏览）
        let deadline = Instant::now() + Duration::from_secs(30);
        let mut last: Vec<PeerInfo> = Vec::new();
        let mut found = None;
        while Instant::now() < deadline {
            let browser = DiscoveryService::new().unwrap();
            last = browser.discover_peers().await.unwrap();
            if let Some(hit) = last.iter().find(|p| p.device_id == device_id) {
                found = Some(hit.clone());
                break;
            }
        }
        let me = match found {
            Some(hit) => hit,
            None => panic!(
                "广播后 30 秒内未能通过 mDNS 发现自己 device_id={device_id}，\
                 最后一次浏览 {} 条: {:?}",
                last.len(),
                last.iter().map(|p| &p.device_id).collect::<Vec<_>>()
            ),
        };

        assert_eq!(me.port, port, "发现的端口应等于广播端口");
        assert_eq!(me.nonce, nonce, "发现的 nonce 应等于广播 nonce");
        assert!(
            !me.ip.is_empty(),
            "发现的记录应带可用地址（mDNS A/AAAA 记录），实际为空"
        );

        disc.stop_advertising().unwrap();
    });
}

/// stop 之后必须**通过 mDNS 发现不到**自己的 device_id（不是只看本地字段清零）。
#[test]
fn stopped_advertising_is_no_longer_discoverable() {
    rt().block_on(async {
        let _gate = mdns_gate().lock().await;
        if !require_ipv4(&local_ipv4_addrs()) {
            return;
        }
        let mut disc = DiscoveryService::new().unwrap();
        let device_id = unique_device_id("stop");
        let nonce = format!("{device_id}-nonce");
        disc.start_advertising(&device_id, 45681, &nonce).unwrap();

        // 前置断言：停之前确实能被发现，否则后面的否定断言是空断言。
        let before = disc.discover_peers().await.unwrap();
        assert!(
            before.iter().any(|p| p.device_id == device_id),
            "前置条件：停止广播前应能发现自己（否则本用例的否定断言无意义）"
        );

        // 幂等：连续 stop 两次都不报错（第二次是无操作）。
        disc.stop_advertising().unwrap();
        disc.stop_advertising().unwrap();

        // 注销是异步宣告的：有界重试直到发现不到；超时仍能发现即失败。
        let deadline = Instant::now() + Duration::from_secs(30);
        loop {
            // 每轮用**新的** daemon 浏览：避免复用上一轮浏览通道自带的缓存。
            let browser = DiscoveryService::new().unwrap();
            let last: Vec<PeerInfo> = browser.discover_peers().await.unwrap();
            if !last.iter().any(|p| p.device_id == device_id) {
                break;
            }
            assert!(
                Instant::now() < deadline,
                "stop_advertising 后 30 秒内仍能通过 mDNS 发现 device_id={device_id}：{:?}",
                last.iter()
                    .filter(|p| p.device_id == device_id)
                    .collect::<Vec<_>>()
            );
        }
    });
}
