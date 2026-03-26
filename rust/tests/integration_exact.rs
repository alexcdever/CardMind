// Phase 2 精确测试目标 - 集成测试入口
// 这些测试验证 Phase 2 契约在集成场景下的行为

// API 测试
#[path = "integration/api_integration_test.rs"]
mod api_integration;

#[path = "integration/api/api_handle_test.rs"]
mod api_handle;

#[path = "integration/api/app_config_test.rs"]
mod app_config;

#[path = "integration/api/card_delete_restore_test.rs"]
mod card_delete_restore;

#[path = "integration/api/card_query_test.rs"]
mod card_query;

#[path = "integration/api/current_user_view_test.rs"]
mod current_user_view;

#[path = "integration/api/pool_detail_test.rs"]
mod pool_detail;

#[path = "integration/api/pool_idempotency_test.rs"]
mod pool_idempotency;

#[path = "integration/api/pool_join_test.rs"]
mod pool_join;

#[path = "integration/api/pool_lifecycle_test.rs"]
mod pool_lifecycle;

#[path = "integration/api/pool_note_attachment_test.rs"]
mod pool_note_attachment;

// Sync 测试
#[path = "integration/sync/api_flow_test.rs"]
mod api_flow;

#[path = "integration/sync/multi_member_sync_test.rs"]
mod multi_member_sync;

#[path = "integration/sync/net_codec_test.rs"]
mod net_codec;

#[path = "integration/sync/net_endpoint_test.rs"]
mod net_endpoint;

#[path = "integration/sync/net_session_test.rs"]
mod net_session;

#[path = "integration/sync/network_flow_test.rs"]
mod network_flow;

#[path = "integration/sync/pool_sync_test.rs"]
mod pool_sync;

// Store 测试
#[path = "integration/store/architecture_contract_test.rs"]
mod architecture_contract;

#[path = "integration/store/projection_flow_test.rs"]
mod projection_flow;
