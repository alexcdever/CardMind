//! 集成测试共享辅助（temp 目录 / tokio runtime / 配对请求构造 / 真实配对）。
//!
//! 并非每个测试文件都用全部 helper，未使用的标 `#[allow(dead_code)]`。

use cardmind_backend::store::NoteStore;
use cardmind_backend::sync::{PairingRequest, PairingTarget, SyncService};

/// 每次调用返回全新空目录：`{tmp}/cardmind-{label}-{pid}`，已存在则先清空。
#[allow(dead_code)]
pub fn temp_dir(label: &str) -> std::path::PathBuf {
    let path = std::env::temp_dir().join(format!("cardmind-{label}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&path);
    std::fs::create_dir_all(&path).unwrap();
    path
}

/// 新建多线程 tokio runtime（测试同步入口）。
#[allow(dead_code)]
pub fn rt() -> tokio::runtime::Runtime {
    tokio::runtime::Runtime::new().unwrap()
}

/// 构造一个发起方请求（测试用）。nonce 必须与会话 nonce 一致
/// （confirm 侧强制校验：空/全零/不匹配均拒绝）。
#[allow(dead_code)]
pub fn requester(code: &str, id: &str, name: &str, nonce: &str) -> PairingRequest {
    PairingRequest {
        code: code.to_string(),
        device_id: id.to_string(),
        device_name: name.to_string(),
        relay_info: String::new(),
        // 指向关闭端口：无真实握手（无 pending 连接）时 confirm 不触发推送
        ips: vec!["127.0.0.1:1".to_string()],
        nonce: nonce.to_string(),
    }
}

/// 无 IPv4 网络接口的环境前置检查：addrs 为空时 eprintln 留痕并返回 false，
/// 调用方应 `return` 让用例静默 skip（通过而非 panic），区分「环境不具备」与「代码错」。
#[allow(dead_code)]
pub fn require_ipv4(addrs: &[String]) -> bool {
    if addrs.is_empty() {
        eprintln!("SKIP: no IPv4 addresses on this machine; test requires network interface");
        return false;
    }
    true
}

/// 真实配对两个 SyncService（initiator ↔ confirmer），双方 paired_devices 互相包含。
///
/// 网络路径：initiator 经 confirmer.local_addrs() 直连（同网段场景）；配对成功后
/// confirm 方自动推送全量快照（决策 8），由 initiator accept 并丢弃。
/// 配对成功后两实例的 `peer_ips` 缓存均填充对端直连 IP（供后续 push 使用）。
#[allow(dead_code)]
pub async fn pair_up(
    initiator: SyncService,
    initiator_store: NoteStore,
    mut confirmer: SyncService,
    confirmer_store: NoteStore,
) -> (SyncService, NoteStore, SyncService, NoteStore) {
    let code = confirmer.begin_pairing_accept().unwrap();
    let target = PairingTarget {
        device_id: confirmer.device_id(),
        ips: confirmer.local_addrs(),
        nonce: confirmer.session_nonce_hex(),
    };
    assert!(
        !target.ips.is_empty(),
        "SKIP: no IPv4 addresses on this machine; test requires network interface"
    );

    let confirmer_code = code.clone();
    let confirmer_handle = tokio::spawn(async move {
        let request = confirmer
            .accept_pairing_request()
            .await
            .expect("confirmer accept pairing request");
        let result = confirmer
            .confirm_pairing(&confirmer_store, &confirmer_code, &request)
            .await
            .expect("confirmer confirm pairing");
        (confirmer, confirmer_store, result)
    });

    let initiator_handle = tokio::spawn(async move {
        let result = initiator
            .begin_pairing_connect(&initiator_store, &code, target)
            .await
            .expect("initiator connect pairing");
        // drain 确认方首次全量同步推送（决策 8）
        let _ = initiator.accept_push().await;
        (initiator, initiator_store, result)
    });

    let (confirmer, confirmer_store, confirm_result) = confirmer_handle.await.unwrap();
    let (initiator, initiator_store, connect_result) = initiator_handle.await.unwrap();
    assert_eq!(confirm_result.peer_id, initiator.device_id());
    assert_eq!(connect_result.peer_id, confirmer.device_id());

    (initiator, initiator_store, confirmer, confirmer_store)
}
