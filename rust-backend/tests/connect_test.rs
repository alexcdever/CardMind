//! 连接层集成测试（任务 F）：
//! 1. 设备身份持久化（SecretKey 稳定 → device_id 稳定）
//! 2. 内存版身份随机
//! 3. 配对设备表 CRUD
//! 4. 推送/接收全链路（直连或 relay）
//! 5. 多设备推送部分失败语义
//! 6. relay 模式配置（任务 K：内存版 Disabled 断言 + 本地 relay 行为验证）

mod common;

use std::collections::HashMap;

use cardmind_backend::store::{NoteStore, PairedDeviceRow};
use cardmind_backend::sync::{PairingTarget, SyncService};
use common::{require_ipv4, temp_dir};

// ━━━ 配对辅助：入站授权的前提 ━━━

/// 确认方侧配对（测试辅助）：接收发起方请求 → confirm，返回发起方 device_id。
///
/// `confirm_pairing` 会把发起方写入确认方 store（`upsert_paired_device`）并加入
/// 确认方的入站授权集合——这是接收方随后能接受该发起方推送的前提
/// （未配对 peer 的推送会被拒绝：`unauthorized push peer`）。
async fn confirm_from_initiator(
    confirmer: &mut SyncService,
    store: &NoteStore,
    code: &str,
) -> String {
    let request = confirmer.accept_pairing_request().await.unwrap();
    confirmer
        .confirm_pairing(store, code, &request)
        .await
        .unwrap();
    request.device_id
}

