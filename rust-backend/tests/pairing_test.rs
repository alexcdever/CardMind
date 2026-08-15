//! 配对流程集成测试（任务 G）：
//! 1. 配对码生成与校验（6 位数字、正确/错误码）
//! 2. 配对码 10 分钟过期
//! 3. 同一码连续错 5 次失效（防暴力猜测）
//! 4. 配对成功后双方持久化（确认方 upsert 发起方；发起方经握手响应 upsert 确认方）
//! 5. 配对成功后确认方自动推送全量快照（决策 8：首次配对自动全量同步）
//! 6. 解除配对（复用模块 2 API）

use cardmind_backend::store::NoteStore;
use cardmind_backend::sync::{PairingRequest, PairingSession, PairingTarget, SyncService};

fn rt() -> tokio::runtime::Runtime {
    tokio::runtime::Runtime::new().unwrap()
}

/// 构造一个发起方请求（测试用）
fn requester(code: &str, id: &str, name: &str) -> PairingRequest {
    PairingRequest {
        code: code.to_string(),
        device_id: id.to_string(),
        device_name: name.to_string(),
        relay_info: String::new(),
        // 指向关闭端口：无真实握手（无 pending 连接）时 confirm 不触发推送
        ips: vec!["127.0.0.1:1".to_string()],
    }
}

/// 保证与正确码不同的错误码
fn wrong_code(code: &str) -> String {
    if code == "123456" {
        "654321".to_string()
    } else {
        "123456".to_string()
    }
}

// ━━━ 验收 1：配对码生成与校验 ━━━

#[test]
fn test_pairing_code_generation_and_validation() {
    rt().block_on(async {
        let confirmer = SyncService::new().await.unwrap();
        let store = NoteStore::new(":memory:").unwrap();
        let code = confirmer.begin_pairing_accept().unwrap();
        let req = requester(&code, "initiator-1", "New Phone");

        assert_eq!(code.len(), 6, "配对码应为 6 位");
        assert!(
            code.chars().all(|c| c.is_ascii_digit()),
            "配对码应全为数字，实际: {code}"
        );
        let numeric: u32 = code.parse().unwrap();
        assert!(
            (100000..=999999).contains(&numeric),
            "配对码应在 100000-999999，实际: {numeric}"
        );

        // 错误码失败
        let err = confirmer
            .confirm_pairing(&store, &wrong_code(&code), &req)
            .await
            .unwrap_err();
        assert!(
            err.to_string().contains("code") || err.to_string().contains("invalid"),
            "错误码应报告 invalid code，实际: {err:#}"
        );

        // 正确码成功，返回发起方身份
        let result = confirmer
            .confirm_pairing(&store, &code, &req)
            .await
            .unwrap();
        assert_eq!(result.peer_id, "initiator-1");
        assert_eq!(result.peer_name, "New Phone");

        // 确认方已 upsert 发起方
        let devices = store.list_paired_devices().unwrap();
        assert!(
            devices.iter().any(|d| d.peer_id == "initiator-1"),
            "配对成功后确认方 store 应含发起方"
        );

        // 码单次使用后失效
        assert!(
            confirmer
                .confirm_pairing(&store, &code, &req)
                .await
                .is_err(),
            "配对码单次使用后应失效"
        );
    });
}

// ━━━ 验收 2：配对码过期 ━━━

#[test]
fn test_pairing_code_expires() {
    rt().block_on(async {
        let confirmer = SyncService::new().await.unwrap();
        let store = NoteStore::new(":memory:").unwrap();
        let code = confirmer.begin_pairing_accept().unwrap();
        let req = requester(&code, "initiator-2", "New Phone");

        // 直接操作状态：把 created_at 拨回 11 分钟前（超过 10 分钟有效窗口）
        let session = confirmer.current_pairing_session().unwrap();
        let expired = PairingSession {
            code: session.code,
            created_at: session.created_at - chrono::Duration::minutes(11),
            failed_attempts: session.failed_attempts,
        };
        confirmer.set_current_pairing_session(Some(expired));

        let err = confirmer
            .confirm_pairing(&store, &code, &req)
            .await
            .unwrap_err();
        assert!(
            err.to_string().contains("expired"),
            "过期码应报 expired，实际: {err:#}"
        );
    });
}

