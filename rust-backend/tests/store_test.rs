use cardmind_backend::store::{LinkRow, NoteStore};
use cardmind_backend::sync::NoteCrdt;

#[test]
fn test_sync_and_list() {
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
fn test_search() {
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
fn test_outgoing_and_back_links() {
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
fn test_links_rebuilt_on_resync() {
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
fn test_search_notes_fts() {
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
fn test_auto_complete_and_tags() {
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
