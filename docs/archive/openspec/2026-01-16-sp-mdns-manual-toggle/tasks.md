# Implementation Tasks: mDNS Temporary Toggle (5-min)

**Change ID**: sp-mdns-manual-toggle
**Related Proposal**: [proposal.md](./proposal.md)

---

## Important Design Notes

- **Timer is NOT persisted** - app restart resets mDNS to disabled (security feature)
- **Duration**: Exactly 5 minutes (300 seconds)
- **Auto-clears**: When timer expires, `mdns_timer_end` becomes `None`

---

## Phase 1: Rust Backend

### Task 1.1: Update DeviceConfig Struct

**File**: `rust/src/models/device_config.rs`

- [x] Add `mdns_timer_end: Option<i64>` field to `DeviceConfig`
  - Stores Unix timestamp (milliseconds) when timer expires
  - `None` = disabled, `Some(timestamp)` = active until that time
- [x] Update `new()` constructor: `mdns_timer_end: None`
- [x] Update `load_or_create()` to handle missing field (backward compat, treat as None)
- [x] Add constant: `const MDNS_TEMP_DURATION_MS: i64 = 5 * 60 * 1000;`

**Testing**:
```bash
cd rust && cargo test device_config_spec --lib
```

---

### Task 1.2: Add mDNS Timer Methods to DeviceConfig

**File**: `rust/src/models/device_config.rs`

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

    /// Cancel active mDNS timer immediately
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

    /// Internal: Get current time in milliseconds
    fn now_ms() -> i64 {
        chrono::Utc::now().timestamp_millis()
    }
}
```

- [x] Implement all methods
- [x] Add tests:
  - Default is inactive
  - Enable sets future timestamp
  - is_mdns_active returns true before expiration
  - is_mdns_active returns false after expiration
  - get_mdns_remaining_ms returns correct countdown
  - cancel clears timer

**Testing**:
```bash
cd rust && cargo test --lib mdns
```

---

### Task 1.3: Update P2PNetwork for Optional mDNS

**File**: `rust/src/p2p/network.rs`

```rust
pub struct P2PNetwork {
    swarm: Swarm<P2PBehaviour>,
    mdns_enabled: bool,  // NEW: whether mDNS is active
}

impl P2PNetwork {
    /// Create network with optional mDNS
    pub fn new(mdns_enabled: bool) -> Result<Self> {
        // If mdns_enabled is true, include mDNS behaviour
        // Otherwise, skip mDNS
    }
}
```

- [x] Add `mdns_enabled` field
- [x] Update `new()` to accept `mdns_enabled` parameter
- [x] Conditionally include mDNS behaviour when enabled

**Testing**:
```bash
cd rust && cargo test --lib p2p
```

---

### Task 1.4: Update P2PSyncService

**File**: `rust/src/p2p/sync_service.rs`

In `P2PSyncService::new()`:
```rust
pub fn new(card_store: Arc<Mutex<CardStore>>, device_config: DeviceConfig) -> Result<Self> {
    // Check if mDNS is currently active
    let mdns_enabled = device_config.is_mdns_active();
    let network = P2PNetwork::new(mdns_enabled)?;
    // ...
}
```

- [x] Check `is_mdns_active()` from DeviceConfig
- [x] Pass result to `P2PNetwork::new()`

---

### Task 1.5: Expose mDNS Timer API to Flutter

**File**: `rust/src/api/device_config.rs`

```rust
#[flutter_rust_bridge::frb(sync)]
impl DeviceConfigApi {
    /// Check if mDNS is currently active
    pub fn is_mdns_active(&self) -> bool {
        self.config.read().unwrap().is_mdns_active()
    }

    /// Enable mDNS for 5 minutes
    pub fn enable_mdns_temporary(&self) {
        let mut config = self.config.write().unwrap();
        config.enable_mdns_temporary();
        // Note: Not saving to storage - timer resets on restart
    }

    /// Cancel mDNS timer immediately
    pub fn cancel_mdns_timer(&self) {
        let mut config = self.config.write().unwrap();
        config.cancel_mdns_timer();
    }

    /// Get remaining time in milliseconds
    pub fn get_mdns_remaining_ms(&self) -> i64 {
        self.config.read().unwrap().get_mdns_remaining_ms()
    }
}
```

- [x] Add all 4 API methods
- [x] **Important**: Do NOT persist timer state (security feature)
- [x] Run `dart tool/generate_bridge.dart` to regenerate bindings

---

## Phase 2: Flutter UI

### Task 2.1: Add Settings Provider State

**File**: `lib/providers/settings_provider.dart`

```dart
class SettingsProvider with ChangeNotifier {
  bool _mdnsActive = false;
  int _remainingMs = 0;
  Timer? _countdownTimer;