// ━━━ 验收 3：暴力尝试限制（连续错 5 次失效）━━━

#[test]
fn test_pairing_code_brute_force_limit() {
    rt().block_on(async {
        let confirmer = SyncService::new().await.unwrap();
        let store = NoteStore::new(":memory:").unwrap();
        let code = confirmer.begin_pairing_accept().unwrap();
        let req = requester(&code, "initiator-3", "New Phone");

        // 连续错 5 次（"000000" 恒不等于生成的 100000-999999 码）
        for i in 0..5 {
            assert!(
                confirmer
                    .confirm_pairing(&store, "000000", &req)
                    .await
                    .is_err(),
                "第 {} 次错误码应失败",
                i + 1
            );
        }

        // 第 6 次即使输正确码也失败（会话已失效，需重新发起）
        let err = confirmer
            .confirm_pairing(&store, &code, &req)
            .await
            .unwrap_err();
        assert!(
            err.to_string().contains("no active pairing code"),
            "锁定后应提示无有效配对码，实际: {err:#}"
        );

        // 重新发起后可成功
        let code2 = confirmer.begin_pairing_accept().unwrap();
        let req2 = requester(&code2, "initiator-3", "New Phone");
        let result = confirmer
            .confirm_pairing(&store, &code2, &req2)
            .await
            .unwrap();
        assert_eq!(result.peer_id, "initiator-3");
    });
}

// ━━━ 验收 4：配对成功后双方持久化 ━━━

#[test]
fn test_pairing_persists_both_sides() {
    rt().block_on(async {
        let confirmer = SyncService::new().await.unwrap();
        confirmer.set_device_name("Trusted PC");
        let initiator = SyncService::new().await.unwrap();
        initiator.set_device_name("New Phone");

        let confirmer_store = NoteStore::new(":memory:").unwrap();
        let initiator_store = NoteStore::new(":memory:").unwrap();

        let code = confirmer.begin_pairing_accept().unwrap();
        let target = PairingTarget {
            device_id: confirmer.device_id(),
            ips: confirmer.local_addrs(),
        };
        assert!(!target.ips.is_empty(), "确认方应至少有一个本地 IPv4 地址");

        // 确认方：接收请求 + 确认（回复握手 + 自动推送）
        let confirmer_code = code.clone();
        let confirmer_handle = tokio::spawn(async move {
            let request = confirmer.accept_pairing_request().await.unwrap();
            let result = confirmer
                .confirm_pairing(&confirmer_store, &confirmer_code, &request)
                .await
                .unwrap();
            (confirmer, confirmer_store, request, result)
        });

        // 发起方：连接 + 发送请求 + 接收握手响应（内部 upsert 确认方）→ 接收并丢弃自动推送
        let initiator_handle = tokio::spawn(async move {
            let result = initiator
                .begin_pairing_connect(&initiator_store, &code, target)
                .await
                .unwrap();
            let _ = initiator.accept_push().await; // drain 自动推送快照
            (initiator, initiator_store, result)
        });

        let (confirmer, confirmer_store, request, confirm_result) =
            confirmer_handle.await.unwrap();
        let (_initiator, initiator_store, connect_result) = initiator_handle.await.unwrap();

        // 确认方 store 含发起方 id（配对成功后自动 upsert）
        let devices = confirmer_store.list_paired_devices().unwrap();
        assert!(
            devices
                .iter()
                .any(|d| d.peer_id == request.device_id && d.name == "New Phone"),
            "确认方配对后应持久化发起方"
        );

        // 发起方（经握手响应）upsert 确认方
        let devices = initiator_store.list_paired_devices().unwrap();
        assert!(
            devices
                .iter()
                .any(|d| d.peer_id == confirmer.device_id() && d.name == "Trusted PC"),
            "发起方经握手响应应持久化确认方"
        );

        // 双方返回值：对端身份
        assert_eq!(connect_result.peer_id, confirmer.device_id());
        assert_eq!(connect_result.peer_name, "Trusted PC");
        assert_eq!(confirm_result.peer_id, request.device_id);
        assert_eq!(confirm_result.peer_name, "New Phone");
    });
}

