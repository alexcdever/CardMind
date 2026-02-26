// input: 临时目录与 PoolStore
// output: 池创建与读取行为验证
// pos: PoolStore 持久化测试（修改本文件需同步更新文件头与所属 DIR.md）
use cardmind_rust::store::pool_store::PoolStore;
use tempfile::tempdir;

#[test]
fn it_should_create_and_read_pool() -> Result<(), Box<dyn std::error::Error>> {
    let dir = tempdir()?;
    let store = PoolStore::new(dir.path().to_string_lossy().as_ref())?;
    let pool = store.create_pool("key", "endpoint", "nickname", "os")?;
    let loaded = store.get_pool(&pool.pool_id)?;
    assert_eq!(loaded.pool_key, "key");
    assert_eq!(loaded.members.len(), 1);
    assert_eq!(loaded.members[0].endpoint_id, "endpoint");
    assert_eq!(loaded.members[0].nickname, "nickname");
    assert_eq!(loaded.members[0].os, "os");
    assert!(loaded.members[0].is_admin);
    Ok(())
}