  bool get mdnsActive => _mdnsActive;
  int get remainingMs => _remainingMs;

  Future<void> refreshMdnsState() async {
    _mdnsActive = await _api.isMdnsActive();
    _remainingMs = await _api.getMdnsRemainingMs();
    notifyListeners();

    if (_mdnsActive && _remainingMs > 0) {
      _startCountdown();
    } else {
      _stopCountdown();
    }
  }

  Future<void> enableMdnsTemporary() async {
    await _api.enableMdnsTemporary();
    await refreshMdnsState();
  }

  Future<void> cancelMdnsTimer() async {
    await _api.cancelMdnsTimer();
    await refreshMdnsState();
  }

  void _startCountdown() {
    _stopCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_remainingMs <= 0) {
        _stopCountdown();
        await refreshMdnsState(); // Will show inactive
      } else {
        _remainingMs = (_remainingMs - 1000).clamp(0, _remainingMs);
        notifyListeners();
      }
    });
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  @override
  void dispose() {
    _stopCountdown();
    super.dispose();
  }
}
```

- [x] Implement SettingsProvider with countdown timer
- [x] Auto-poll for expiration
- [x] Clean up timer on dispose

---

### Task 2.2: Add Settings Screen UI

**File**: `lib/screens/settings_screen.dart`

```dart
Widget buildMdnsSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('mDNS Discovery', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          settingsProvider.mdnsActive ? 'Active' : 'Disabled',
                          style: TextStyle(
                            fontSize: 18,
                            color: settingsProvider.mdnsActive ? Colors.green : Colors.grey,
                          ),
                        ),
                        if (settingsProvider.mdnsActive)
                          Text(
                            _formatDuration(settingsProvider.remainingMs),
                            style: const TextStyle(fontSize: 14, color: Colors.green),
                          ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: settingsProvider.mdnsActive
                        ? settingsProvider.cancelMdnsTimer
                        : settingsProvider.enableMdnsTemporary,
                    child: Text(settingsProvider.mdnsActive ? 'Turn Off' : 'Enable 5 min'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'mDNS discovery will automatically disable after 5 minutes for privacy.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

String _formatDuration(int ms) {
  final seconds = (ms / 1000).round();
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;
  return '${minutes}m ${remainingSeconds}s remaining';
}
```

- [x] Add mDNS section to settings screen
- [x] Show countdown when active
- [x] Show enable button when inactive
- [x] Add privacy note

---

## Phase 3: Testing

### Task 3.1: Create Spec Test File

**File**: `rust/tests/sp_mdns_001_spec.rs`

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use cardmind_rust::models::device_config::DeviceConfig;

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
    fn it_should_calculate_remaining_time() {
        let mut config = DeviceConfig::new();
        config.enable_mdns_temporary();

        // Should have close to 5 minutes remaining
        let remaining = config.get_mdns_remaining_ms();
        assert!(remaining > 4 * 60 * 1000); // At least 4 minutes
        assert!(remaining <= 5 * 60 * 1000); // At most 5 minutes
    }

    #[test]
    fn it_should_cancel_mdns_timer() {
        let mut config = DeviceConfig::new();
        config.enable_mdns_temporary();
        assert!(config.is_mdns_active());

        config.cancel_mdns_timer();
        assert!(!config.is_mdns_active());
    }
}
```

- [x] Create test file with all test cases
- [x] Run: `cd rust && cargo test --test sp_mdns_001_spec`

---

### Task 3.2: Integration Test

- [x] Test full flow: Settings → API → DeviceConfig → SyncService
- [x] Verify mDNS auto-expires
- [x] Verify app restart resets mDNS (no persistence)

---

## Verification Checklist

- [x] `cargo clippy` passes (0 warnings)
- [x] `flutter analyze` passes (0 errors)
- [x] All new tests pass
- [x] `dart tool/specs_tool.dart` shows 100% spec coverage
- [x] Manual testing: countdown works, auto-expires, restart resets

---

## Estimated Effort

| Task | Lines Changed | Complexity |
|------|---------------|------------|
| Task 1.1 | ~10 | Low |
| Task 1.2 | ~50 | Medium |
| Task 1.3 | ~50 | Medium |
| Task 1.4 | ~10 | Low |
| Task 1.5 | ~30 | Low |
| Task 2.1 | ~60 | Medium |
| Task 2.2 | ~50 | Low |
| Task 3.1 | ~50 | Low |
| **Total** | ~310 | 3-4 hours |

---

## Rollout

After implementation:
1. Commit: `feat(mdns): add temporary 5-min toggle with auto-disable`
2. Run `dart tool/check_lint.dart`
3. Push to develop branch
4. Create PR
