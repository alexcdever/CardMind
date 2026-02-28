// input: rust/tests/pool_sync_test.rs 上游输入（用户操作、外部参数或依赖返回）。
// output: 对外状态更新、返回结果或副作用（保持行为不变）。
// pos: Rust 测试模块，验证关键行为、边界条件与错误路径。 修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：Rust 测试模块，验证关键行为、边界条件与错误路径。
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
