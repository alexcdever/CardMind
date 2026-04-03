// input: 应用级配置初始化参数、建池/入池 API 调用参数，以及用于入池的已有卡片数据。
// output: 断言 join_by_code 返回真实后端结果，并自动挂接已有 noteId 与稳定错误语义。
// pos: 覆盖 joinByCode 无句柄后端主路径的回归测试。修改本文件需同步更新文件头与所属 DIR.md。
use cardmind_rust::api::{
    create_card_note, create_pool, get_pool_detail, init_app_config, join_by_code,
    reset_app_config_for_tests, setup_app_lock, verify_app_lock_with_pin,
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

fn unlock_app_lock() -> Result<(), Box<dyn std::error::Error>> {
    setup_app_lock("1234".to_string(), true)?;
    verify_app_lock_with_pin("1234".to_string())?;
    Ok(())
}

#[test]
#[serial]
fn join_by_code_should_return_backend_result_and_attach_existing_notes(
) -> Result<(), Box<dyn std::error::Error>> {
    let _guard = app_config_test_guard().lock().unwrap();
    reset_app_config()?;
    let dir = tempdir()?;
    init_app_config(dir.path().to_string_lossy().to_string())?;
    unlock_app_lock()?;

    let attached = create_card_note("attached".to_string(), "body".to_string())?;
    let pool = create_pool(
        "endpoint-a".to_string(),
        "nick-a".to_string(),
        "macos".to_string(),
    )?;

    let joined = join_by_code(
        pool.id.clone(),
        "endpoint-b".to_string(),
        "nick-b".to_string(),
        "ios".to_string(),
    )?;
    let detail = get_pool_detail(pool.id.clone(), "endpoint-a".to_string())?;

    assert_eq!(joined.id, pool.id);
    assert_eq!(joined.member_count, 2);
    assert!(detail.note_ids.contains(&attached.id));

    let timeout = join_by_code(
        "timeout".to_string(),
        "endpoint-c".to_string(),
        "nick-c".to_string(),
        "android".to_string(),
    )
    .unwrap_err();
    assert_eq!(timeout.code, "REQUEST_TIMEOUT");

    reset_app_config()?;
    Ok(())
}
