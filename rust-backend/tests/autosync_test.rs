//! 自动同步调度集成测试（任务 H）：
//! 1. 编辑保存即推送（决策 4）：A 编辑后触发调度推送，B accept/import 可见
//! 2. 周期拉取（决策 4）：周期任务运行后，B 上 A 之前创建的笔记可见
//! 3. 同步开关（决策 6 能力）：set_sync_allowed(false) 阻断推送，恢复后推送
//! 4. 待同步计数基础（模块 5 准备）：编辑后 pending >= 1，成功推送后归零
//! 5. 编辑不被网络阻塞：无对端可达时编辑 API 立即返回
//! 6. 推送失败静默（决策 18）：对端离线时编辑 + 推送无错误返回

use std::time::{Duration, Instant};

use cardmind_backend::store::NoteStore;
use cardmind_backend::sync::{PairingTarget, SyncService};

fn rt() -> tokio::runtime::Runtime {
    tokio::runtime::Runtime::new().unwrap()
}

/// 真实配对两个 SyncService（initiator ↔ confirmer），双方 paired_devices 互相包含。
///
/// 网络路径：initiator 经 confirmer.local_addrs() 直连（同网段场景）；配对成功后
/// confirm 方自动推送全量快照（决策 8），由 initiator accept 并丢弃。
/// 配对成功后两实例的 `peer_ips` 缓存均填充对端直连 IP（供后续 push 使用）。
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

// ━━━ 验收 1：编辑保存即推送 ━━━

#[test]
fn test_edit_triggers_push() {
    rt().block_on(async {
        let (mut a, a_store, mut b, b_store) = pair_up(
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
        )
        .await;

        // A 编辑（create_note）→ 触发推送待办
        a.create_note("n1".to_string(), "# Hello\n\nbody").unwrap();
        assert!(a.pending_sync_count() >= 1, "编辑后应有待同步笔记");

        // B 端周期 accept 监听中（模拟 B 的 accept + import 路径）
        let b_handle = tokio::spawn(async move {
            let data = b.accept_push().await.unwrap();
            b.import_all(&data).unwrap();
            b
        });

        // 调度器触发推送（编辑 API 返回后异步进行）
        let results = a.push_pending(&a_store).await;
        assert!(
            results.iter().any(|r| r.ok),
            "推送应成功，结果: {results:?}"
        );

        let b = b_handle.await.unwrap();
        assert_eq!(
            b.get_note("n1").as_deref(),
            Some("# Hello\n\nbody"),
            "B 应能看到 A 编辑后的新内容"
        );
        assert_eq!(a.pending_sync_count(), 0, "成功推送后待同步计数应归零");
        drop((b, b_store, a_store));
    });
}

// ━━━ 验收 2：周期拉取同步 ━━━

#[test]
fn test_periodic_pull_syncs_notes() {
    rt().block_on(async {
        let (mut a, a_store, mut b, b_store) = pair_up(
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
        )
        .await;

        // A 之前创建的笔记（未主动推送）
        a.create_note("n1".to_string(), "# From A\n\nperiodic body")
            .unwrap();

        // B 周期 accept 监听中（模拟 B 周期任务的 accept + import 阶段）
        let b_handle = tokio::spawn(async move {
            let data = b.accept_push().await.unwrap();
            b.import_all(&data).unwrap();
            b
        });

        // A 的周期任务运行：push 给所有对端 + 短窗口 accept 对端 push
        let result = a.run_sync_cycle(&a_store).await.unwrap();
        assert!(
            result.pushed_count >= 1,
            "周期任务应推送成功，结果: {result:?}"
        );

        let b = b_handle.await.unwrap();
        assert_eq!(
            b.get_note("n1").as_deref(),
            Some("# From A\n\nperiodic body"),
            "B 周期 accept + import 后应能看到 A 的笔记"
        );
        drop((b, b_store, a_store));
    });
}

// ━━━ 验收 3：同步开关阻断推送（决策 6 能力）━━━

#[test]
fn test_sync_disabled_blocks_push() {
    rt().block_on(async {
        let (mut a, a_store, mut b, b_store) = pair_up(
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
        )
        .await;

        // 关闭同步（移动端蜂窝网络场景）
        a.set_sync_allowed(false);
        assert!(!a.sync_allowed());

        // A 编辑：本地成功，但调度推送被跳过
        a.create_note("n1".to_string(), "# Blocked\n\nbody")
            .unwrap();
        assert!(a.pending_sync_count() >= 1, "编辑后应有待同步笔记");

        let results = a.push_pending(&a_store).await;
        assert!(results.is_empty(), "禁用时不应推送任何设备");
        assert!(
            a.pending_sync_count() >= 1,
            "禁用时推送被跳过，待同步计数应保留"
        );
        assert_eq!(b.get_note("n1"), None, "B 不应看到被禁用的推送");

        // 恢复同步（回到 WiFi）→ 推送成功
        a.set_sync_allowed(true);
        let b_handle = tokio::spawn(async move {
            let data = b.accept_push().await.unwrap();
            b.import_all(&data).unwrap();
            b
        });
        let results = a.push_pending(&a_store).await;
        assert!(results.iter().any(|r| r.ok), "恢复后推送应成功");
        let b = b_handle.await.unwrap();
        assert_eq!(b.get_note("n1").as_deref(), Some("# Blocked\n\nbody"));
        assert_eq!(a.pending_sync_count(), 0);
        drop((b, b_store, a_store));
    });
}

