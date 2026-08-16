//! debug-log 任务验收测试（Rust 侧）。
//!
//! 验收标准映射：
//! 1. debug logger redacts device ids —— 完整 id 只输出脱敏形式；SecretKey/API key/
//!    配对码/笔记正文不进入事件（test_redact_device_id + test_events_never_contain_sensitive_data）
//! 2. startup emits initialization events —— 构造成功发出 startup 事件
//!    （test_startup_emits_init_and_relay_events + test_startup_failure_emits_event）
//! 3. relay config emits safe endpoint event —— host/port/enabled，不含凭据/完整 URL
//!    （test_startup_emits_init_and_relay_events + test_relay_config_strips_credentials）
//! 5. mdns discovery emits count and duration —— 发现数量与耗时（test_mdns_discovery_emits_count_and_duration）
//! 6. pairing accept lifecycle emits all stages —— 显示码/accept/request/confirm 完整
//!    （test_pairing_accept_lifecycle_emits_all_stages）
//! 7. relay connection emits transport and error chain —— direct/relay 区分 + 错误链 + 耗时
//!    （test_connect_emits_transport_and_error_chain）
//! 8. initial sync emits counts only —— 数量/方向/耗时，无正文（test_initial_sync_emits_counts_only）
//! 9. logger failure does not break flow —— sink 抛异常时主流程仍完成
//!    （test_logger_failure_does_not_break_flow）

use std::sync::Arc;

use cardmind_backend::api;
use cardmind_backend::debug_log::{self, CollectingSink, LogEvent, PanickingSink};
use cardmind_backend::store::NoteStore;
use cardmind_backend::sync::{PairingTarget, SyncService};

fn rt() -> tokio::runtime::Runtime {
    tokio::runtime::Runtime::new().unwrap()
}

fn temp_dir(label: &str) -> std::path::PathBuf {
    let path =
        std::env::temp_dir().join(format!("cardmind-dbglog-{label}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&path);
    std::fs::create_dir_all(&path).unwrap();
    path
}

fn sink() -> Arc<CollectingSink> {
    Arc::new(CollectingSink::new())
}

/// 事件字段取值辅助：`relay.enabled` → Some("true")。
fn field<'a>(event: &'a LogEvent, key: &str) -> Option<&'a str> {
    event
        .fields
        .iter()
        .find(|(k, _): &&(String, String)| k == key)
        .map(|(_, v): &(String, String)| v.as_str())
}

/// 事件文本（Debug 序列化，模拟日志输出）。
fn event_text(events: &[LogEvent]) -> String {
    events.iter().map(|e| format!("{e:?}")).collect::<Vec<_>>().join("\n")
}

// ━━━ 验收 1a：脱敏函数 ━━━

#[test]
fn test_redact_device_id() {
    // 短 id（≤16 字符）原样返回
    assert_eq!(debug_log::redact_device_id("short-id"), "short-id");
    assert_eq!(debug_log::redact_device_id("1234567890123456"), "1234567890123456");
    // 长 id：只保留前 8 + 后 8
    let full = "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGH"; // 36 chars
    let red = debug_log::redact_device_id(full);
    assert_eq!(red, "abcdefgh…ABCDEFGH");
    assert!(
        !red.contains("ijklmnopqrstuvwxyz0123456789"),
        "脱敏后不应包含中间部分: {red}"
    );
    assert!(
        !red.contains(full),
        "脱敏后不应包含完整 id: {red}"
    );
}

// ━━━ 验收 1b：事件中绝不出现敏感数据 ━━━