/// 发起方侧配对（测试辅助）：连接确认方 → 完成握手 → drain 确认方的首次全量推送。
///
/// 决策 8：确认方 confirm 成功后自动向发起方推送全量快照。该快照的**内容**不是
/// 调用方测试的验收对象（要验的是之后显式推送的数据），但「没送达」必须显式
/// 暴露：静默吞掉只会表现为别处的超时或断言失败。有界等待避免推送根本没发出时
/// 挂死；不 drain 则会让确认方的 `push_to_peer` 等满 10s 连接关闭超时
/// （配对已成功，推送失败容忍）。
async fn pair_with_confirmer(
    initiator: &SyncService,
    store: &NoteStore,
    code: &str,
    target: PairingTarget,
) {
    initiator
        .begin_pairing_connect(store, code, target)
        .await
        .unwrap();
    let drained = tokio::time::timeout(std::time::Duration::from_secs(10), initiator.accept_push())
        .await
        .expect("确认方配对后的首次全量推送未在 10s 内送达");
    drained.expect("确认方配对后的首次全量推送未送达");
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

    // update_last_seen → 该设备 last_seen 非空且排在最前（最近连接优先）。
    // 排序键 (last_seen IS NULL), last_seen DESC, peer_id ASC：update_last_seen
    // 后 peer-a 的 last_seen 从 NULL 变非 NULL，(last_seen IS NULL) 从 1→0，
    // 必然排在 last_seen 仍为 NULL 的 peer-b 之前，无需 sleep。
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
        let mut b = SyncService::new().await.unwrap();

        a.create_note("note-1".into(), "# 同步笔记\n\n正文内容。")
            .unwrap();

        // B 提供实际地址（同网段直连优先）
        let b_id = b.device_id();
        let b_ips = b.local_addrs();
        if !require_ipv4(&b_ips) {
            return;
        }

        // 入站授权前提（security_sync_test 冻结的语义）：接收端只接受已配对设备的
        // 推送，所以先走一次真实配对握手。确认方 B 的 confirm_pairing 会做两件事：
        // 把 A 写入 B 的 paired_devices（落库），并把 A 加入 B 的服务级内存授权
        // 集合 authorized_peers（sync.rs:1050-1055）。本测试走 accept_push()，用的
        // 正是这份内存集合（sync.rs:2030）——**不会**像后台接收器那样从 store 重建
        // 授权集合（那条路径见 sync.rs:2779-2784）。
        let a_id = a.device_id();
        let store_a = NoteStore::new(":memory:").unwrap();
        let store_b = NoteStore::new(":memory:").unwrap();
        let code = b.begin_pairing_accept().unwrap();
        let code_for_b = code.clone();
        let target_b = PairingTarget {
            device_id: b_id.clone(),
            ips: b_ips.clone(),
            nonce: b.session_nonce_hex(),
        };

        // B 进入接收态：先配对（把 A 记为已配对设备），再接收推送并导入
        let b_handle = tokio::spawn(async move {
            assert_eq!(
                confirm_from_initiator(&mut b, &store_b, &code_for_b).await,
                a_id,
                "确认方应收到 A 的配对请求"
            );
            assert!(
                store_b
                    .list_paired_devices()
                    .unwrap()
                    .iter()
                    .any(|d| d.peer_id == a_id),
                "配对后 B 的 store 应含 A（配对结果已落库）"
            );
            let data = b.accept_push().await.unwrap();
            let mut b = b;
            b.import_all(&data).unwrap();
            b
        });

        // A 完成配对握手（并 drain 确认方的首次全量推送）
        pair_with_confirmer(&a, &store_a, &code, target_b).await;

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
        let mut b = SyncService::new().await.unwrap();
        let mut c = SyncService::new().await.unwrap();
        a.create_note("n1".into(), "hello from a").unwrap();

        let a_id = a.device_id();
        let b_id = b.device_id();
        let c_id = c.device_id();
        let b_ips = b.local_addrs();
        let c_ips = c.local_addrs();

        // 入站授权前提（同 test_push_receive_roundtrip_relay_or_direct）：
        // B、C 各自与 A 走一次真实配对握手，把 A 写入自己的 paired_devices。
        let store_a = NoteStore::new(":memory:").unwrap();
        let store_b = NoteStore::new(":memory:").unwrap();
        let store_c = NoteStore::new(":memory:").unwrap();
        let code_b = b.begin_pairing_accept().unwrap();
        let code_c = c.begin_pairing_accept().unwrap();
        let target_b = PairingTarget {
            device_id: b_id.clone(),
            ips: b_ips.clone(),
            nonce: b.session_nonce_hex(),
        };
        let target_c = PairingTarget {
            device_id: c_id.clone(),
            ips: c_ips.clone(),
            nonce: c.session_nonce_hex(),
        };

        // B、C 真实设备进入接收态：先配对（把 A 记为已配对设备），再接收推送并导入
        let a_id_for_b = a_id.clone();
        let code_b_for_b = code_b.clone();
        let b_handle = tokio::spawn(async move {
            assert_eq!(
                confirm_from_initiator(&mut b, &store_b, &code_b_for_b).await,
                a_id_for_b,
                "确认方 B 应收到 A 的配对请求"
            );
            let data = b.accept_push().await.unwrap();
            let mut b = b;
            b.import_all(&data).unwrap();
            b
        });
        let a_id_for_c = a_id.clone();
        let code_c_for_c = code_c.clone();
        let c_handle = tokio::spawn(async move {
            assert_eq!(
                confirm_from_initiator(&mut c, &store_c, &code_c_for_c).await,
                a_id_for_c,
                "确认方 C 应收到 A 的配对请求"
            );
            let data = c.accept_push().await.unwrap();
            let mut c = c;
            c.import_all(&data).unwrap();
            c
        });

        // A 依次与 B、C 完成配对握手（各自 drain 确认方的首次全量推送）
        pair_with_confirmer(&a, &store_a, &code_b, target_b).await;
        pair_with_confirmer(&a, &store_a, &code_c, target_c).await;

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

// ━━━ 验收 6：relay 模式配置（任务 K）━━━

/// 内存版 `new()` 的 relay 模式恒为 `Disabled`（任务 K 契约：默认仅局域网，
/// 不读 relay.txt；relay 是可选配置，由 `new_persistent` 经数据目录 `relay.txt`
/// 启用）。详细配置行为见 `relay_config_test.rs`。
#[test]
fn test_relay_mode_disabled_by_default() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let svc = SyncService::new().await.unwrap();
        assert_eq!(
            *svc.relay_mode(),
            iroh::RelayMode::Disabled,
            "任务 K：内存版 new() 默认 Disabled（仅局域网），relay 需显式配置"
        );
    });
}

