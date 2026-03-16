// input: 应用级配置初始化参数与无句柄 create/list/get/update 用例 API 的调用参数。
// output: 断言 pool/card 用例 API 返回稳定 DTO，且查询结果与写入结果一致。
// pos: 覆盖无句柄后端用例 API 契约场景的回归测试。修改本文件需同步更新文件头与所属 DIR.md。
use cardmind_rust::api::{
    create_card_note, create_pool, get_card_note_detail, get_pool_detail, init_app_config,
    list_card_notes, list_pools, reset_app_config_for_tests, update_card_note,
};
use std::sync::{Mutex, OnceLock};
use tempfile::tempdir;

fn app_config_test_guard() -> &'static Mutex<()> {
    static GUARD: OnceLock<Mutex<()>> = OnceLock::new();
    GUARD.get_or_init(|| Mutex::new(()))
}

fn reset_app_config() -> Result<(), Box<dyn std::error::Error>> {
    reset_app_config_for_tests()?;
    Ok(())
}

#[test]
fn create_pool_should_return_stable_pool_dto_without_store_handle()
-> Result<(), Box<dyn std::error::Error>> {
    let _guard = app_config_test_guard().lock().unwrap();
    reset_app_config()?;
    let dir = tempdir()?;
    init_app_config(dir.path().to_string_lossy().to_string())?;

    let created = create_pool(
        "endpoint-a".to_string(),
        "nick-a".to_string(),
        "macos".to_string(),
    )?;
    let listed = list_pools()?;
    let detail = get_pool_detail(created.id.clone(), "endpoint-a".to_string())?;

    assert_eq!(created.name, "nick-a's pool");
    assert!(!created.id.is_empty());
    assert_eq!(created.current_user_role, "admin");
    assert_eq!(created.member_count, 1);
    assert_eq!(listed.len(), 1);
    assert_eq!(listed[0].id, created.id);
    assert_eq!(detail.id, created.id);
    assert_eq!(detail.note_ids.len(), 0);

    reset_app_config()?;
    Ok(())
}

#[test]
fn create_card_note_should_return_stable_card_dto_without_store_handle()
-> Result<(), Box<dyn std::error::Error>> {
    let _guard = app_config_test_guard().lock().unwrap();
    reset_app_config()?;
    let dir = tempdir()?;
    init_app_config(dir.path().to_string_lossy().to_string())?;

    let created = create_card_note("title".to_string(), "body".to_string())?;
    let listed = list_card_notes()?;
    let updated = update_card_note(
        created.id.clone(),
        "title-2".to_string(),
        "body-2".to_string(),
    )?;
    let detail = get_card_note_detail(created.id.clone())?;

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

    reset_app_config()?;
    Ok(())
}