#[test]
fn test_events_never_contain_sensitive_data() {
    rt().block_on(async {
        let dir = temp_dir("redact");
        let sink = sink();
        let mut svc = SyncService::new_persistent_with_log_sink(&dir, sink.clone())
            .await
            .unwrap();
        let device_id = svc.device_id();
        let secret_key_hex = std::fs::read_to_string(dir.join("device.key")).unwrap();

        // 触发各事件路径：建笔记 → export/import → 生成配对码 → 无设备 push
        svc.create_note("n1".into(), "TOP-SECRET-NOTE-BODY-CONTENT").unwrap();
        svc.create_note("n2".into(), "ANOTHER-PRIVATE-BODY").unwrap();
        let code = svc.begin_pairing_accept().unwrap();
        let store = NoteStore::new(":memory:").unwrap();
        let _ = svc.push_pending(&store).await; // 无配对设备 → skipped 事件
        let data = svc.export_all().unwrap();
        svc.import_all(&data).unwrap();

        let events = sink.snapshot();
        assert!(!events.is_empty(), "应至少捕获若干事件");
        let text = event_text(&events);

        assert!(
            !text.contains(&device_id),
            "完整 device id 不得出现在事件中（脱敏后只能有 {device_id} 的 8+8 形式）"
        );
        assert!(!text.contains(&secret_key_hex), "SecretKey hex 不得出现在事件中");
        assert!(
            !text.contains("TOP-SECRET-NOTE-BODY-CONTENT")
                && !text.contains("ANOTHER-PRIVATE-BODY"),
            "笔记正文不得出现在事件中"
        );
        assert!(
            !text.contains("api_key") && !text.contains("apikey"),
            "API key 字段不得出现在事件中"
        );
        // 配对码：不出现在任何字段值中（6 位数字可能巧合出现在时间戳，故只查字段值）
        assert!(
            events
                .iter()
                .all(|e| !e.fields.iter().any(|(_, v)| v == &code)
                    && !e.device_ids.iter().any(|d| d == &code)
                    && !e.fields.iter().any(|(k, _)| k == "code")),
            "配对码不得出现在事件字段中"
        );

        // 脱敏形式应出现（证明 device id 以脱敏形式被记录）
        let red = debug_log::redact_device_id(&device_id);
        assert!(text.contains(&red), "事件中应含脱敏 device id（{red}）");

        let _ = std::fs::remove_dir_all(dir);
    });
}

// ━━━ 验收 2/3：启动事件 + relay 配置事件（含凭据剥离）━━━

#[test]
fn test_startup_emits_init_and_relay_events() {
    rt().block_on(async {
        let dir = temp_dir("startup");
        std::fs::write(
            dir.join("relay.txt"),
            "https://user:secret@relay.example.com:9443/path?token=abc",
        )
        .unwrap();
        let sink = sink();
        let svc = SyncService::new_persistent_with_log_sink(&dir, sink.clone())
            .await
            .unwrap();
        let events = sink.snapshot();

        // 启动成功事件
        let startup = events
            .iter()
            .find(|e| e.event == "startup.sync_service")
            .expect("应发出 startup.sync_service 事件");
        assert_eq!(startup.stage, "sync.init");
        assert_eq!(
            startup.device_ids,
            vec![debug_log::redact_device_id(&svc.device_id())],
            "启动事件应携带脱敏本机 device id"
        );

        // relay 配置事件：enabled/host/port 安全输出
        let relay = events
            .iter()
            .find(|e| e.event == "relay.config")
            .expect("应发出 relay.config 事件");
        assert_eq!(field(relay, "enabled"), Some("true"));
        assert_eq!(field(relay, "relay_host"), Some("relay.example.com"));
        assert_eq!(field(relay, "relay_port"), Some("9443"));

        let text = format!("{relay:?}");
        assert!(
            !text.contains("user") && !text.contains("secret"),
            "relay 配置事件不得含 URL 凭据（user/password）"
        );
        assert!(
            !text.contains("token=abc") && !text.contains("https://"),
            "relay 配置事件不得含 token 或完整 URL"
        );

        let _ = std::fs::remove_dir_all(dir);
    });
}

/// 未配置 relay → enabled=false，无 host/port 字段。
#[test]
fn test_relay_config_event_disabled_case() {
    rt().block_on(async {
        let dir = temp_dir("no-relay");
        let sink = sink();
        let _svc = SyncService::new_persistent_with_log_sink(&dir, sink.clone())
            .await
            .unwrap();
        let relay = sink
            .snapshot()
            .into_iter()
            .find(|e| e.event == "relay.config")
            .expect("应发出 relay.config 事件");
        assert_eq!(field(&relay, "enabled"), Some("false"));
        assert!(field(&relay, "relay_host").is_none(), "禁用时不应有 relay_host");
        assert!(field(&relay, "relay_port").is_none(), "禁用时不应有 relay_port");
        let _ = std::fs::remove_dir_all(dir);
    });
}

/// 启动失败（无效 relay URL）也应发出失败事件（全局兜底 sink）。
#[test]
fn test_startup_failure_emits_event() {
    rt().block_on(async {
        let dir = temp_dir("bad-relay");
        std::fs::write(dir.join("relay.txt"), "not-a-url").unwrap();
        let global_sink = sink();
        debug_log::set_global_sink(Some(global_sink.clone()));
        let result = api::create_persistent_sync_service(dir.to_string_lossy().into()).await;
        debug_log::set_global_sink(None);
        assert!(result.is_err(), "无效 relay URL 应构造失败");
        let failed = global_sink
            .snapshot()
            .into_iter()
            .find(|e| e.event == "startup.sync_service" && field(e, "action") == Some("failed"))
            .expect("启动失败应发出 startup.sync_service failed 事件");
        assert!(failed.error_chain.is_some(), "失败事件应携带错误链");
        let _ = std::fs::remove_dir_all(dir);
    });
}

