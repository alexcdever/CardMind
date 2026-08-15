//! 回收站（软删除 / 恢复 / 彻底删除 / 过期清理）集成测试。
//!
//! 第一轮：覆盖任务单验收 1-5（store 独立删除）。
//! 第二轮：删除状态迁移到 Loro（SyncService.soft_delete_note / restore_note /
//! purge_note / purge_expired），SQLite 只做读投影；新增墓碑（tombstones）与
//! envelope v3 测试，覆盖第二轮验收标准 1-7。

use cardmind_backend::api::sync_notes_to_store;
use cardmind_backend::store::NoteStore;
use cardmind_backend::sync::{NoteCrdt, SyncService};
use chrono::{Duration, Utc};
use rusqlite::Connection;
use std::time::Duration as StdDuration;

/// 临时数据目录（测试结束清理）
fn temp_dir(label: &str) -> std::path::PathBuf {
    let path = std::env::temp_dir().join(format!("cardmind-trash2-{label}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&path);
    std::fs::create_dir_all(&path).unwrap();
    path
}

/// 向 v3 payload 追加一条笔记记录 `(id_len u32, id, snapshot_len u32, snapshot)`
fn push_record(buf: &mut Vec<u8>, id: &str, snapshot: &[u8]) {
    buf.extend_from_slice(&(id.len() as u32).to_le_bytes());
    buf.extend_from_slice(id.as_bytes());
    buf.extend_from_slice(&(snapshot.len() as u32).to_le_bytes());
    buf.extend_from_slice(snapshot);
}

/// 构造包含 N 条软删笔记的 v3 payload（墓碑 section 为空 + 记录流）
fn soft_deleted_payload(notes: &[(&str, &str, Option<String>)]) -> Vec<u8> {
    let mut payload = Vec::new();
    payload.extend_from_slice(&0u32.to_le_bytes()); // 墓碑数 = 0
    for (id, content, deleted_at) in notes {
        let note = NoteCrdt::new();
        note.set_content(content);
        note.set_deleted_at(deleted_at.clone());
        push_record(&mut payload, id, &note.export_snapshot().unwrap());
    }
    payload
}

// ═══ 第一轮验收（职责调整后：删除状态来自 Loro，SQLite 只做投影）═══

/// 验收 1：软删后投影 deleted_at 非空、主列表排除、回收站包含
#[test]
fn test_soft_delete_marks_deleted_at() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let dir = temp_dir("soft-delete");
        let mut svc = SyncService::new_persistent(&dir).await.unwrap();
        svc.create_note("n1".into(), "# 一\n\n内容一。").unwrap();
        let store = NoteStore::new(":memory:").unwrap();
        sync_notes_to_store(&svc, &store).unwrap();

        svc.soft_delete_note("n1").unwrap();
        sync_notes_to_store(&svc, &store).unwrap();

        assert!(
            store.deleted_at("n1").unwrap().is_some(),
            "软删后投影 deleted_at 应为非空"
        );
        let notes = store.list_notes().unwrap();
        assert!(
            notes.iter().all(|r| r.id != "n1"),
            "主列表不应包含已软删笔记"
        );
        let trash = store.trash_list().unwrap();
        assert_eq!(trash.len(), 1, "回收站应包含该笔记");
        assert_eq!(trash[0].id, "n1");
        let _ = std::fs::remove_dir_all(&dir);
    });
}

/// 验收 2：恢复后投影 deleted_at 为 NULL、主列表重新可见、回收站移除
#[test]
fn test_restore_clears_deleted_at() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let dir = temp_dir("restore");
        let mut svc = SyncService::new_persistent(&dir).await.unwrap();
        svc.create_note("n1".into(), "# 一\n\n内容一。").unwrap();
        let store = NoteStore::new(":memory:").unwrap();
        sync_notes_to_store(&svc, &store).unwrap();

        svc.soft_delete_note("n1").unwrap();
        sync_notes_to_store(&svc, &store).unwrap();
        assert!(
            !store.trash_list().unwrap().is_empty(),
            "前置：软删后进回收站"
        );

        svc.restore_note("n1").unwrap();
        sync_notes_to_store(&svc, &store).unwrap();

        assert!(
            store.deleted_at("n1").unwrap().is_none(),
            "恢复后投影 deleted_at 应为 NULL"
        );
        let notes = store.list_notes().unwrap();
        assert!(notes.iter().any(|r| r.id == "n1"), "恢复后主列表应重新可见");
        assert!(
            store.trash_list().unwrap().is_empty(),
            "回收站不应包含已恢复笔记"
        );
        let _ = std::fs::remove_dir_all(&dir);
    });
}

