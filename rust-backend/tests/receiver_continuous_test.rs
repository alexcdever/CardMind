//! 任务 O：持续 push 接收器（continuous receiver）集成测试。
//!
//! 红阶段（缺陷复现，已记录红输出）：
//! 1. `receiver absent causes push timeout`：B 调度器已启动（周期未到）但无接收器，
//!    A push 时 B 不在 accept → 10 秒超时（修复后 B 由接收器兜底，10 秒内 receive/import）。
//! 2. `paired device remains offline without last_seen`：配对成功后双方 paired row 的
//!    last_seen 为空 → UI 按 5 分钟窗口判离线（修复后配对成功立即更新 last_seen）。
//! 3. `symmetric cycles can miss each other`：两端都"先 push 后 accept"，周期错开时
//!    互相错过 → 数据不同步（修复后接收器与周期相位无关，数据仍会同步）。
//!
//! 修复后的验收断言见各测试（B 启动接收器后 A push 10 秒内成功；配对成功
//! last_seen 立即非空；周期错开仍同步）。

use std::time::{Duration, Instant};

use cardmind_backend::store::NoteStore;
use cardmind_backend::sync::{PairingTarget, SyncService};

fn rt() -> tokio::runtime::Runtime {
    tokio::runtime::Runtime::new().unwrap()
}