// ━━━ 验收 5：mDNS 发现数量与耗时 ━━━

#[test]
fn test_mdns_discovery_emits_count_and_duration() {
    rt().block_on(async {
        let dir = temp_dir("mdns");
        let sink = sink();
        let svc = SyncService::new_persistent_with_log_sink(&dir, sink.clone())
            .await
            .unwrap();
        // 真实 mDNS 扫描（约 3 秒窗口；本机无对端 → 空结果也属验收场景）
        let peers = tokio::time::timeout(std::time::Duration::from_secs(10), svc.discover_peers())
            .await
            .expect("discover_peers 应在 10s 内完成")
            .unwrap();
        let events = sink.snapshot();

        let start = events
            .iter()
            .find(|e| e.event == "discovery.mdns" && field(e, "action") == Some("start"))
            .expect("应发出 discovery start 事件");
        assert_eq!(start.stage, "discovery.mdns");

        let result = events
            .iter()
            .find(|e| e.event == "discovery.mdns" && field(e, "action") == Some("result"))
            .expect("应发出 discovery result 事件");
        assert_eq!(
            field(result, "count"),
            Some(peers.len().to_string().as_str()),
            "result 事件应记录发现数量"
        );
        assert!(
            result.duration_ms.is_some(),
            "result 事件应记录发现耗时"
        );
        let _ = std::fs::remove_dir_all(dir);
    });
}

// ━━━ 验收 6：配对 accept 生命周期事件完整 ━━━

#[test]
fn test_pairing_accept_lifecycle_emits_all_stages() {
    rt().block_on(async {
        let dir_a = temp_dir("life-a");
        let dir_b = temp_dir("life-b");
        let sink_a = sink();
        let sink_b = sink();
        let mut confirmer =
            SyncService::new_persistent_with_log_sink(&dir_a, sink_a.clone())
                .await
                .unwrap();
        let requester = SyncService::new_persistent_with_log_sink(&dir_b, sink_b.clone())
            .await
            .unwrap();
        let store_a = NoteStore::new(":memory:").unwrap();
        let store_b = NoteStore::new(":memory:").unwrap();

        let confirmer_id = confirmer.device_id();
        let addrs = confirmer.local_addrs();
        assert!(!addrs.is_empty(), "确认方应至少有一个本地 IPv4 地址");

        // 显示码 + 广播（组合 API）
        let code = confirmer
            .begin_pairing_accept_with_advertising()
            .await
            .unwrap();

        // 确认方：有界接收 + 确认（spawn 两侧都用 timeout 兜底）
        let confirmer_code = code.clone();
        let confirmer_handle = tokio::spawn(async move {
            let request = tokio::time::timeout(
                std::time::Duration::from_secs(20),
                confirmer.accept_pairing_request_with_timeout(std::time::Duration::from_secs(20)),
            )
            .await
            .expect("accept 应在 20s 内返回")
            .unwrap()
            .expect("应收到配对请求");
            let result = tokio::time::timeout(
                std::time::Duration::from_secs(30),
                confirmer.confirm_pairing(&store_a, &confirmer_code, &request),
            )
            .await
            .expect("confirm 应在 30s 内返回")
            .unwrap();
            (result.peer_id, request.device_id.clone())
        });

        // 发起方：连接 + 接收握手响应；随后 drain 确认方自动推送的首次全量快照
        //（与 pairing_test.rs 同模式——否则确认方 push 等待 conn.closed 直至超时）
        let requester_target_id = confirmer_id.clone();
        let requester_handle = tokio::spawn(async move {
            let result = tokio::time::timeout(
                std::time::Duration::from_secs(20),
                requester.begin_pairing_connect(
                    &store_b,
                    &code,
                    PairingTarget {
                        device_id: requester_target_id,
                        ips: addrs,
                    },
                ),
            )
            .await
            .expect("connect 应在 20s 内返回")
            .unwrap();
            let _ = tokio::time::timeout(
                std::time::Duration::from_secs(15),
                requester.accept_push(),
            )
            .await;
            result
        });

        let (_confirm_peer, request_id) = confirmer_handle.await.unwrap();
        let requester_result = requester_handle.await.unwrap();
        assert_eq!(requester_result.peer_id, confirmer_id);

        // ━━ 确认方事件断言（生命周期完整）━━
        let events_a = sink_a.snapshot();
        let text_a = event_text(&events_a);
        for expected in [
            "pairing.show_code",       // 显示码：开始 + 成功
            "pairing.advertise",       // 广播启动
            "pairing.accept",          // accept loop 开始/结束
            "pairing.request",         // 请求接收
            "pairing.confirm",         // confirm 开始/成功
        ] {
            assert!(
                text_a.contains(&format!("\"{expected}\"")),
                "确认方事件应包含 {expected}；实际:\n{text_a}"
            );
        }
        // confirm 成功事件
        let confirm_ok = events_a
            .iter()
            .find(|e| e.event == "pairing.confirm" && field(e, "action") == Some("success"))
            .expect("应有 confirm success 事件");
        assert!(
            confirm_ok
                .device_ids
                .iter()
                .any(|d| d == &debug_log::redact_device_id(&request_id)),
            "confirm success 事件应含脱敏对端 id"
        );

        // ━━ 发起方事件断言：连接 start/success + transport=direct ━━
        let events_b = sink_b.snapshot();
        let text_b = event_text(&events_b);
        assert!(text_b.contains("\"pairing.connect\""), "发起方应发出 connect 事件");
        let connect_start = events_b
            .iter()
            .find(|e| e.event == "pairing.connect" && field(e, "action") == Some("start"))
            .expect("应有 connect start 事件");
        assert_eq!(field(connect_start, "transport"), Some("direct"));
        assert!(
            events_b
                .iter()
                .any(|e| e.event == "pairing.connect" && field(e, "action") == Some("success")),
            "应有 connect success 事件"
        );

        let _ = std::fs::remove_dir_all(dir_a);
        let _ = std::fs::remove_dir_all(dir_b);
    });
}

