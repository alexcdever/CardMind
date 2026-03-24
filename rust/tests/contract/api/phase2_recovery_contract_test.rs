// input: 查询收敛处于 pending 状态的证据。
// output: 断言 recovery_contract 正确计算 Phase 2 契约字段。
// pos: Phase 2 recovery_contract 规则归一化单元测试。修改本文件需同步更新所属 DIR.md。
use cardmind_rust::api::recovery_contract::*;

#[test]
fn test_safe_with_ready_substates_is_stable() {
    let contract = RecoveryContract::from_evidence("ready", "ready", "ready", false);
    assert_eq!(contract.local_content_safety, LocalContentSafety::Safe);
    assert_eq!(contract.recovery_stage, RecoveryStage::Stable);
    assert_eq!(contract.continuity_state, ContinuityState::SamePath);
    assert_eq!(contract.next_action, NextAction::None);
    assert!(contract.validate().is_ok());
}

#[test]
fn test_safe_with_pending_query_is_path_at_risk() {
    let contract = RecoveryContract::from_evidence("ready", "pending", "ready", false);
    assert_eq!(contract.local_content_safety, LocalContentSafety::Safe);
    assert_eq!(contract.query_convergence_state, SubState::Pending);
    assert_eq!(contract.continuity_state, ContinuityState::PathAtRisk);
    assert!(contract.validate().is_ok());
}

#[test]
fn test_blocked_sync_is_read_only_risk() {
    let contract = RecoveryContract::from_evidence("blocked", "ready", "ready", false);
    assert_eq!(
        contract.local_content_safety,
        LocalContentSafety::ReadOnlyRisk
    );
    assert_eq!(contract.recovery_stage, RecoveryStage::NeedsUserAction);
    assert_eq!(contract.continuity_state, ContinuityState::PathAtRisk);
    assert_ne!(contract.next_action, NextAction::None);
    assert!(contract.validate().is_ok());
}

#[test]
fn test_unknown_content_safety_is_unsafe_unknown() {
    let contract = RecoveryContract::from_evidence("ready", "ready", "ready", true);
    assert_eq!(contract.local_content_safety, LocalContentSafety::Unknown);
    assert_eq!(contract.recovery_stage, RecoveryStage::UnsafeUnknown);
    assert!(contract.forbidden_operations.contains(&"write".to_string()));
    assert!(contract.validate().is_ok());
}

#[test]
fn test_blocked_query_is_needs_user_action() {
    let contract = RecoveryContract::from_evidence("ready", "blocked", "ready", false);
    assert_eq!(contract.query_convergence_state, SubState::Blocked);
    assert_eq!(contract.recovery_stage, RecoveryStage::NeedsUserAction);
    assert_ne!(contract.next_action, NextAction::None);
    assert!(contract.validate().is_ok());
}

#[test]
fn test_read_only_risk_forbids_write() {
    let contract = RecoveryContract::from_evidence("blocked", "ready", "ready", false);
    assert_eq!(
        contract.local_content_safety,
        LocalContentSafety::ReadOnlyRisk
    );
    assert!(!contract.allowed_operations.contains(&"write".to_string()));
    assert!(
        !contract
            .allowed_operations
            .contains(&"continue_edit".to_string())
    );
    assert!(contract.forbidden_operations.contains(&"write".to_string()));
    assert!(contract.validate().is_ok());
}

#[test]
fn test_continuity_state_derivation_safe_non_ready_is_path_at_risk() {
    let contract = RecoveryContract::from_evidence("ready", "pending", "ready", false);
    assert_eq!(contract.local_content_safety, LocalContentSafety::Safe);
    assert!(
        contract.sync_state == SubState::Ready
            || contract.query_convergence_state != SubState::Ready
            || contract.instance_continuity_state != SubState::Ready
    );
    assert_eq!(contract.continuity_state, ContinuityState::PathAtRisk);
    assert!(contract.validate().is_ok());
}

