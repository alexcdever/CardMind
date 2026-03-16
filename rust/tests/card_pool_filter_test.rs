// input: 应用级配置初始化参数、多个池的卡片数据
// output: 断言 query_card_notes 支持按 pool_id 筛选
// pos: 覆盖按池筛选卡片查询的后端契约测试

use cardmind_rust::api::{
    create_card_note_in_pool, create_pool, delete_card_note, init_app_config, query_card_notes,
    reset_app_config_for_tests,
};
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
fn query_card_notes_should_filter_by_pool_id() -> Result<(), Box<dyn std::error::Error>> {
    let _guard = app_config_test_guard().lock().unwrap();
    reset_app_config()?;
    let dir = tempdir()?;
    init_app_config(dir.path().to_string_lossy().to_string())?;

    // 创建两个池
    let pool_a = create_pool(
        "endpoint-a".to_string(),
        "owner-a".to_string(),
        "macos".to_string(),
    )?;
    let pool_b = create_pool(
        "endpoint-b".to_string(),
        "owner-b".to_string(),
        "macos".to_string(),
    )?;

    // 在 pool_a 创建卡片
    let card_a1 = create_card_note_in_pool(
        pool_a.id.clone(),
        "Card A1".to_string(),
        "Body A1".to_string(),
    )?;
    let card_a2 = create_card_note_in_pool(
        pool_a.id.clone(),
        "Card A2".to_string(),
        "Body A2".to_string(),
    )?;

    // 在 pool_b 创建卡片
    let card_b1 = create_card_note_in_pool(
        pool_b.id.clone(),
        "Card B1".to_string(),
        "Body B1".to_string(),
    )?;

    // 测试：筛选 pool_a
    let pool_a_cards = query_card_notes("".to_string(), Some(pool_a.id.clone()), Some(false))?;
    assert_eq!(pool_a_cards.len(), 2);
    assert!(pool_a_cards.iter().any(|c| c.id == card_a1.id));
    assert!(pool_a_cards.iter().any(|c| c.id == card_a2.id));
    assert!(!pool_a_cards.iter().any(|c| c.id == card_b1.id));

    // 测试：筛选 pool_b
    let pool_b_cards = query_card_notes("".to_string(), Some(pool_b.id.clone()), Some(false))?;
    assert_eq!(pool_b_cards.len(), 1);
    assert!(pool_b_cards.iter().any(|c| c.id == card_b1.id));

    // 测试：不筛选（全部）
    let all_cards = query_card_notes("".to_string(), None, Some(false))?;
    assert_eq!(all_cards.len(), 3);

    // 测试：软删除卡片筛选
    // 软删除 pool_a 的一张卡片
    delete_card_note(card_a1.id.clone())?;
    // 默认查询（不含软删除）应只返回 1 张
    let pool_a_active = query_card_notes("".to_string(), Some(pool_a.id.clone()), Some(false))?;
    assert_eq!(pool_a_active.len(), 1);
    assert!(!pool_a_active.iter().any(|c| c.id == card_a1.id));
    // 包含软删除的查询应返回 2 张
    let pool_a_with_deleted =
        query_card_notes("".to_string(), Some(pool_a.id.clone()), Some(true))?;
    assert_eq!(pool_a_with_deleted.len(), 2);

    reset_app_config()?;
    Ok(())
}

// 临时辅助函数桩，返回空 Vec 使测试可编译
// 将在 Task 1.2 Step 3 替换为实际 API: query_card_notes("...", Some(pool_id), Some(false))
fn query_card_notes_filtered(
    _pool_id: &str,
) -> Result<Vec<cardmind_rust::api::CardNoteDto>, Box<dyn std::error::Error>> {
    Ok(vec![])
}

// 临时辅助函数桩（含软删除），将在 Task 1.2 Step 3 替换为实际 API: query_card_notes("...", Some(pool_id), Some(true))
fn query_card_notes_filtered_with_deleted(
    _pool_id: &str,
) -> Result<Vec<cardmind_rust::api::CardNoteDto>, Box<dyn std::error::Error>> {
    Ok(vec![])
}
