//! mDNS 设备发现最小广播测试
//!
//! 确保不启用任何自定义 mDNS 广播负载。

use cardmind_rust::p2p::discovery::CUSTOM_MDNS_PAYLOAD_ENABLED;

#[test]
fn it_should_not_enable_custom_mdns_payload() {
    assert!(!CUSTOM_MDNS_PAYLOAD_ENABLED);
}
