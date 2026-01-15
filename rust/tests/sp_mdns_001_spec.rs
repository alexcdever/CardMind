//! SP-MDNS-001: mDNS Temporary Toggle Specification
//!
//! This spec defines the requirements for mDNS peer discovery temporary toggle.
//! Timer is NOT persisted for privacy protection.
//!
//! Test commands:
//! ```bash
//! cd rust && cargo test --test sp_mdns_001_spec
//! ```

use cardmind_rust::models::device_config::DeviceConfig;

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::tempdir;

    #[test]
    fn it_should_have_mdns_inactive_by_default() {
        let config = DeviceConfig::new("test-device");
        assert!(
            !config.is_mdns_active(),
            "mDNS should be inactive by default"
        );
        assert_eq!(
            config.get_mdns_remaining_ms(),
            0,
            "Remaining time should be 0"
        );
    }

    #[test]
    fn it_should_enable_mdns_temporarily() {
        let mut config = DeviceConfig::new("test-device");
        assert!(!config.is_mdns_active());

        config.enable_mdns_temporary();

        assert!(
            config.is_mdns_active(),
            "mDNS should be active after enabling"
        );

        let remaining = config.get_mdns_remaining_ms();
        assert!(
            remaining > 4 * 60 * 1000,
            "Expected > 4 minutes remaining, got {}ms",
            remaining
        );
        assert!(
            remaining <= 5 * 60 * 1000,
            "Expected <= 5 minutes remaining, got {}ms",
            remaining
        );
    }

    #[test]
    fn it_should_return_correct_remaining_time() {
        let mut config = DeviceConfig::new("test-device");
        config.enable_mdns_temporary();

        let remaining = config.get_mdns_remaining_ms();

        assert!(
            remaining > 4 * 60 * 1000,
            "Should have > 4 minutes remaining"
        );
        assert!(
            remaining <= 5 * 60 * 1000,
            "Should have <= 5 minutes remaining"
        );
    }

    #[test]
    fn it_should_auto_disable_mdns_after_expiration() {
        let mut config = DeviceConfig::new("test-device");
        config.enable_mdns_temporary();

        // Set timer to 6 minutes ago (definitely in the past)
        config.mdns_timer.timer_end_ms = Some(config.mdns_timer.timer_end_ms.unwrap() - 360000);

        assert!(
            !config.is_mdns_active(),
            "mDNS should be inactive after expiration"
        );
        assert_eq!(
            config.get_mdns_remaining_ms(),
            0,
            "Remaining time should be 0"
        );
    }

    #[test]
    fn it_should_cancel_mdns_timer() {
        let mut config = DeviceConfig::new("test-device");
        config.enable_mdns_temporary();
        assert!(config.is_mdns_active());

        config.cancel_mdns_timer();

        assert!(
            !config.is_mdns_active(),
            "mDNS should be inactive after cancellation"
        );
        assert_eq!(
            config.get_mdns_remaining_ms(),
            0,
            "Remaining time should be 0"
        );
    }

    #[test]
    fn it_should_not_persist_timer_state() {
        let temp_dir = tempdir().unwrap();
        let config_path = temp_dir.path().join("config.json");

        // Enable mDNS and save
        let mut config = DeviceConfig::new("test-device");
        config.enable_mdns_temporary();
        assert!(
            config.mdns_timer.timer_end_ms.is_some(),
            "Timer should be set before save"
        );
        config.save(&config_path).unwrap();

        // Load in a new config (simulating app restart)
        let loaded = DeviceConfig::load(&config_path).unwrap();

        // Timer should be None because mdns_timer is marked with #[serde(skip_serializing)]
        assert!(
            !loaded.is_mdns_active(),
            "mDNS should be inactive after restart"
        );
        assert_eq!(
            loaded.get_mdns_remaining_ms(),
            0,
            "Remaining time should be 0"
        );
    }
}
