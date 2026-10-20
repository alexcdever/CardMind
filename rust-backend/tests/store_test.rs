mod common;

use cardmind_backend::store::{LinkRow, NoteStore};
use cardmind_backend::sync::NoteCrdt;
use rusqlite::Connection;

#[test]
fn paired_devices_schema_migration_keeps_online_semantics() {
    let path =
        std::env::temp_dir().join(format!("cardmind-store-migration-{}", std::process::id()));
    let _ = std::fs::remove_file(&path);
    let conn = Connection::open(&path).unwrap();
    conn.execute_batch(
        "CREATE TABLE paired_devices (
            peer_id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            last_seen TEXT NULL,
            paired_at TEXT NOT NULL
        );
        INSERT INTO paired_devices(peer_id, name, last_seen, paired_at)
        VALUES ('legacy-peer', 'Legacy', '2026-01-01T00:00:00Z', '2025-12-01T00:00:00Z');",
    )
    .unwrap();
    drop(conn);

    let store = NoteStore::new(&path.to_string_lossy()).unwrap();
    let row = store.list_paired_devices().unwrap().pop().unwrap();
    assert_eq!(row.peer_id, "legacy-peer");
    assert_eq!(row.last_seen.as_deref(), Some("2026-01-01T00:00:00Z"));
    assert!(
        row.last_sync_at.is_none(),
        "legacy rows have no sync timestamp"
    );

    store.update_last_seen("legacy-peer").unwrap();
    let after_check = store.list_paired_devices().unwrap().pop().unwrap();
    assert!(after_check.last_seen.is_some());
    assert!(
        after_check.last_sync_at.is_none(),
        "connectivity check does not mean sync"
    );

    store.update_last_sync_at("legacy-peer").unwrap();
    let after_sync = store.list_paired_devices().unwrap().pop().unwrap();
    assert!(after_sync.last_seen.is_some());
    assert_eq!(after_sync.last_seen, after_sync.last_sync_at);

    store
        .update_paired_device_ips(
            "legacy-peer",
            &["127.0.0.1:1234".to_string(), "192.168.1.2:5678".to_string()],
        )
        .unwrap();
    drop(store);
    let reopened = NoteStore::new(&path.to_string_lossy()).unwrap();
    assert_eq!(
        reopened.paired_device_ips("legacy-peer").unwrap(),
        vec!["127.0.0.1:1234", "192.168.1.2:5678"]
    );

    let _ = std::fs::remove_file(path);
}

#[test]
fn synced_notes_list_in_expected_order() {
    // 使用内存数据库
    let store = NoteStore::new(":memory:").unwrap();

    // 创建笔记并通过 NoteCrdt 填充内容
    let note = NoteCrdt::new();
    note.set_content("# 测试笔记\n\n这是一条测试内容。");
    store.sync_note("note-1", &note).unwrap();

    // 第二条笔记
    let note2 = NoteCrdt::new();
    note2.set_content("# 第二条笔记\n\n更多内容……");
    store.sync_note("note-2", &note2).unwrap();

    // 列出所有笔记
    let notes = store.list_notes().unwrap();
    assert_eq!(notes.len(), 2, "应有 2 条笔记");

    // 按 updated_at DESC，所以 note-2 在前
    assert_eq!(notes[0].id, "note-2");
    assert_eq!(notes[0].title, "第二条笔记");
    assert!(notes[0].content_preview.starts_with("更多内容"));

    assert_eq!(notes[1].id, "note-1");
    assert_eq!(notes[1].title, "测试笔记");

    // 更新笔记后重新同步
    note.set_content("# 测试笔记(已更新)\n\n更新后的内容。");
    store.sync_note("note-1", &note).unwrap();

    let notes = store.list_notes().unwrap();
    assert_eq!(notes.len(), 2, "更新不改变笔记数量");
    // note-1 现在 updated_at 更新，排到前面
    assert_eq!(notes[0].id, "note-1");
    assert_eq!(notes[0].title, "测试笔记(已更新)");
}

