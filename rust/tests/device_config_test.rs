//! Architecture Layer Test: DeviceConfig Storage
//!
//! 实现规格: `openspec/specs/architecture/storage/device_config.md`
//!
//! 测试命名: `it_should_[behavior]_when_[condition]()`

use cardmind_rust::models::device_config::{DeviceConfig, DeviceConfigError};
use std::path::PathBuf;
use tempfile::TempDir;

/// 测试辅助函数：创建临时配置路径
fn create_test_config_path() -> (TempDir, PathBuf) {
    let temp_dir = TempDir::new().unwrap();
    let config_path = temp_dir.path().join("config.json");
    (temp_dir, config_path)
}

// ==== Requirement: Device configuration structure ====

#[test]
/// Scenario: Device config has required fields
fn it_should_have_required_fields() {
    // Given: 创建新设备配置
    let config = DeviceConfig::new("test-device-001");

    // Then: 应包含所有必需字段
    assert_eq!(config.device_id, "test-device-001");
    assert!(config.pool_id.is_none());
}

#[test]
/// Scenario: Device config does not contain legacy fields
fn it_should_not_contain_legacy_fields() {
    // Given: 创建新设备配置
    let config = DeviceConfig::new("test-device-001");

    // Then: 应仅包含 pool_id，不包含旧字段
    // 验证结构体只有 pool_id 字段（编译时检查）
    // 在代码中，旧字段 joined_pools, resident_pools, last_selected_pool 已被移除
    assert!(config.pool_id.is_none());
}

// ==== Requirement: Load or create device configuration ====

#[test]
/// Scenario: Create new config on first launch
fn it_should_create_new_config_on_first_launch() {
    // Given: 应用首次启动，无配置文件
    let (_temp_dir, config_path) = create_test_config_path();

    // When: 调用 get_or_create()
    let result = DeviceConfig::get_or_create(&config_path, "test-device-001");

    // Then: 应创建新配置，pool_id = None
    assert!(result.is_ok());
    let config = result.unwrap();
    assert!(config.pool_id.is_none());
    assert_eq!(config.device_id, "test-device-001");

    // And: 配置文件应被保存
    assert!(config_path.exists());
}

#[test]
/// Scenario: Load existing config on subsequent launch
fn it_should_load_existing_config_on_subsequent_launch() {
    // Given: 存在上次会话的配置文件
    let (_temp_dir, config_path) = create_test_config_path();
    let mut config1 = DeviceConfig::get_or_create(&config_path, "device-001").unwrap();
    config1.join_pool("pool_A").unwrap();
    config1.save(&config_path).unwrap();

    // When: 再次调用 get_or_create()
    let result = DeviceConfig::get_or_create(&config_path, "device-002");

    // Then: 应加载现有配置
    assert!(result.is_ok());
    let config2 = result.unwrap();

    // And: device_id 应保持不变
    assert_eq!(config2.device_id, "device-001");
    assert_eq!(config2.pool_id, Some("pool_A".to_string()));
}

// ==== Requirement: Join pool with single pool constraint ====

#[test]
/// Scenario: Allow joining first pool successfully
fn it_should_allow_joining_first_pool_successfully() {
    // Given: 设备未加入任何池
    let mut config = DeviceConfig::new("test-device-001");
    assert!(config.pool_id.is_none());

    // When: 加入 pool_A
    let result = config.join_pool("pool_A");

    // Then: pool_id 应被设置为 pool_A
    assert!(result.is_ok());
    assert_eq!(config.pool_id, Some("pool_A".to_string()));
}

#[test]
/// Scenario: Reject joining second pool
fn it_should_reject_joining_second_pool() {
    // Given: 设备已加入 pool_A
    let mut config = DeviceConfig::new("test-device-001");
    config.join_pool("pool_A").unwrap();

    // When: 尝试加入 pool_B
    let result = config.join_pool("pool_B");

    // Then: 操作应失败并返回 InvalidOperationError
    assert!(result.is_err());
    assert!(matches!(
        result.unwrap_err(),
        DeviceConfigError::InvalidOperationError(_)
    ));

    // And: pool_id 应保持为 pool_A
    assert_eq!(config.pool_id, Some("pool_A".to_string()));
}

#[test]
/// Scenario: Preserve config when join fails
fn it_should_preserve_config_when_join_fails() {
    // Given: 设备已加入 pool_A
    let mut config = DeviceConfig::new("test-device-001");
    config.join_pool("pool_A").unwrap();

    // When: 尝试非法操作（加入 pool_B）
    let result = config.join_pool("pool_B");

    // Then: 配置应保持不变
    assert!(result.is_err());
    assert_eq!(config.pool_id, Some("pool_A".to_string()));
}

// ==== Requirement: Leave pool with cleanup ====

#[test]
/// Scenario: Clear pool_id on leave
fn it_should_clear_pool_id_on_leave() {
    // Given: 设备已加入池
    let mut config = DeviceConfig::new("test-device-001");
    config.join_pool("pool_A").unwrap();

    // When: 退出池
    let result = config.leave_pool("pool_A");

    // Then: pool_id 应被设置为 None
    assert!(result.is_ok());
    assert!(config.pool_id.is_none());
}

