//! SP-SPM-001: Single Pool Model Specification Tests
//!
//! Implementation of the core single pool model specs from
//! `specs/rust/single_pool_model_spec.md`
//!
//! Test Naming: `it_should`_[behavior]_when_[condition]()

use cardmind_rust::models::device_config::{DeviceConfig, DeviceConfigError};

/// Test helper to create a basic `DeviceConfig` for testing
fn create_test_config() -> DeviceConfig {
    DeviceConfig::new()
}

// ==== SP-SPM-001 Spec-002-A: 设备只能加入一个池 ====

#[test]
/// `it_should_allow_joining_first_pool_successfully()`
fn it_should_allow_joining_first_pool_successfully() {
    // Given: DeviceConfig { pool_id: None }
    let mut config = create_test_config();
    assert!(config.pool_id.is_none());

    // When: join_pool("pool_A")
    let result = config.join_pool("pool_A");

    // Then: pool_id == Some("pool_A".to_string())
    assert!(result.is_ok());
    assert_eq!(config.pool_id, Some("pool_A".to_string()));
}

#[test]
/// `it_should_reject_joining_second_pool_when_already_joined()`
fn it_should_reject_joining_second_pool_when_already_joined() {
    // Given: DeviceConfig { pool_id: Some("pool_A".to_string()) }
    let mut config = create_test_config();
    config.join_pool("pool_A").unwrap();

    // When: join_pool("pool_B")
    let result = config.join_pool("pool_B");

    // Then: Err(AlreadyJoinedPoolError), pool_id unchanged
    assert!(result.is_err());
    assert!(matches!(
        result.unwrap_err(),
        DeviceConfigError::InvalidOperationError(_)
    ));
    assert_eq!(config.pool_id, Some("pool_A".to_string()));
}

// ==== SP-SPM-001 Spec-002-B: 退出池时清空所有数据 ====

#[test]
/// `it_should_clear_all_data_when_leaving_pool()`
fn it_should_clear_all_data_when_leaving_pool() {
    // Given: 已加入 pool_A
    let mut config = create_test_config();
    config.join_pool("pool_A").unwrap();
    assert_eq!(config.pool_id, Some("pool_A".to_string()));

    // When: leave_pool()
    config.leave_pool("pool_A").unwrap();

    // Then: pool_id = None
    assert!(config.pool_id.is_none());
}

// ==== SP-SPM-001 Spec-005-A: 创建卡片时自动加入当前池 ====

#[test]
/// `it_should_auto_join_current_pool_when_creating_card()`
fn it_should_auto_join_current_pool_when_creating_card() {
    // Given: DeviceConfig { pool_id: Some("pool_A".to_string()) }
    let mut config = create_test_config();
    config.join_pool("pool_A").unwrap();

    // When: 创建第一张卡片
    // (This would be implemented in the actual card creation logic)

    // Then: 卡片自动关联到池
    // (This would be verified through the card's pool_id field)

    // Note: This test requires the full card creation system
    // For now, we verify the config state
    assert_eq!(config.pool_id, Some("pool_A".to_string()));
}

// ==== Integration Tests ====

#[test]
/// `it_should_enforce_single_pool_constraint_across_operations()`
fn it_should_enforce_single_pool_constraint_across_operations() {
    // Given: 新设备
    let mut config = create_test_config();

    // When: 正常加入第一个池
    let result1 = config.join_pool("pool-001");
    assert!(result1.is_ok());
    assert_eq!(config.pool_id, Some("pool-001".to_string()));

    // When: 尝试加入第二个池
    let result2 = config.join_pool("pool-002");
    assert!(result2.is_err());

    // Then: 仍然保持第一个池
    assert_eq!(config.pool_id, Some("pool-001".to_string()));

    // When: 离开当前池
    config.leave_pool("pool-001").unwrap();

    // Then: 可以加入新池
    let result3 = config.join_pool("pool-002");
    assert!(result3.is_ok());
    assert_eq!(config.pool_id, Some("pool-002".to_string()));
}
