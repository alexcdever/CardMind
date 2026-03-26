// input: 应用级配置初始化参数，以及卡片创建/删除/恢复与查询 API 的调用参数。
// output: 断言 delete/restore 经由无句柄后端 API 往返后，查询结果真实反映 deleted 状态变化。
// pos: 覆盖卡片删除与恢复主路径的后端回归测试。修改本文件需同步更新文件头与所属 DIR.md。
use cardmind_rust::api::{
    create_card_note, delete_card_note, get_card_note_detail, init_app_config, list_card_notes,
    reset_app_config_for_tests, restore_card_note,
};
use serial_test::serial;
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
#[serial]
fn delete_and_restore_card_should_roundtrip_through_backend_api(
) -> Result<(), Box<dyn std::error::Error>> {
    let _guard = app_config_test_guard().lock().unwrap();
    reset_app_config()?;
    let dir = tempdir()?;
    init_app_config(dir.path().to_string_lossy().to_string())?;

    let created = create_card_note("title".to_string(), "body".to_string())?;

    delete_card_note(created.id.clone())?;
    let deleted_detail = get_card_note_detail(created.id.clone())?;
    let deleted_list = list_card_notes()?;

    restore_card_note(created.id.clone())?;
    let restored_detail = get_card_note_detail(created.id.clone())?;
    let restored_list = list_card_notes()?;

    assert!(deleted_detail.deleted);
    assert!(deleted_list
        .iter()
        .any(|item| item.id == created.id && item.deleted));
    assert!(!restored_detail.deleted);
    assert!(restored_list
        .iter()
        .any(|item| item.id == created.id && !item.deleted));

    reset_app_config()?;
    Ok(())
}
