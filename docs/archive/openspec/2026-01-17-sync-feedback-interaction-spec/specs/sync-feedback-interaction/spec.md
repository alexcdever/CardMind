# Sync Feedback Interaction Specification

## 📋 规格编号: SP-FLUT-010
**版本**: 1.0.0
**状态**: 草稿
**依赖**: SP-FLUT-008 (主页交互规格), SP-SYNC-006 (同步层规格)

---

## ADDED Requirements

### Requirement: System displays sync status indicator
The system SHALL display a sync status indicator in the AppBar that shows the current synchronization state.

#### Scenario: Indicator is visible in AppBar
- **WHEN** user is on the home screen
- **THEN** sync status indicator is visible in the AppBar at the right side

#### Scenario: Indicator updates in real-time
- **WHEN** sync status changes
- **THEN** indicator updates within 500ms

#### Scenario: Indicator subscribes to status stream
- **WHEN** home screen loads
- **THEN** system subscribes to `SyncApi.statusStream`

#### Scenario: Indicator unsubscribes on dispose
- **WHEN** home screen is disposed
- **THEN** system unsubscribes from status stream

---

### Requirement: System defines sync state machine
The system SHALL implement a 4-state state machine for synchronization status.

#### Scenario: Initial state is disconnected
- **WHEN** app starts with no peers
- **THEN** sync status is `disconnected`

#### Scenario: Transition from disconnected to syncing
- **WHEN** system discovers a peer and starts sync
- **THEN** sync status transitions to `syncing`

#### Scenario: Transition from syncing to synced
- **WHEN** sync completes successfully
- **THEN** sync status transitions to `synced`

#### Scenario: Transition from syncing to failed
- **WHEN** sync fails due to error
- **THEN** sync status transitions to `failed`

#### Scenario: Transition from synced to syncing
- **WHEN** new changes are detected
- **THEN** sync status transitions to `syncing`

#### Scenario: Transition from failed to syncing
- **WHEN** user retries sync
- **THEN** sync status transitions to `syncing`

---

### Requirement: System displays disconnected state
The system SHALL display a disconnected indicator when no peers are available.

#### Scenario: Disconnected shows cloud_off icon
- **WHEN** sync status is `disconnected`
- **THEN** indicator displays `Icons.cloud_off`

