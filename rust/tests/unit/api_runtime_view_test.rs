use cardmind_rust::models::pool::PoolMember;
use cardmind_rust::models::pool_runtime::{MemberRuntimeStatus, PoolMemberRuntime};

#[test]
fn member_runtime_status_should_render_connected_syncing_offline() {
    assert_eq!(
        MemberRuntimeStatus::from_signals(true, false).as_str(),
        "connected"
    );
    assert_eq!(
        MemberRuntimeStatus::from_signals(true, true).as_str(),
        "syncing"
    );
    assert_eq!(
        MemberRuntimeStatus::from_signals(false, false).as_str(),
        "offline"
    );
}

#[test]
fn current_device_flag_should_be_true_only_for_matching_endpoint() {
    let member = PoolMember {
        endpoint_id: "owner-endpoint".to_string(),
        nickname: "Owner".to_string(),
        os: "macOS".to_string(),
        is_admin: true,
    };

    let current = PoolMemberRuntime::from_member(
        &member,
        "owner-endpoint",
        MemberRuntimeStatus::Connected,
        Some(1_713_700_000),
    );
    let other = PoolMemberRuntime::from_member(
        &member,
        "joiner-endpoint",
        MemberRuntimeStatus::Connected,
        Some(1_713_700_000),
    );

    assert!(current.is_current_device);
    assert!(!other.is_current_device);
    assert_eq!(current.role, "admin");
    assert_eq!(other.role, "admin");
}
