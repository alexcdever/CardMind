// Phase 2 精确测试目标 - 单元测试入口
// 这些测试验证 Phase 2 契约在单元级别的行为

// 引用已存在的单元测试
#[path = "unit/api_functions_test.rs"]
mod api_functions;

#[path = "unit/net/pool_network_sync_test.rs"]
mod pool_network_sync;

#[path = "unit/store/card_store_projection_test.rs"]
mod card_store_projection;