#### Scenario: Disconnected icon is grey
- **WHEN** sync status is `disconnected`
- **THEN** icon color is grey (#757575)

#### Scenario: Disconnected shows text
- **WHEN** sync status is `disconnected`
- **THEN** indicator displays text "未同步"

#### Scenario: Disconnected has no animation
- **WHEN** sync status is `disconnected`
- **THEN** icon is static (no animation)

---

### Requirement: System displays syncing state
The system SHALL display a syncing indicator when synchronization is in progress.

#### Scenario: Syncing shows sync icon
- **WHEN** sync status is `syncing`
- **THEN** indicator displays `Icons.sync`

#### Scenario: Syncing icon is primary color
- **WHEN** sync status is `syncing`
- **THEN** icon color is primary color (#00897B)

#### Scenario: Syncing shows text
- **WHEN** sync status is `syncing`
- **THEN** indicator displays text "同步中..."

#### Scenario: Syncing icon rotates
- **WHEN** sync status is `syncing`
- **THEN** icon rotates continuously (360° every 2 seconds)

#### Scenario: Syncing shows peer count
- **WHEN** sync status is `syncing` with N peers
- **THEN** indicator displays "同步中 (N 台设备)"

---

### Requirement: System displays synced state
The system SHALL display a synced indicator when synchronization is complete.

#### Scenario: Synced shows cloud_done icon
- **WHEN** sync status is `synced`
- **THEN** indicator displays `Icons.cloud_done`

#### Scenario: Synced icon is green
- **WHEN** sync status is `synced`
- **THEN** icon color is green (#43A047)

#### Scenario: Synced shows text
- **WHEN** sync status is `synced`
- **THEN** indicator displays text "已同步"

#### Scenario: Synced has no animation
- **WHEN** sync status is `synced`
- **THEN** icon is static (no animation)

#### Scenario: Synced shows last sync time
- **WHEN** sync status is `synced`
- **THEN** indicator displays "已同步 (刚刚)" or relative time

---

### Requirement: System displays failed state
The system SHALL display a failed indicator when synchronization fails.

#### Scenario: Failed shows cloud_off icon with warning
- **WHEN** sync status is `failed`
- **THEN** indicator displays `Icons.cloud_off` with warning badge

#### Scenario: Failed icon is orange
- **WHEN** sync status is `failed`
- **THEN** icon color is orange (#FB8C00)

#### Scenario: Failed shows text
- **WHEN** sync status is `failed`
- **THEN** indicator displays text "同步失败"

#### Scenario: Failed has no animation
- **WHEN** sync status is `failed`
- **THEN** icon is static (no animation)

---

### Requirement: User can tap indicator to view details
The system SHALL allow users to tap the sync status indicator to view synchronization details.

#### Scenario: Tapping indicator shows details dialog
- **WHEN** user taps sync status indicator
- **THEN** system displays sync details dialog

#### Scenario: Details dialog shows current status
- **WHEN** details dialog is displayed
- **THEN** dialog shows current sync status and description

#### Scenario: Details dialog shows peer list
- **WHEN** details dialog is displayed with active peers
- **THEN** dialog shows list of connected peers

#### Scenario: Details dialog shows error message
- **WHEN** details dialog is displayed with failed status
- **THEN** dialog shows error message and retry button

#### Scenario: Tapping retry triggers sync
- **WHEN** user taps retry button in details dialog
- **THEN** system attempts to restart synchronization

---

### Requirement: System handles sync status updates efficiently
The system SHALL optimize sync status updates to avoid excessive UI rebuilds.

#### Scenario: Duplicate status updates are filtered
- **WHEN** status stream emits duplicate status
- **THEN** system does NOT rebuild UI

#### Scenario: Status updates are debounced
- **WHEN** status changes rapidly (< 500ms between changes)
- **THEN** system debounces updates to avoid flicker

#### Scenario: Stream subscription is managed properly
- **WHEN** widget is disposed
- **THEN** system cancels stream subscription

---

### Requirement: System provides accessibility support
The system SHALL provide accessibility labels for sync status indicator.

#### Scenario: Disconnected has semantic label
- **WHEN** sync status is `disconnected`
- **THEN** indicator has semantic label "未同步，无可用设备"

#### Scenario: Syncing has semantic label
- **WHEN** sync status is `syncing`
- **THEN** indicator has semantic label "正在同步数据"

#### Scenario: Synced has semantic label
- **WHEN** sync status is `synced`
- **THEN** indicator has semantic label "已同步，数据最新"

#### Scenario: Failed has semantic label
- **WHEN** sync status is `failed`
- **THEN** indicator has semantic label "同步失败，点击查看详情"

---

## MODIFIED Requirements

### Requirement: Home screen AppBar displays sync status
**Modified from**: SP-FLUT-008 - Home screen displays AppBar

The home screen AppBar SHALL display a sync status indicator at the right side.

**Changes**:
- ADDED: Sync status indicator widget
- ADDED: Real-time status updates via Stream

#### Scenario: AppBar includes sync indicator
- **WHEN** home screen is displayed
- **THEN** AppBar includes sync status indicator at the right

#### Scenario: Sync indicator is always visible
- **WHEN** user scrolls the card list
- **THEN** sync indicator remains visible in AppBar

---

## Test Coverage

### Unit Tests
- `it_should_initialize_with_disconnected_state()`
- `it_should_transition_from_disconnected_to_syncing()`
- `it_should_transition_from_syncing_to_synced()`
- `it_should_transition_from_syncing_to_failed()`
- `it_should_filter_duplicate_status_updates()`
- `it_should_debounce_rapid_status_changes()`
- `it_should_cancel_subscription_on_dispose()`

### Widget Tests
- `it_should_render_sync_status_indicator()`
- `it_should_show_cloud_off_icon_when_disconnected()`
- `it_should_show_rotating_sync_icon_when_syncing()`
- `it_should_show_cloud_done_icon_when_synced()`
- `it_should_show_warning_icon_when_failed()`
- `it_should_display_correct_text_for_each_state()`
- `it_should_use_correct_color_for_each_state()`
- `it_should_show_details_dialog_on_tap()`
- `it_should_show_retry_button_when_failed()`

### Integration Tests
- `it_should_update_indicator_when_sync_status_changes()`
- `it_should_subscribe_to_sync_api_stream()`
- `it_should_trigger_sync_on_retry()`
- `it_should_display_peer_count_when_syncing()`

---

## State Machine Diagram

```
┌─────────────┐
│ disconnected│◄─────┐
└──────┬──────┘      │
       │             │
       │ discover    │ disconnect
       │ peer        │
       ▼             │
┌─────────────┐      │
│   syncing   │──────┤
└──────┬──────┘      │
       │             │
       ├─────────────┘
       │ success
       ▼
┌─────────────┐
│   synced    │
└──────┬──────┘
       │
       │ new changes
       │
       └──────────────► syncing

       syncing ──error──► failed ──retry──► syncing
```

---

## Implementation Notes

### SyncStatus Model
```dart
enum SyncState {
  disconnected,
  syncing,
  synced,
  failed,
}

class SyncStatus {
  final SyncState state;
  final int syncingPeers;
  final DateTime? lastSyncTime;
  final String? errorMessage;

  bool get isActive => state == SyncState.syncing || state == SyncState.synced;
}
```

### Stream Integration
```dart
StreamBuilder<SyncStatus>(
  stream: SyncApi.statusStream.distinct(),
  builder: (context, snapshot) {
    final status = snapshot.data ?? SyncStatus.disconnected();
    return SyncStatusIndicator(status: status);
  },
)
```

### Animation
```dart
AnimatedRotation(
  turns: _isRotating ? _rotationController.value : 0,
  child: Icon(Icons.sync),
)
```

---

## Acceptance Criteria

- [ ] All unit tests pass
- [ ] All widget tests pass
- [ ] All integration tests pass
- [ ] State machine transitions correctly
- [ ] UI updates in real-time (< 500ms)
- [ ] No memory leaks (stream properly disposed)
- [ ] Accessibility labels present
- [ ] Code review approved
- [ ] Documentation updated

---

**最后更新**: 2026-01-16
**作者**: CardMind Team
