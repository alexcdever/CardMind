# Design Document: mDNS Temporary Toggle (5-min)

**Change ID**: sp-mdns-manual-toggle
**Status**: Implementation Complete
**Date**: 2026-01-16
**Author**: CardMind Development Team

---

## Context

### Background

CardMind uses mDNS (Multicast DNS) for peer discovery on local networks, enabling devices to automatically find each other for P2P synchronization. However, always-on mDNS discovery raises privacy concerns:

1. **Privacy**: Devices continuously broadcast their presence on the network
2. **Battery**: Mobile devices consume power for continuous network scanning
3. **User Control**: Users have no control over when their device is discoverable

### Current State

- mDNS is always enabled when P2PSyncService is created
- No mechanism to temporarily disable/enable mDNS
- No user-facing controls for mDNS discovery

### Constraints

- Must maintain backward compatibility with existing P2P sync architecture
- Cannot break existing libp2p network behavior
- Must work across all platforms (Android, iOS, Linux, macOS, Windows)
- Timer state must NOT persist (security requirement)

### Stakeholders

- **End Users**: Need privacy control and battery optimization
- **Security Team**: Require non-persistent timer for privacy protection
- **Development Team**: Need clean integration with existing P2P stack

---

## Goals / Non-Goals

### Goals

1. **Privacy by Default**: mDNS disabled by default, user must explicitly enable
2. **Temporary Enable**: 5-minute auto-expiring timer for mDNS discovery
3. **Manual Control**: User can enable/cancel at any time via Settings UI
4. **Security**: Timer state never persists across app restarts
5. **Clean Integration**: Minimal changes to existing P2P architecture

### Non-Goals

1. **Persistent mDNS Settings**: Intentionally NOT saving timer state (security feature)
2. **Configurable Duration**: Fixed 5-minute duration (not user-configurable)
3. **Background Auto-Enable**: No automatic enabling based on context/location
4. **Per-Pool mDNS Control**: Global setting, not per-pool configuration

---

## Decisions

### Decision 1: Timer Storage Location

**Choice**: Store timer in `DeviceConfig` as `Option<i64>` timestamp

**Rationale**:
- `DeviceConfig` is already the central device-level configuration
- `Option<i64>` provides clear semantics: `None` = disabled, `Some(timestamp)` = active until timestamp
- Unix timestamp (milliseconds) is platform-independent and easy to compare

**Alternatives Considered**:
- ❌ **Separate timer service**: Adds complexity, requires lifecycle management
- ❌ **Store duration instead of timestamp**: Requires tracking start time separately
- ❌ **Boolean flag**: Cannot represent expiration time, requires separate timer thread

**Trade-offs**:
- ✅ Simple to implement and test
- ✅ No additional dependencies
- ⚠️ Requires checking expiration on every `is_mdns_active()` call (acceptable overhead)

---

### Decision 2: Non-Persistent Timer (Security Feature)

**Choice**: Mark `mdns_timer_end` with `#[serde(skip_serializing)]` to prevent persistence

**Rationale**:
- **Privacy Protection**: App restart forces user to re-enable mDNS explicitly
- **Security by Design**: Prevents unintended long-term device discovery
- **User Awareness**: User must consciously enable mDNS each session

**Alternatives Considered**:
- ❌ **Persist timer state**: Violates privacy-by-default principle
- ❌ **Persist with expiration check on load**: Still allows unintended discovery after restart
- ❌ **User preference for persistence**: Adds complexity, most users won't understand implications

**Trade-offs**:
- ✅ Strong privacy guarantee
- ✅ Simple implementation (just skip serialization)
- ⚠️ User must re-enable after every restart (acceptable for privacy-focused feature)

---

### Decision 3: P2PNetwork Optional mDNS via Toggle

**Choice**: Use libp2p's `Toggle<mdns::tokio::Behaviour>` wrapper

**Rationale**:
- libp2p provides `Toggle` specifically for optional behaviors
- Allows runtime enable/disable without recreating the entire network stack
- Clean integration with existing `NetworkBehaviour` derive macro

