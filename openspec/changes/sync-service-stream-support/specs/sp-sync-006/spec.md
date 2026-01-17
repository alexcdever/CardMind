# SP-SYNC-006: Sync Layer Specification (Delta)

**Status**: Delta
**Date**: 2026-01-17
**Module**: Rust Backend - P2P Sync
**Related Tests**: `rust/tests/sp_sync_006_spec.rs`

---

## ADDED Requirements

### Requirement: Sync service provides status change stream
The system SHALL provide a stream API that emits sync status changes in real-time.

#### Scenario: Get status stream returns valid stream
- **WHEN** calling `get_sync_status_stream()`
- **THEN** system returns a Stream<SyncStatus>
- **AND** stream emits status updates as they occur

#### Scenario: Stream emits initial status on subscription
- **WHEN** subscribing to the status stream
- **THEN** stream immediately emits the current sync status
- **AND** continues to emit subsequent updates

#### Scenario: Stream supports multiple subscribers
- **WHEN** multiple components subscribe to status stream
- **THEN** each subscriber receives independent status updates
- **AND** cancelling one subscription does not affect others

#### Scenario: Stream handles subscriber cancellation
- **WHEN** subscriber cancels the stream subscription
- **THEN** system stops sending updates to that subscriber
- **AND** resources are properly cleaned up

---

### Requirement: Sync service broadcasts status at key events
The system SHALL broadcast status changes at critical synchronization events.

#### Scenario: Broadcast when peer discovered
- **WHEN** sync service discovers a new peer
- **THEN** system broadcasts status with state=syncing
- **AND** syncing_peers count reflects active peers

#### Scenario: Broadcast when sync completes
- **WHEN** sync operation completes successfully
- **THEN** system broadcasts status with state=synced
- **AND** last_sync_time is updated

#### Scenario: Broadcast when sync fails
- **WHEN** sync operation encounters an error
- **THEN** system broadcasts status with state=failed
- **AND** error_message contains failure details

#### Scenario: Broadcast when all peers disconnect
- **WHEN** last peer disconnects from network
- **THEN** system broadcasts status with state=disconnected
- **AND** online_peers count is 0

---

### Requirement: Sync service supports retry after failure
The system SHALL provide a retry mechanism to restart synchronization.

#### Scenario: Retry clears error and restarts sync
- **WHEN** calling `retry_sync()` after failure
- **THEN** system clears error_message
- **AND** transitions to syncing state
- **AND** attempts to reconnect to known peers

#### Scenario: Retry broadcasts status change
- **WHEN** retry_sync() is called
- **THEN** system broadcasts new syncing status
- **AND** subscribers receive the update

#### Scenario: Retry handles no peers gracefully
- **WHEN** calling retry_sync() with no known peers
- **THEN** system returns error indicating no peers available
- **AND** status remains in failed or disconnected state

---

## MODIFIED Requirements

### Requirement: Sync Status Reporting
**Modified from**: SP-SYNC-006 - Sync Status Reporting

The system SHALL provide a SyncStatus struct that reflects the current sync state and supports real-time updates via streams.

**Changes**:
- ADDED: Stream-based status updates
- ADDED: Status change broadcasting
- RETAINED: Snapshot-based status via `get_sync_status()`

#### Scenario: Initial sync status has zero online peers
- **WHEN** requesting SyncStatus from newly created SyncService
- **THEN** online_peers count SHALL be 0
- **AND** syncing_peers count SHALL be 0

#### Scenario: Sync status reflects independent copies
- **WHEN** multiple threads request SyncStatus
- **THEN** each request SHALL return an independent copy
- **AND** modifications to one copy SHALL NOT affect others

#### Scenario: Sync status can be obtained via snapshot or stream
- **WHEN** component needs current status
- **THEN** component can call `get_sync_status()` for snapshot
- **OR** subscribe to `get_sync_status_stream()` for real-time updates

---

## Test Coverage

### New Unit Tests
- `it_should_return_valid_status_stream()`
- `it_should_emit_initial_status_on_subscription()`
- `it_should_support_multiple_stream_subscribers()`
- `it_should_broadcast_status_when_peer_discovered()`
- `it_should_broadcast_status_when_sync_completes()`
- `it_should_broadcast_status_when_sync_fails()`
- `it_should_broadcast_status_when_peer_disconnects()`
- `it_should_clear_error_on_retry()`
- `it_should_restart_sync_on_retry()`
- `it_should_handle_retry_with_no_peers()`

### Modified Tests
- `it_should_track_online_peers()` - verify both snapshot and stream
- `it_should_report_sync_status()` - verify both APIs work

---

## Implementation Notes

### API Changes
```rust
// Existing API (retained)
pub fn get_sync_status() -> Result<SyncStatus>;

// New Stream API
#[flutter_rust_bridge::frb]
pub fn get_sync_status_stream() -> impl Stream<Item = SyncStatus>;

// New Retry API
#[flutter_rust_bridge::frb]
pub async fn retry_sync() -> Result<()>;
```

### Internal Changes
```rust
pub struct P2PSyncService {
    // New field for broadcasting
    status_tx: broadcast::Sender<SyncStatus>,
    last_status: Option<SyncStatus>,
    // ... existing fields
}
```

---

## Acceptance Criteria

- [ ] All existing SP-SYNC-006 tests still pass
- [ ] All new tests pass
- [ ] Stream API works with flutter_rust_bridge
- [ ] Status updates broadcast within 100ms
- [ ] Multiple subscribers work correctly
- [ ] Retry functionality works as expected
- [ ] No breaking changes to existing API
- [ ] Code review approved

---

**最后更新**: 2026-01-17
**作者**: CardMind Team
