use cardmind_backend::store::NoteStore;
use cardmind_backend::sync::SyncService;

/// 两个 SyncService 实例的完整同步流程测试
///
/// 覆盖：
/// - 创建笔记 → 导出 → 导入对端
/// - 修改笔记 → 再次导出 → 对端看到更新
/// - 数据完整性：未修改的笔记不受影响
#[test]
fn test_full_sync_flow() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        // 1. 创建设备 A 和 B
        let mut svc_a = SyncService::new().await.unwrap();
        let mut svc_b = SyncService::new().await.unwrap();

        // 2. A 创建 2 条笔记
        svc_a.create_note("note-1".into(), "# 标题一\n\n内容A");
        svc_a.create_note("note-2".into(), "# 标题二\n\n内容B");

        // 3. A 导出 → B 导入
        let data = svc_a.export_all().unwrap();
        svc_b.import_all(&data).unwrap();

        // 4. 验证 B 拿到笔记
        assert_eq!(
            svc_b.get_note("note-1"),
            Some("# 标题一\n\n内容A".into())
        );
        assert_eq!(
            svc_b.get_note("note-2"),
            Some("# 标题二\n\n内容B".into())
        );

        // 5. A 修改一条笔记
        svc_a
            .update_note("note-1", "# 标题一（改）\n\n新内容")
            .unwrap();

        // 6. 再次导出 → B 导入
        let data2 = svc_a.export_all().unwrap();
        svc_b.import_all(&data2).unwrap();

        // 7. 验证 B 看到更新
        assert_eq!(
            svc_b.get_note("note-1"),
            Some("# 标题一（改）\n\n新内容".into())
        );

        // 8. 数据完整性：note-2 仍然存在且内容不变
        assert_eq!(
            svc_b.get_note("note-2"),
            Some("# 标题二\n\n内容B".into())
        );
    });
}

/// NoteStore + NoteCrdt 集成测试
///
/// 验证：
/// - NoteCrdt 的内容正确写入 SQLite 读投影
/// - list_notes 返回的标题正确提取（去除 "# " 前缀）
/// - sync_note 幂等写入
#[test]
fn test_store_integration() {
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let store = NoteStore::new(":memory:").unwrap();
        let crdt = cardmind_backend::sync::NoteCrdt::new();
        crdt.set_content("# 测试\n\n内容");

        store.sync_note("n1", &crdt).unwrap();
        let rows = store.list_notes().unwrap();
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0].id, "n1");
        assert_eq!(rows[0].title, "测试");

        // 幂等性：再次同步不应报错
        store.sync_note("n1", &crdt).unwrap();
        let rows2 = store.list_notes().unwrap();
        assert_eq!(rows2.len(), 1);
        assert_eq!(rows2[0].id, "n1");
    });
}
