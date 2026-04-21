// input: 所有集成测试模块的聚合入口。
// output: 引入 integration 模块，触发所有集成测试编译和运行。
// pos: Rust 集成测试根入口。修改本文件需同步更新文件头与所属 DIR.md。
// 中文注释：集成测试主入口，使用 #[path] 指定子目录测试文件位置。

// API 测试
#[path = "integration/api_integration_test.rs"]
mod api_integration_test;

#[path = "integration/api/api_handle_test.rs"]
mod api_handle_test;

#[path = "integration/api/app_config_test.rs"]
mod app_config_test;

#[path = "integration/api/card_delete_restore_test.rs"]
mod card_delete_restore_test;

#[path = "integration/api/card_query_test.rs"]
mod card_query_test;

#[path = "integration/api/current_user_view_test.rs"]
mod current_user_view_test;

#[path = "integration/api/pool_detail_test.rs"]
mod pool_detail_test;

#[path = "integration/api/pool_idempotency_test.rs"]
mod pool_idempotency_test;

#[path = "integration/api/pool_join_test.rs"]
mod pool_join_test;

#[path = "integration/api/pool_lifecycle_test.rs"]
mod pool_lifecycle_test;

#[path = "integration/api/pool_note_attachment_test.rs"]
mod pool_note_attachment_test;

#[path = "integration/api_runtime_view_integration_test.rs"]
mod api_runtime_view_integration_test;

// Sync 测试
#[path = "integration/sync/api_flow_test.rs"]
mod api_flow_test;

#[path = "integration/sync/multi_member_sync_test.rs"]
mod multi_member_sync_test;

#[path = "integration/sync/net_codec_test.rs"]
mod net_codec_test;

#[path = "integration/sync/net_endpoint_test.rs"]
mod net_endpoint_test;

#[path = "integration/sync/net_session_test.rs"]
mod net_session_test;

#[path = "integration/sync/network_flow_test.rs"]
mod network_flow_test;

#[path = "integration/sync/pool_sync_test.rs"]
mod pool_sync_test;

// Store 测试
#[path = "integration/store/architecture_contract_test.rs"]
mod architecture_contract_test;

#[path = "integration/store/projection_flow_test.rs"]
mod projection_flow_test;