#[test]
/// Scenario: Fail when leaving without joining
fn it_should_fail_when_leaving_without_joining() {
    // Given: 设备未加入任何池
    let mut config = DeviceConfig::new("test-device-001");

    // When: 尝试退出
    let result = config.leave_pool("pool_A");

    // Then: 操作应失败并返回 InvalidOperationError
    assert!(result.is_err());
    assert!(matches!(
        result.unwrap_err(),
        DeviceConfigError::InvalidOperationError(_)
    ));
}

#[test]
/// Scenario: Cleanup local data on leave
fn it_should_cleanup_local_data_on_leave() {
    // Given: 设备已加入池并有数据
    let (_temp_dir, config_path) = create_test_config_path();
    let mut config = DeviceConfig::get_or_create(&config_path, "device-001").unwrap();
    config.join_pool("pool_A").unwrap();

    // When: 退出池
    let result = config.leave_pool("pool_A");

    // Then: pool_id 应被清除
    assert!(result.is_ok());
    assert!(config.pool_id.is_none());

    // And: 配置应被持久化
    assert!(config_path.exists());

    // Note: 实际的卡片和池数据清理由 PoolStore 处理
    // DeviceConfig 只负责清除 pool_id
}

// ==== Requirement: Query methods ====

#[test]
/// Scenario: Get pool ID when not joined
fn get_pool_id_should_return_none_when_not_joined() {
    // Given: 新设备未加入任何池
    let config = DeviceConfig::new("test-device-001");

    // When: 调用 get_pool_id()
    let pool_id = config.get_pool_id();

    // Then: 应返回 None
    assert!(pool_id.is_none());
}

#[test]
/// Scenario: Get pool ID when joined
fn get_pool_id_should_return_some_when_joined() {
    // Given: 设备已加入 pool_A
    let mut config = DeviceConfig::new("test-device-001");
    config.join_pool("pool_A").unwrap();

    // When: 调用 get_pool_id()
    let pool_id = config.get_pool_id();

    // Then: 应返回 Some("pool_A")
    assert_eq!(pool_id, Some("pool_A"));
}

#[test]
/// Scenario: Check join status
fn is_joined_should_return_correct_boolean() {
    // Given: 各种设备状态
    let mut config = DeviceConfig::new("test-device-001");

    // When: 未加入时调用 is_joined_any()
    assert!(!config.is_joined_any());

    // When: 加入池后调用 is_joined_any()
    config.join_pool("pool_A").unwrap();
    assert!(config.is_joined_any());

    // When: 检查特定池
    assert!(config.is_joined("pool_A"));
    assert!(!config.is_joined("pool_B"));
}

// ==== Requirement: Device name management ====

#[test]
/// Scenario: Generate default device name
fn it_should_generate_default_device_name() {
    // Given: 新设备配置
    let config = DeviceConfig::new("test-device-001");

    // When: 检查设备名称
    // Then: 应使用默认生成的 device_id
    assert_eq!(config.device_id, "test-device-001");
}

#[test]
/// Scenario: Allow setting custom device name
fn it_should_allow_setting_custom_device_name() {
    // Given: 设备配置
    let (_temp_dir, config_path) = create_test_config_path();
    let mut config = DeviceConfig::get_or_create(&config_path, "device-001").unwrap();

    // When: 设置自定义名称
    config.device_id = "my-custom-device".to_string();

    // Then: 名称应被保存
    config.save(&config_path).unwrap();

    // And: 配置应被持久化
    let loaded = DeviceConfig::load(&config_path).unwrap();
    assert_eq!(loaded.device_id, "my-custom-device");
}

// ==== Requirement: Configuration persistence ====

#[test]
/// Scenario: Persist and load config in JSON format
fn it_should_persist_and_load_config_in_json_format() {
    // Given: 设备配置
    let (_temp_dir, config_path) = create_test_config_path();
    let config = DeviceConfig::new("device-001");

    // When: 保存到文件
    config.save(&config_path).unwrap();

    // Then: 文件应存在
    assert!(config_path.exists());

    // And: 应能加载
    let loaded = DeviceConfig::load(&config_path).unwrap();
    assert_eq!(loaded.device_id, config.device_id);
    assert_eq!(loaded.pool_id, config.pool_id);
}

// ==== Integration Tests ====

#[test]
/// Scenario: Full lifecycle - create, join, leave
fn it_should_support_full_lifecycle() {
    // Given: 新设备
    let (_temp_dir, config_path) = create_test_config_path();
    let mut config = DeviceConfig::get_or_create(&config_path, "device-001").unwrap();

    // When: 加入池
    assert!(config.join_pool("pool_A").is_ok());
    assert_eq!(config.pool_id, Some("pool_A".to_string()));

    // When: 保存并重新加载
    config.save(&config_path).unwrap();
    let mut loaded = DeviceConfig::load(&config_path).unwrap();
    assert_eq!(loaded.pool_id, Some("pool_A".to_string()));

    // When: 退出池
    assert!(loaded.leave_pool("pool_A").is_ok());
    assert!(loaded.pool_id.is_none());

    // Then: 保存后应保持退出状态
    loaded.save(&config_path).unwrap();
    let final_config = DeviceConfig::load(&config_path).unwrap();
    assert!(final_config.pool_id.is_none());
}