/// 验收 3：彻底删除移除投影行并级联删除该笔记的出链 links
#[test]
fn test_purge_removes_row_and_links() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let dir = temp_dir("purge-links");
        let mut svc = SyncService::new_persistent(&dir).await.unwrap();
        // note-a 正文含指向 note-b 的链接 → links 表有 (source=note-a, target=note-b)
        svc.create_note("note-a".into(), "# A\n\n指向 [[note-b|B 的别名]]")
            .unwrap();
        svc.create_note("note-b".into(), "# B\n\n正文").unwrap();
        let store = NoteStore::new(":memory:").unwrap();
        sync_notes_to_store(&svc, &store).unwrap();
        assert_eq!(
            store.outgoing_links("note-a").unwrap().len(),
            1,
            "前置：note-a 应有出链"
        );

        svc.purge_note("note-a").unwrap();
        sync_notes_to_store(&svc, &store).unwrap();

        assert!(
            store.list_notes().unwrap().iter().all(|r| r.id != "note-a"),
            "主列表不应包含已彻底删除的笔记"
        );
        assert!(
            store.trash_list().unwrap().iter().all(|r| r.id != "note-a"),
            "回收站不应包含已彻底删除的笔记"
        );
        assert!(
            store.outgoing_links("note-a").unwrap().is_empty(),
            "note-a 的出链 links 应级联删除"
        );
        let _ = std::fs::remove_dir_all(&dir);
    });
}

/// 验收 4：过期清理 — deleted_at 31 天前的被删，1 天前的保留（30 天边界）
#[test]
fn test_expired_trash_cleanup() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let dir = temp_dir("cleanup");
        let mut svc = SyncService::new_persistent(&dir).await.unwrap();
        let old = (Utc::now() - Duration::days(31)).to_rfc3339();
        let fresh = Utc::now().to_rfc3339();
        let payload = soft_deleted_payload(&[
            ("old", "# 旧\n\n内容", Some(old)),
            ("fresh", "# 新\n\n内容", Some(fresh)),
        ]);
        svc.import_all(&payload).unwrap();

        let cutoff = (Utc::now() - Duration::days(30)).to_rfc3339();
        let purged = svc.purge_expired(&cutoff).unwrap();
        assert_eq!(purged, 1, "应恰好清理 1 条过期笔记");

        let store = NoteStore::new(":memory:").unwrap();
        sync_notes_to_store(&svc, &store).unwrap();
        let trash = store.trash_list().unwrap();
        assert!(trash.iter().all(|r| r.id != "old"), "31 天前的笔记应被清理");
        assert!(trash.iter().any(|r| r.id == "fresh"), "1 天前的笔记应保留");
        let _ = std::fs::remove_dir_all(&dir);
    });
}

/// 验收 5：回收站按 deleted_at 倒序（后删的在前）
#[test]
fn test_trash_ordering() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let dir = temp_dir("trash-order");
        let mut svc = SyncService::new_persistent(&dir).await.unwrap();
        svc.create_note("n1".into(), "# 一\n\n内容").unwrap();
        svc.create_note("n2".into(), "# 二\n\n内容").unwrap();
        svc.create_note("n3".into(), "# 三\n\n内容").unwrap();
        let store = NoteStore::new(":memory:").unwrap();
        sync_notes_to_store(&svc, &store).unwrap();

        svc.soft_delete_note("n1").unwrap();
        std::thread::sleep(StdDuration::from_millis(5));
        svc.soft_delete_note("n2").unwrap();
        std::thread::sleep(StdDuration::from_millis(5));
        svc.soft_delete_note("n3").unwrap();
        sync_notes_to_store(&svc, &store).unwrap();

        let trash = store.trash_list().unwrap();
        let ids: Vec<&str> = trash.iter().map(|r| r.id.as_str()).collect();
        assert_eq!(
            ids,
            vec!["n3", "n2", "n1"],
            "trash_list 应按 deleted_at 倒序"
        );
        let _ = std::fs::remove_dir_all(&dir);
    });
}

