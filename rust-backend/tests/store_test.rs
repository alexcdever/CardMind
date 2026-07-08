use cardmind_backend::store::NoteStore;
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
    assert!(notes[0].content_preview.starts_with("# 第二条笔记"));

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
