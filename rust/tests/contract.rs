// Phase 2 精确测试目标 - 契约测试入口
// 这些测试验证 Phase 2 契约的语义正确性

// 引用已存在的契约测试
#[path = "contract/api/sync_api_contract.rs"]
mod sync_api_contract;

// Phase 2 恢复契约测试
#[path = "contract/api/phase2_recovery_contract_test.rs"]
mod phase2_recovery_contract;
