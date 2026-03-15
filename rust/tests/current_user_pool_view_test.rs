// input: 应用级配置初始化参数、建池/入池 API 调用参数，以及当前调用者视角的 joined pool 查询请求。
// output: 断言 joined pool 视图中的 current_user_role 以后端当前调用者身份为准，而不是成员顺序近似。
// pos: 覆盖 joined pool 当前用户角色真实性的后端契约测试。修改本文件需同步更新文件头与所属 DIR.md。
use cardmind_rust::api::{create_pool, init_app_config, join_by_code, reset_app_config_for_tests};
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
fn joined_pool_view_should_return_current_user_role_for_calling_endpoint()
-> Result<(), Box<dyn std::error::Error>> {
    let _guard = app_config_test_guard().lock().unwrap();
    reset_app_config()?;
    let dir = tempdir()?;
    init_app_config(dir.path().to_string_lossy().to_string())?;

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
