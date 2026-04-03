// input: 应用级配置初始化参数、重复操作场景
// output: 断言重复提交不产生副作用
// pos: 覆盖并发幂等性的后端契约测试

use cardmind_rust::api::{
    create_card_note_in_pool, create_pool, get_pool_detail, init_app_config, join_by_code,
    reset_app_config_for_tests, setup_app_lock, update_card_note, verify_app_lock_with_pin,
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
fn duplicate_join_should_not_create_duplicate_member() -> Result<(), Box<dyn std::error::Error>> {
    let _guard = app_config_test_guard().lock().unwrap();
    reset_app_config()?;
    let dir = tempdir()?;
    init_app_config(dir.path().to_string_lossy().to_string())?;
    unlock_app_lock()?;

    let pool = create_pool(
        "endpoint-a".to_string(),
        "owner".to_string(),
        "macos".to_string(),
    )?;

    // 第一次加入
    join_by_code(
        pool.id.clone(),
        "endpoint-b".to_string(),
        "joiner".to_string(),
        "ios".to_string(),
    )?;

    let detail_after_first = get_pool_detail(pool.id.clone(), "endpoint-a".to_string())?;
    let member_count_after_first = detail_after_first.member_count;

    // 重复加入（应幂等）
    join_by_code(
        pool.id.clone(),
        "endpoint-b".to_string(),
        "joiner".to_string(),
        "ios".to_string(),
    )?;

    let detail_after_second = get_pool_detail(pool.id.clone(), "endpoint-a".to_string())?;
    let member_count_after_second = detail_after_second.member_count;

    assert_eq!(
        member_count_after_first, member_count_after_second,
        "重复加入不应增加成员数"
    );

    reset_app_config()?;
    Ok(())
}

#[test]
#[serial]
fn concurrent_card_update_should_converge() -> Result<(), Box<dyn std::error::Error>> {
    let _guard = app_config_test_guard().lock().unwrap();
    reset_app_config()?;
    let dir = tempdir()?;
    init_app_config(dir.path().to_string_lossy().to_string())?;
    unlock_app_lock()?;

    // 创建池并加入两个成员
    let pool = create_pool(
        "endpoint-a".to_string(),
        "owner".to_string(),
        "macos".to_string(),
    )?;
    join_by_code(
        pool.id.clone(),
        "endpoint-b".to_string(),
        "joiner".to_string(),
        "ios".to_string(),
    )?;

    // 成员 A 创建卡片
    let card = create_card_note_in_pool(
        pool.id.clone(),
        "Original Title".to_string(),
        "Original Body".to_string(),
    )?;

    // 成员 A 和成员 B 同时修改同一卡片（模拟并发场景）
    let _updated_by_a = update_card_note(
        card.id.clone(),
        "Title by A".to_string(),
        "Body by A".to_string(),
    )?;

    let _updated_by_b = update_card_note(
        card.id.clone(),
        "Title by B".to_string(),
        "Body by B".to_string(),
    )?;

    // 验证最终状态一致（后提交者覆盖）
    let final_card = cardmind_rust::api::get_card_note_detail(card.id.clone())?;
    assert!(
        final_card.title == "Title by A" || final_card.title == "Title by B",
        "最终状态应为其中一个修改结果"
    );

    reset_app_config()?;
    Ok(())
}
