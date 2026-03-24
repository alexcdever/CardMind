// Phase 2 精确测试目标 - 集成测试入口
// 这些测试验证 Phase 2 契约在集成场景下的行为

// 引用已存在的集成测试
#[path = "integration/api_integration_test.rs"]
mod api_integration;

#[path = "integration/sync/api_flow_test.rs"]
mod api_flow;

#[path = "integration/sync/network_flow_test.rs"]
mod network_flow;

#[path = "integration/store/projection_flow_test.rs"]
mod projection_flow;