// ━━━ 验收 7：连接阶段区分 direct/relay + 错误链 + 耗时 ━━━

#[test]
fn test_connect_emits_transport_and_error_chain() {
    rt().block_on(async {
        // 直连路径（ips 非空）→ transport=direct；127.0.0.1:1 立即拒绝 → failed 事件含错误链与耗时
        let dir = temp_dir("connect-direct");
        let sink = sink();
        let svc = SyncService::new_persistent_with_log_sink(&dir, sink.clone())
            .await
            .unwrap();
        let store = NoteStore::new(":memory:").unwrap();
        let target = PairingTarget {
            device_id: "aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899"
                .to_string(),
            ips: vec!["127.0.0.1:1".to_string()],
        };
        let res = tokio::time::timeout(
            std::time::Duration::from_secs(15),
            svc.begin_pairing_connect(&store, "123456", target),
        )
        .await;
        let events = sink.snapshot();
        let start = events
            .iter()
            .find(|e| e.event == "pairing.connect" && field(e, "action") == Some("start"))
            .expect("应有 connect start 事件");
        assert_eq!(field(start, "transport"), Some("direct"));

        if let Ok(Err(_)) = res {
            let failed = events
                .iter()
                .find(|e| e.event == "pairing.connect" && field(e, "action") == Some("failed"))
                .expect("连接失败应发出 failed 事件");
            assert!(
                failed.error_chain.is_some(),
                "失败事件应含错误链"
            );
            assert!(
                failed.duration_ms.is_some(),
                "失败事件应含耗时"
            );
        }
        let _ = std::fs::remove_dir_all(dir);

        // relay 路径（空 ips + relay.txt 配置）→ transport=relay
        let dir2 = temp_dir("connect-relay");
        std::fs::write(dir2.join("relay.txt"), "http://127.0.0.1:1").unwrap();
        let sink2 = Arc::new(CollectingSink::new());
        let svc2 = SyncService::new_persistent_with_log_sink(&dir2, sink2.clone())
            .await
            .unwrap();
        let store2 = NoteStore::new(":memory:").unwrap();
        let target2 = PairingTarget {
            device_id: "aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899"
                .to_string(),
            ips: vec![],
        };
        let _ = tokio::time::timeout(
            std::time::Duration::from_secs(15),
            svc2.begin_pairing_connect(&store2, "123456", target2),
        )
        .await;
        let start2 = sink2
            .snapshot()
            .into_iter()
            .find(|e| e.event == "pairing.connect" && field(e, "action") == Some("start"))
            .expect("relay 配置下 connect start 事件应存在");
        assert_eq!(field(&start2, "transport"), Some("relay"));
        let _ = std::fs::remove_dir_all(dir2);
    });
}

// ━━━ 验收 8：首次全量同步只记录数量/方向/耗时，不记录正文 ━━━

