// input: 临时数据库文件路径与 SqliteStore::new 初始化调用。
// output: 断言 SQLite 存储 schema 初始化完成并处于可用状态。
// pos: 覆盖 SQLite 存储基础建库初始化场景的回归测试。修改本文件需同步更新文件头与所属 DIR.md。
use cardmind_rust::store::sqlite_store::SqliteStore;
use tempfile::tempdir;

#[test]
fn it_should_init_schema() -> Result<(), Box<dyn std::error::Error>> {
    let dir = tempdir()?;
    let db_path = dir.path().join("cardmind.sqlite");
    let store = SqliteStore::new(&db_path)?;
    assert!(store.is_ready());
    Ok(())
}
