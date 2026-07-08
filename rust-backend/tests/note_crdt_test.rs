use cardmind_backend::sync::NoteCrdt;

#[test]
fn test_create_and_read() {
    let note = NoteCrdt::new();
    note.set_content("Hello, CRDT World!");
    assert_eq!(note.get_content(), "Hello, CRDT World!");
}

#[test]
fn test_title_extraction() {
    let note = NoteCrdt::new();
    note.set_content("# 我的标题\n\n正文内容");
    assert_eq!(note.get_title(), "我的标题");

    // 二级标题
    let note2 = NoteCrdt::new();
    note2.set_content("## 二级标题\n正文");
    assert_eq!(note2.get_title(), "二级标题");

    // 无标题前缀
    let note3 = NoteCrdt::new();
    note3.set_content("纯文本行\n正文");
    assert_eq!(note3.get_title(), "纯文本行");
}

#[test]
fn test_snapshot_roundtrip() {
    let note_a = NoteCrdt::new();
    note_a.set_content("快照测试内容");

    let snapshot = note_a.export_snapshot().unwrap();

    let note_b = NoteCrdt::new();
    note_b.import_snapshot(&snapshot).unwrap();

    assert_eq!(note_a.get_content(), note_b.get_content());
    assert_eq!(note_a.get_title(), note_b.get_title());
}

#[test]
fn test_delta_sync() {
    // A 创建并设置初始内容
    let a = NoteCrdt::new();
    a.set_content("初始内容");

    // 导出快照，B 导入
    let delta1 = a.export_snapshot().unwrap();
    let b = NoteCrdt::new();
    b.import_snapshot(&delta1).unwrap();
    assert_eq!(a.get_content(), b.get_content());

    // A 修改内容
    a.set_content("修改后的内容");

    // 导出全量快照，B 导入后应一致
    let delta2 = a.export_snapshot().unwrap();
    b.import_snapshot(&delta2).unwrap();
    assert_eq!(a.get_content(), b.get_content());
}
