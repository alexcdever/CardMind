# OpenSpec Change Proposal: mDNS Manual Toggle (Temporary)

**Change ID**: sp-mdns-manual-toggle
**Status**: Draft
**Date**: 2026-01-15
**Author**: CardMind User

---

## 1. Problem Statement

### Current Behavior
mDNS peer discovery is designed to be always enabled by default. This may:
- Expose device presence on local network without user consent
- Cause unnecessary battery/network usage on mobile devices
- Violate user privacy expectations

### Desired Behavior
mDNS peer discovery should be:
- **Default OFF**: mDNS is disabled by default
- **Temporary ON**: User can enable it, but it auto-disables after 5 minutes
- **Manual Re-enable**: User must manually re-enable when needed again
- **No Persistence**: Timer resets on app restart (security by design)

---

## 2. Requirements

### Requirement: DeviceConfig mDNS Timer

The system SHALL manage mDNS as a temporary state with timeout.

#### Scenario: mDNS is disabled by default
- GIVEN a new device installation or app restart
- WHEN loading DeviceConfig
- THEN mDNS timer state SHALL be `None` (disabled)

#### Scenario: Enable mDNS starts 5-minute timer
- GIVEN mDNS is currently disabled
- WHEN `enable_mdns_temporary()` is called
- THEN mDNS discovery SHALL become active
- AND a 5-minute timer SHALL start
- AND timer end timestamp SHALL be stored in DeviceConfig

#### Scenario: mDNS auto-disables after 5 minutes
- GIVEN mDNS was enabled and 5 minutes have elapsed
- WHEN checking or using mDNS state
- THEN mDNS discovery SHALL be disabled
- AND timer state SHALL be cleared

#### Scenario: Timer resets on app restart (security feature)
- GIVEN mDNS was enabled with timer running
- WHEN the app restarts
- THEN the timer state SHALL be lost
- AND mDNS SHALL be disabled (user must manually enable again)

---

### Requirement: mDNS Toggle API

The system SHALL provide temporary mDNS enable API.

#### Scenario: Enable mDNS for 5 minutes
- GIVEN mDNS is currently disabled
- WHEN `enable_mdns_temporary()` is called
- THEN mDNS discovery SHALL become active for 5 minutes
- AND return a timer ID for potential cancellation

#### Scenario: Check mDNS status with auto-expiration
- GIVEN mDNS was enabled at time T
- WHEN `is_mdns_active()` is called at time T+3min
- THEN return `true` (still active)

#### Scenario: Check mDNS status after expiration
- GIVEN mDNS was enabled at time T
- WHEN `is_mdns_active()` is called at time T+6min
- THEN return `false` (expired and auto-disabled)
- AND timer state SHALL be cleared

#### Scenario: Cancel active timer
- GIVEN mDNS is active with a running timer
- WHEN `cancel_mdns_timer()` is called
- THEN mDNS discovery SHALL be disabled immediately
- AND timer state SHALL be cleared

---

### Requirement: Sync Service mDNS Integration

The P2PSyncService SHALL respect the temporary mDNS state.

#### Scenario: Sync service uses mDNS when active
- GIVEN `is_mdns_active()` returns `true`
- WHEN creating/using P2PSyncService
- THEN the service SHALL include mDNS discovery

#### Scenario: Sync service skips mDNS when inactive
- GIVEN `is_mdns_active()` returns `false`
- WHEN creating/using P2PSyncService
- THEN the service SHALL NOT include mDNS discovery

---

### Requirement: Flutter Settings UI

The app SHALL provide UI to temporarily enable mDNS.

#### Scenario: Settings shows mDNS status
- GIVEN the user opens settings
- THEN the user SHALL see mDNS status:
  - "mDNS Discovery: OFF" (when disabled)
  - "mDNS Discovery: ON (4:32 remaining)" (when active with timer)

#### Scenario: User enables mDNS
- GIVEN the mDNS is OFF
- WHEN the user taps "Enable for 5 minutes"
- THEN mDNS discovery SHALL start
- AND countdown SHALL display
- AND after 5 minutes, mDNS SHALL auto-disable

#### Scenario: Timer countdown display
- GIVEN mDNS is active with remaining time
- WHEN the settings screen is visible
- THEN show remaining time in mm:ss format
- AND update every second

#### Scenario: User cancels mDNS early
- GIVEN mDNS is active with timer running
- WHEN the user taps "Turn Off"
- THEN mDNS discovery SHALL stop immediately
- AND timer SHALL be cancelled

---

## 3. Implementation Plan

### Phase 1: Rust Backend Changes

1. **Update DeviceConfig struct** (`rust/src/models/device_config.rs`)
   ```rust
   pub struct DeviceConfig {
       pub device_id: String,
       pub device_name: String,
       pub pool_id: Option<String>,
       pub mdns_timer_end: Option<i64>,  // NEW: Unix timestamp when timer expires
       pub updated_at: i64,
   }

   impl DeviceConfig {
       /// Duration of temporary mDNS enable (5 minutes in milliseconds)
       const MDNS_TEMP_DURATION_MS: i64 = 5 * 60 * 1000;
   }
   ```

