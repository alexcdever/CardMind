// 实机验证：两个持久化 SyncService 经真实 dogcloud relay
// （旧 :9443 回滚链路 + 标准 443 签名凭证链路）完成 配对 → 首次全量同步 全链路。
// 发起方 target.ips 为空 → 必须凭 node_id 经 relay 中转连接（同机也无法直连短路）。
// 手动运行：cargo test --test live_relay_test -- --ignored --nocapture
use std::fs;
use std::path::PathBuf;
use std::sync::Arc;
use std::time::Duration;

use cardmind_backend::debug_log::{redact_device_id, CollectingSink};
use cardmind_backend::store::NoteStore;
use cardmind_backend::sync::{nonce_to_hex, PairingTarget, SyncService};

/// 旧回滚 relay（:9443，仅作历史链路保留；不得作为标准 443 验收证据）。
const RELAY_URL: &str = "https://relay.alexc.cn:9443";
/// 标准 443 relay：relay.alexc.cn DNS-only 直连 206.237.16.164:443，
/// nginx 443 → 127.0.0.1:8087 → 容器 iroh-relay-nginx（8087->3340）。
const RELAY_URL_443: &str = "https://relay.alexc.cn";

fn temp_dir_relay(label: &str, relay_url: &str) -> PathBuf {
    let path = std::env::temp_dir().join(format!(
        "cardmind-live-relay-{label}-{}",
        std::process::id()
    ));
    let _ = fs::remove_dir_all(&path);
    fs::create_dir_all(&path).unwrap();
    // 两端数据目录都放 relay.txt（任务 K 的配置约定）
    fs::write(path.join("relay.txt"), relay_url).unwrap();
    path
}

fn temp_dir(label: &str) -> PathBuf {
    temp_dir_relay(label, RELAY_URL)
}

/// 人工 test stdout 只允许脱敏 device id 与掩码配对码（不得打印完整 id / 码）。
fn masked_device_id(id: &str) -> String {
    redact_device_id(id)
}

fn masked_code(code: &str) -> String {
    if code.len() <= 4 {
        return "*".repeat(code.len());
    }
    format!("{}…{}", &code[..2], &code[code.len() - 2..])
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

        let mut initiator = SyncService::new_persistent(&dir_b).await.unwrap();
        initiator.set_device_name("New Phone");

        println!(
            "[live] confirmer id: {}",
            masked_device_id(&confirmer.device_id())
        );
        println!(
            "[live] initiator id: {}",
            masked_device_id(&initiator.device_id())
        );

        let confirmer_store = NoteStore::new(":memory:").unwrap();
        let initiator_store = NoteStore::new(":memory:").unwrap();

        // 确认方显示码（mDNS 广播在单机下无对端，无碍——relay 路径不依赖它）
        let code = confirmer.begin_pairing_accept().unwrap();
        println!("[live] pairing code: {}", masked_code(&code));

        // 发起方目标：仅 node_id，无直连 IP → 必须经 relay
        let target = PairingTarget {
            device_id: confirmer.device_id(),
            ips: vec![],
            nonce: confirmer.session_nonce_hex(),
        };

        // 确认方：接收请求 + 确认（内部自动推送首次全量快照）
        // 超时保护：发起方失败/退出后 accept_pairing_request 的 accept 循环无对端可接，
        // 无全局超时会无限等待 → Runtime drop 阻塞 → 测试进程挂死。120s 超时 panic 输出诊断。
        let confirmer_code = code.clone();
        let confirmer_handle = tokio::spawn(async move {
            let outcome = tokio::time::timeout(Duration::from_secs(120), async {
                let request = confirmer.accept_pairing_request().await.unwrap();
                let result = confirmer
                    .confirm_pairing(&confirmer_store, &confirmer_code, &request)
                    .await
                    .unwrap();
                (confirmer, confirmer_store, request, result)
            })
            .await;
            match outcome {
                Ok(v) => v,
                Err(_) => panic!(
                    "[live] confirmer accept+confirm 超时（120s）：发起方可能已失败退出，\
                     accept 循环无对端可接（检查发起方连接错误输出）"
                ),
            }
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
            // drain 首次全量快照：accept_push 只返回原始数据，必须 import_all 导入，
            // 否则 initiator 内存态 notes 为空、后续断言失败（此前 DNS 失败走不到这步，
            // 该 bug 未暴露；relay 修复后暴露，一并修）。
            let pushed = initiator
                .accept_push()
                .await
                .expect("[live] drain 首次全量快照失败");
            initiator
                .import_all(&pushed)
                .expect("[live] import 首次全量快照失败");
            (initiator, initiator_store, result)
        });

        let (confirmer, confirmer_store, _request, confirm_result) =
            confirmer_handle.await.unwrap();
        let (initiator, initiator_store, connect_result) = initiator_handle.await.unwrap();

        println!(
            "[live] paired: {} <-> {}",
            masked_device_id(&connect_result.peer_id),
            masked_device_id(&confirm_result.peer_id)
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

        // 清理临时数据目录（正常路径；失败时保留便于诊断）
        let _ = fs::remove_dir_all(&dir_a);
        let _ = fs::remove_dir_all(&dir_b);
    });
}

