# Sync Status Stream Specification

## 📋 规格编号: SP-SYNC-007
**版本**: 1.0.0
**状态**: 草稿
**依赖**: SP-SYNC-006 (同步层规格)

---

## ADDED Requirements

### Requirement: Sync service broadcasts status changes
The system SHALL broadcast sync status changes to all subscribers in real-time.

#### Scenario: Status change is broadcast to all subscribers
- **WHEN** sync status changes from one state to another
- **THEN** system broadcasts the new status to all active subscribers
- **AND** broadcast completes within 100ms

#### Scenario: Multiple subscribers receive same status
- **WHEN** multiple subscribers are listening to status stream
- **THEN** all subscribers receive the same status update
- **AND** each subscriber receives an independent copy

#### Scenario: Broadcast continues when no subscribers
- **WHEN** status changes with no active subscribers
- **THEN** system does NOT fail or panic
- **AND** system is ready for future subscribers

#### Scenario: Slow subscribers do not block fast subscribers
- **WHEN** one subscriber is slow to process status updates
- **THEN** other subscribers continue to receive updates without delay
- **AND** slow subscriber receives lagged notification

---

### Requirement: Sync service provides status stream API
The system SHALL provide a stream API that allows Flutter to subscribe to status changes.

#### Scenario: Get status stream returns valid stream
- **WHEN** calling `get_sync_status_stream()`
- **THEN** system returns a valid Stream<SyncStatus>
- **AND** stream is ready to emit status updates

#### Scenario: Stream emits current status on subscription
- **WHEN** subscribing to status stream
- **THEN** stream immediately emits the current sync status
- **AND** subsequent updates are emitted as they occur

#### Scenario: Stream subscription can be cancelled
- **WHEN** subscriber cancels the stream subscription
- **THEN** system stops sending updates to that subscriber
- **AND** other subscribers are not affected

#### Scenario: Multiple concurrent subscriptions are supported
- **WHEN** multiple widgets subscribe to status stream
- **THEN** each subscription receives independent updates
- **AND** cancelling one subscription does not affect others

---

### Requirement: Sync service triggers status changes at key events
The system SHALL trigger status change notifications at critical synchronization events.

#### Scenario: Status changes to syncing when peer discovered
- **WHEN** sync service discovers a new peer
- **THEN** system broadcasts status with state=syncing
- **AND** syncing_peers count is updated

#### Scenario: Status changes to synced when sync completes
- **WHEN** sync operation completes successfully
- **THEN** system broadcasts status with state=synced
- **AND** last_sync_time is updated to current time

#### Scenario: Status changes to failed when sync errors
- **WHEN** sync operation fails with an error
- **THEN** system broadcasts status with state=failed
- **AND** error_message contains the failure reason

#### Scenario: Status changes to disconnected when all peers disconnect
- **WHEN** last peer disconnects from sync service
- **THEN** system broadcasts status with state=disconnected
- **AND** online_peers count is 0

#### Scenario: Status changes to syncing on retry
- **WHEN** user triggers retry_sync() after failure
- **THEN** system broadcasts status with state=syncing
- **AND** error_message is cleared

---

### Requirement: Sync service deduplicates status updates
The system SHALL avoid broadcasting duplicate status updates to reduce unnecessary notifications.

#### Scenario: Duplicate status is not broadcast
- **WHEN** sync status changes to the same state and values
- **THEN** system does NOT broadcast the duplicate status
- **AND** subscribers do not receive redundant updates

#### Scenario: Status with different values is broadcast
- **WHEN** sync status changes to same state but different values (e.g., peer count)
- **THEN** system broadcasts the updated status
- **AND** subscribers receive the new values

#### Scenario: Rapid status changes are all broadcast
- **WHEN** sync status changes rapidly through different states
- **THEN** system broadcasts all distinct status changes
- **AND** subscribers receive all state transitions

---

### Requirement: Sync service implements retry functionality
The system SHALL provide a retry mechanism to restart synchronization after failure.

#### Scenario: Retry clears error state
- **WHEN** calling retry_sync() after sync failure
- **THEN** system clears the error_message
- **AND** status transitions to syncing

#### Scenario: Retry restarts sync with known peers
- **WHEN** calling retry_sync() with known peers
- **THEN** system attempts to reconnect to known peers
- **AND** broadcasts syncing status

#### Scenario: Retry fails gracefully when no peers available
- **WHEN** calling retry_sync() with no known peers
- **THEN** system returns error indicating no peers
- **AND** status remains in failed or disconnected state

#### Scenario: Retry is idempotent
- **WHEN** calling retry_sync() multiple times rapidly
- **THEN** system handles concurrent retries safely
- **AND** only one retry operation is active at a time

---

