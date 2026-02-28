// input: 临时目录、CardStore 实例与创建后卡片 id 查询参数。
// output: 断言卡片可从 SQLite 持久化层读取且字段值正确。
// pos: 覆盖卡片存储创建后持久化读取场景的回归测试。修改本文件需同步更新文件头与所属 DIR.md。
use cardmind_rust::store::card_store::CardStore;
use tempfile::tempdir;

#[test]
fn it_should_create_and_read_card_from_sqlite() -> Result<(), Box<dyn std::error::Error>> {
    let dir = tempdir()?;
    let store = CardStore::new(dir.path().to_string_lossy().as_ref())?;
    let card = store.create_card("t", "c")?;
    let loaded = store.get_card(&card.id)?;
    assert_eq!(loaded.title, "t");
    Ok(())
}
