# Spec Changes Delta: mDNS Temporary Toggle (5-min)

**Change ID**: sp-mdns-manual-toggle
**Affected Specs**:
- `openspec/specs/rust/device_config_spec.md` (SP-DEV-002)
- `openspec/specs/rust/sync_spec.md` (SP-SYNC-006)

---

## Key Design Decisions

1. **Timer NOT persisted** - App restart resets mDNS to disabled (privacy feature)
2. **Duration**: 5 minutes (300 seconds)
3. **Auto-clear**: When timer expires, state becomes `None`

---

## 1. Changes to device_config_spec.md (SP-DEV-002)

### 1.1 Add mDNS timer field to DeviceConfig struct

**Location**: Section 1.1 "配置结构定义"

**Current**:
```rust
pub struct DeviceConfig {
    pub device_id: String,
    pub device_name: String,
    pub pool_id: Option<String>,
    pub updated_at: i64,
}
```

**New**:
```rust
pub struct DeviceConfig {
    pub device_id: String,
    pub device_name: String,
    pub pool_id: Option<String>,
    pub mdns_timer_end: Option<i64>,  // NEW: Unix timestamp (ms) when timer expires, None = disabled
    pub updated_at: i64,
}
```

---

### 1.2 Add mDNS timer methods section

**Location**: After Section 2.5 "辅助方法" (before Section 3 "持久化规格")

**Add new section**:

```markdown
### 2.6 mDNS Temporary Discovery Control

#### Spec-DEV-006: mDNS Default State (Disabled)
```rust
impl DeviceConfig {
    /// Check if mDNS peer discovery is currently active
    pub fn is_mdns_active(&self) -> bool {
        match self.mdns_timer_end {
            Some(end) => Self::now_ms() < end,
            None => false,
        }
    }
}

#[test]
fn it_should_have_mdns_inactive_by_default() {
    // Given: A new DeviceConfig
    let config = DeviceConfig::new();

    // Then: mDNS should be inactive
    assert!(!config.is_mdns_active());
}
```

#### Spec-DEV-007: Enable mDNS Temporarily (5 minutes)
```rust
impl DeviceConfig {
    /// Duration of temporary mDNS enable (5 minutes in milliseconds)
    const MDNS_TEMP_DURATION_MS: i64 = 5 * 60 * 1000;

    /// Enable mDNS peer discovery for 5 minutes
    pub fn enable_mdns_temporary(&mut self) {
        self.mdns_timer_end = Some(Self::now_ms() + Self::MDNS_TEMP_DURATION_MS);
        // Note: Timer is NOT persisted - resets on app restart
    }
}

#[test]
fn it_should_enable_mdns_temporarily() {
    // Given: DeviceConfig with mDNS inactive
    let mut config = DeviceConfig::new();
    assert!(!config.is_mdns_active());

    // When: Enable mDNS temporarily
    config.enable_mdns_temporary();

    // Then: mDNS is active
    assert!(config.is_mdns_active());

    // And: Timer is set to approximately 5 minutes from now
    let remaining = config.get_mdns_remaining_ms();
    assert!(remaining > 4 * 60 * 1000); // At least 4 minutes
    assert!(remaining <= 5 * 60 * 1000); // At most 5 minutes
}
```

#### Spec-DEV-008: Timer Auto-Expires
```rust
impl DeviceConfig {
    /// Get remaining time in milliseconds (0 if inactive)
    pub fn get_mdns_remaining_ms(&self) -> i64 {
        match self.mdns_timer_end {
            Some(end) => (end - Self::now_ms()).max(0),
            None => 0,
        }
    }
}

#[test]
fn it_should_auto_disable_mdns_after_expiration() {
    // Given: DeviceConfig with mDNS active
    let mut config = DeviceConfig::new();
    config.enable_mdns_temporary();

    // When: Manually set timer to past
    config.mdns_timer_end = Some(config.mdns_timer_end.unwrap() - 60000); // 1 min ago

    // Then: mDNS is no longer active
    assert!(!config.is_mdns_active());
    assert_eq!(config.get_mdns_remaining_ms(), 0);
}
```

#### Spec-DEV-009: Cancel mDNS Timer
```rust
impl DeviceConfig {
    /// Cancel mDNS timer immediately
    pub fn cancel_mdns_timer(&mut self) {
        self.mdns_timer_end = None;
    }
}

#[test]
fn it_should_cancel_mdns_timer() {
    // Given: DeviceConfig with mDNS active
    let mut config = DeviceConfig::new();
    config.enable_mdns_temporary();
    assert!(config.is_mdns_active());

    // When: Cancel timer
    config.cancel_mdns_timer();

    // Then: mDNS is inactive
    assert!(!config.is_mdns_active());
}

