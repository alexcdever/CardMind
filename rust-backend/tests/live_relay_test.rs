// 实机验证：两个持久化 SyncService 经真实 dogcloud relay（relay.alexc.cn:9443）
// 完成 配对 → 首次全量同步 → 编辑推送 全链路。
// 发起方 target.ips 为空 → 必须凭 node_id 经 relay 中转连接（同机也无法直连短路）。
// 手动运行：cargo test --test live_relay_test -- --ignored --nocapture
use cardmind_backend::store::NoteStore;
use cardmind_backend::sync::{PairingTarget, SyncService};
use std::fs;
use std::path::PathBuf;
use std::time::Duration;

const RELAY_URL: &str = "https://relay.alexc.cn:9443";

fn temp_dir(label: &str) -> PathBuf {
    let path = std::env::temp_dir().join(format!(
        "cardmind-live-relay-{label}-{}",
        std::process::id()
    ));
    let _ = fs::remove_dir_all(&path);
    fs::create_dir_all(&path).unwrap();
    // 两端数据目录都放 relay.txt（任务 K 的配置约定）
    fs::write(path.join("relay.txt"), RELAY_URL).unwrap();
    path
}

#[test]
#[ignore] // 需要公网 + relay 服务，手动运行
fn live_pairing_and_sync_over_dogcloud_relay() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let dir_a = temp_dir("confirmer");
        let dir_b = temp_dir("initiator");

        let mut confirmer = SyncService::new_persistent(&dir_a).await.unwrap();
        confirmer.set_device_name("Trusted PC");
        confirmer
            .create_note("n1".to_string(), "# From trusted\\n\\nbody one")
            .unwrap();

        let initiator = SyncService::new_persistent(&dir_b).await.unwrap();
        initiator.set_device_name("New Phone");

        println!("[live] confirmer id: {}", confirmer.device_id());
        println!("[live] initiator id: {}", initiator.device_id());

        let confirmer_store = NoteStore::new(":memory:").unwrap();
        let initiator_store = NoteStore::new(":memory:").unwrap();

        // 确认方显示码（mDNS 广播在单机下无对端，无碍——relay 路径不依赖它）
        let code = confirmer.begin_pairing_accept().unwrap();
        println!("[live] pairing code: {code}");

        // 发起方目标：仅 node_id，无直连 IP → 必须经 relay
        let target = PairingTarget {
            device_id: confirmer.device_id(),
            ips: vec![],
        };

        // 确认方：接收请求 + 确认（内部自动推送首次全量快照）
        let confirmer_code = code.clone();
        let confirmer_handle = tokio::spawn(async move {
            let request = confirmer.accept_pairing_request().await.unwrap();
            let result = confirmer
                .confirm_pairing(&confirmer_store, &confirmer_code, &request)
                .await
                .unwrap();
            (confirmer, confirmer_store, request, result)
        });

        // 发起方：relay 连接 + 配对请求 + 握手响应 + drain 自动推送
        let initiator_handle = tokio::spawn(async move {
            let result = tokio::time::timeout(
                Duration::from_secs(90),
                initiator.begin_pairing_connect(&initiator_store, &code, target),
            )
            .await
            .expect("[live] relay 连接超时（90s）")
            .unwrap();
            let _ = initiator.accept_push().await; // drain 首次全量快照
            (initiator, initiator_store, result)
        });

        let (confirmer, confirmer_store, _request, confirm_result) =
            confirmer_handle.await.unwrap();
        let (initiator, initiator_store, connect_result) = initiator_handle.await.unwrap();

        println!(
            "[live] paired: {} <-> {}",
            connect_result.peer_id, confirm_result.peer_id
        );

        // 双方持久化对端
        assert!(
            confirmer_store
                .list_paired_devices()
                .unwrap()
                .iter()
                .any(|d| d.peer_id == initiator.device_id() && d.name == "New Phone"),
            "确认方应持久化发起方"
        );
        assert!(
            initiator_store
                .list_paired_devices()
                .unwrap()
                .iter()
                .any(|d| d.peer_id == confirmer.device_id() && d.name == "Trusted PC"),
            "发起方应持久化确认方"
        );

        // 首次全量同步：发起方收到确认方的笔记（经 relay 推送 + import）
        sync_notes(&initiator, &initiator_store);
        let notes = initiator_store.list_notes().unwrap();
        assert!(
            notes.iter().any(|r| r.id == "n1"),
            "发起方应收到首次全量同步的笔记 n1（实际: {:?}）",
            notes.iter().map(|r| r.id.clone()).collect::<Vec<_>>()
        );

        println!("[live] ✅ 配对 + 首次同步经 dogcloud relay 全链路成功");
        drop((confirmer, initiator));
    });
}

fn sync_notes(svc: &SyncService, store: &NoteStore) {
    // 复用 api.rs 的投影同步（测试内直接调）
    cardmind_backend::api::sync_notes_to_store(svc, store).unwrap();
}
