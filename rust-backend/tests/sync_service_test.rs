use cardmind_backend::sync::SyncService;

/// 验证 SyncService 的序列化/反序列化逻辑
///
/// 创建两个 SyncService 实例 A 和 B。
/// A 创建一条笔记 → 导出全部 → B 导入 → 验证内容一致。
#[test]
fn test_export_import_roundtrip() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        // ━━━ 设备 A：创建笔记 ━━━
        let mut service_a = SyncService::new().await.unwrap();
        service_a.create_note("note-1".to_string(), "# 第一条笔记\n\n这是测试内容。");

        // ━━━ 导出全部 → B 导入 ━━━
        let exported = service_a.export_all().unwrap();
        assert!(!exported.is_empty(), "导出的数据不应为空");

        let mut service_b = SyncService::new().await.unwrap();
        service_b.import_all(&exported).unwrap();

        // ━━━ 验证 B 拿到了笔记 ━━━
        assert_eq!(
            service_a.get_note("note-1"),
            service_b.get_note("note-1"),
            "B 导入后应与 A 内容一致"
        );
        assert_eq!(
            service_b.get_note("note-1").unwrap(),
            "# 第一条笔记\n\n这是测试内容。"
        );
    });
}

/// 验证多条笔记的批量导入导出
#[test]
fn test_multiple_notes_roundtrip() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let mut service = SyncService::new().await.unwrap();
        service.create_note("a".to_string(), "笔记 A");
        service.create_note("b".to_string(), "笔记 B");
        service.create_note("c".to_string(), "笔记 C");

        let exported = service.export_all().unwrap();

        let mut imported = SyncService::new().await.unwrap();
        imported.import_all(&exported).unwrap();

        assert_eq!(imported.get_note("a").unwrap(), "笔记 A");
        assert_eq!(imported.get_note("b").unwrap(), "笔记 B");
        assert_eq!(imported.get_note("c").unwrap(), "笔记 C");
        assert!(imported.get_note("nonexistent").is_none());
    });
}

/// 验证空集合的导出导入
#[test]
fn test_empty_export_import() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let service = SyncService::new().await.unwrap();
        let exported = service.export_all().unwrap();
        assert!(exported.is_empty(), "无笔记时应导出空数据");

        let mut imported = SyncService::new().await.unwrap();
        imported.import_all(&exported).unwrap();
        // 验证没有崩溃
        assert!(imported.get_note("anything").is_none());
    });
}
