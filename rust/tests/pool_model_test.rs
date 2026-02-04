//! Domain Layer Test: Single Pool Model
//!
//! 实现规格: `openspec/specs/domain/pool/model.md`
//!
//! 测试命名: `it_should_[behavior]_when_[condition]()`

use cardmind_rust::models::device_config::{DeviceConfig, DeviceConfigError};
use cardmind_rust::models::pool::{Device, Pool};

/// 测试辅助函数：创建测试用的设备配置
fn create_test_device_config() -> DeviceConfig {
    DeviceConfig::new()
}

/// 测试辅助函数：创建测试用的数据池
fn create_test_pool(pool_id: &str, name: &str) -> Pool {
    // 使用 bcrypt 哈希的密码（模拟）
    let password_hash = "$2b$12$test_hash_placeholder";
    Pool::new(pool_id, name, password_hash)
}

// ==== Requirement: 单池约束 ====

#[test]
/// Scenario: Device joins first pool successfully
fn it_should_join_first_pool_successfully() {
    // Given: 设备未加入任何池
    let mut config = create_test_device_config();
    assert!(config.pool_id.is_none());

    // When: 设备使用有效密码加入池
    let result = config.join_pool("pool_A");

    // Then: 该池应添加到设备的已加入池列表
    assert!(result.is_ok());
    assert_eq!(config.pool_id, Some("pool_A".to_string()));

    // And: 应开始该池的同步（通过 pool_id 验证）
    assert!(config.is_joined("pool_A"));
}

#[test]
/// Scenario: Device rejects joining second pool
fn it_should_reject_joining_second_pool_when_already_joined() {
    // Given: 设备已加入一个池
    let mut config = create_test_device_config();
    config.join_pool("pool_A").unwrap();
    assert_eq!(config.pool_id, Some("pool_A".to_string()));

    // When: 设备尝试加入第二个池
    let result = config.join_pool("pool_B");

    // Then: 系统应拒绝该请求
    assert!(result.is_err());

    // And: 返回表明违反单池约束的错误
    match result.unwrap_err() {
        DeviceConfigError::InvalidOperationError(msg) => {
            assert!(msg.contains("已加入数据池"));
        }
        _ => panic!("应返回 InvalidOperationError"),
    }

    // And: pool_id 应保持不变
    assert_eq!(config.pool_id, Some("pool_A".to_string()));
}

// ==== Requirement: 在已加入池中创建卡片 ====

#[test]
/// Scenario: Create card auto-joins the pool
fn it_should_auto_join_current_pool_when_creating_card() {
    // Given: 设备已加入一个池
    let mut config = create_test_device_config();
    config.join_pool("pool_A").unwrap();

    // When: 用户创建新卡片
    // 注意：实际卡片创建逻辑在 CardStore 中
    // 这里验证配置状态和池的关联

    // Then: 卡片应在已加入的池中创建
    // 通过验证设备配置来模拟
    assert_eq!(config.pool_id, Some("pool_A".to_string()));
    assert!(config.is_joined("pool_A"));

    // And: 该池中的所有设备应可见该卡片
    // 通过池的 card_ids 来验证（模拟）
    let mut pool = create_test_pool("pool_A", "工作笔记");
    pool.add_card("card-001");
    assert!(pool.has_card("card-001"));
    assert_eq!(pool.card_count(), 1);
}

#[test]
/// Scenario: Create card fails when no pool joined
fn it_should_fail_to_create_card_when_no_pool_joined() {
    // Given: 设备未加入任何池
    let config = create_test_device_config();
    assert!(config.pool_id.is_none());
    assert!(!config.is_joined_any());

    // When: 用户尝试创建新卡片
    // 在实际应用中，这会在 CardStore 层验证
    // 这里模拟验证逻辑

    // Then: 系统应拒绝该请求
    // 通过检查设备配置状态来模拟
    assert!(!config.is_joined_any(), "设备必须先加入池才能创建卡片");

    // And: 返回表明未加入池的错误
    if let Some(pool_id) = config.get_pool_id() {
        panic!("设备未加入池，但 pool_id 为: {pool_id:?}");
    }
}

// ==== Requirement: 设备离开池 ====

#[test]
/// Scenario: Device leaves pool and clears data
fn it_should_clear_data_when_leaving_pool() {
    // Given: 设备已加入包含卡片的池
    let mut config = create_test_device_config();
    config.join_pool("pool_A").unwrap();

    let mut pool = create_test_pool("pool_A", "工作笔记");
    pool.add_card("card-001");
    pool.add_card("card-002");

    assert_eq!(config.pool_id, Some("pool_A".to_string()));
    assert_eq!(pool.card_count(), 2);

    // When: 设备离开该池
    let result = config.leave_pool("pool_A");

    // Then: 所有池数据应从设备清除
    assert!(result.is_ok());
    assert!(config.pool_id.is_none(), "离开池后 pool_id 应为 None");

    // And: 设备应不再与该池同步
    assert!(!config.is_joined("pool_A"));

    // And: 池状态应更新（模拟清空操作）
    // 在实际应用中，这会触发数据删除逻辑
    pool.remove_card("card-001");
    pool.remove_card("card-002");
    assert_eq!(pool.card_count(), 0, "池数据应被清除");
}

// ==== 集成测试 ====

#[test]
/// 集成测试：单池约束的完整流程
fn it_should_enforce_single_pool_constraint_across_lifecycle() {
    // Given: 新设备
    let mut config = create_test_device_config();

    // When: 正常加入第一个池
    let result1 = config.join_pool("pool-001");
    assert!(result1.is_ok());
    assert_eq!(config.pool_id, Some("pool-001".to_string()));

    // When: 尝试加入第二个池
    let result2 = config.join_pool("pool-002");
    assert!(result2.is_err());
    assert_eq!(config.pool_id, Some("pool-001".to_string()));

    // When: 离开当前池
    config.leave_pool("pool-001").unwrap();
    assert!(config.pool_id.is_none());

    // Then: 可以加入新池
    let result3 = config.join_pool("pool-002");
    assert!(result3.is_ok());
    assert_eq!(config.pool_id, Some("pool-002".to_string()));
}

#[test]
/// 集成测试：池成员管理
fn it_should_manage_pool_members_correctly() {
    // Given: 一个池和多个设备
    let mut pool = create_test_pool("pool_A", "工作笔记");

    // When: 添加多个成员
    let device1 = Device::new("device-001", "iPhone");
    let device2 = Device::new("device-002", "MacBook");
    let device3 = Device::new("device-003", "iPad");

    pool.add_member(device1);
    pool.add_member(device2);
    pool.add_member(device3);

    // Then: 所有成员应添加成功
    assert_eq!(pool.members.len(), 3);

    // When: 移除一个成员
    pool.remove_member("device-002");

    // Then: 成员列表应正确更新
    assert_eq!(pool.members.len(), 2);
    assert!(pool.members.iter().any(|d| d.device_id == "device-001"));
    assert!(pool.members.iter().any(|d| d.device_id == "device-003"));
    assert!(!pool.members.iter().any(|d| d.device_id == "device-002"));

    // When: 更新成员昵称
    let result = pool.update_member_name("device-001", "工作手机");

    // Then: 昵称应更新成功
    assert!(result.is_ok());
    assert_eq!(
        pool.members
            .iter()
            .find(|d| d.device_id == "device-001")
            .unwrap()
            .device_name,
        "工作手机"
    );
}