/// 任务 T2 必做 1：标准 443 relay + 签名凭证 live test。
///
/// 与旧 :9443 测试并存（旧测试仅保留作回滚证据，本测试才是标准 443 验收）。
/// 链路：confirmer 生成签名凭证（begin_pairing_credential，不依赖 mDNS）→
/// initiator 只拿凭证字符串（begin_pairing_connect_with_credential，不输入
/// node id、不调 mDNS，target.ips=[] 由凭证内嵌 endpoint 经 relay 解析）→
/// accept_pairing_request + confirm_pairing → 首次全量 push → accept_push +
/// import_all → 双方配对记录 + last_seen → n1 到达 initiator 读模型。
///
/// 结构化日志（CollectingSink）证明 pairing.connect transport=relay，并断言
/// 产品日志不含完整凭证 / 配对码 / 完整 device id / 笔记正文（脱敏）。
///
/// 手动运行：
/// ```bash
/// timeout 3m cargo test --test live_relay_test live_signed_credential_pairing_over_standard_443_relay -- --ignored --nocapture
/// ```
#[test]
#[ignore] // 需要公网 + 标准 443 relay 服务，手动运行
fn live_signed_credential_pairing_over_standard_443_relay() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let dir_a = temp_dir_relay("confirmer443", RELAY_URL_443);
        let dir_b = temp_dir_relay("initiator443", RELAY_URL_443);

        // 两侧注入收集 sink：断言结构化日志 transport=relay + 脱敏
        let confirmer_sink = Arc::new(CollectingSink::new());
        let initiator_sink = Arc::new(CollectingSink::new());

        let mut confirmer =
            SyncService::new_persistent_with_log_sink(&dir_a, confirmer_sink.clone())
                .await
                .unwrap();
        confirmer.set_device_name("Trusted PC");
        confirmer
            .create_note("n1".to_string(), "# From trusted\n\nbody one")
            .unwrap();

        let mut initiator =
            SyncService::new_persistent_with_log_sink(&dir_b, initiator_sink.clone())
                .await
                .unwrap();
        initiator.set_device_name("New Phone");

        // 两端 relay 配置必须严格为标准 443 URL（字符串不得带 :9443）
        for (label, svc) in [("confirmer", &confirmer), ("initiator", &initiator)] {
            let urls: Vec<String> = svc
                .relay_mode()
                .relay_map()
                .urls::<Vec<iroh::RelayUrl>>()
                .into_iter()
                .map(|u| u.to_string())
                .collect();
            assert_eq!(
                urls.len(),
                1,
                "{label} 应恰好配置 1 个 relay，实际 {urls:?}"
            );
            let url = &urls[0];
            assert!(
                url.starts_with("https://relay.alexc.cn"),
                "{label} relay 必须是标准 443 URL，实际 {url}"
            );
            assert!(
                !url.contains(":9443"),
                "{label} relay 不得为旧 :9443 回滚地址，实际 {url}"
            );
            println!("[live443] {label} relay={url}");
        }

        let confirmer_store = NoteStore::new(":memory:").unwrap();
        let initiator_store = NoteStore::new(":memory:").unwrap();

        // 确认方生成签名凭证（无广播调用 → 不依赖 mDNS）
        let display = confirmer.begin_pairing_credential().unwrap();
        assert!(
            display.credential.starts_with("cm1."),
            "凭证必须以 cm1. 开头"
        );
        println!(
            "[live443] confirmer id: {}",
            masked_device_id(&confirmer.device_id())
        );
        println!(
            "[live443] credential len={} code={} expires_at={}",
            display.credential.len(),
            masked_code(&display.code),
            display.expires_at
        );

        // 凭证对应的会话 = 当前 PairingSession（code + nonce 一致，对照
        // pairing_credential_test.rs 的会话校验逻辑）
        let session = confirmer
            .current_pairing_session()
            .expect("begin_pairing_credential 后会话必须存在");
        assert_eq!(session.code, display.code, "会话 code 必须等于凭证 code");
        assert_eq!(
            nonce_to_hex(&session.nonce),
            confirmer.session_nonce_hex(),
            "会话 nonce hex 必须可读"
        );

        let confirmer_code = display.code.clone();
        let confirmer_handle = tokio::spawn(async move {
            let outcome = tokio::time::timeout(Duration::from_secs(120), async {
                let request = confirmer.accept_pairing_request().await.unwrap();
                // confirm 前校验请求携带的 code/nonce 与当前凭证会话一致
                // （confirm_pairing 内部强制校验并清除会话，故在 confirm 前断言）
                let session = confirmer
                    .current_pairing_session()
                    .expect("accept 返回后、confirm 前会话必须仍存在");
                assert_eq!(
                    request.code, confirmer_code,
                    "请求 code 必须与凭证 code 一致（实际: {}）",
                    request.code
                );
                assert_eq!(
                    request.nonce,
                    nonce_to_hex(&session.nonce),
                    "请求 nonce 必须与凭证会话 nonce 一致"
                );
                let result = confirmer
                    .confirm_pairing(&confirmer_store, &confirmer_code, &request)
                    .await
                    .unwrap();
                (confirmer, confirmer_store, request, result)
            })
            .await;
            match outcome {
                Ok(v) => v,
                Err(_) => panic!(
                    "[live443] confirmer accept+confirm 超时（120s）：发起方可能已失败退出，\
                     accept 循环无对端可接（检查发起方连接错误输出）"
                ),
            }
        });

        // 发起方：只拿凭证字符串，经标准 443 relay 连接 + 配对 + drain 首次全量快照
        let credential = display.credential.clone();
        let initiator_handle = tokio::spawn(async move {
            let outcome = tokio::time::timeout(Duration::from_secs(90), async {
                let result = initiator
                    .begin_pairing_connect_with_credential(&initiator_store, &credential)
                    .await
                    .unwrap();
                // drain 首次全量快照：accept_push 只返回原始数据，必须 import_all 导入
                let pushed = initiator
                    .accept_push()
                    .await
                    .expect("[live443] drain 首次全量快照失败");
                initiator
                    .import_all(&pushed)
                    .expect("[live443] import 首次全量快照失败");
                (initiator, initiator_store, result)
            })
            .await;
            match outcome {
                Ok(v) => v,
                Err(_) => panic!(
                    "[live443] initiator 凭证连接超时（90s）：标准 443 relay 不可达，\
                     或确认方未注册（检查 relay.alexc.cn:443 可达性）"
                ),
            }
        });

        // spawn 出的 task 两侧都包 timeout：join 侧同样兜底，防单侧挂死拖死进程
        let (confirmer, confirmer_store, request, confirm_result) =
            tokio::time::timeout(Duration::from_secs(150), confirmer_handle)
                .await
                .expect("[live443] confirmer task 挂起（150s）")
                .unwrap();
        let (initiator, initiator_store, connect_result) =
            tokio::time::timeout(Duration::from_secs(120), initiator_handle)
                .await
                .expect("[live443] initiator task 挂起（120s）")
                .unwrap();

        println!(
            "[live443] paired: {} <-> {}",
            masked_device_id(&connect_result.peer_id),
            masked_device_id(&confirm_result.peer_id)
        );

        // 配对握手身份一致：confirm 方收到的发起方 = initiator；connect 方收到的确认方 = confirmer
        assert_eq!(connect_result.peer_id, confirmer.device_id());
        assert_eq!(confirm_result.peer_id, initiator.device_id());
        assert_eq!(request.device_id, initiator.device_id());

        // 双方持久化对端
        let confirmer_devices = confirmer_store.list_paired_devices().unwrap();
        let initiator_devices = initiator_store.list_paired_devices().unwrap();
        let c_row = confirmer_devices
            .iter()
            .find(|d| d.peer_id == initiator.device_id())
            .expect("确认方应持久化发起方");
        let i_row = initiator_devices
            .iter()
            .find(|d| d.peer_id == confirmer.device_id())
            .expect("发起方应持久化确认方");
        assert_eq!(c_row.name, "New Phone");
        assert_eq!(i_row.name, "Trusted PC");

        // 双方 last_seen 非空且在合理时间窗（对比现网时间，容差 10 分钟内）
        let now = chrono::Utc::now();
        for (label, row) in [("confirmer", &c_row), ("initiator", &i_row)] {
            let last_seen = row
                .last_seen
                .as_deref()
                .unwrap_or_else(|| panic!("{label} last_seen 必须非空"));
            let ts = chrono::DateTime::parse_from_rfc3339(last_seen)
                .expect("last_seen 必须是 RFC3339")
                .with_timezone(&chrono::Utc);
            let age = (now - ts).num_seconds();
            assert!(
                (0..=600).contains(&age),
                "{label} last_seen 应在合理时间窗（0-600s），实际 age={age}s last_seen={last_seen}"
            );
            println!("[live443] {label} last_seen={last_seen} (age={age}s)");
        }

        // 首次全量同步：n1 到达 initiator 读模型
        sync_notes(&initiator, &initiator_store);
        let notes = initiator_store.list_notes().unwrap();
        assert!(
            notes.iter().any(|r| r.id == "n1"),
            "发起方应收到首次全量同步的笔记 n1（实际: {:?}）",
            notes.iter().map(|r| r.id.clone()).collect::<Vec<_>>()
        );

        // 结构化日志证据：pairing.connect transport=relay（start + success 两条）
        let initiator_events = initiator_sink.snapshot();
        let connect_events: Vec<_> = initiator_events
            .iter()
            .filter(|e| e.event == "pairing.connect")
            .collect();
        assert!(
            !connect_events.is_empty(),
            "发起方必须产生 pairing.connect 事件"
        );
        for ev in &connect_events {
            let action = ev
                .fields
                .iter()
                .find(|(k, _)| k == "action")
                .map(|(_, v)| v.as_str())
                .unwrap_or_default();
            let transport = ev
                .fields
                .iter()
                .find(|(k, _)| k == "transport")
                .map(|(_, v)| v.as_str())
                .unwrap_or_default();
            println!("[live443] log pairing.connect action={action} transport={transport}");
            if action == "start" || action == "success" {
                assert_eq!(
                    transport, "relay",
                    "凭证路径（target.ips=[] + relay.txt 标准 443）必须走 relay；事件: {ev:?}"
                );
            }
        }
        assert!(
            connect_events.iter().any(|e| e
                .fields
                .iter()
                .any(|(k, v)| k == "action" && v == "success")),
            "必须存在 pairing.connect action=success"
        );

        // 产品结构化日志脱敏：不得含完整凭证 / 凭证 body / 配对码 / 完整 device id / 笔记正文
        for (label, sink) in [
            ("confirmer", &confirmer_sink),
            ("initiator", &initiator_sink),
        ] {
            let text = sink
                .snapshot()
                .iter()
                .map(|e| format!("{e:?}"))
                .collect::<Vec<_>>()
                .join("\n");
            assert!(
                !text.contains(&display.credential),
                "{label} 日志不得含完整凭证"
            );
            assert!(
                !text.contains(&display.credential[4..]),
                "{label} 日志不得含凭证 body（base64url）"
            );
            assert!(!text.contains(&display.code), "{label} 日志不得含配对码");
            assert!(
                !text.contains(&confirmer.device_id()),
                "{label} 日志不得含完整 confirmer device id"
            );
            assert!(
                !text.contains(&initiator.device_id()),
                "{label} 日志不得含完整 initiator device id"
            );
            assert!(!text.contains("body one"), "{label} 日志不得含笔记正文");
        }

        println!("[live443] ✅ 标准 443 relay 签名凭证配对 + 首次同步全链路成功");
        drop((confirmer, initiator));

        // 清理临时数据目录（正常路径；失败时保留便于诊断）
        let _ = fs::remove_dir_all(&dir_a);
        let _ = fs::remove_dir_all(&dir_b);
    });
}

fn sync_notes(svc: &SyncService, store: &NoteStore) {
    // 复用 api.rs 的投影同步（测试内直接调）
    cardmind_backend::api::sync_notes_to_store(svc, store).unwrap();
}