#[test]
fn search_matches_note_content() {
    let store = NoteStore::new(":memory:").unwrap();

    // 三条笔记
    let note1 = NoteCrdt::new();
    note1.set_content("# Rust 笔记\n\n所有权与借用规则。");
    store.sync_note("note-1", &note1).unwrap();

    let note2 = NoteCrdt::new();
    note2.set_content("# Python 笔记\n\n列表推导与生成器。");
    store.sync_note("note-2", &note2).unwrap();

    let note3 = NoteCrdt::new();
    note3.set_content("# Rust 异步\n\nTokio 运行时基础。");
    store.sync_note("note-3", &note3).unwrap();

    // 搜索 "Rust" → 期望 note-1, note-3
    let results = store.search("Rust").unwrap();
    assert_eq!(results.len(), 2, "搜索 'Rust' 应返回 2 条");
    let ids: Vec<&str> = results.iter().map(|r| r.id.as_str()).collect();
    assert!(ids.contains(&"note-1"));
    assert!(ids.contains(&"note-3"));

    // 搜索 "Python" → 期望 note-2
    let results = store.search("Python").unwrap();
    assert_eq!(results.len(), 1, "搜索 'Python' 应返回 1 条");
    assert_eq!(results[0].id, "note-2");

    // 搜索 "不存在的笔记" → 0 条
    let results = store.search("不存在的").unwrap();
    assert!(results.is_empty(), "不存在的关键词应返回 0 条");
}

#[test]
fn link_index_tracks_outgoing_and_back_links() {
    let store = NoteStore::new(":memory:").unwrap();

    let note_a = NoteCrdt::new();
    note_a.set_content("# A\n\n链接到 [[note-b|B 的别名]] 和 [[note-c]]");
    store.sync_note("note-a", &note_a).unwrap();

    let note_b = NoteCrdt::new();
    note_b.set_content("# B 标题\n\n正文");
    store.sync_note("note-b", &note_b).unwrap();

    // 出链：note-a → note-b（存在）、note-c（悬空）
    let out = store.outgoing_links("note-a").unwrap();
    assert_eq!(out.len(), 2);
    let by_id: std::collections::HashMap<&str, &LinkRow> =
        out.iter().map(|l| (l.id.as_str(), l)).collect();
    assert_eq!(by_id["note-b"].title, "B 标题");
    assert_eq!(by_id["note-b"].alias, "B 的别名");
    assert!(by_id["note-b"].exists, "note-b 存在，exists 应为 true");
    assert_eq!(by_id["note-c"].alias, "note-c", "alias 缺省应取 target_id");
    assert!(!by_id["note-c"].exists, "note-c 不存在，exists 应为 false");

    // 反链：指向 note-b 的是 note-a
    let back = store.backlinks("note-b").unwrap();
    assert_eq!(back.len(), 1);
    assert_eq!(back[0].id, "note-a");
    assert_eq!(back[0].title, "A");
    assert_eq!(back[0].alias, "B 的别名");
    assert!(back[0].exists);

    // 无链接笔记出链为空
    assert!(store.outgoing_links("note-b").unwrap().is_empty());
}

#[test]
fn resync_rebuilds_the_link_index() {
    let store = NoteStore::new(":memory:").unwrap();
    let note = NoteCrdt::new();
    note.set_content("[[old-target]]");
    store.sync_note("note-a", &note).unwrap();
    assert_eq!(store.outgoing_links("note-a").unwrap().len(), 1);

    // 更新正文后重新同步，链接索引应重建（旧链接消失）
    note.set_content("[[new-target]]");
    store.sync_note("note-a", &note).unwrap();
    let out = store.outgoing_links("note-a").unwrap();
    assert_eq!(out.len(), 1);
    assert_eq!(out[0].id, "new-target");
}

