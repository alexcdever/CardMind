//! 连接层集成测试（任务 F）：
//! 1. 设备身份持久化（SecretKey 稳定 → device_id 稳定）
//! 2. 内存版身份随机
//! 3. 配对设备表 CRUD
//! 4. 推送/接收全链路（直连或 relay）
//! 5. 多设备推送部分失败语义
//! 6. relay 模式启用（配置断言 + 本地 relay 行为验证）

use std::collections::HashMap;

use cardmind_backend::store::{NoteStore, PairedDeviceRow};
use cardmind_backend::sync::SyncService;

fn temp_dir(label: &str) -> std::path::PathBuf {
    let path =
        std::env::temp_dir().join(format!("cardmind-connect-{label}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&path);
    std::fs::create_dir_all(&path).unwrap();
    path
}

// ━━━ 验收 1：设备身份持久化 ━━━

#[test]
fn test_device_identity_persists() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let dir = temp_dir("identity");

        // 首次创建：生成并持久化 device.key
        let service_a = SyncService::new_persistent(&dir).await.unwrap();
        let id_a = service_a.device_id();
        drop(service_a);

        // device.key 文件应存在
        assert!(
            dir.join("device.key").exists(),
            "new_persistent 后应生成 device.key 文件"
        );

        // 重启：同一数据目录加载同一 SecretKey → device_id 稳定
        let service_b = SyncService::new_persistent(&dir).await.unwrap();
        assert_eq!(
            id_a,
            service_b.device_id(),
            "同一数据目录重启后 device_id 应保持不变"
        );

        let _ = std::fs::remove_dir_all(dir);
    });
}

// ━━━ 验收 2：内存版身份随机 ━━━

#[test]
fn test_memory_service_random_identity() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let a = SyncService::new().await.unwrap();
        let b = SyncService::new().await.unwrap();
        assert_ne!(
            a.device_id(),
            b.device_id(),
            "内存版 new() 两次创建 device_id 应不同（保持随机）"
        );
    });
}

// ━━━ 验收 3：配对设备表 CRUD ━━━

#[test]
fn test_paired_devices_crud() {
    let store = NoteStore::new(":memory:").unwrap();

    // upsert 两台设备
    store.upsert_paired_device("peer-a", "Alice").unwrap();
    store.upsert_paired_device("peer-b", "Bob").unwrap();

    let devices = store.list_paired_devices().unwrap();
    assert_eq!(devices.len(), 2, "upsert 两台后 list 应有 2 台");
    let by_id: HashMap<&str, &PairedDeviceRow> =
        devices.iter().map(|d| (d.peer_id.as_str(), d)).collect();
    assert_eq!(by_id["peer-a"].name, "Alice");
    assert_eq!(by_id["peer-b"].name, "Bob");
    // 配对时间已写入
    assert!(!by_id["peer-a"].paired_at.is_empty());
    // 初始 last_seen 为 None（尚未连接过）
    assert!(by_id["peer-a"].last_seen.is_none());

    // update_last_seen → 该设备 last_seen 非空且排在最前（最近连接优先）
    std::thread::sleep(std::time::Duration::from_millis(5));
    store.update_last_seen("peer-a").unwrap();
    let devices = store.list_paired_devices().unwrap();
    assert_eq!(devices.len(), 2);
    assert_eq!(devices[0].peer_id, "peer-a", "最近连接的设备应排最前");
    assert!(
        devices[0].last_seen.is_some(),
        "update_last_seen 后 last_seen 应非空"
    );
    assert!(devices[1].last_seen.is_none());

    // upsert 覆盖 name（重复 peer_id）
    store.upsert_paired_device("peer-a", "Alice-2").unwrap();
    let devices = store.list_paired_devices().unwrap();
    let by_id: HashMap<&str, &PairedDeviceRow> =
        devices.iter().map(|d| (d.peer_id.as_str(), d)).collect();
    assert_eq!(by_id["peer-a"].name, "Alice-2", "重复 upsert 应覆盖 name");

    // remove 后消失
    store.remove_paired_device("peer-b").unwrap();
    let devices = store.list_paired_devices().unwrap();
    assert_eq!(devices.len(), 1, "remove 后 list 应只剩 1 台");
    assert_eq!(devices[0].peer_id, "peer-a");
}

// ━━━ 验收 4：推送/接收全链路（直连或 relay）━━━

#[test]
fn test_push_receive_roundtrip_relay_or_direct() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let mut a = SyncService::new().await.unwrap();
        let b = SyncService::new().await.unwrap();

        a.create_note("note-1".into(), "# 同步笔记\n\n正文内容。")
            .unwrap();

        // B 提供实际地址（同网段直连优先）
        let b_id = b.device_id();
        let b_ips = b.local_addrs();
        assert!(!b_ips.is_empty(), "B 应至少有一个本地 IPv4 地址");

        // B 进入接收态
        let b_handle = tokio::spawn(async move {
            let data = b.accept_push().await.unwrap();
            let mut b = b;
            b.import_all(&data).unwrap();
            b
        });

        // A 推送（B 提供实际地址）
        a.push_to_peer(&b_id, b_ips).await.unwrap();

        // B 接收并导入后笔记可见
        let b = b_handle.await.unwrap();
        assert_eq!(
            b.get_note("note-1").as_deref(),
            Some("# 同步笔记\n\n正文内容。"),
            "B accept_push + import_all 后应能看到 A 的笔记"
        );
    });
}

// ━━━ 验收 5：多设备推送部分失败语义 ━━━

