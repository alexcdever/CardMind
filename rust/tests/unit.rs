// input: 单元测试主入口。
// output: 引入所有子目录测试模块，供 Cargo test 统一运行。
// pos: Rust 单元测试根入口。修改本文件需同步更新所属 DIR.md。
// 中文注释：单元测试主入口，使用 #[path] 指定子目录测试文件位置。

// Store 模块测试
#[path = "unit/store/card_store_business_test.rs"]
mod card_store_business_test;

#[path = "unit/store/pool_store_business_test.rs"]
mod pool_store_business_test;

#[path = "unit/store/path_resolver_test.rs"]
mod path_resolver_test;

#[path = "unit/store/loro_store_test.rs"]
mod loro_store_test;

#[path = "unit/store/card_store_projection_test.rs"]
mod card_store_projection_test;

#[path = "unit/store/pool_store_projection_test.rs"]
mod pool_store_projection_test;

#[path = "unit/store/sqlite_store_test.rs"]
mod sqlite_store_test;

// Models 模块测试
#[path = "unit/models/api_error_test.rs"]
mod api_error_test;

#[path = "unit/models/error_test.rs"]
mod error_test;

// Net 模块测试
#[path = "unit/net/net_codec_test.rs"]
mod net_codec_test;

#[path = "unit/net/session_test.rs"]
mod session_test;

#[path = "unit/net/endpoint_test.rs"]
mod endpoint_test;

#[path = "unit/net/pool_network_test.rs"]
mod pool_network_test;

#[path = "unit/net/pool_network_sync_test.rs"]
mod pool_network_sync_test;

// API 模块测试
#[path = "unit/api_internal_test.rs"]
mod api_internal_test;

#[path = "unit/api_functions_test.rs"]
mod api_functions_test;

#[path = "unit/api_utils_test.rs"]
mod api_utils_test;

// CLI 模块测试
#[path = "unit/cli/debug_console_test.rs"]
mod debug_console_test;

// Application 模块测试
#[path = "unit/application/backend_service_test.rs"]
mod backend_service_test;

// Runtime 模块测试
#[path = "unit/runtime/entry_manager_test.rs"]
mod entry_manager_test;