/// 真实配对两个 SyncService（initiator ↔ confirmer），双方 paired_devices 互相包含。
async fn pair_up(
    initiator: SyncService,
    initiator_store: NoteStore,
    mut confirmer: SyncService,
    confirmer_store: NoteStore,
) -> (SyncService, NoteStore, SyncService, NoteStore) {
    let code = confirmer.begin_pairing_accept().unwrap();
    let target = PairingTarget {
        device_id: confirmer.device_id(),
        ips: confirmer.local_addrs(),
    };
    assert!(!target.ips.is_empty(), "确认方应至少有一个本地 IPv4 地址");

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

// ━━━ 验收 1：receiver absent causes push timeout ━━━

/// 红阶段缺陷复现：B 无接收器时 A push 超时 10 秒（红输出已记录：
/// `error="push timeout after 10s" duration_ms=10003`）。
/// 修复后：B 调度器启动即运行接收器，A push 应在 10 秒内被 B receive/import。
#[test]
fn receiver_absent_causes_push_timeout() {
    rt().block_on(async {
        let (mut a, a_store, b, b_store) = pair_up(
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
        )
        .await;

        // B 调度器已启动：接收器运行（修复后行为）
        b.start_receiver(b_store.clone()).await.unwrap();

        // A 编辑并立即推送
        a.create_note("n1".to_string(), "# Hello\n\nbody").unwrap();
        let start = Instant::now();
        let results = a.push_pending(&a_store).await;
        let elapsed = start.elapsed();

        assert!(
            results.iter().any(|r| r.ok),
            "A 的 push 应在 10 秒内被 B 接收（B 调度器运行期间持续可接收），\
             实际耗时 {:?} 结果: {results:?}",
            elapsed
        );
        assert!(
            elapsed < Duration::from_secs(10),
            "push 不应超时，实际耗时 {:?}",
            elapsed
        );
        // B 已 receive + import（接收器自动 import）
        assert_eq!(
            b.get_note("n1").as_deref(),
            Some("# Hello\n\nbody"),
            "B 的接收器应自动 import A 的推送"
        );
        // 接收器停止（清理后台任务）
        b.stop_receiver().await.unwrap();
        drop(b);
        drop(b_store);
        drop(a_store);
    });
}

// ━━━ 验收 2：paired device remains offline without last_seen ━━━

/// 红阶段缺陷复现：配对成功后 `upsert_paired_device` 写入 last_seen=NULL，
/// 双方设备页按 5 分钟窗口判为离线（红输出已记录：last_seen 应非空）。
/// 修复后：配对握手成功立即更新双方 last_seen。
#[test]
fn paired_device_remains_offline_without_last_seen() {
    rt().block_on(async {
        let (initiator, initiator_store, confirmer, confirmer_store) = pair_up(
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
        )
        .await;

        let initiator_id = initiator.device_id();
        let confirmer_id = confirmer.device_id();

        // 双方 paired row 都应立即进入"近期在线"（last_seen 非空且在当前窗口内）
        let confirmer_row = confirmer_store
            .list_paired_devices()
            .unwrap()
            .into_iter()
            .find(|d| d.peer_id == initiator_id)
            .expect("确认方应有发起方配对记录");
        let initiator_row = initiator_store
            .list_paired_devices()
            .unwrap()
            .into_iter()
            .find(|d| d.peer_id == confirmer_id)
            .expect("发起方应有确认方配对记录");

        for (side, row) in [("确认方", &confirmer_row), ("发起方", &initiator_row)] {
            let last_seen = row.last_seen.as_deref().expect(
                "配对成功后 last_seen 应非空（立即进入近期在线），\
                 当前实现 upsert 写 NULL → 设备页离线（红）",
            );
            let time = chrono::DateTime::parse_from_rfc3339(last_seen)
                .unwrap_or_else(|_| panic!("{side} last_seen 应为 RFC3339: {last_seen}"));
            let age = chrono::Utc::now().signed_duration_since(time.with_timezone(&chrono::Utc));
            assert!(
                age.num_seconds().abs() < 60,
                "{side} last_seen 应在当前时间窗口内，实际 age={age:?}"
            );
        }
        drop((initiator, initiator_store, confirmer, confirmer_store));
    });
}

// ━━━ 验收 3：symmetric cycles can miss each other ━━━

/// 红阶段缺陷复现：两端周期同步都按"先 push 后 accept"，相位错开时互相错过
/// （红输出已记录：`aborted by peer: connection closed during handshake`）。
/// 修复后：独立接收器与周期相位无关，A 的 push 被 B 接收器接收，
/// 数据在 10 秒内同步。
#[test]
fn symmetric_cycles_can_miss_each_other() {
    rt().block_on(async {
        let (mut a, a_store, mut b, b_store) = pair_up(
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
        )
        .await;

        // 两端调度器启动（接收器运行）
        a.start_receiver(a_store.clone()).await.unwrap();
        b.start_receiver(b_store.clone()).await.unwrap();

        a.create_note("n1".to_string(), "# Missed\n\nbody").unwrap();

        // A 周期先跑：push（B 接收器接收）后 accept 2s
        let r1 = a.run_sync_cycle(&a_store).await.unwrap();
        // B 周期后跑：push（A 接收器接收）后 accept 2s
        let r2 = b.run_sync_cycle(&b_store).await.unwrap();

        // 修复后：B 的接收器已收到 A 的 push → 笔记可见（不受周期相位影响）
        assert_eq!(
            b.get_note("n1").as_deref(),
            Some("# Missed\n\nbody"),
            "两端周期错开（先 push 后 accept）仍应互相同步；r1={r1:?} r2={r2:?}"
        );
        a.stop_receiver().await.unwrap();
        b.stop_receiver().await.unwrap();
        drop(b);
        drop(b_store);
        drop(a_store);
    });
}

// ━━━ 验收 4：receiver starts once and is idempotent ━━━

/// 重复 start 只有一个接收器：start 两次后 receiver_running 为 true，
/// 且 stop 一次后即完全停止（没有第二个 listener 残留）。
#[test]
fn receiver_starts_once_and_is_idempotent() {
    rt().block_on(async {
        let svc = SyncService::new().await.unwrap();
        let store = NoteStore::new(":memory:").unwrap();

        svc.start_receiver(store.clone()).await.unwrap();
        assert!(svc.receiver_running(), "第一次 start 后应在运行");
        svc.start_receiver(store.clone()).await.unwrap();
        assert!(svc.receiver_running(), "重复 start 不应停掉已有接收器");

        // 幂等验证：单次 stop 后完全停止（若重复 start 产生第二个任务，stop 后
        // receiver_running 仍应为 true —— 但我们要求为 false）
        svc.stop_receiver().await.unwrap();
        assert!(
            !svc.receiver_running(),
            "stop 后不应再运行（无重复 listener）"
        );

        // 再次 start 可重新运行（restart 语义）
        svc.start_receiver(store.clone()).await.unwrap();
        assert!(svc.receiver_running(), "restart 应可再次运行");
        svc.stop_receiver().await.unwrap();
        assert!(!svc.receiver_running());
    });
}

// ━━━ 验收 5：receiver continuously accepts push（与周期相位无关）━━━

/// A 在任意时间 push（B 接收器已运行一段时间，处于空闲窗口），
/// B 在 10 秒内 receive/import。
#[test]
fn receiver_continuously_accepts_push() {
    rt().block_on(async {
        let (mut a, a_store, b, b_store) = pair_up(
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
        )
        .await;

        b.start_receiver(b_store.clone()).await.unwrap();
        // 让接收器先经历若干空闲窗口（模拟应用运行任意时刻）
        tokio::time::sleep(Duration::from_millis(900)).await;

        a.create_note("n1".to_string(), "# Anytime\n\nbody")
            .unwrap();
        let start = Instant::now();
        let results = a.push_pending(&a_store).await;
        assert!(
            results.iter().any(|r| r.ok),
            "A push 应在 10 秒内成功，实际结果: {results:?}"
        );
        assert!(
            start.elapsed() < Duration::from_secs(10),
            "receive/import 应在 10 秒内完成，实际 {:?}",
            start.elapsed()
        );
        // B 已自动 import（接收器自动完成，无需周期）
        assert_eq!(
            b.get_note("n1").as_deref(),
            Some("# Anytime\n\nbody"),
            "B 的接收器应自动 import"
        );
        b.stop_receiver().await.unwrap();
        drop((b, b_store, a_store));
    });
}

// ━━━ 验收 6：receiver stop is bounded（3 秒内返回，停止后不再处理新 push）━━━

#[test]
fn receiver_stop_is_bounded() {
    rt().block_on(async {
        let (mut a, a_store, b, b_store) = pair_up(
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
        )
        .await;

        b.start_receiver(b_store.clone()).await.unwrap();
        tokio::time::sleep(Duration::from_millis(100)).await;

        // stop 必须在 3 秒内返回
        let start = Instant::now();
        b.stop_receiver().await.unwrap();
        let stop_elapsed = start.elapsed();
        assert!(
            stop_elapsed < Duration::from_secs(3),
            "stop 应在 3 秒内返回，实际 {:?}",
            stop_elapsed
        );
        assert!(!b.receiver_running());

        // 停止后不再处理新 push：A push → B 不在 accept → 超时失败
        a.create_note("n1".to_string(), "# After stop\n\nbody")
            .unwrap();
        let results = a.push_pending(&a_store).await;
        assert!(
            results.iter().all(|r| !r.ok),
            "停止后 B 不应再接收 push，结果: {results:?}"
        );
        assert_eq!(b.get_note("n1"), None, "停止后 B 不应导入任何数据");
        drop((b, b_store, a_store));
    });
}

// ━━━ 验收 7：receiver does not block edits ━━━

/// 接收等待期间（接收器空闲轮询 accept），create/edit 应在 1 秒内完成。
#[test]
fn receiver_does_not_block_edits() {
    rt().block_on(async {
        let (a, _a_store, mut b, b_store) = pair_up(
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
        )
        .await;
        let _ = a;

        b.start_receiver(b_store.clone()).await.unwrap();
        // 接收器已进入等待窗口
        tokio::time::sleep(Duration::from_millis(100)).await;

        // create / update 均应在 1 秒内完成（不被接收器的 accept 等待阻塞）
        let start = Instant::now();
        b.create_note("local".to_string(), "# Local\n\nedit")
            .unwrap();
        let create_elapsed = start.elapsed();
        assert!(
            create_elapsed < Duration::from_secs(1),
            "接收等待期间 create 应 <1s，实际 {:?}",
            create_elapsed
        );

        let start = Instant::now();
        b.update_note("local", "# Local v2\n\nedit").unwrap();
        let update_elapsed = start.elapsed();
        assert!(
            update_elapsed < Duration::from_secs(1),
            "接收等待期间 update 应 <1s，实际 {:?}",
            update_elapsed
        );
        assert_eq!(b.get_note("local").as_deref(), Some("# Local v2\n\nedit"));

        b.stop_receiver().await.unwrap();
        drop(b_store);
    });
}

// ━━━ 验收 8：receiver does not block outbound push ━━━

/// 接收等待期间仍可主动 push（A 与 B 都运行接收器，B 编辑后主动推送成功）。
#[test]
fn receiver_does_not_block_outbound_push() {
    rt().block_on(async {
        let (a, a_store, mut b, b_store) = pair_up(
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
        )
        .await;

        a.start_receiver(a_store.clone()).await.unwrap();
        b.start_receiver(b_store.clone()).await.unwrap();
        tokio::time::sleep(Duration::from_millis(100)).await;

        // B 在自身接收器等待期间主动 push 给 A
        b.create_note("from-b".to_string(), "# From B\n\nbody")
            .unwrap();
        let start = Instant::now();
        let results = b.push_pending(&b_store).await;
        assert!(
            results.iter().any(|r| r.ok),
            "接收等待期间 B 的主动 push 应成功，结果: {results:?}"
        );
        assert!(
            start.elapsed() < Duration::from_secs(10),
            "主动 push 应 10 秒内完成，实际 {:?}",
            start.elapsed()
        );
        // A 的接收器收到并导入
        let deadline = tokio::time::Instant::now() + Duration::from_secs(10);
        loop {
            if a.get_note("from-b").is_some() {
                break;
            }
            if tokio::time::Instant::now() >= deadline {
                panic!("A 应在 10 秒内收到 B 的 push");
            }
            tokio::time::sleep(Duration::from_millis(100)).await;
        }
        assert_eq!(a.get_note("from-b").as_deref(), Some("# From B\n\nbody"));
        a.stop_receiver().await.unwrap();
        b.stop_receiver().await.unwrap();
        drop((b, b_store, a_store));
    });
}

// ━━━ 验收 9：pairing and push routing coexist（统一路由不回归）━━━

/// B 接收器运行期间同时：1) 已配对设备 A 推送数据；2) 新设备 C 发起配对。
/// 配对请求不被接收器吞掉，push 不被配对等待吞掉，两条路由并存。
#[test]
fn pairing_and_push_routing_coexist() {
    rt().block_on(async {
        let (mut a, a_store, mut b, b_store) = pair_up(
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
        )
        .await;

        // B 接收器运行（会参与 incoming 路由）
        b.start_receiver(b_store.clone()).await.unwrap();
        let b_id = b.device_id();
        let b_ips = b.local_addrs();

        // B 同时进入配对等待（新设备 C 加入）
        let code = b.begin_pairing_accept().unwrap();
        let b_handle = tokio::spawn(async move {
            let request = b.accept_pairing_request().await.unwrap();
            (b, request)
        });

        // A 在 B 配对等待 + 接收器运行期间推送 → 应被接收器导入
        a.create_note("n1".to_string(), "# Routing\n\nbody")
            .unwrap();
        let results = a.push_pending(&a_store).await;
        assert!(
            results.iter().any(|r| r.ok),
            "A 的 push 应成功，结果: {results:?}"
        );

        // 新设备 C 发起配对 → B 的 accept_pairing_request 应正确拿到 C 的请求
        let c = SyncService::new().await.unwrap();
        c.set_device_name("New Phone");
        let c_store = NoteStore::new(":memory:").unwrap();
        let c_code = code.clone();
        let c_handle = tokio::spawn(async move {
            let result = c
                .begin_pairing_connect(
                    &c_store,
                    &c_code,
                    PairingTarget {
                        device_id: b_id,
                        ips: b_ips,
                    },
                )
                .await
                .unwrap();
            // drain 确认方首次全量同步推送
            let _ = c.accept_push().await;
            (c, c_store, result)
        });

        let (b, request) = tokio::time::timeout(Duration::from_secs(15), b_handle)
            .await
            .expect("B 配对等待超时")
            .expect("B 配对等待 panic");
        let confirm = b.confirm_pairing(&b_store, &code, &request).await.unwrap();
        let (c, c_store, connect) = c_handle.await.unwrap();
        assert_eq!(confirm.peer_id, c.device_id());
        assert_eq!(connect.peer_id, b.device_id());

        // 统一路由不回归：A 的 push 被接收器导入（未被配对等待吞掉）
        assert_eq!(
            b.get_note("n1").as_deref(),
            Some("# Routing\n\nbody"),
            "接收器应导入 A 的 push（配对等待不吞推送帧）"
        );
        b.stop_receiver().await.unwrap();
        drop((c, c_store, a_store, b_store));
    });
}

// ━━━ 验收 10：receiver failure is recoverable ━━━

/// 单次接收失败（未知帧）记录日志并继续下一窗口：随后正常 push 仍被处理。
#[test]
fn receiver_failure_is_recoverable() {
    rt().block_on(async {
        let (mut a, a_store, b, b_store) = pair_up(
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
        )
        .await;

        b.start_receiver(b_store.clone()).await.unwrap();
        tokio::time::sleep(Duration::from_millis(100)).await;

        // 恶意/损坏连接：发一个既不是 CARDMIND magic 也不是 0x01 开头的帧
        let garbage = b"NOT-CARDMIND-GARBAGE-DATA";
        let bad_peer = iroh::Endpoint::builder(iroh::endpoint::presets::N0)
            .secret_key(iroh::SecretKey::generate())
            .alpns(vec![b"cardmind-v2".to_vec()])
            .relay_mode(iroh::RelayMode::Disabled)
            .bind()
            .await
            .unwrap();
        let node_id: iroh::EndpointId = b.device_id().parse().unwrap();
        let ips: Vec<iroh::TransportAddr> = b
            .local_addrs()
            .iter()
            .filter_map(|s| s.parse::<std::net::SocketAddr>().ok())
            .map(iroh::TransportAddr::Ip)
            .collect();
        let addr = bad_peer
            .connect(iroh::EndpointAddr::from_parts(node_id, ips), b"cardmind-v2")
            .await
            .unwrap();
        let mut send = addr.open_uni().await.unwrap();
        let _ = send.write_all(garbage).await;
        let _ = send.finish();
        // 等接收器处理完坏帧（记录 failed_tolerated）
        tokio::time::sleep(Duration::from_millis(500)).await;

        // 正常 push 仍被接收器处理（可恢复，未永久退出/busy loop）
        a.create_note("n2".to_string(), "# After failure\n\nbody")
            .unwrap();
        let results = a.push_pending(&a_store).await;
        assert!(
            results.iter().any(|r| r.ok),
            "坏帧后正常 push 应成功，结果: {results:?}"
        );
        let deadline = tokio::time::Instant::now() + Duration::from_secs(10);
        loop {
            if b.get_note("n2").is_some() {
                break;
            }
            if tokio::time::Instant::now() >= deadline {
                panic!("坏帧后接收器应恢复并导入 n2");
            }
            tokio::time::sleep(Duration::from_millis(100)).await;
        }
        assert_eq!(b.get_note("n2").as_deref(), Some("# After failure\n\nbody"));
        b.stop_receiver().await.unwrap();
        drop((b, b_store, a_store));
    });
}

// ━━━ 验收 11/12/13/14：last_seen 更新 ━━━

/// 验收 11 已由 `paired_device_remains_offline_without_last_seen` 覆盖（配对成功
/// 双方 last_seen 立即非空、在当前窗口内）。
///
/// 验收 12：received push updates sender last_seen——B 接收器导入 A 的 push 后，
/// B store 中 A 的 last_seen 非空。
#[test]
fn received_push_updates_sender_last_seen() {
    rt().block_on(async {
        let (mut a, a_store, b, b_store) = pair_up(
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
        )
        .await;
        let a_id = a.device_id();

        b.start_receiver(b_store.clone()).await.unwrap();
        a.create_note("n1".to_string(), "# Push me\n\nbody")
            .unwrap();
        let results = a.push_pending(&a_store).await;
        assert!(results.iter().any(|r| r.ok));

        // B 的接收器应更新发送方（A）last_seen
        let deadline = tokio::time::Instant::now() + Duration::from_secs(10);
        let row = loop {
            let row = b_store
                .list_paired_devices()
                .unwrap()
                .into_iter()
                .find(|d| d.peer_id == a_id)
                .expect("B 应有 A 的配对记录");
            if row.last_seen.is_some() {
                break row;
            }
            if tokio::time::Instant::now() >= deadline {
                panic!("收到 push 后 B 应在 10 秒内更新 A 的 last_seen");
            }
            tokio::time::sleep(Duration::from_millis(100)).await;
        };
        let time = chrono::DateTime::parse_from_rfc3339(row.last_seen.as_deref().unwrap()).unwrap();
        let age = chrono::Utc::now().signed_duration_since(time.with_timezone(&chrono::Utc));
        assert!(age.num_seconds().abs() < 60, "last_seen 应在当前窗口内");

        b.stop_receiver().await.unwrap();
        drop((b, b_store, a_store));
    });
}

/// 验收 13：successful outbound push updates peer last_seen——A 成功推送后，
/// A store 中 B 的 last_seen 非空。
#[test]
fn successful_outbound_push_updates_peer_last_seen() {
    rt().block_on(async {
        let (mut a, a_store, b, b_store) = pair_up(
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
        )
        .await;
        let b_id = b.device_id();

        b.start_receiver(b_store.clone()).await.unwrap();
        a.create_note("n1".to_string(), "# Outbound\n\nbody")
            .unwrap();
        let results = a.push_pending(&a_store).await;
        assert!(results.iter().any(|r| r.ok), "push 应成功: {results:?}");

        let row = a_store
            .list_paired_devices()
            .unwrap()
            .into_iter()
            .find(|d| d.peer_id == b_id)
            .expect("A 应有 B 的配对记录");
        assert!(
            row.last_seen.is_some(),
            "成功推送后 A 应更新对端 B 的 last_seen"
        );

        b.stop_receiver().await.unwrap();
        drop((b, b_store, a_store));
    });
}

/// 验收 14：failed push does not mark online——对端不可达时 push 失败，
/// 不刷新 last_seen（保持原值）。
#[test]
fn failed_push_does_not_mark_online() {
    rt().block_on(async {
        let (mut a, a_store, b, b_store) = pair_up(
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
        )
        .await;
        let b_id = b.device_id();
        // 记录当前 last_seen（配对成功已更新）
        let before = a_store
            .list_paired_devices()
            .unwrap()
            .into_iter()
            .find(|d| d.peer_id == b_id)
            .unwrap()
            .last_seen;
        assert!(before.is_some(), "配对成功后应有 last_seen");

        // 对端离线：B endpoint 关闭
        drop(b);
        drop(b_store);
        tokio::time::sleep(Duration::from_millis(100)).await;

        a.create_note("n1".to_string(), "# Offline\n\nbody")
            .unwrap();
        let results = a.push_pending(&a_store).await;
        assert!(
            results.iter().all(|r| !r.ok) || results.is_empty(),
            "对端离线 push 应失败，结果: {results:?}"
        );

        // 失败不得刷新 last_seen（保持不变）
        let after = a_store
            .list_paired_devices()
            .unwrap()
            .into_iter()
            .find(|d| d.peer_id == b_id)
            .unwrap()
            .last_seen;
        assert_eq!(before, after, "失败 push 不得改变 last_seen");
        drop(a_store);
    });
}

// ━━━ 验收 16：two live schedulers sync independent of phase ━━━

/// 两个真实 SyncService + store + 接收器，随机错开周期，编辑后 10 秒内同步。
#[test]
fn two_live_schedulers_sync_independent_of_phase() {
    rt().block_on(async {
        let (mut a, a_store, mut b, b_store) = pair_up(
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
        )
        .await;

        a.start_receiver(a_store.clone()).await.unwrap();
        b.start_receiver(b_store.clone()).await.unwrap();

        // 编辑发生在任意时刻（模拟用户编辑，不等待周期对齐）
        a.create_note("n1".to_string(), "# Phase-free\n\nbody")
            .unwrap();
        // 编辑保存即推送
        let results = a.push_pending(&a_store).await;
        assert!(results.iter().any(|r| r.ok), "push 应成功: {results:?}");

        // B 在 10 秒内看到 A 的笔记（接收器持续接收，与周期相位无关）
        let deadline = tokio::time::Instant::now() + Duration::from_secs(10);
        loop {
            if b.get_note("n1").is_some() {
                break;
            }
            if tokio::time::Instant::now() >= deadline {
                panic!("编辑后 10 秒内 B 应同步到 A 的笔记");
            }
            tokio::time::sleep(Duration::from_millis(100)).await;
        }
        assert_eq!(b.get_note("n1").as_deref(), Some("# Phase-free\n\nbody"));

        // 反向：B 编辑 → A 10 秒内可见
        b.create_note("n2".to_string(), "# Reverse\n\nbody")
            .unwrap();
        let results = b.push_pending(&b_store).await;
        assert!(results.iter().any(|r| r.ok));
        let deadline = tokio::time::Instant::now() + Duration::from_secs(10);
        loop {
            if a.get_note("n2").is_some() {
                break;
            }
            if tokio::time::Instant::now() >= deadline {
                panic!("反向编辑后 10 秒内 A 应同步到 B 的笔记");
            }
            tokio::time::sleep(Duration::from_millis(100)).await;
        }
        assert_eq!(a.get_note("n2").as_deref(), Some("# Reverse\n\nbody"));

        a.stop_receiver().await.unwrap();
        b.stop_receiver().await.unwrap();
        drop((b, b_store, a_store));
    });
}
