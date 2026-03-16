// 后端配置 API 契约测试
// 验证入口启用配置的默认行为和持久化语义

use std::path::Path;
use std::sync::Mutex;

static TEST_MUTEX: Mutex<()> = Mutex::new(());

fn init_app_config_for_test(path: &Path) {
    // 重置配置状态，然后初始化
    let _ = cardmind_rust::api::reset_app_config_for_tests();
    cardmind_rust::api::init_app_config(path.to_str().unwrap().to_string()).unwrap();
}

#[test]
fn backend_config_defaults_disable_optional_entries() {
    let _guard = TEST_MUTEX.lock().unwrap();
    let dir = tempfile::tempdir().unwrap();
    init_app_config_for_test(dir.path());

    let config = cardmind_rust::api::get_backend_config().unwrap();

    assert!(!config.http_enabled);
    assert!(!config.mcp_enabled);
    assert!(!config.cli_enabled);
}

#[test]
fn backend_config_update_persists_entry_flags() {
    let _guard = TEST_MUTEX.lock().unwrap();
    let dir = tempfile::tempdir().unwrap();
    init_app_config_for_test(dir.path());

    cardmind_rust::api::update_backend_config(true, false, true).unwrap();
    let reloaded = cardmind_rust::api::get_backend_config().unwrap();

    assert!(reloaded.http_enabled);
    assert!(!reloaded.mcp_enabled);
    assert!(reloaded.cli_enabled);
}
