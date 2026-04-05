// input: app-level config 初始化路径与无句柄资源 API 调用。
// output: 断言 init_app_config 满足幂等/冲突语义，且未初始化前资源 API 返回稳定错误。
// pos: 覆盖 app config 初始化契约与无句柄 API 前置条件。修改本文件需同步更新文件头与所属 DIR.md。
use cardmind_rust::api::{init_app_config, list_card_notes, reset_app_config_for_tests};
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
fn init_app_config_should_be_idempotent_for_same_directory(
) -> Result<(), Box<dyn std::error::Error>> {
    let _guard = app_config_test_guard().lock().unwrap();
    reset_app_config()?;
    let dir = tempdir()?;
    let app_data_dir = dir.path().to_string_lossy().to_string();

    init_app_config(app_data_dir.clone())?;
    init_app_config(app_data_dir)?;

    reset_app_config()?;
    Ok(())
}

#[test]
#[serial]
fn init_app_config_should_fail_for_different_directory_after_configured(
) -> Result<(), Box<dyn std::error::Error>> {
    let _guard = app_config_test_guard().lock().unwrap();
    reset_app_config()?;
    let dir_a = tempdir()?;
    let dir_b = tempdir()?;

    init_app_config(dir_a.path().to_string_lossy().to_string())?;

    let error = init_app_config(dir_b.path().to_string_lossy().to_string()).unwrap_err();
    assert_eq!(error.code, "APP_CONFIG_CONFLICT");

    reset_app_config()?;
    Ok(())
}

#[test]
#[serial]
fn product_api_should_fail_before_app_config_is_initialized(
) -> Result<(), Box<dyn std::error::Error>> {
    let _guard = app_config_test_guard().lock().unwrap();
    reset_app_config()?;
    let error = list_card_notes().unwrap_err();
    assert_eq!(error.code, "APP_CONFIG_NOT_INITIALIZED");
    Ok(())
}