/// 验收：health-check 使用独立 ACK 帧，不发送笔记快照。
///
/// 该用例验证真实双端链路上的连接可用性语义。
#[test]
fn test_health_check_updates_last_seen_without_syncing_notes() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let dir_a = temp_dir("health-a");
        let dir_b = temp_dir("health-b");
        let a = SyncService::new_persistent(&dir_a).await.unwrap();
        let b = SyncService::new_persistent(&dir_b).await.unwrap();
        let store_a = NoteStore::new(&dir_a.join("cardmind.db").to_string_lossy()).unwrap();
        let store_b = NoteStore::new(&dir_b.join("cardmind.db").to_string_lossy()).unwrap();
        let a_id = a.device_id();
        let b_id = b.device_id();
        store_a.upsert_paired_device(&b_id, "B").unwrap();
        store_b.upsert_paired_device(&a_id, "A").unwrap();
        b.start_receiver(store_b.clone()).await.unwrap();

        let latency = a
            .check_connectivity(&store_a, &b_id, b.local_addrs())
            .await
            .unwrap();
        assert!(latency < 3_000);
        let row = store_a.list_paired_devices().unwrap().remove(0);
        assert!(row.last_seen.is_some());
        assert!(row.last_sync_at.is_none());
        assert!(a.get_note("health-note").is_none());
        assert!(b.get_note("health-note").is_none());

        b.stop_receiver().await.unwrap();
        let _ = std::fs::remove_dir_all(dir_a);
        let _ = std::fs::remove_dir_all(dir_b);
    });
}

#[test]
fn test_health_check_failure_does_not_update_last_seen() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let dir = temp_dir("health-failure");
        let svc = SyncService::new_persistent(&dir).await.unwrap();
        let store = NoteStore::new(&dir.join("cardmind.db").to_string_lossy()).unwrap();
        let fake_key = iroh::SecretKey::generate();
        let fake_id = fake_key.public().to_string();
        store.upsert_paired_device(&fake_id, "unreachable").unwrap();
        let started = std::time::Instant::now();
        let result = svc
            .check_connectivity(&store, &fake_id, vec!["127.0.0.1:1".to_string()])
            .await;
        assert!(result.is_err());
        assert!(started.elapsed() < std::time::Duration::from_secs(6));

        // 总预算回归网（验收 3）：last_ips 直连失败后回退 id-only 寻址，
        // 两条路径合计不得把「对端真不在线」的失败拖过 6 秒。
        let row = store.list_paired_devices().unwrap().remove(0);
        assert!(row.last_seen.is_none());
        assert!(row.last_sync_at.is_none());
        let _ = std::fs::remove_dir_all(dir);
    });
}

#[test]
fn test_health_check_same_peer_rejects_in_flight_request() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let dir = temp_dir("health-in-flight");
        let svc = SyncService::new_persistent(&dir).await.unwrap();
        let store = NoteStore::new(&dir.join("cardmind.db").to_string_lossy()).unwrap();
        let fake_key = iroh::SecretKey::generate();
        let peer_id = fake_key.public().to_string();
        store.upsert_paired_device(&peer_id, "unreachable").unwrap();
        let first = svc.check_connectivity(&store, &peer_id, vec!["127.0.0.1:1".to_string()]);
        tokio::pin!(first);
        tokio::task::yield_now().await;
        let second = svc
            .check_connectivity(&store, &peer_id, vec!["127.0.0.1:1".to_string()])
            .await;
        assert!(second.is_err(), "same peer checks must not overlap");
        let _ = first.await;
        let _ = std::fs::remove_dir_all(dir);
    });
}

#[test]
fn test_relay_cross_network_connect() {
    use iroh::endpoint::presets;
    use iroh::tls::CaTlsConfig;
    use iroh::{Endpoint, EndpointAddr, RelayMode, SecretKey};

    const ALPN: &[u8] = b"cardmind-v2";

    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        // 本地 relay 服务器（loopback，离线可用）
        let (relay_map, relay_url, _guard) = iroh::test_utils::run_relay_server()
            .await
            .expect("spawn local relay");

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
            let conn = incoming
                .accept()
                .expect("B accept")
                .await
                .expect("B accept conn");
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
        assert_eq!(
            received, "hello over relay",
            "relay 中转后 B 应收到完整数据"
        );
    });
}

// ━━━ 验收 2/3 补充：多对「测试连接」失败场景的预算与语义 ━━━