#[test]
fn test_path_broken_cannot_be_safe() {
    // 手动构造非法组合来验证约束检查
    let mut contract = RecoveryContract::from_evidence("ready", "ready", "ready", false);
    // 强制设置为 path_broken（这是非法的，因为 safe 不能配 path_broken）
    contract.continuity_state = ContinuityState::PathBroken;
    // 验证约束检查能捕获这个错误
    assert!(contract.validate().is_err());
}

#[test]
fn test_needs_user_action_requires_non_none_next_action() {
    let contract = RecoveryContract::from_evidence("blocked", "ready", "ready", false);
    assert_eq!(contract.recovery_stage, RecoveryStage::NeedsUserAction);
    assert_ne!(contract.next_action, NextAction::None);
    assert!(contract.validate().is_ok());
}

#[test]
fn test_illegal_safe_path_broken_detected() {
    // 构造一个非法状态：safe + path_broken
    let mut contract = RecoveryContract::from_evidence("ready", "ready", "ready", false);
    contract.local_content_safety = LocalContentSafety::Safe;
    contract.continuity_state = ContinuityState::PathBroken;
    assert!(contract.validate().is_err());
}

#[test]
fn test_all_ready_substates_require_stable_stage() {
    let contract = RecoveryContract::from_evidence("ready", "ready", "ready", false);
    assert_eq!(contract.sync_state, SubState::Ready);
    assert_eq!(contract.query_convergence_state, SubState::Ready);
    assert_eq!(contract.instance_continuity_state, SubState::Ready);
    assert_eq!(contract.recovery_stage, RecoveryStage::Stable);
    assert!(contract.validate().is_ok());
}

#[test]
fn test_unknown_safety_allows_only_limited_actions() {
    let contract = RecoveryContract::from_evidence("ready", "ready", "ready", true);
    assert_eq!(contract.local_content_safety, LocalContentSafety::Unknown);
    assert!(
        !contract
            .allowed_operations
            .contains(&"continue_edit".to_string())
    );
    assert!(!contract.allowed_operations.contains(&"write".to_string()));
    assert!(
        contract
            .forbidden_operations
            .contains(&"content_safety_promise".to_string())
    );
    assert!(contract.validate().is_ok());
}

#[test]
fn test_allowed_operations_safe() {
    let contract = RecoveryContract::from_evidence("ready", "ready", "ready", false);
    assert!(contract.allowed_operations.contains(&"view".to_string()));
    assert!(
        contract
            .allowed_operations
            .contains(&"continue_edit".to_string())
    );
    assert!(
        contract
            .forbidden_operations
            .contains(&"content_lost_expression".to_string())
    );
}

#[test]
fn test_substate_from_str() {
    assert_eq!(SubState::from("ready"), SubState::Ready);
    assert_eq!(SubState::from("recovering"), SubState::Recovering);
    assert_eq!(SubState::from("blocked"), SubState::Blocked);
    assert_eq!(SubState::from("pending"), SubState::Pending);
    assert_eq!(SubState::from("unknown"), SubState::Blocked); // 默认保守
}

#[test]
fn test_local_content_safety_from_str() {
    assert_eq!(LocalContentSafety::from("safe"), LocalContentSafety::Safe);
    assert_eq!(
        LocalContentSafety::from("read_only_risk"),
        LocalContentSafety::ReadOnlyRisk
    );
    assert_eq!(
        LocalContentSafety::from("unknown"),
        LocalContentSafety::Unknown
    );
    assert_eq!(
        LocalContentSafety::from("invalid"),
        LocalContentSafety::Unknown
    ); // 默认保守
}

#[test]
fn test_enum_as_str() {
    assert_eq!(LocalContentSafety::Safe.as_str(), "safe");
    assert_eq!(SubState::Ready.as_str(), "ready");
    assert_eq!(RecoveryStage::Stable.as_str(), "stable");
    assert_eq!(ContinuityState::SamePath.as_str(), "same_path");
    assert_eq!(NextAction::None.as_str(), "none");
}
