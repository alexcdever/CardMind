//! Security Layer Test: P2P Discovery (Minimal)
//!
//! 实现规格: `docs/specs/architecture/security/privacy.md`
//!
//! 测试命名: `it_should_[behavior]_when_[condition]()`

// ==== Requirement: Minimal Information Exposure ====

use cardmind_rust::p2p::discovery::CUSTOM_MDNS_PAYLOAD_ENABLED;

#[test]
/// Scenario: Disable custom payload in mDNS
fn it_should_disable_custom_mdns_payload() {
    assert!(!CUSTOM_MDNS_PAYLOAD_ENABLED);
}