### Requirement: Status stream integrates with flutter_rust_bridge
The system SHALL use flutter_rust_bridge Stream support for cross-language communication.

#### Scenario: Stream is compatible with flutter_rust_bridge
- **WHEN** generating bridge code for get_sync_status_stream()
- **THEN** flutter_rust_bridge generates valid Dart Stream<SyncStatus>
- **AND** Dart code can subscribe using standard Stream API

#### Scenario: Stream handles backpressure
- **WHEN** Flutter subscriber is slow to process updates
- **THEN** Rust side buffers updates up to capacity
- **AND** oldest updates are dropped if buffer is full

#### Scenario: Stream cleanup on Flutter side
- **WHEN** Flutter widget disposes and cancels subscription
- **THEN** Rust side detects cancellation
- **AND** stops sending updates to that subscriber

---

### Requirement: Status changes are logged for debugging
The system SHALL log status changes to aid in debugging synchronization issues.

#### Scenario: Status change is logged with timestamp
- **WHEN** sync status changes
- **THEN** system logs the state transition with timestamp
- **AND** log includes previous and new state

#### Scenario: Status change includes context
- **WHEN** sync status changes due to specific event
- **THEN** log includes event context (e.g., "peer_discovered", "sync_complete")
- **AND** log includes relevant details (peer ID, error message)

#### Scenario: Broadcast errors are logged
- **WHEN** broadcast fails (e.g., channel full)
- **THEN** system logs the error with details
- **AND** system continues operating normally

---

## Test Coverage

### Unit Tests
- `it_should_broadcast_status_to_all_subscribers()`
- `it_should_not_broadcast_duplicate_status()`
- `it_should_broadcast_when_peer_discovered()`
- `it_should_broadcast_when_sync_completes()`
- `it_should_broadcast_when_sync_fails()`
- `it_should_broadcast_when_peer_disconnects()`
- `it_should_handle_no_subscribers_gracefully()`
- `it_should_support_multiple_concurrent_subscriptions()`
- `it_should_emit_current_status_on_subscription()`
- `it_should_clear_error_on_retry()`
- `it_should_restart_sync_on_retry()`
- `it_should_handle_concurrent_retries_safely()`

### Integration Tests
- `it_should_stream_status_to_flutter()`
- `it_should_handle_flutter_subscription_cancellation()`
- `it_should_handle_slow_flutter_subscriber()`
- `it_should_integrate_with_flutter_rust_bridge()`

---

## Implementation Notes

### Broadcast Channel Setup
```rust
use tokio::sync::broadcast;

pub struct P2PSyncService {
    status_tx: broadcast::Sender<SyncStatus>,
    last_status: Option<SyncStatus>,
    // ... other fields
}

impl P2PSyncService {
    pub fn new(config: SyncConfig) -> Result<Self> {
        let (status_tx, _) = broadcast::channel(100);
        Ok(Self {
            status_tx,
            last_status: None,
            // ...
        })
    }

    fn notify_status_change(&mut self, new_status: SyncStatus) {
        // Deduplicate
        if self.last_status.as_ref() != Some(&new_status) {
            self.last_status = Some(new_status.clone());

            // Log the change
            tracing::info!(
                "Sync status changed: {:?} -> {:?}",
                self.last_status,
                new_status
            );

            // Broadcast (ignore error if no subscribers)
            let _ = self.status_tx.send(new_status);
        }
    }
}
```

### Stream API
```rust
#[flutter_rust_bridge::frb]
pub fn get_sync_status_stream() -> impl Stream<Item = SyncStatus> {
    let rx = with_sync_service(|service| {
        service.status_tx.subscribe()
    });

    tokio_stream::wrappers::BroadcastStream::new(rx)
        .filter_map(|result| async move { result.ok() })
}
```

### Retry Implementation
```rust
#[flutter_rust_bridge::frb]
pub async fn retry_sync() -> Result<()> {
    with_sync_service_mut(|service| {
        // Clear error state
        service.clear_error();

        // Transition to syncing
        let status = SyncStatus {
            state: SyncState::Syncing,
            syncing_peers: 0,
            online_peers: service.peer_count(),
            last_sync_time: None,
            error_message: None,
        };
        service.notify_status_change(status);

        // Restart sync
        service.restart_sync()
    })
}
```

---

## Acceptance Criteria

- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] Status updates broadcast within 100ms
- [ ] Multiple subscribers work correctly
- [ ] No memory leaks (subscriptions properly cleaned up)
- [ ] Duplicate status updates are filtered
- [ ] Retry functionality works as expected
- [ ] flutter_rust_bridge integration works
- [ ] Status changes are logged
- [ ] Code review approved

---

**最后更新**: 2026-01-17
**作者**: CardMind Team