// ━━━ 验收 4：待同步计数跟踪 ━━━

#[test]
fn test_pending_count_tracks_unsynced() {
    rt().block_on(async {
        let (mut a, a_store, mut b, b_store) = pair_up(
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
        )
        .await;

        assert_eq!(a.pending_sync_count(), 0, "初始无待同步");

        a.create_note("n1".to_string(), "# One").unwrap();
        a.update_note("n1", "# One v2").unwrap();
        assert_eq!(a.pending_sync_count(), 1, "同笔记多次编辑计为 1 篇待同步");

        // 成功推送对端后归零
        let b_handle = tokio::spawn(async move {
            let data = b.accept_push().await.unwrap();
            b.import_all(&data).unwrap();
            b
        });
        let results = a.push_pending(&a_store).await;
        assert!(results.iter().any(|r| r.ok));
        let b = b_handle.await.unwrap();
        assert_eq!(a.pending_sync_count(), 0, "成功推送后待同步归零");
        assert_eq!(b.get_note("n1").as_deref(), Some("# One v2"));
        drop((b, b_store, a_store));
    });
}

// ━━━ 验收 5：编辑不被网络阻塞 ━━━

#[test]
fn test_edit_not_blocked_by_network() {
    rt().block_on(async {
        // 无配对设备、无对端可达
        let mut a = SyncService::new().await.unwrap();
        let a_store = NoteStore::new(":memory:").unwrap();

        let start = Instant::now();
        a.create_note("n1".to_string(), "# Fast\n\nlocal edit")
            .unwrap();
        let elapsed = start.elapsed();
        assert!(
            elapsed < Duration::from_secs(2),
            "编辑 API 应远快于推送超时(10s)，实际耗时 {elapsed:?}"
        );
        assert_eq!(a.get_note("n1").as_deref(), Some("# Fast\n\nlocal edit"));

        // 调度推送无设备：立即返回（不因网络等待）
        let start = Instant::now();
        let results = a.push_pending(&a_store).await;
        assert!(
            results.is_empty(),
            "无配对设备时推送结果应为空，实际: {results:?}"
        );
        assert!(start.elapsed() < Duration::from_secs(2));
        assert!(a.pending_sync_count() >= 1, "无对端时待同步保留");
    });
}

// ━━━ 验收 6：推送失败静默（决策 18）━━━

#[test]
fn test_push_failure_silent() {
    rt().block_on(async {
        let (mut a, a_store, b, _b_store) = pair_up(
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
        )
        .await;

        // 对端离线：B 被 drop（endpoint 关闭，A connect 不可达）
        drop(b);

        // 编辑成功（本地持久化）——编辑 API 不被网络阻塞（决策 4）
        let start = Instant::now();
        a.create_note("n1".to_string(), "# Silent\n\nbody").unwrap();
        let edit_elapsed = start.elapsed();
        assert!(
            edit_elapsed < Duration::from_secs(2),
            "编辑 API 应立即返回（不因网络等待），实际耗时 {edit_elapsed:?}"
        );

        // 调度推送：对端不可达 → 失败记录在结果中，但不向调用方返回错误（决策 18 静默）。
        // push_to_paired_devices 单台超时 10s 为既有设计；编辑 API 在前已返回，
        // 调度推送在后台异步进行，UI 不感知失败。
        let results = a.push_pending(&a_store).await;
        assert!(
            results.iter().all(|r| !r.ok) || results.is_empty(),
            "对端离线时推送应失败或为空，结果: {results:?}"
        );
        assert!(
            a.pending_sync_count() >= 1,
            "推送失败后待同步保留（等待下个周期兜底）"
        );
    });
}

// ━━━ M2 回归：推送帧首字节与配对帧标记 0x01 冲突（墓碑数=1 时）━━━