/// 场景：已配对 peer 完全无地址（ips=[] 且内存 peer_ips 为空）→ 走 id-only 寻址。
/// 断言：有界时间内失败返回（不挂死），且不写 last_seen。
/// 作用：约束 id-only 兜底路径本身有独立上限，不能无限等待。
#[test]
fn test_health_check_no_ips_id_only_bounded() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let dir = temp_dir("health-noidips");
        let svc = SyncService::new_persistent(&dir).await.unwrap();
        let store = NoteStore::new(&dir.join("cardmind.db").to_string_lossy()).unwrap();
        let fake_key = iroh::SecretKey::generate();
        let fake_id = fake_key.public().to_string();
        store
            .upsert_paired_device(&fake_id, "no-addr-peer")
            .unwrap();
        let started = std::time::Instant::now();
        let result = svc.check_connectivity(&store, &fake_id, vec![]).await;
        let elapsed = started.elapsed();
        assert!(result.is_err(), "无地址的不存在 peer 应失败");
        assert!(
            elapsed < std::time::Duration::from_secs(15),
            "id-only 寻址失败应在上限内返回，实测 {:?}",
            elapsed
        );
        let row = store.list_paired_devices().unwrap().remove(0);
        assert!(row.last_seen.is_none());
        let _ = std::fs::remove_dir_all(dir);
    });
}

// ━━━ 验收 4：入站连接把对端真实 ip:port 刷新进地址表 ━━━

/// B 的接收器收到 A 的直连推送后，B 的 store.last_ips 应被更新为 A 本次连接的
/// 真实 ip:port（而不是停留在配对时写入的旧值）。
#[test]
fn test_inbound_push_refreshes_last_ips() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let mut a = SyncService::new().await.unwrap();
        let mut b = SyncService::new().await.unwrap();
        a.create_note("n-refresh".into(), "ip refresh").unwrap();

        let a_id = a.device_id();
        let b_id = b.device_id();
        let b_ips = b.local_addrs();
        let store_a = NoteStore::new(":memory:").unwrap();
        let store_b = NoteStore::new(":memory:").unwrap();
        let code = b.begin_pairing_accept().unwrap();
        let code_for_b = code.clone();
        let target_b = PairingTarget {
            device_id: b_id.clone(),
            ips: b_ips.clone(),
            nonce: b.session_nonce_hex(),
        };
        let a_id_for_b = a_id.clone();
        let b_handle = tokio::spawn(async move {
            assert_eq!(
                confirm_from_initiator(&mut b, &store_b, &code_for_b).await,
                a_id_for_b
            );
            // 把 A 的 last_ips 写成假过期值，等推送后断言被真实地址覆盖
            store_b
                .update_paired_device_ips(&a_id_for_b, &["10.9.9.9:9999".to_string()])
                .unwrap();
            b.start_receiver(store_b.clone()).await.unwrap();
            // 轮询「last_ips 已被真实地址覆盖」而不是盲等固定 6 秒：
            // 条件成立立即返回，超时则有界失败（10 秒上限，覆盖推送 + 接收器落库）。
            let deadline = tokio::time::Instant::now() + std::time::Duration::from_secs(10);
            loop {
                let refreshed = store_b
                    .paired_device_ips(&a_id_for_b)
                    .map(|ips| ips.join(","))
                    .unwrap_or_default();
                if !refreshed.is_empty() && !refreshed.contains("10.9.9.9:9999") {
                    break;
                }
                if tokio::time::Instant::now() >= deadline {
                    panic!("推送后 10 秒内 last_ips 未被真实地址覆盖，实际: {refreshed}");
                }
                tokio::time::sleep(std::time::Duration::from_millis(100)).await;
            }
            b.stop_receiver().await.unwrap();
            (b, store_b)
        });
        pair_with_confirmer(&a, &store_a, &code, target_b).await;
        a.push_to_peer(&b_id, b_ips).await.unwrap();
        let (_b, store_b) = b_handle.await.unwrap();
        let ips = store_b.paired_device_ips(&a_id).unwrap().join(",");
        assert!(
            !ips.contains("10.9.9.9:9999"),
            "推送后 last_ips 应被真实地址覆盖，实际: {ips}"
        );
        assert!(
            ips.contains(':') && !ips.is_empty(),
            "推送后 last_ips 应含真实 ip:port，实际: {ips}"
        );
    });
}