#[test]
fn full_text_search_returns_matching_notes() {
    let store = NoteStore::new(":memory:").unwrap();

    let note1 = NoteCrdt::new();
    note1.set_tags(&["work".to_string(), "idea".to_string()]);
    note1.set_content("# Rust 笔记\n\n所有权与借用规则。");
    store.sync_note("note-1", &note1).unwrap();

    let note2 = NoteCrdt::new();
    note2.set_content("# Python 笔记\n\n列表推导。");
    store.sync_note("note-2", &note2).unwrap();

    // 3+ 字符走 FTS5，命中 content，snippet 非空
    let results = store.search_notes("所有权").unwrap();
    assert_eq!(results.len(), 1);
    assert_eq!(results[0].id, "note-1");
    assert!(!results[0].content_preview.is_empty(), "snippet 不应为空");

    // 不命中
    let results = store.search_notes("不存在的词xyz").unwrap();
    assert!(results.is_empty());

    // 2 字符回退 LIKE，preview 来自正文
    let results = store.search_notes("所有").unwrap();
    assert_eq!(results.len(), 1);
    assert_eq!(results[0].id, "note-1");
    assert!(
        results[0].content_preview.contains("所有权"),
        "LIKE 回退 preview 应含匹配词"
    );
}

#[test]
fn tag_autocomplete_returns_matching_tags() {
    let store = NoteStore::new(":memory:").unwrap();

    let note1 = NoteCrdt::new();
    note1.set_tags(&["work".to_string(), "idea".to_string()]);
    note1.set_content("# Alpha 笔记\n\n正文");
    store.sync_note("note-1", &note1).unwrap();

    let note2 = NoteCrdt::new();
    note2.set_tags(&["idea".to_string(), "rust".to_string()]);
    note2.set_content("# Beta 笔记\n\n正文");
    store.sync_note("note-2", &note2).unwrap();

    let note3 = NoteCrdt::new();
    note3.set_content("# Gamma\n\n正文");
    store.sync_note("note-3", &note3).unwrap();

    // 链接自动补全：标题前缀
    let results = store.auto_complete_links("Al").unwrap();
    assert_eq!(results.len(), 1);
    assert_eq!(results[0].id, "note-1");
    assert_eq!(results[0].title, "Alpha 笔记");

    // 全部标签：去重 + 按名称排序
    let tags = store.get_all_tags().unwrap();
    assert_eq!(tags, vec!["idea", "rust", "work"]);

    // 按标签搜索
    let results = store.search_by_tag("idea").unwrap();
    assert_eq!(results.len(), 2);
    let ids: Vec<&str> = results.iter().map(|r| r.id.as_str()).collect();
    assert!(ids.contains(&"note-1"));
    assert!(ids.contains(&"note-2"));

    let results = store.search_by_tag("work").unwrap();
    assert_eq!(results.len(), 1);
    assert_eq!(results[0].id, "note-1");
}

// ═══ legacy_notes（零覆盖补测）═══

/// 直接以 `Connection` 预置两条 `updated_at` 不同的行：验证 `legacy_notes`
/// 返回 `(id, content)` 的内容与 `ORDER BY updated_at ASC` 顺序（更早的在前）。
#[test]
fn legacy_notes_list_by_updated_at_ascending() {
    let dir = common::temp_dir("legacy-notes-order");
    let path = dir.join("cardmind.db");
    let path_str = path.to_string_lossy().to_string();
    let store = NoteStore::new(&path_str).unwrap();

    {
        let conn = Connection::open(&path).unwrap();
        conn.execute(
            "INSERT INTO notes (id, title, content, tags, created_at, updated_at, deleted_at)
             VALUES (?1, ?2, ?3, '', ?4, ?5, NULL)",
            rusqlite::params![
                "note-newer",
                "较新",
                "较新的正文",
                "2026-01-02T00:00:00Z",
                "2026-01-02T00:00:00Z"
            ],
        )
        .unwrap();
        conn.execute(
            "INSERT INTO notes (id, title, content, tags, created_at, updated_at, deleted_at)
             VALUES (?1, ?2, ?3, '', ?4, ?5, NULL)",
            rusqlite::params![
                "note-older",
                "较旧",
                "较旧的正文",
                "2026-01-01T00:00:00Z",
                "2026-01-01T00:00:00Z"
            ],
        )
        .unwrap();
    }

    // 插入顺序是「新 → 旧」，但 ASC 顺序要求「旧 → 新」，可区分排序是否真的生效。
    let notes = store.legacy_notes().unwrap();
    assert_eq!(
        notes,
        vec![
            ("note-older".to_string(), "较旧的正文".to_string()),
            ("note-newer".to_string(), "较新的正文".to_string()),
        ],
        "legacy_notes 应按 updated_at ASC 返回 (id, content)"
    );

    let _ = std::fs::remove_dir_all(&dir);
}