#[test]
fn test_push_multi_device_partial_failure() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let mut a = SyncService::new().await.unwrap();
        let b = SyncService::new().await.unwrap();
        let c = SyncService::new().await.unwrap();
        a.create_note("n1".into(), "hello from a").unwrap();

        let b_id = b.device_id();
        let c_id = c.device_id();
        let b_ips = b.local_addrs();
        let c_ips = c.local_addrs();

        // B、C 真实设备进入接收态
        let b_handle = tokio::spawn(async move {
            let data = b.accept_push().await.unwrap();
            let mut b = b;
            b.import_all(&data).unwrap();
            b
        });
        let c_handle = tokio::spawn(async move {
            let data = c.accept_push().await.unwrap();
            let mut c = c;
            c.import_all(&data).unwrap();
            c
        });

        // 假设备：有效 EndpointId（可解析）+ 不可达地址（127.0.0.1 关闭端口，快速失败）
        let fake_key = iroh::SecretKey::generate();
        let fake_id = fake_key.public().to_string();
        let fake_ips = vec!["127.0.0.1:1".to_string()];

        let devices = vec![
            (b_id.clone(), Some(b_ips)),
            (c_id.clone(), Some(c_ips)),
            (fake_id.clone(), Some(fake_ips)),
        ];
        let results = a.push_to_paired_devices(&devices).await;

        // 3 台都要有结果，顺序与输入一致
        assert_eq!(results.len(), 3, "每台设备都应有一个结果");
        assert_eq!(results[0].peer_id, b_id);
        assert_eq!(results[1].peer_id, c_id);
        assert_eq!(results[2].peer_id, fake_id);

        // 真设备成功，假设备失败
        assert!(results[0].ok, "B（真设备）应推送成功");
        assert!(results[1].ok, "C（真设备）应推送成功");
        assert!(!results[2].ok, "D（假设备）应失败");
        assert!(!results[2].message.is_empty(), "失败应有原因信息");

        // 真设备确实收到了数据（单个失败不影响其它设备）
        let b = b_handle.await.unwrap();
        let c = c_handle.await.unwrap();
        assert_eq!(b.get_note("n1").as_deref(), Some("hello from a"));
        assert_eq!(c.get_note("n1").as_deref(), Some("hello from a"));
    });
}

// ━━━ 验收 6：relay 模式启用 ━━━

#[test]
fn test_relay_mode_enabled() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let svc = SyncService::new().await.unwrap();
        assert_ne!(
            *svc.relay_mode(),
            iroh::RelayMode::Disabled,
            "生产配置 relay_mode 应为官方公共 relay（RelayMode::Default），不得为 Disabled"
        );
    });
}

/// 验收 6 行为补充：两个"跨网段"endpoint 仅凭对端 relay URL（无直连 IP）建立连接并传输数据。
///
/// 使用本地 relay 服务器（iroh::test_utils::run_relay_server），不依赖公共 relay 的网络可达性，
/// 验证本环境下 relay 打洞/中转路径可用 —— 支撑生产 RelayMode::Default 配置的可行性。
#[test]
fn test_relay_cross_network_connect() {
    use iroh::endpoint::presets;
    use iroh::tls::CaTlsConfig;
    use iroh::{Endpoint, EndpointAddr, RelayMode, SecretKey};

    const ALPN: &[u8] = b"cardmind-v2";

    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        // 本地 relay 服务器（loopback，离线可用）
        let (relay_map, relay_url, _guard) =
            iroh::test_utils::run_relay_server().await.expect("spawn local relay");

        // 设备 B（接收端）：relay 中转可达，无直连 IP 暴露给 A
        let key_b = SecretKey::generate();
        let ep_b = Endpoint::builder(presets::Minimal)
            .secret_key(key_b)
            .alpns(vec![ALPN.to_vec()])
            .relay_mode(RelayMode::Custom(relay_map.clone()))
            .ca_tls_config(CaTlsConfig::insecure_skip_verify())
            .bind()
            .await
            .expect("B bind");
        // 等待 B 经 relay 上线
        ep_b.online().await;
        let b_id = ep_b.id();

        let b_handle = tokio::spawn(async move {
            let incoming = ep_b.accept().await.expect("B accept incoming");
            let conn = incoming.accept().expect("B accept").await.expect("B accept conn");
            let mut recv = conn.accept_uni().await.expect("B accept uni");
            let data = recv.read_to_end(usize::MAX).await.expect("B read data");
            conn.close(0u32.into(), b"done");
            String::from_utf8(data).expect("utf8 data")
        });

        // 设备 A（发送端）：仅凭 B 的 node id + relay URL 连接（模拟跨网段，无直连 IP）
        let key_a = SecretKey::generate();
        let ep_a = Endpoint::builder(presets::Minimal)
            .secret_key(key_a)
            .alpns(vec![ALPN.to_vec()])
            .relay_mode(RelayMode::Custom(relay_map))
            .ca_tls_config(CaTlsConfig::insecure_skip_verify())
            .bind()
            .await
            .expect("A bind");

        let addr_b = EndpointAddr::new(b_id).with_relay_url(relay_url);
        let conn = ep_a
            .connect(addr_b, ALPN)
            .await
            .expect("A connect via relay");
        let mut send = conn.open_uni().await.expect("A open uni");
        send.write_all(b"hello over relay").await.expect("A write");
        send.finish().expect("A finish");
        conn.closed().await;

        let received = b_handle.await.expect("B task join");
        assert_eq!(received, "hello over relay", "relay 中转后 B 应收到完整数据");
    });
}

