// input: 应用级配置初始化参数、建池/入池 API 调用参数，以及带调用者身份的详情查询请求。
// output: 断言 pool detail 的 current_user_role 必须按调用者身份计算，而不是按成员顺序兜底。
// pos: 覆盖 pool detail caller-scoped 契约的后端测试。修改本文件需同步更新文件头与所属 DIR.md。
use cardmind_rust::api::{
    create_pool, get_pool_detail, init_app_config, join_by_code, reset_app_config_for_tests,
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
fn pool_detail_should_compute_current_user_role_from_calling_endpoint(
) -> Result<(), Box<dyn std::error::Error>> {
    let _guard = app_config_test_guard()
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner());
    reset_app_config()?;
    let dir = tempdir()?;
    init_app_config(dir.path().to_string_lossy().to_string())?;

    let pool = create_pool(
        "owner-endpoint".to_string(),
        "owner".to_string(),
        "macos".to_string(),
    )?;
    join_by_code(
        pool.id.clone(),
        "joiner-endpoint".to_string(),
        "joiner".to_string(),
        "ios".to_string(),
    )?;

    let owner_detail = get_pool_detail(pool.id.clone(), "owner-endpoint".to_string())?;
    let joiner_detail = get_pool_detail(pool.id.clone(), "joiner-endpoint".to_string())?;

    assert_eq!(owner_detail.current_user_role, "admin");
    assert_eq!(joiner_detail.current_user_role, "member");

    reset_app_config()?;
    Ok(())
}