/// 复现 reviewer M2：网络推送发送的是 `export_all()` 输出（无 envelope 前缀），
/// 其首 4 字节 = `tombstones.len() as u32` LE。当推送方有 1 个墓碑（或 257/513…）
/// 时首字节 = 0x01 = PAIRING_FRAME_REQUEST——旧路由用单字节判定，推送帧被误判为
/// 配对帧 → decode_pairing_request 失败 → 数据丢弃且 pending 被错误清空。
/// 修复后：推送帧在网络上带 8 字节 CARDMIND magic 前缀，路由按 magic 判定，
/// 推送 payload 不再与配对帧标记冲突。
#[test]
fn test_push_with_tombstone_not_misrouted() {
    rt().block_on(async {
        let (mut a, a_store, mut b, b_store) = pair_up(
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
        )
        .await;

        // A：创建 2 篇 → 彻底删除 1 篇（tombstones=1 → 推送 payload 首字节 0x01）
        a.create_note("keep-note".to_string(), "# Keep\n\nbody")
            .unwrap();
        a.create_note("del-note".to_string(), "# Delete me\n\nbody")
            .unwrap();
        a.soft_delete_note("del-note").unwrap();
        a.purge_note("del-note").unwrap();
        assert!(
            a.tombstones().contains("del-note"),
            "前置：A 应有墓碑 del-note"
        );
        // 红验证关键前置：确认 export_all 首字节确为 0x01（触发 M2 的诱因）
        let exported = a.export_all().unwrap();
        assert_eq!(
            exported[0], 0x01,
            "前置：墓碑数=1 时推送 payload 首字节应为 0x01（= PAIRING_FRAME_REQUEST）"
        );

        // B 接受推送并导入
        let b_handle = tokio::spawn(async move {
            let data = b.accept_push().await.unwrap();
            b.import_all(&data).unwrap();
            b
        });

        let results = a.push_pending(&a_store).await;
        assert!(
            results.iter().any(|r| r.ok),
            "推送应成功（数据被 B 消费），结果: {results:?}"
        );
        let b = b_handle.await.unwrap();

        // M2 核心断言：推送未被误判为配对帧，数据正确导入、删除传播
        assert_eq!(
            b.get_note("keep-note").as_deref(),
            Some("# Keep\n\nbody"),
            "B 应看到 A 剩余的笔记（推送不得被误判丢弃）"
        );
        assert_eq!(
            b.get_note("del-note"),
            None,
            "删除应传播（墓碑阻止被删笔记复活）"
        );
        assert!(b.tombstones().contains("del-note"), "墓碑应传播到 B");
        assert_eq!(a.pending_sync_count(), 0, "推送被正确消费后 pending 归零");
        drop((b, b_store, a_store));
    });
}

/// 复现需决策点 3 的遗漏方向：B 处于 accept_pairing_request 轮询等待（等待新设备 C
/// 配对）时，已配对设备 A 恰好推送数据。配对等待器抢到的是**推送帧**——修复前
/// `let _ =` 丢弃导致 A 推送被"消费"（连接被 accept 并关闭 → A 判定成功 → 清空
/// pending），但 B 实际没导入数据；修复后 B 应立即 import_all。
// ━━━ M1 回归：配对等待期间的对端推送不丢失 ━━━
#[test]
fn test_pairing_wait_does_not_drop_push() {
    rt().block_on(async {
        let (mut a, a_store, mut b, b_store) = pair_up(
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
            SyncService::new().await.unwrap(),
            NoteStore::new(":memory:").unwrap(),
        )
        .await;

        // B 准备接受新配对（设备 C 加入）：先生成配对码，再进入配对等待轮询
        let code = b.begin_pairing_accept().unwrap();
        let b_id = b.device_id();
        let b_ips = b.local_addrs();
        let b_handle = tokio::spawn(async move {
            let request = b.accept_pairing_request().await.unwrap();
            (b, request)
        });

        // 已配对设备 A 在 B 配对等待期间推送 → 推送帧被配对等待器抢到 → 应导入而非丢弃
        a.create_note("n1".to_string(), "# During pairing wait\n\nbody")
            .unwrap();
        let results = a.push_pending(&a_store).await;
        assert!(
            results.iter().any(|r| r.ok),
            "A 的推送应成功（连接被 B 消费并导入），结果: {results:?}"
        );
        assert_eq!(a.pending_sync_count(), 0, "A 的推送被消费后 pending 清空");

        // 新设备 C 发起配对 → 结束 B 的 accept_pairing_request（拿到 C 的请求）
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

        let (b, request) = b_handle.await.unwrap();
        let confirm = b.confirm_pairing(&b_store, &code, &request).await.unwrap();
        let (c, c_store, connect) = c_handle.await.unwrap();

        // 配对流程正常完成（B 的配对等待没有被推送帧破坏）
        assert_eq!(confirm.peer_id, c.device_id());
        assert_eq!(confirm.peer_name, "New Phone");
        assert_eq!(connect.peer_id, b.device_id());

        // M1 核心断言：配对等待期间被抢到的推送数据已导入 B，未丢失
        assert_eq!(
            b.get_note("n1").as_deref(),
            Some("# During pairing wait\n\nbody"),
            "配对等待期间 A 推送的数据必须被导入，不得被静默吞掉"
        );
        drop((c, c_store, a_store, b_store));
    });
}
