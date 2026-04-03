// input: app config 初始化参数与网络资源初始化参数。
// output: 断言应用配置替代 card store handle 生命周期，且网络句柄仍可初始化并关闭。
// pos: 覆盖 app config 生命周期替代旧 handle 机制的回归测试。修改本文件需同步更新文件头与所属 DIR.md。
use cardmind_rust::api::{
    close_pool_network, init_app_config, init_pool_network, reset_app_config_for_tests,
    setup_app_lock, verify_app_lock_with_pin,
};
use serial_test::serial;
use std::sync::{Mutex, OnceLock};
use tempfile::tempdir;

fn app_config_test_guard() -> &'static Mutex<()> {
    static GUARD: OnceLock<Mutex<()>> = OnceLock::new();
    GUARD.get_or_init(|| Mutex::new(()))
}

#[test]
#[serial]
fn app_config_should_replace_card_store_handle_lifecycle() -> Result<(), Box<dyn std::error::Error>>
{
    let _guard = app_config_test_guard().lock().unwrap();
    reset_app_config_for_tests()?;
    let dir = tempdir()?;
    let app_data_dir = dir.path().to_string_lossy().to_string();

    init_app_config(app_data_dir.clone())?;
    init_app_config(app_data_dir)?;

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
fn it_should_init_and_close_pool_network() -> Result<(), Box<dyn std::error::Error>> {
    let _guard = app_config_test_guard().lock().unwrap();
    reset_app_config_for_tests()?;
    let dir = tempdir()?;
    let app_data_dir = dir.path().to_string_lossy().to_string();
    init_app_config(app_data_dir.clone())?;
    unlock_app_lock()?;
    let id = init_pool_network(app_data_dir)?;
    close_pool_network(id)?;
    Ok(())
}
