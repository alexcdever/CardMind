// input: 应用级配置初始化参数、池用例 API 与卡片用例 API 的调用参数。
// output: 断言入池自动挂接已有笔记，且池上下文更新笔记不会产生重复 note 引用。
// pos: 覆盖无句柄池笔记挂接规则场景的回归测试。修改本文件需同步更新文件头与所属 DIR.md。
use cardmind_rust::api::{
    create_card_note, create_card_note_in_pool, create_pool, get_pool_detail, init_app_config,
    join_pool, reset_app_config_for_tests, update_card_note,
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
fn join_pool_should_attach_existing_notes_including_soft_deleted()
-> Result<(), Box<dyn std::error::Error>> {
    let _guard = app_config_test_guard().lock().unwrap();
    reset_app_config()?;
    let dir = tempdir()?;
    init_app_config(dir.path().to_string_lossy().to_string())?;

    let active = create_card_note("active".to_string(), "body".to_string())?;
    let deleted = create_card_note("deleted".to_string(), "body".to_string())?;
    let _deleted = update_card_note(
        deleted.id.clone(),
        "deleted".to_string(),
        "body-updated".to_string(),
    )?;
    let pool = create_pool(
        "endpoint-a".to_string(),
        "nick-a".to_string(),
        "macos".to_string(),
    )?;

    let _joined = join_pool(
        pool.id.clone(),
        "endpoint-b".to_string(),
        "nick-b".to_string(),
        "ios".to_string(),
    )?;
    let detail = get_pool_detail(pool.id.clone())?;

    assert_eq!(detail.note_ids.len(), 2);
    assert!(detail.note_ids.contains(&active.id));
    assert!(detail.note_ids.contains(&deleted.id));

    reset_app_config()?;
    Ok(())
}

#[test]
fn update_card_should_not_create_duplicate_note_reference() -> Result<(), Box<dyn std::error::Error>>
{
    let _guard = app_config_test_guard().lock().unwrap();
    reset_app_config()?;
    let dir = tempdir()?;
    init_app_config(dir.path().to_string_lossy().to_string())?;

    let pool = create_pool(
        "endpoint-a".to_string(),
        "nick-a".to_string(),
        "macos".to_string(),
    )?;
    let created =
        create_card_note_in_pool(pool.id.clone(), "title".to_string(), "body".to_string())?;
    let _updated = update_card_note(
        created.id.clone(),
        "title-2".to_string(),
        "body-2".to_string(),
    )?;
    let detail = get_pool_detail(pool.id.clone())?;

    assert_eq!(detail.note_ids, vec![created.id]);

    reset_app_config()?;
    Ok(())
}