**Alternatives Considered**:
- ❌ **Two separate P2PBehaviour types**: Code duplication, complex type system
- ❌ **Conditional compilation**: Cannot change at runtime
- ❌ **Manual NetworkBehaviour implementation**: Complex, error-prone

**Trade-offs**:
- ✅ Clean, idiomatic libp2p usage
- ✅ No code duplication
- ⚠️ Requires passing `mdns_enabled` parameter through call chain (acceptable)

---

### Decision 4: Check mDNS State at Service Creation

**Choice**: Check `DeviceConfig.is_mdns_active()` when creating `P2PSyncService`

**Rationale**:
- Service creation is the natural point to configure network behavior
- Avoids runtime state changes in active network connections
- Simpler than dynamic enable/disable of running mDNS

**Alternatives Considered**:
- ❌ **Dynamic enable/disable**: Requires recreating network stack, complex lifecycle
- ❌ **Periodic polling**: Wasteful, adds background threads
- ❌ **Event-driven updates**: Over-engineered for this use case

**Trade-offs**:
- ✅ Simple, predictable behavior
- ✅ No runtime state management complexity
- ⚠️ Requires service restart to change mDNS state (acceptable, services are short-lived)

---

### Decision 5: Fixed 5-Minute Duration

**Choice**: Hardcode `MDNS_TEMP_DURATION_MS = 5 * 60 * 1000` (5 minutes)

**Rationale**:
- **User Experience**: 5 minutes is long enough for typical sync operations
- **Privacy**: Short enough to limit exposure window
- **Simplicity**: No UI complexity for duration selection

**Alternatives Considered**:
- ❌ **User-configurable duration**: Adds UI complexity, most users won't change it
- ❌ **Adaptive duration**: Over-engineered, hard to predict user needs
- ❌ **Longer duration (15-30 min)**: Increases privacy risk

**Trade-offs**:
- ✅ Simple implementation and UX
- ✅ Good balance between usability and privacy
- ⚠️ Some users may want longer/shorter duration (can add later if needed)

---

## Architecture

### Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        Flutter UI                            │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Settings Screen                                        │ │
│  │  - Display mDNS status (ON/OFF)                        │ │
│  │  - Show countdown timer (mm:ss)                        │ │
│  │  - Enable/Cancel buttons                               │ │
│  └────────────────────────────────────────────────────────┘ │
└───────────────────────────┬─────────────────────────────────┘
                            │ Flutter Rust Bridge API
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      Rust Backend                            │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  DeviceConfig API (device_config.rs)                   │ │
│  │  - is_mdns_active() -> bool                            │ │
│  │  - enable_mdns_temporary()                             │ │
│  │  - cancel_mdns_timer()                                 │ │
│  │  - get_mdns_remaining_ms() -> i64                      │ │
│  └────────────────────────────────────────────────────────┘ │
│                            │                                 │
│                            ▼                                 │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  DeviceConfig Model (device_config.rs)                 │ │
│  │  - mdns_timer: MDnsTimerConfig                         │ │
│  │    - timer_end_ms: Option<i64>  [NOT PERSISTED]       │ │
│  │    - is_active() -> bool                               │ │
│  │    - start_timer()                                     │ │
│  │    - cancel_timer()                                    │ │
│  │    - remaining_ms() -> i64                             │ │
│  └────────────────────────────────────────────────────────┘ │
│                            │                                 │
│                            ▼                                 │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  P2PSyncService (sync_service.rs)                      │ │
│  │  - Checks is_mdns_active() at creation                 │ │
│  │  - Passes mdns_enabled to P2PNetwork                   │ │
│  └────────────────────────────────────────────────────────┘ │
│                            │                                 │
│                            ▼                                 │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  P2PNetwork (network.rs)                               │ │
│  │  - new(mdns_enabled: bool)                             │ │
│  │  - P2PBehaviour {                                      │ │
│  │      ping: PingBehaviour,                              │ │
│  │      sync: RequestResponse,                            │ │
│  │      mdns: Toggle<mdns::tokio::Behaviour>  // NEW     │ │
│  │    }                                                   │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

#### Enable mDNS Flow