/// 已有库迁移：旧 notes 表无 deleted_at 列时，打开后自动补列，投影可读写删除状态。
#[test]
fn test_migration_adds_deleted_at_column() {
    let db_path = temp_dir("migrate-column").join("cardmind.db");
    {
        // 模拟旧 schema（无 deleted_at 列）的已有库
        let conn = Connection::open(&db_path).unwrap();
        conn.execute_batch(
            "CREATE TABLE notes (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                content TEXT NOT NULL,
                tags TEXT NOT NULL DEFAULT '',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );",
        )
        .unwrap();
        conn.execute(
            "INSERT INTO notes (id, title, content, tags, created_at, updated_at)
             VALUES ('old-note', '旧标题', '旧正文', '', 't1', 't2')",
            [],
        )
        .unwrap();
    }

    // 打开后自动补 deleted_at 列
    let store = NoteStore::new(&db_path.to_string_lossy()).unwrap();
    assert!(
        store.deleted_at("old-note").unwrap().is_none(),
        "补列后旧行 deleted_at 应为 NULL"
    );

    // 旧库迁移后投影应能写入 deleted_at（NoteCrdt 软删 → sync_note）
    let crdt = NoteCrdt::new();
    crdt.set_content("# 旧标题\n\n旧正文");
    crdt.set_deleted_at(Some(Utc::now().to_rfc3339()));
    store.sync_note("old-note", &crdt).unwrap();
    assert!(
        store.deleted_at("old-note").unwrap().is_some(),
        "迁移后投影应能写入 deleted_at"
    );
    let trash = store.trash_list().unwrap();
    assert_eq!(trash.len(), 1);
    assert_eq!(trash[0].id, "old-note");

    // 恢复（crdt 清除 deleted_at → sync_note）也应可用
    crdt.set_deleted_at(None);
    store.sync_note("old-note", &crdt).unwrap();
    assert!(
        store.deleted_at("old-note").unwrap().is_none(),
        "迁移后投影应能清除 deleted_at"
    );
    assert_eq!(store.list_notes().unwrap().len(), 1);
    drop(store);
    let _ = std::fs::remove_dir_all(db_path.parent().unwrap());
}

// ═══ 第二轮验收 1：purge 后重建投影不复活（第一轮失败的场景反转）═══

#[test]
fn test_purge_persists_across_sync() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let dir = temp_dir("purge-sync");
        let mut svc = SyncService::new_persistent(&dir).await.unwrap();
        svc.create_note("n1".into(), "# One\n\nBody").unwrap();
        svc.create_note("n2".into(), "# Two\n\nBody").unwrap();
        let store = NoteStore::new(":memory:").unwrap();
        sync_notes_to_store(&svc, &store).unwrap();
        assert_eq!(
            store.list_notes().unwrap().len(),
            2,
            "前置：两篇笔记都在投影"
        );

        svc.purge_note("n1").unwrap();
        assert!(svc.get_note("n1").is_none(), "purge 后 Loro 中无该笔记");
        assert!(svc.tombstones().contains("n1"), "purge 后进入墓碑集合");

        // 重建投影：被删笔记不得复活
        sync_notes_to_store(&svc, &store).unwrap();
        let ids: Vec<String> = store
            .list_notes()
            .unwrap()
            .iter()
            .map(|r| r.id.clone())
            .collect();
        assert!(
            !ids.contains(&"n1".to_string()),
            "purge 后 sync_notes_to_store 重建投影不得复活 n1"
        );
        assert!(ids.contains(&"n2".to_string()), "其余笔记仍在投影");
        let _ = std::fs::remove_dir_all(&dir);
    });
}