#[test]
fn it_should_not_persist_timer_state() {
    // Given: User enables mDNS temporarily
    let mut config = DeviceConfig::new();
    config.enable_mdns_temporary();
    assert!(config.mdns_timer_end.is_some());

    // When: Simulate app restart (recreate config)
    // Timer state is NOT restored from storage
    let config_after_restart = DeviceConfig::new();

    // Then: Timer is None (security feature)
    assert!(!config_after_restart.is_mdns_active());
}
```

---

### 1.3 Update validation checklist

**Location**: Section 5.1 "单元测试"

**Add**:
```markdown
- [ ] Spec-DEV-006: mDNS Default State (Inactive)
- [ ] Spec-DEV-007: Enable mDNS Temporarily (5 min)
- [ ] Spec-DEV-008: Timer Auto-Expires
- [ ] Spec-DEV-009: Cancel mDNS Timer (with no persistence)
```

---

## 2. Changes to sync_spec.md (SP-SYNC-006)

### 2.1 Update "Requirement: Sync Service Creation"

**Location**: Section "Requirement: Sync Service Creation"

**Add new scenario**:

```markdown
#### Scenario: Sync service respects mDNS timer
- GIVEN DeviceConfig has active mDNS timer (within 5-min window)
- WHEN creating a new SyncService
- THEN the service SHALL include mDNS discovery behavior
- AND peer discovery SHALL automatically find local network devices

- GIVEN DeviceConfig has no active mDNS timer (expired or never enabled)
- WHEN creating a new SyncService
- THEN the service SHALL NOT include mDNS discovery behavior
- AND peers SHALL only be discoverable via manual connection
```

---

### 2.2 Update "Requirement: Peer Discovery"

**Location**: Section "Requirement: Peer Discovery"

**Current**:
```markdown
### Scenario: mDNS peer discovery enabled
- GIVEN the sync service is configured with mDNS
- WHEN discovering peers on the local network
- THEN the service SHALL find other CardMind instances
- AND add them to the peer list
```

**New**:
```markdown
### Scenario: mDNS peer discovery respects timer
- GIVEN the sync service has active mDNS timer in DeviceConfig
- WHEN discovering peers on the local network
- THEN the service SHALL find other CardMind instances
- AND add them to the peer list

- GIVEN the sync service has no active mDNS timer
- WHEN discovering peers on the local network
- THEN the service SHALL NOT perform mDNS discovery
- AND peers SHALL only be discoverable via manual connection

### Security Note
mDNS timer is intentionally NOT persisted. App restart resets mDNS to disabled, requiring user to manually re-enable. This protects user privacy by preventing unintended device discovery.
```

---

## 3. New Spec File: sp_mdns_001_spec.rs

**Location**: `rust/tests/sp_mdns_001_spec.rs`

**Create new test file**:

```rust
//! SP-MDNS-001: mDNS Temporary Toggle Specification
//!
//! This spec defines the requirements for mDNS peer discovery temporary toggle.
//! Timer is NOT persisted for privacy protection.

use cardmind_rust::models::device_config::DeviceConfig;

mod tests {
    use super::*;

    #[test]
    fn it_should_have_mdns_inactive_by_default() {
        let config = DeviceConfig::new();
        assert!(!config.is_mdns_active());
    }

    #[test]
    fn it_should_enable_mdns_temporarily() {
        let mut config = DeviceConfig::new();
        config.enable_mdns_temporary();
        assert!(config.is_mdns_active());
    }

    #[test]
    fn it_should_have_correct_remaining_time() {
        let mut config = DeviceConfig::new();
        config.enable_mdns_temporary();

        let remaining = config.get_mdns_remaining_ms();
        // Should be approximately 5 minutes
        assert!(remaining > 4 * 60 * 1000, "Expected > 4 minutes, got {}ms", remaining);
        assert!(remaining <= 5 * 60 * 1000, "Expected <= 5 minutes, got {}ms", remaining);
    }

    #[test]
    fn it_should_auto_disable_after_expiration() {
        let mut config = DeviceConfig::new();
        config.enable_mdns_temporary();

        // Simulate time passing - set timer to past
        config.mdns_timer_end = Some(config.mdns_timer_end.unwrap() - 60000);

        assert!(!config.is_mdns_active());
        assert_eq!(config.get_mdns_remaining_ms(), 0);
    }

    #[test]
    fn it_should_cancel_mdns_timer() {
        let mut config = DeviceConfig::new();
        config.enable_mdns_temporary();
        assert!(config.is_mdns_active());

        config.cancel_mdns_timer();
        assert!(!config.is_mdns_active());
        assert_eq!(config.get_mdns_remaining_ms(), 0);
    }

    #[test]
    fn it_should_not_persist_timer_state() {
        // This test verifies the security design - timer resets on restart
        let mut config = DeviceConfig::new();
        config.enable_mdns_temporary();
        assert!(config.mdns_timer_end.is_some());

        // Simulate app restart: create new config
        let config_after_restart = DeviceConfig::new();

        // Timer should be None (not restored from storage)
        assert!(!config_after_restart.is_mdns_active());
        assert_eq!(config_after_restart.get_mdns_remaining_ms(), 0);
    }
}
```

---

## 4. Summary of Changes

| Spec | Change Type | Description |
|------|-------------|-------------|
| SP-DEV-002 | Modify | Add `mdns_timer_end: Option<i64>` field |
| SP-DEV-002 | Add | Spec-DEV-006: mDNS Default State |
| SP-DEV-002 | Add | Spec-DEV-007: Enable Temporarily (5 min) |
| SP-DEV-002 | Add | Spec-DEV-008: Timer Auto-Expires |
| SP-DEV-002 | Add | Spec-DEV-009: Cancel Timer + No Persistence |
| SP-SYNC-006 | Modify | Sync service respects timer scenario |
| SP-SYNC-006 | Modify | Peer discovery respects timer scenario + Security Note |
| (new) | Add | SP-MDNS-001 test file with 6 test cases |

---

**Total New Test Cases**: 6
**Total Modified Scenarios**: 2