```
User taps "Enable 5 min"
    │
    ▼
Flutter calls enable_mdns_temporary()
    │
    ▼
DeviceConfig.enable_mdns_temporary()
    │
    ├─ Set timer_end_ms = now + 5 minutes
    └─ Return success
    │
    ▼
Flutter starts countdown timer (UI update every second)
    │
    ▼
After 5 minutes: is_mdns_active() returns false
    │
    ▼
Flutter UI shows "Disabled"
```

#### Service Creation Flow

```
Create P2PSyncService
    │
    ▼
Check DeviceConfig.is_mdns_active()
    │
    ├─ true  → P2PNetwork::new(mdns_enabled: true)
    │           │
    │           └─ mDNS behaviour included in swarm
    │
    └─ false → P2PNetwork::new(mdns_enabled: false)
                │
                └─ mDNS behaviour disabled (Toggle::None)
```

---

## Implementation Details

### 1. DeviceConfig Changes

**File**: `rust/src/models/device_config.rs`

**New Structure**:
```rust
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Default)]
pub struct MDnsTimerConfig {
    #[serde(default, skip_serializing)]  // Security: NOT persisted
    pub timer_end_ms: Option<i64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct DeviceConfig {
    pub device_id: String,
    pub pool_id: Option<String>,
    #[serde(default)]
    pub mdns_timer: MDnsTimerConfig,  // NEW
}
```

**Key Methods**:
- `is_mdns_active()`: Check if current time < timer_end_ms
- `enable_mdns_temporary()`: Set timer_end_ms = now + 5 minutes
- `cancel_mdns_timer()`: Set timer_end_ms = None
- `get_mdns_remaining_ms()`: Calculate (timer_end_ms - now).max(0)

### 2. P2PNetwork Changes

**File**: `rust/src/p2p/network.rs`

**Updated Behaviour**:
```rust
#[derive(NetworkBehaviour)]
pub struct P2PBehaviour {
    pub ping: PingBehaviour,
    pub sync: request_response::json::Behaviour<SyncRequest, SyncResponse>,
    pub mdns: Toggle<mdns::tokio::Behaviour>,  // NEW: Optional mDNS
}
```

**Constructor**:
```rust
pub fn new(mdns_enabled: bool) -> Result<Self> {
    let mdns_behaviour = if mdns_enabled {
        match mdns::tokio::Behaviour::new(mdns::Config::default(), local_peer_id) {
            Ok(mdns) => Some(mdns).into(),
            Err(e) => {
                warn!("mDNS init failed: {}", e);
                None.into()
            }
        }
    } else {
        None.into()
    };
    // ...
}
```

### 3. P2PSyncService Integration

**File**: `rust/src/p2p/sync_service.rs`

**Service Creation**:
```rust
pub fn new(card_store: Arc<Mutex<CardStore>>, device_config: DeviceConfig) -> Result<Self> {
    let mdns_enabled = device_config.is_mdns_active();
    info!("mDNS status: {}", if mdns_enabled { "enabled" } else { "disabled" });
    
    let network = P2PNetwork::new(mdns_enabled)?;
    // ...
}
```

### 4. Flutter API

**File**: `rust/src/api/device_config.rs`

**Exposed APIs**:
```rust
#[flutter_rust_bridge::frb]
pub fn is_mdns_active() -> Result<bool>;

#[flutter_rust_bridge::frb]
pub fn enable_mdns_temporary() -> Result<()>;

#[flutter_rust_bridge::frb]
pub fn cancel_mdns_timer() -> Result<()>;

#[flutter_rust_bridge::frb]
pub fn get_mdns_remaining_ms() -> Result<i64>;
```

---

## Risks / Trade-offs

### Risk 1: Timer Drift

**Risk**: System clock changes could affect timer accuracy

**Mitigation**:
- Use monotonic time source where available
- 5-minute window is large enough to tolerate minor drift
- User can manually cancel if needed

**Impact**: Low (acceptable for this use case)

---

### Risk 2: Service Recreation Overhead

**Risk**: Changing mDNS state requires recreating P2PSyncService

**Mitigation**:
- Services are already short-lived in current architecture
- Recreation is fast (< 100ms)
- User-initiated action, not frequent

**Impact**: Low (acceptable UX)

---