// ━━━ 验收 5：首次配对自动全量同步（决策 8）━━━

#[test]
fn test_pairing_triggers_initial_full_sync() {
    rt().block_on(async {
        let mut confirmer = SyncService::new().await.unwrap();
        confirmer.set_device_name("Trusted PC");
        confirmer
            .create_note("n1".to_string(), "# From trusted\n\nbody one")
            .unwrap();
        confirmer
            .create_note("n2".to_string(), "# Second\n\nbody two")
            .unwrap();
        let initiator = SyncService::new().await.unwrap();
        initiator.set_device_name("New Phone");

        let confirmer_store = NoteStore::new(":memory:").unwrap();
        let initiator_store = NoteStore::new(":memory:").unwrap();

        let code = confirmer.begin_pairing_accept().unwrap();
        let confirmer_id = confirmer.device_id();
        let target = PairingTarget {
            device_id: confirmer_id.clone(),
            ips: confirmer.local_addrs(),
        };

        // 确认方：接收请求 + 确认（内部自动推送全量快照给发起方）
        let confirmer_code = code.clone();
        let confirmer_handle = tokio::spawn(async move {
            let request = confirmer.accept_pairing_request().await.unwrap();
            let result = confirmer
                .confirm_pairing(&confirmer_store, &confirmer_code, &request)
                .await
                .unwrap();
            (result, request)
        });

        // 发起方：连接 + 发送请求 + 接收响应 → 首次全量同步：接收快照并导入
        let mut initiator = initiator;
        let initiator_handle = tokio::spawn(async move {
            let result = initiator
                .begin_pairing_connect(&initiator_store, &code, target)
                .await
                .unwrap();
            let data = initiator.accept_push().await.unwrap();
            initiator.import_all(&data).unwrap();
            (result, initiator)
        });

        let (confirm_result, request) = confirmer_handle.await.unwrap();
        let (connect_result, initiator) = initiator_handle.await.unwrap();

        // 发起方收到的对端身份 = 确认方本机身份；确认方收到的对端身份 = 发起方请求身份
        assert_eq!(connect_result.peer_id, confirmer_id);
        assert_eq!(connect_result.peer_name, "Trusted PC");
        assert_eq!(confirm_result.peer_id, request.device_id);
        assert_eq!(confirm_result.peer_name, "New Phone");

        // 发起方 import 后笔记可见
        assert_eq!(
            initiator.get_note("n1").as_deref(),
            Some("# From trusted\n\nbody one"),
            "发起方应能通过首次全量同步看到确认方笔记"
        );
        assert_eq!(
            initiator.get_note("n2").as_deref(),
            Some("# Second\n\nbody two")
        );
    });
}

// ━━━ 验收 6：解除配对 ━━━

#[test]
fn test_unpair_removes_device() {
    let store = NoteStore::new(":memory:").unwrap();
    store.upsert_paired_device("peer-a", "Alice").unwrap();
    assert!(
        store
            .list_paired_devices()
            .unwrap()
            .iter()
            .any(|d| d.peer_id == "peer-a")
    );

    store.remove_paired_device("peer-a").unwrap();
    assert!(
        store
            .list_paired_devices()
            .unwrap()
            .iter()
            .all(|d| d.peer_id != "peer-a"),
        "解除配对后设备应从列表消失"
    );
}