2. **Add mDNS timer methods to DeviceConfig**
   ```rust
   impl DeviceConfig {
       /// Check if mDNS is currently active (within timer window)
       pub fn is_mdns_active(&self) -> bool {
           match self.mdns_timer_end {
               Some(end) => Self::now_ms() < end,
               None => false,
           }
       }

       /// Enable mDNS temporarily for 5 minutes
       pub fn enable_mdns_temporary(&mut self) {
           self.mdns_timer_end = Some(Self::now_ms() + Self::MDNS_TEMP_DURATION_MS);
       }

       /// Cancel active mDNS timer
       pub fn cancel_mdns_timer(&mut self) {
           self.mdns_timer_end = None;
       }

       /// Get remaining time in milliseconds (0 if inactive)
       pub fn get_mdns_remaining_ms(&self) -> i64 {
           match self.mdns_timer_end {
               Some(end) => (end - Self::now_ms()).max(0),
               None => 0,
           }
       }

       fn now_ms() -> i64 {
           chrono::Utc::now().timestamp_millis()
       }
   }
   ```

3. **Update P2PNetwork to support optional mDNS** (`rust/src/p2p/network.rs`)
   - Add `mdns_enabled` parameter to `P2PNetwork::new()`
   - Conditionally include mDNS behaviour when enabled

4. **Update P2PSyncService** (`rust/src/p2p/sync_service.rs`)
   - Check `is_mdns_active()` from DeviceConfig
   - Pass to P2PNetwork based on active state

5. **Add timer check in API layer** (`rust/src/api/device_config.rs`)
   - `is_mdns_active()` - checks timer and auto-clears if expired

### Phase 2: Flutter UI Changes

1. **Add settings UI with countdown** (lib/screens/settings_screen.dart)
   ```dart
   ListTile(
     title: Text('mDNS Discovery'),
     subtitle: _mdnsActive
         ? Text('Active (${_formatDuration(_remainingMs)})')
         : Text('Disabled'),
     trailing: _mdnsActive
         ? ElevatedButton(
             onPressed: _disableMdns,
             child: Text('Turn Off'),
           )
         : ElevatedButton(
             onPressed: _enableMdnsTemporary,
             child: Text('Enable for 5 min'),
           ),
   )
   ```

2. **Wire up API calls**
   - `cardMindApi.isMdnsActive()` - returns bool
   - `cardMindApi.enableMdnsTemporary()` - starts 5-min timer
   - `cardMindApi.cancelMdnsTimer()` - cancels timer
   - `cardMindApi.getMdnsRemainingMs()` - for countdown display

3. **Add countdown timer widget**
   - Use `Timer.periodic` to update countdown every second
   - Auto-refresh when timer expires

### Phase 3: Testing

1. **Unit tests** (rust/tests/sp_mdns_spec.rs)
   - Default mDNS inactive
   - Enable starts timer
   - Auto-expire after 5 minutes
   - Manual cancel works
   - Timer resets on app restart (no persistence)

2. **Integration test**
   - Full toggle flow from UI to Rust

---

## 4. Files to Modify

| File | Change |
|------|--------|
| `rust/src/models/device_config.rs` | Add `mdns_timer_end` field and methods |
| `rust/src/p2p/network.rs` | Support optional mDNS |
| `rust/src/p2p/sync_service.rs` | Check active state, pass to network |
| `rust/src/api/device_config.rs` | Expose mDNS timer API to Flutter |
| `lib/screens/settings_screen.dart` | Add UI with countdown |
| `lib/providers/settings_provider.dart` | Manage timer state and polling |

---

## 5. Breaking Changes

**None**. This is an additive feature that:
- Does not change existing API signatures (new methods only)
- Does not modify stored data format (new field is optional)
- Maintains backward compatibility

**Security Feature**: Timer state is NOT persisted - app restart resets mDNS to disabled. This is intentional for privacy protection.

---

## 6. Rollout Plan

1. **Deploy**: Code change with temporary mDNS feature
2. **User Education**: Note in release that mDNS auto-expires after 5 minutes for privacy

---

## 7. Acceptance Criteria

- [ ] DeviceConfig has `mdns_timer_end` field (None by default)
- [ ] `is_mdns_active()` returns true only within 5-minute window
- [ ] API provides `enableMdnsTemporary()`, `cancelMdnsTimer()`, `getMdnsRemainingMs()`
- [ ] P2PSyncService respects active state
- [ ] Settings screen shows countdown when active
- [ ] Timer auto-expires and disables mDNS
- [ ] App restart resets mDNS to disabled (no persistence)
- [ ] All tests pass

---

**Related Specs**:
- [SP-SYNC-006: Sync Layer](./specs/rust/sync_spec.md)
- [SP-DEV-002: DeviceConfig](./specs/rust/device_config_spec.md)

**Tags**: p2p, sync, mDNS, privacy, settings
