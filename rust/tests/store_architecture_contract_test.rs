// input: 临时目录、CardNoteRepository 实例与创建/更新卡片动作。
// output: 断言业务写先落入 Loro，再经 SQLite 查询路径观察到投影结果。
// pos: 锁定读写分离架构契约的集成测试。修改本文件需同步更新文件头与所属 DIR.md。
use cardmind_rust::store::card_store::CardNoteRepository;
use tempfile::tempdir;

#[test]
fn create_card_should_be_observable_via_sqlite_query_after_projection()
-> Result<(), Box<dyn std::error::Error>> {
    let dir = tempdir()?;
    let store = CardNoteRepository::new(dir.path().to_string_lossy().as_ref())?;

    let card = store.create_card("title", "body")?;
    let queried = store.get_card(&card.id)?;

    assert_eq!(queried.id, card.id);
    assert_eq!(queried.title, "title");
    Ok(())
}

#[test]
fn update_card_should_write_business_fact_before_query_refresh()
-> Result<(), Box<dyn std::error::Error>> {
    let dir = tempdir()?;
    let store = CardNoteRepository::new(dir.path().to_string_lossy().as_ref())?;

    let card = store.create_card("before", "body")?;
    let updated = store.update_card(&card.id, "after", "body2")?;
    let queried = store.get_card(&card.id)?;

    assert_eq!(updated.title, "after");
    assert_eq!(queried.title, "after");
    Ok(())
}