#[test]
fn test_initial_sync_emits_counts_only() {
    rt().block_on(async {
        let dir_a = temp_dir("sync-a");
        let dir_b = temp_dir("sync-b");
        let sink_a = sink();
        let sink_b = sink();
        let mut confirmer =
            SyncService::new_persistent_with_log_sink(&dir_a, sink_a.clone())
                .await
                .unwrap();
        confirmer
            .create_note("n1".into(), "# SECRET-BODY-1\n\nprivate content")
            .unwrap();
        confirmer
            .create_note("n2".into(), "SECRET-BODY-2 private")
            .unwrap();
        let mut initiator = SyncService::new_persistent_with_log_sink(&dir_b, sink_b.clone())
            .await
            .unwrap();
        let store_a = NoteStore::new(":memory:").unwrap();
        let store_b = NoteStore::new(":memory:").unwrap();

        let code = confirmer.begin_pairing_accept().unwrap();
        let target = PairingTarget {
            device_id: confirmer.device_id(),
            ips: confirmer.local_addrs(),
        };

        let confirmer_code = code.clone();
        let confirmer_handle = tokio::spawn(async move {
            let request = tokio::time::timeout(
                std::time::Duration::from_secs(15),
                confirmer.accept_pairing_request_with_timeout(std::time::Duration::from_secs(15)),
            )
            .await
            .expect("accept 应在 15s 内返回")
            .unwrap()
            .expect("应收到请求");
            confirmer
                .confirm_pairing(&store_a, &confirmer_code, &request)
                .await
                .unwrap();
        });
        let initiator_handle = tokio::spawn(async move {
            initiator
                .begin_pairing_connect(&store_b, &code, target)
                .await
                .unwrap();
            let data = tokio::time::timeout(
                std::time::Duration::from_secs(15),
                initiator.accept_push(),
            )
            .await
            .expect("accept_push 应在 15s 内返回")
            .unwrap();
            initiator.import_all(&data).unwrap();
        });
        confirmer_handle.await.unwrap();
        initiator_handle.await.unwrap();

        // 发起方侧：应收到推送/导入事件，且只含数量与耗时，不含正文
        let events_b = sink_b.snapshot();
        let text_b = event_text(&events_b);
        assert!(
            !text_b.contains("SECRET-BODY-1") && !text_b.contains("SECRET-BODY-2"),
            "同步事件不得记录笔记正文"
        );
        let import_ok = events_b
            .iter()
            .find(|e| e.event == "sync.import" && field(e, "action") == Some("success"))
            .expect("发起方应有 sync.import success 事件");
        assert_eq!(field(import_ok, "direction"), Some("import"));
        assert_eq!(field(import_ok, "note_count"), Some("2"));
        assert!(import_ok.duration_ms.is_some(), "导入事件应含耗时");

        // 确认方侧：推送事件只含数量
        let events_a = sink_a.snapshot();
        let push_ok = events_a
            .iter()
            .find(|e| e.event == "sync.push" && field(e, "action") == Some("success"))
            .expect("确认方应有 sync.push success 事件");
        assert_eq!(field(push_ok, "direction"), Some("push"));
        assert_eq!(field(push_ok, "note_count"), Some("2"));

        let _ = std::fs::remove_dir_all(dir_a);
        let _ = std::fs::remove_dir_all(dir_b);
    });
}

// ━━━ 验收 9：日志失败不影响主流程 ━━━

#[test]
fn test_logger_failure_does_not_break_flow() {
    rt().block_on(async {
        let dir = temp_dir("panic");
        // 构造即触发 startup 事件 → sink panic → 必须被吞掉
        let mut svc = SyncService::new_persistent_with_log_sink(&dir, Arc::new(PanickingSink))
            .await
            .unwrap();
        // 写笔记 → persist → 标记待同步（无日志事件）；import 会触发日志事件
        svc.create_note("n1".into(), "body").unwrap();
        let data = svc.export_all().unwrap();
        svc.import_all(&data).unwrap();
        // 配对码生成会触发日志事件
        let code = svc.begin_pairing_accept().unwrap();
        assert_eq!(code.len(), 6);
        // push_pending 触发日志事件（无设备 → skipped）
        let store = NoteStore::new(":memory:").unwrap();
        let results = svc.push_pending(&store).await;
        assert!(results.is_empty(), "无配对设备时应返回空结果");
        // 主流程数据完整
        assert_eq!(svc.get_note("n1").as_deref(), Some("body"));
        let _ = std::fs::remove_dir_all(dir);
    });
}