// ═══ 第二轮验收 2：墓碑随快照传播 ═══

#[test]
fn test_tombstone_survives_export_import() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let dir_a = temp_dir("tomb-export");
        let mut a = SyncService::new_persistent(&dir_a).await.unwrap();
        a.create_note("n1".into(), "# One\n\nBody").unwrap();
        a.create_note("n2".into(), "# Two\n\nBody").unwrap();
        a.purge_note("n1").unwrap();
        let exported = a.export_all().unwrap();

        let dir_b = temp_dir("tomb-import");
        let mut b = SyncService::new_persistent(&dir_b).await.unwrap();
        b.import_all(&exported).unwrap();

        assert!(b.tombstones().contains("n1"), "导入后对端墓碑应含 n1");
        assert!(
            b.iter_notes().all(|(id, _)| id != "n1"),
            "导入后 iter_notes 不含 n1"
        );
        assert!(b.get_note("n2").is_some(), "其余笔记正常导入");
        let _ = std::fs::remove_dir_all(&dir_a);
        let _ = std::fs::remove_dir_all(&dir_b);
    });
}

// ═══ 第二轮验收 3：软删经 meta 传播 ═══

#[test]
fn test_soft_delete_propagates_via_meta() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let dir_a = temp_dir("soft-export");
        let mut a = SyncService::new_persistent(&dir_a).await.unwrap();
        a.create_note("n1".into(), "# One\n\nBody").unwrap();
        a.soft_delete_note("n1").unwrap();
        let exported = a.export_all().unwrap();

        let dir_b = temp_dir("soft-import");
        let mut b = SyncService::new_persistent(&dir_b).await.unwrap();
        b.import_all(&exported).unwrap();

        // 软删笔记仍在 notes HashMap（iter_notes 可见），仅 meta 标记
        assert!(b.get_note("n1").is_some(), "软删笔记应仍在 notes 中");
        assert!(b.tombstones().is_empty(), "软删不产生墓碑");

        // 投影：主列表不可见、回收站可见
        let store = NoteStore::new(":memory:").unwrap();
        sync_notes_to_store(&b, &store).unwrap();
        assert!(
            store.list_notes().unwrap().iter().all(|r| r.id != "n1"),
            "软删笔记投影后主列表不可见"
        );
        let trash = store.trash_list().unwrap();
        assert!(
            trash.iter().any(|r| r.id == "n1"),
            "软删笔记投影后回收站可见"
        );
        let _ = std::fs::remove_dir_all(&dir_a);
        let _ = std::fs::remove_dir_all(&dir_b);
    });
}

// ═══ 第二轮验收 4：恢复经 meta 传播 ═══

#[test]
fn test_restore_propagates_via_meta() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let dir_a = temp_dir("restore-export");
        let mut a = SyncService::new_persistent(&dir_a).await.unwrap();
        a.create_note("n1".into(), "# One\n\nBody").unwrap();
        a.soft_delete_note("n1").unwrap();
        a.restore_note("n1").unwrap();
        let exported = a.export_all().unwrap();

        let dir_b = temp_dir("restore-import");
        let mut b = SyncService::new_persistent(&dir_b).await.unwrap();
        b.import_all(&exported).unwrap();

        let store = NoteStore::new(":memory:").unwrap();
        sync_notes_to_store(&b, &store).unwrap();
        assert!(
            store.list_notes().unwrap().iter().any(|r| r.id == "n1"),
            "恢复后投影主列表可见"
        );
        assert!(
            store.trash_list().unwrap().iter().all(|r| r.id != "n1"),
            "恢复后回收站不可见"
        );
        let _ = std::fs::remove_dir_all(&dir_a);
        let _ = std::fs::remove_dir_all(&dir_b);
    });
}

// ═══ 第二轮验收 5：批量过期清理 ═══

