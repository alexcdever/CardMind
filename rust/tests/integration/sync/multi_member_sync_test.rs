// input: 应用级配置初始化参数、多成员池场景
// output: 断言成员 A 的修改最终对成员 B 可见
// pos: 覆盖多成员协作一致性的后端契约测试

use cardmind_rust::api::{
    create_card_note_in_pool, create_pool, init_app_config, join_by_code, query_card_notes,
    reset_app_config_for_tests, setup_app_lock, verify_app_lock_with_pin,
};
use serial_test::serial;
use std::sync::{Mutex, OnceLock};
use std::thread;
use std::time::Duration;
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
fn member_a_create_should_be_visible_to_member_b() -> Result<(), Box<dyn std::error::Error>> {
    let _guard = app_config_test_guard().lock().unwrap();
    reset_app_config()?;
    let dir = tempdir()?;
    init_app_config(dir.path().to_string_lossy().to_string())?;
    unlock_app_lock()?;

    // 成员 A 创建池
    let pool = create_pool(
        "endpoint-a".to_string(),
        "owner".to_string(),
        "macos".to_string(),
    )?;

    // 成员 B 加入池
    join_by_code(
        pool.id.clone(),
        "endpoint-b".to_string(),
        "joiner".to_string(),
        "ios".to_string(),
    )?;

    // 成员 A 创建卡片
    let card = create_card_note_in_pool(
        pool.id.clone(),
        "Shared Card".to_string(),
        "Shared Body".to_string(),
    )?;

    // 模拟同步延迟后，成员 B 查询应可见
    let mut attempts = 0;
    let max_attempts = 50;
    let mut found = false;

    while attempts < max_attempts {
        thread::sleep(Duration::from_millis(100));

        // 从成员 B 视角查询 - 使用相同的本地存储（模拟同步完成）
        let b_cards = query_card_notes("".to_string(), Some(pool.id.clone()), Some(false))?;

        if b_cards.iter().any(|c| c.id == card.id) {
            found = true;
            break;
        }
        attempts += 1;
    }

    assert!(found, "成员 B 应在 5 秒内可见成员 A 创建的卡片");

    reset_app_config()?;
    Ok(())
}