/// 对照腿：空库（无任何 notes 行）时 `legacy_notes` 返回空 `Vec`。
#[test]
fn legacy_notes_on_empty_store_is_empty() {
    let dir = common::temp_dir("legacy-notes-empty");
    let path = dir.join("cardmind.db");
    let path_str = path.to_string_lossy().to_string();
    let store = NoteStore::new(&path_str).unwrap();

    let notes = store.legacy_notes().unwrap();
    assert!(notes.is_empty(), "空库应返回空 Vec，实际 {:?}", notes);

    // 软删（deleted_at 非空）的行仍在 legacy 全量里：迁移要带上回收站内容。
    {
        let conn = Connection::open(&path).unwrap();
        conn.execute(
            "INSERT INTO notes (id, title, content, tags, created_at, updated_at, deleted_at)
             VALUES (?1, ?2, ?3, '', ?4, ?5, ?6)",
            rusqlite::params![
                "note-deleted",
                "已删",
                "已删的正文",
                "2026-01-03T00:00:00Z",
                "2026-01-03T00:00:00Z",
                "2026-01-04T00:00:00Z"
            ],
        )
        .unwrap();
    }
    let after = store.legacy_notes().unwrap();
    assert_eq!(
        after,
        vec![("note-deleted".to_string(), "已删的正文".to_string())],
        "legacy_notes 不过滤 deleted_at（全量迁移）"
    );

    let _ = std::fs::remove_dir_all(&dir);
}

// ═══ is_paired_device（零覆盖补测）═══

/// 两腿：未配对的 peer_id → false；`upsert_paired_device` 之后同一 peer_id → true。
/// 另加一条反向腿：只有被 upsert 的那个 peer 为 true，其余 peer 仍为 false。
#[test]
fn is_paired_device_flips_false_to_true_after_upsert() {
    let store = NoteStore::new(":memory:").unwrap();

    assert!(
        !store.is_paired_device("peer-a").unwrap(),
        "空库中任何 peer 都未配对"
    );

    store.upsert_paired_device("peer-a", "设备 A").unwrap();

    assert!(
        store.is_paired_device("peer-a").unwrap(),
        "upsert 后该 peer 应判为已配对"
    );
    assert!(
        !store.is_paired_device("peer-b").unwrap(),
        "未 upsert 的 peer 仍应判为未配对"
    );

    // 重新打开（非内存库）：未配对库上应为 false，upsert 后跨重开仍为 true。
    let dir = common::temp_dir("is-paired-device");
    let path = dir.join("cardmind.db");
    let path_str = path.to_string_lossy().to_string();
    let disk = NoteStore::new(&path_str).unwrap();
    assert!(
        !disk.is_paired_device("peer-a").unwrap(),
        "全新磁盘库中 peer 尚未配对"
    );
    disk.upsert_paired_device("peer-a", "设备 A").unwrap();
    drop(disk);

    let reopened = NoteStore::new(&path_str).unwrap();
    assert!(
        reopened.is_paired_device("peer-a").unwrap(),
        "配对状态应跨重开持久化"
    );

    let _ = std::fs::remove_dir_all(&dir);
}
