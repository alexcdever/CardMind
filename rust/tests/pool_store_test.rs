// input: 临时目录环境与 PoolStore::new 初始化参数。
// output: 断言数据池存储实例可成功创建且初始化过程无错误。
// pos: 覆盖数据池存储基础初始化场景的回归测试。修改本文件需同步更新文件头与所属 DIR.md。
use cardmind_rust::store::pool_store::PoolStore;
use tempfile::tempdir;

#[test]
fn it_should_create_pool_store() -> Result<(), Box<dyn std::error::Error>> {
    let dir = tempdir()?;
    let _store = PoolStore::new(dir.path().to_string_lossy().as_ref())?;
    Ok(())
}