### Risk 3: User Confusion (Non-Persistence)

**Risk**: Users may not understand why mDNS resets after app restart

**Mitigation**:
- Clear UI messaging: "Auto-disables after 5 minutes for privacy"
- Settings screen shows current status prominently
- Documentation explains privacy rationale

**Impact**: Medium (requires good UX design)

---

### Risk 4: Platform-Specific mDNS Issues

**Risk**: mDNS may fail on some platforms (permissions, network config)

**Mitigation**:
- Graceful fallback: If mDNS init fails, log warning and continue without it
- Manual peer connection still works
- Error handling in P2PNetwork::new()

**Impact**: Low (already handled in implementation)

---

## Testing Strategy

### Unit Tests

**File**: `rust/src/models/device_config.rs`
- ✅ Default state (disabled)
- ✅ Enable temporary (5 minutes)
- ✅ Auto-expiration
- ✅ Manual cancel
- ✅ Non-persistence

**File**: `rust/src/p2p/network.rs`
- ✅ Create with mDNS enabled
- ✅ Create with mDNS disabled
- ✅ Network behavior with/without mDNS

### Specification Tests

**File**: `rust/tests/sp_mdns_001_spec.rs`
- ✅ 16 comprehensive spec tests
- ✅ Covers all scenarios from proposal
- ✅ Validates security requirements

### Integration Tests

**Pending**: Flutter UI integration tests
- Settings screen displays correct status
- Countdown timer updates correctly
- Enable/cancel buttons work

---

## Migration Plan

### Deployment Steps

1. **Backend Deployment** (✅ Complete)
   - Deploy Rust changes with new DeviceConfig field
   - Backward compatible: existing configs load with `mdns_timer = None`
   - No data migration needed

2. **Flutter UI Deployment** (⏳ Pending)
   - Add Settings screen UI
   - Wire up API calls
   - Test on all platforms

3. **Rollout**
   - Gradual rollout to beta users first
   - Monitor for mDNS-related issues
   - Full release after validation

### Rollback Strategy

- **Backend**: Remove `mdns_timer` field, revert to always-on mDNS
- **Flutter**: Hide Settings UI, remove API calls
- **Data**: No data loss (timer was never persisted)

### Backward Compatibility

- ✅ Old configs load correctly (missing field defaults to `None`)
- ✅ Old clients ignore new field
- ✅ No breaking API changes

---

## Open Questions

### Q1: Should we add analytics for mDNS usage?

**Status**: Deferred

**Options**:
- Track how often users enable mDNS
- Track average session duration
- Track success rate of peer discovery

**Decision**: Defer until after initial release, evaluate user feedback first

---

### Q2: Should we allow configurable duration in future?

**Status**: Deferred

**Options**:
- Add duration selector (5/10/15/30 minutes)
- Add "Keep enabled" option (with warning)

**Decision**: Start with fixed 5 minutes, add configurability if users request it

---

### Q3: Should we show notification when mDNS expires?

**Status**: Deferred

**Options**:
- Silent expiration (current design)
- Toast notification
- Persistent notification with re-enable action

**Decision**: Start with silent expiration, add notification if users report confusion

---

## Success Metrics

### Technical Metrics

- ✅ All unit tests pass (23/23)
- ✅ All spec tests pass (16/16)
- ✅ Zero clippy warnings in new code
- ✅ Code coverage > 80% for new code

### User Metrics (Post-Release)

- mDNS enable rate (% of users who enable)
- Average session duration
- User feedback on privacy controls
- Bug reports related to mDNS

---

## References

- **Proposal**: `openspec/changes/sp-mdns-manual-toggle/proposal.md`
- **Specs**: `openspec/changes/sp-mdns-manual-toggle/specs/spec_changes.md`
- **Tasks**: `openspec/changes/sp-mdns-manual-toggle/tasks.md`
- **Spec Tests**: `rust/tests/sp_mdns_001_spec.rs`
- **ADR-0005**: Logging standards (for mDNS status logging)

---

**Document Status**: ✅ Complete (Implementation finished, Flutter UI pending)
**Last Updated**: 2026-01-16
**Next Review**: After Flutter UI implementation
