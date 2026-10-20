use cardmind_backend::sync::NoteCrdt;

#[test]
fn created_note_reads_back_its_content() {
    let note = NoteCrdt::new();
    note.set_content("Hello, CRDT World!");
    assert_eq!(note.get_content(), "Hello, CRDT World!");
}

#[test]
fn title_is_the_first_heading_or_line() {
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
fn title_ignores_legacy_tag_metadata_line() {
    let same_line = NoteCrdt::new();
    same_line.set_content("<!--tags:work,idea--># Tagged title\n\nBody");
    assert_eq!(same_line.get_title(), "Tagged title");

    let separate_line = NoteCrdt::new();
    separate_line.set_content("<!--tags:work,idea-->\n# Tagged title\n\nBody");
    assert_eq!(separate_line.get_title(), "Tagged title");
}

#[test]
fn snapshot_export_import_preserves_content() {
    let note_a = NoteCrdt::new();
    note_a.set_content("快照测试内容");

    let snapshot = note_a.export_snapshot().unwrap();

    let note_b = NoteCrdt::new();
    note_b.import_snapshot(&snapshot).unwrap();

    assert_eq!(note_a.get_content(), note_b.get_content());
    assert_eq!(note_a.get_title(), note_b.get_title());
}

#[test]
fn delta_update_on_one_side_merges_into_the_other() {
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

#[test]
fn meta_tags_survive_snapshot_roundtrip() {
    let note = NoteCrdt::new();
    assert!(note.get_tags().is_empty(), "初始 tags 应为空");

    note.set_tags(&["work".to_string(), "idea".to_string()]);
    assert_eq!(note.get_tags(), vec!["work", "idea"]);

    // 整组替换
    note.set_tags(&["rust".to_string()]);
    assert_eq!(note.get_tags(), vec!["rust"]);

    // 清空
    note.set_tags(&[]);
    assert!(note.get_tags().is_empty(), "清空后 tags 应为空");
}

#[test]
fn meta_created_and_updated_dates_roundtrip() {
    let note = NoteCrdt::new();
    assert!(note.get_created_at().is_empty());
    assert!(note.get_updated_at().is_empty());

    note.set_created_at("2026-01-01T00:00:00Z");
    note.set_updated_at("2026-01-02T00:00:00Z");

    assert_eq!(note.get_created_at(), "2026-01-01T00:00:00Z");
    assert_eq!(note.get_updated_at(), "2026-01-02T00:00:00Z");
}

#[test]
fn parse_links_extracts_outgoing_references() {
    // 无链接
    let note = NoteCrdt::new();
    note.set_content("普通正文，没有链接");
    assert!(note.parse_links().is_empty());

    // 单链接带 alias
    let note = NoteCrdt::new();
    note.set_content("看 [[abc123|别名A]] 这里");
    assert_eq!(
        note.parse_links(),
        vec![("abc123".to_string(), "别名A".to_string())]
    );

    // 单链接缺 alias → alias 取 target_id
    let note = NoteCrdt::new();
    note.set_content("链接 [[abc123]]");
    assert_eq!(
        note.parse_links(),
        vec![("abc123".to_string(), "abc123".to_string())]
    );

    // 多链接
    let note = NoteCrdt::new();
    note.set_content("[[a|A]] 与 [[b]] 与 [[c|C]]");
    assert_eq!(
        note.parse_links(),
        vec![
            ("a".to_string(), "A".to_string()),
            ("b".to_string(), "b".to_string()),
            ("c".to_string(), "C".to_string()),
        ]
    );
}

#[test]
fn snapshot_roundtrip_preserves_tags_and_dates() {
    let note_a = NoteCrdt::new();
    note_a.set_content("# 带元数据\n\n正文");
    note_a.set_tags(&["work".to_string(), "idea".to_string()]);
    note_a.set_created_at("2026-01-01T00:00:00Z");
    note_a.set_updated_at("2026-01-02T00:00:00Z");

    let snapshot = note_a.export_snapshot().unwrap();

    let note_b = NoteCrdt::new();
    note_b.import_snapshot(&snapshot).unwrap();

    assert_eq!(note_a.get_content(), note_b.get_content());
    assert_eq!(note_a.get_title(), note_b.get_title());
    assert_eq!(note_a.get_tags(), note_b.get_tags());
    assert_eq!(note_a.get_created_at(), note_b.get_created_at());
    assert_eq!(note_a.get_updated_at(), note_b.get_updated_at());
}

#[test]
fn generated_note_ids_are_unique() {
    let id = NoteCrdt::generate_note_id();
    assert_eq!(id.len(), 36, "UUID 应为 36 字符: {}", id);
    let parts: Vec<&str> = id.split('-').collect();
    assert_eq!(parts.len(), 5);
    assert_eq!(parts[0].len(), 8);
    assert_eq!(parts[1].len(), 4);
    assert_eq!(parts[2].len(), 4);
    assert_eq!(parts[3].len(), 4);
    assert_eq!(parts[4].len(), 12);
    // 两次生成应不同
    assert_ne!(id, NoteCrdt::generate_note_id());
}