#[test]
fn test_purge_expired_batch() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let dir = temp_dir("expired-batch");
        let mut svc = SyncService::new_persistent(&dir).await.unwrap();
        let old = (Utc::now() - Duration::days(31)).to_rfc3339();
        let recent = Utc::now().to_rfc3339();
        let payload = soft_deleted_payload(&[
            ("n1", "# 过期一\n\nBody", Some(old.clone())),
            ("n2", "# 过期二\n\nBody", Some(old)),
            ("n3", "# 未过期\n\nBody", Some(recent)),
        ]);
        svc.import_all(&payload).unwrap();

        let cutoff = (Utc::now() - Duration::days(30)).to_rfc3339();
        let purged = svc.purge_expired(&cutoff).unwrap();
        assert_eq!(purged, 2, "应清理 2 篇过期软删笔记");
        assert!(svc.tombstones().contains("n1"));
        assert!(svc.tombstones().contains("n2"));
        assert!(!svc.tombstones().contains("n3"), "未过期笔记不入墓碑");

        // 投影：trash_list 只剩未过期 1 篇
        let store = NoteStore::new(":memory:").unwrap();
        sync_notes_to_store(&svc, &store).unwrap();
        let trash = store.trash_list().unwrap();
        assert_eq!(trash.len(), 1, "trash_list 应剩 1 篇");
        assert_eq!(trash[0].id, "n3");
        let _ = std::fs::remove_dir_all(&dir);
    });
}

// ═══ 第二轮验收 6：v2 文件无损升级 ═══

#[test]
fn test_v2_file_loads_without_tombstones() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let dir = temp_dir("v2-file");
        let loro_file = dir.join("cardmind.loro");
        // 手工构造 v2 envelope：magic + version=2 + payload=纯记录流（无墓碑 section）
        let note = NoteCrdt::new();
        note.set_content("# V2\n\n旧格式正文");
        let mut payload = Vec::new();
        push_record(&mut payload, "v2-note", &note.export_snapshot().unwrap());
        let mut bytes = Vec::new();
        bytes.extend_from_slice(b"CARDMIND");
        bytes.extend_from_slice(&2u32.to_le_bytes());
        bytes.extend_from_slice(&(payload.len() as u64).to_le_bytes());
        bytes.extend_from_slice(&payload);
        std::fs::write(&loro_file, &bytes).unwrap();

        let svc = SyncService::new_persistent(&dir).await.unwrap();
        assert!(svc.tombstones().is_empty(), "v2 文件加载后墓碑应为空");
        assert_eq!(
            svc.get_note("v2-note").as_deref(),
            Some("# V2\n\n旧格式正文"),
            "v2 数据完整（无损升级）"
        );
        let _ = std::fs::remove_dir_all(&dir);
    });
}

// ═══ 第二轮验收 7：导入时墓碑 id 的记录被跳过（不复活）═══

#[test]
fn test_tombstoned_id_skipped_on_import() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let dir = temp_dir("skip-import");
        let mut b = SyncService::new_persistent(&dir).await.unwrap();
        // 手工构造 v3 payload：墓碑 section 含 ghost + 记录流同时含 ghost 与 alive
        let mut payload = Vec::new();
        payload.extend_from_slice(&1u32.to_le_bytes()); // 墓碑数 = 1
        let ghost = b"ghost";
        payload.extend_from_slice(&(ghost.len() as u32).to_le_bytes());
        payload.extend_from_slice(ghost);
        let ghost_note = NoteCrdt::new();
        ghost_note.set_content("# Ghost\n\n旧的残留");
        push_record(
            &mut payload,
            "ghost",
            &ghost_note.export_snapshot().unwrap(),
        );
        let alive_note = NoteCrdt::new();
        alive_note.set_content("# Alive\n\n还在");
        push_record(
            &mut payload,
            "alive",
            &alive_note.export_snapshot().unwrap(),
        );

        b.import_all(&payload).unwrap();

        assert!(b.tombstones().contains("ghost"), "墓碑 id 应进入墓碑集合");
        assert!(
            b.get_note("ghost").is_none(),
            "墓碑 id 的记录不得在导入时复活"
        );
        assert!(b.get_note("alive").is_some(), "非墓碑记录正常导入");
        let _ = std::fs::remove_dir_all(&dir);
    });
}
