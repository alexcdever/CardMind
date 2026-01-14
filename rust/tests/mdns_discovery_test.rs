//! mDNS 设备发现数据结构测试
//!
//! 验证 Phase 5 中的隐私字段约束（仅广播非敏感信息）以及序列化兼容性。

use cardmind_rust::p2p::discovery::{DeviceInfo, PoolInfo};

#[test]
fn it_should_device_info_serialization_contains_only_whitelisted_fields() {
    let info = DeviceInfo {
        device_id: "device-001".to_string(),
        device_name: "MacBook-018c8".to_string(),
        pools: vec![PoolInfo {
            pool_id: "pool-abc".to_string(),
        }],
    };

    let json = serde_json::to_string(&info).expect("serialize to json");

    // 必须包含允许的字段
    assert!(json.contains("device_id"));
    assert!(json.contains("device_name"));
    assert!(json.contains("pool-abc"));

    // 不应包含敏感字段（名称、密码等）
    assert!(!json.contains("pool_name"));
    assert!(!json.contains("password"));
}
