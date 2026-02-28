// input: 两份 LoroDoc 文档状态、snapshot/updates 导出结果与导入调用。
// output: 断言增量同步可成功导入，且仅在 pending 为 Some 时断言其为空。
// pos: 覆盖 Loro 快照与增量同步工具链场景的回归测试。修改本文件需同步更新文件头与所属 DIR.md。
use cardmind_rust::net::sync::{export_snapshot, export_updates, import_updates};
use loro::LoroDoc;

#[test]
fn it_should_export_snapshot_and_updates() -> Result<(), Box<dyn std::error::Error>> {
    let a = LoroDoc::new();
    a.get_text("t").insert(0, "hi")?;
    a.commit();
    let snap = export_snapshot(&a)?;
    let b = LoroDoc::from_snapshot(&snap)?;

    b.get_text("t").insert(2, "!")?;
    b.commit();
    let updates = export_updates(&b, &a.oplog_vv())?;
    let status = import_updates(&a, &updates)?;
    if let Some(pending) = status.pending {
        assert!(pending.is_empty());
    }
    Ok(())
}
