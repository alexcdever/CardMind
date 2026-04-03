// input: 应用级配置初始化参数、建池/入池 API 调用参数，以及当前调用者视角的 joined pool 查询请求。
// output: 断言 joined pool 视图中的 current_user_role 以后端当前调用者身份为准，而不是成员顺序近似。
// pos: 覆盖 joined pool 当前用户角色真实性的后端契约测试。修改本文件需同步更新文件头与所属 DIR.md。
use cardmind_rust::api::{
    create_pool, get_joined_pool_view, init_app_config, join_by_code, list_pools,
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
fn joined_pool_view_should_return_current_user_role_for_calling_endpoint()
-> Result<(), Box<dyn std::error::Error>> {
    let _guard = app_config_test_guard()
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner());
    reset_app_config()?;
    let dir = tempdir()?;
    init_app_config(dir.path().to_string_lossy().to_string())?;
    unlock_app_lock()?;

    let pool = create_pool(
        "owner-endpoint".to_string(),
        "owner".to_string(),
        "macos".to_string(),
    )?;

    let joined = join_by_code(
        pool.id,
        "joiner-endpoint".to_string(),
        "joiner".to_string(),
        "ios".to_string(),
    )?;

    assert_eq!(joined.current_user_role, "member");

    reset_app_config()?;
    Ok(())
}

#[test]
#[serial]
fn joined_pool_view_should_fail_when_endpoint_is_not_a_member()
-> Result<(), Box<dyn std::error::Error>> {
    let _guard = app_config_test_guard()
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner());
    reset_app_config()?;
    let dir = tempdir()?;
    init_app_config(dir.path().to_string_lossy().to_string())?;
    unlock_app_lock()?;

    create_pool(
        "owner-endpoint".to_string(),
        "owner".to_string(),
        "macos".to_string(),
    )?;

    let error = get_joined_pool_view("unknown-endpoint".to_string())
        .expect_err("expected NOT_MEMBER for unknown caller");

    assert_eq!(error.code, "NOT_MEMBER");

    reset_app_config()?;
    Ok(())
}

#[test]
#[serial]
fn list_pools_should_return_current_user_role_for_calling_endpoint()
-> Result<(), Box<dyn std::error::Error>> {
    let _guard = app_config_test_guard()
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner());
    reset_app_config()?;
    let dir = tempdir()?;
    init_app_config(dir.path().to_string_lossy().to_string())?;
    unlock_app_lock()?;

    let pool = create_pool(
        "owner-endpoint".to_string(),
        "owner".to_string(),
        "macos".to_string(),
    )?;

    join_by_code(
        pool.id,
        "joiner-endpoint".to_string(),
        "joiner".to_string(),
        "ios".to_string(),
    )?;

    let owner_view = list_pools("owner-endpoint".to_string())?;
    let joiner_view = list_pools("joiner-endpoint".to_string())?;

    assert_eq!(owner_view.len(), 1);
    assert_eq!(owner_view[0].current_user_role, "admin");
    assert_eq!(joiner_view.len(), 1);
    assert_eq!(joiner_view[0].current_user_role, "member");

    reset_app_config()?;
    Ok(())
}
