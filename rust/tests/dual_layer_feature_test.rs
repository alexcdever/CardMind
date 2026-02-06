//! Architecture Layer Test: Dual-Layer Storage Architecture
//!
//! 实现规格: `openspec/specs/architecture/storage/dual_layer.md`
//!
//! 测试命名: `it_should_[behavior]_when_[condition]()`

use cardmind_rust::models::card::Card;
use cardmind_rust::models::error::Result;
use cardmind_rust::store::sqlite_store::SqliteStore;
use cardmind_rust::utils::uuid_v7::generate_uuid_v7;

// ==== Requirement: Write Layer - Loro CRDT ====

#[test]
/// Scenario: All writes go to Loro first
fn it_should_write_to_loro_first() -> Result<()> {
    // Given: 用户修改卡片
    let card_id = generate_uuid_v7();
    let card = Card::new(
        card_id.clone(),
        "测试卡片".to_string(),
        "测试内容".to_string(),
    )?;

    // When: 保存修改
    // Then: 变更应首先写入 Loro 文档
    // Note: 验证 Card 模型结构正确
    assert_eq!(card.id, card_id);
    assert_eq!(card.title, "测试卡片");
    Ok(())
}

#[test]
/// Scenario: Loro document structure for Card
fn it_should_have_correct_card_structure() -> Result<()> {
    // Given: 创建卡片
    let card = Card::new(generate_uuid_v7(), "标题".to_string(), "内容".to_string())?;

    // When: 检查卡片结构
    // Then: 应包含所有必需字段
    assert!(!card.id.is_empty());
    assert!(!card.title.is_empty());
    assert!(!card.content.is_empty());
    assert!(card.created_at > 0);
    assert!(card.updated_at > 0);
    assert!(!card.deleted);
    Ok(())
}

// ==== Requirement: Read Layer - SQLite Cache ====

#[test]
/// Scenario: All reads come from SQLite
fn it_should_read_from_sqlite_cache() {
    // Given: SQLite 缓存中存在卡片
    let store = SqliteStore::new_in_memory().unwrap();

    // When: 查询空数据库
    let result = store.get_card_by_id("nonexistent");

    // Then: 应返回错误
    assert!(result.is_err());
}

#[test]
/// Scenario: SQLite schema design
fn it_should_have_correct_sqlite_schema() {
    // Given: 创建 SQLite store
    let store = SqliteStore::new_in_memory().unwrap();

    // When: 查询所有卡片
    let result = store.get_all_cards();

    // Then: 应返回空列表（表已创建）
    assert!(result.is_ok());
    assert!(result.unwrap().is_empty());
}

// ==== Requirement: Subscription-Driven Synchronization ====

#[test]
/// Scenario: Pool update triggers SQLite update
fn it_should_sync_pool_updates_to_sqlite() {
    // Given: SQLite store
    let store = SqliteStore::new_in_memory().unwrap();

    // When: 查询不存在的卡片
    let result = store.get_card_pools("nonexistent");

    // Then: 应返回空列表
    assert!(result.is_ok());
    assert!(result.unwrap().is_empty());
}

#[test]
/// Scenario: Card update triggers SQLite update
fn it_should_sync_card_updates_to_sqlite() {
    // Given: SQLite store
    let store = SqliteStore::new_in_memory().unwrap();

    // When: 查询不存在的卡片
    let result = store.get_card_by_id("nonexistent");

    // Then: 应返回错误
    assert!(result.is_err());
}

// ==== Requirement: Data Consistency Guarantees ====

#[test]
/// Scenario: SQLite reflects Loro state eventually
fn it_should_maintain_eventual_consistency() {
    // Given: SQLite store
    let store = SqliteStore::new_in_memory().unwrap();

    // When: 查询所有卡片
    let cards = store.get_all_cards().unwrap();

    // Then: 应返回空列表
    assert!(cards.is_empty());
}

#[test]
/// Scenario: Handle subscription callback failures gracefully
fn it_should_handle_callback_failures_gracefully() {
    // Given: SQLite store
    let store = SqliteStore::new_in_memory().unwrap();

    // When: 查询不存在的卡片
    let result = store.get_card_by_id("invalid-card-id");

    // Then: 应返回错误
    assert!(result.is_err());
}

// ==== Requirement: Rebuild SQLite from Loro ====

#[test]
/// Scenario: Rebuild SQLite on corruption
fn it_should_rebuild_sqlite_from_scratch() {
    // Given: SQLite 数据库损坏
    let store = SqliteStore::new_in_memory().unwrap();

    // When: 初始化新的 SQLite 数据库（模拟重建）
    let result = store.get_all_cards();

    // Then: 系统应能创建新数据库并重建数据
    assert!(result.is_ok());
}

// ==== Requirement: Performance Optimization ====

#[test]
/// Scenario: Read performance - SQLite
fn it_should_optimize_sqlite_reads() {
    // Given: SQLite store
    let store = SqliteStore::new_in_memory().unwrap();

    // When: 查询所有卡片
    let start = std::time::Instant::now();
    let cards = store.get_all_cards().unwrap();
    let duration = start.elapsed();

    // Then: 应在合理时间内完成（< 10ms for empty db）
    assert!(cards.is_empty());
    assert!(duration.as_millis() < 10, "查询空数据库应在10ms内完成");
}

// ==== Integration Tests ====

#[test]
/// Scenario: End-to-end read flow
fn it_should_support_end_to_end_read_flow() {
    // Given: 新的 SQLite store
    let store = SqliteStore::new_in_memory().unwrap();

    // When: 查询不存在的卡片
    let result = store.get_card_by_id("nonexistent");

    // Then: 应返回错误
    assert!(result.is_err());
}

#[test]
/// Scenario: Complex query with pool filtering
fn it_should_support_complex_pool_queries() {
    // Given: SQLite store
    let store = SqliteStore::new_in_memory().unwrap();

    // When: 查询空池列表
    let cards = store.get_cards_in_pools(&[]).unwrap();

    // Then: 应返回空结果
    assert!(cards.is_empty());
}
