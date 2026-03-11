// input: 后端句柄初始化参数、池用例 API 与卡片用例 API 的调用参数。
// output: 断言入池自动挂接已有笔记，且池上下文更新笔记不会产生重复 note 引用。
// pos: 覆盖池笔记挂接规则场景的回归测试。修改本文件需同步更新文件头与所属 DIR.md。
use cardmind_rust::api::{
    close_card_store, create_card_note, create_card_note_in_pool, create_pool, get_pool_detail,
    init_card_store, join_pool, update_card_note,
};
use tempfile::tempdir;

#[test]
fn join_pool_should_attach_existing_notes_including_soft_deleted(
) -> Result<(), Box<dyn std::error::Error>> {
    let dir = tempdir()?;
    let store_id = init_card_store(dir.path().to_string_lossy().to_string())?;

    let active = create_card_note(store_id, "active".to_string(), "body".to_string())?;
    let deleted = create_card_note(store_id, "deleted".to_string(), "body".to_string())?;
    let _deleted = update_card_note(
        store_id,
        deleted.id.clone(),
        "deleted".to_string(),
        "body-updated".to_string(),
    )?;
    let pool = create_pool(
        store_id,
        "endpoint-a".to_string(),
        "nick-a".to_string(),
        "macos".to_string(),
    )?;

    let _joined = join_pool(
        store_id,
        pool.id.clone(),
        "endpoint-b".to_string(),
        "nick-b".to_string(),
        "ios".to_string(),
    )?;
    let detail = get_pool_detail(store_id, pool.id.clone())?;

    assert_eq!(detail.note_ids.len(), 2);
    assert!(detail.note_ids.contains(&active.id));
    assert!(detail.note_ids.contains(&deleted.id));

    close_card_store(store_id)?;
    Ok(())
}

#[test]
fn update_card_should_not_create_duplicate_note_reference() -> Result<(), Box<dyn std::error::Error>>
{
    let dir = tempdir()?;
    let store_id = init_card_store(dir.path().to_string_lossy().to_string())?;

    let pool = create_pool(
        store_id,
        "endpoint-a".to_string(),
        "nick-a".to_string(),
        "macos".to_string(),
    )?;
    let created = create_card_note_in_pool(
        store_id,
        pool.id.clone(),
        "title".to_string(),
        "body".to_string(),
    )?;
    let _updated = update_card_note(
        store_id,
        created.id.clone(),
        "title-2".to_string(),
        "body-2".to_string(),
    )?;
    let detail = get_pool_detail(store_id, pool.id.clone())?;

    assert_eq!(detail.note_ids, vec![created.id]);

    close_card_store(store_id)?;
    Ok(())
}
