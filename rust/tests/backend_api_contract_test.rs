// input: 后端句柄初始化参数与 create/list/get/update 用例 API 的调用参数。
// output: 断言 pool/card 用例 API 返回稳定 DTO，且查询结果与写入结果一致。
// pos: 覆盖后端用例 API 契约场景的回归测试。修改本文件需同步更新文件头与所属 DIR.md。
use cardmind_rust::api::{
    close_card_store, create_card_note, create_pool, get_card_note_detail, get_pool_detail,
    init_card_store, list_card_notes, list_pools, update_card_note,
};
use tempfile::tempdir;

#[test]
fn create_pool_should_return_stable_pool_dto() -> Result<(), Box<dyn std::error::Error>> {
    let dir = tempdir()?;
    let store_id = init_card_store(dir.path().to_string_lossy().to_string())?;

    let created = create_pool(
        store_id,
        "endpoint-a".to_string(),
        "nick-a".to_string(),
        "macos".to_string(),
    )?;
    let listed = list_pools(store_id)?;
    let detail = get_pool_detail(store_id, created.id.clone())?;

    assert_eq!(created.name, "nick-a's pool");
    assert!(!created.id.is_empty());
    assert_eq!(created.current_user_role, "admin");
    assert_eq!(created.member_count, 1);
    assert_eq!(listed.len(), 1);
    assert_eq!(listed[0].id, created.id);
    assert_eq!(detail.id, created.id);
    assert_eq!(detail.note_ids.len(), 0);

    close_card_store(store_id)?;
    Ok(())
}

#[test]
fn create_card_note_should_return_stable_card_dto() -> Result<(), Box<dyn std::error::Error>> {
    let dir = tempdir()?;
    let store_id = init_card_store(dir.path().to_string_lossy().to_string())?;

    let created = create_card_note(store_id, "title".to_string(), "body".to_string())?;
    let listed = list_card_notes(store_id)?;
    let updated = update_card_note(
        store_id,
        created.id.clone(),
        "title-2".to_string(),
        "body-2".to_string(),
    )?;
    let detail = get_card_note_detail(store_id, created.id.clone())?;

    assert!(!created.id.is_empty());
    assert_eq!(created.title, "title");
    assert_eq!(created.content, "body");
    assert!(!created.deleted);
    assert_eq!(listed.len(), 1);
    assert_eq!(listed[0].id, created.id);
    assert_eq!(updated.title, "title-2");
    assert_eq!(detail.id, created.id);
    assert_eq!(detail.title, "title-2");
    assert_eq!(detail.content, "body-2");

    close_card_store(store_id)?;
    Ok(())
}
