# SP-FLUT-010: Sync Feedback Interaction Specification (Delta)

**Status**: Delta
**Date**: 2026-01-17
**Module**: Flutter UI - Sync Feedback
**Related Tests**: `test/widgets/sync_status_indicator_test.dart`, `test/screens/home_screen_test.dart`

---

## MODIFIED Requirements

### Requirement: System displays sync status indicator
**Modified from**: SP-FLUT-010 - System displays sync status indicator

The system SHALL display a sync status indicator in the AppBar that shows the current synchronization state using real-time stream updates.

**Changes**:
- MODIFIED: Use real Stream from `get_sync_status_stream()` instead of mock data
- MODIFIED: Implement proper stream subscription management
- ADDED: Stream error handling and fallback to disconnected state

#### Scenario: Indicator is visible in AppBar
- **WHEN** user is on the home screen
- **THEN** sync status indicator is visible in the AppBar at the right side

#### Scenario: Indicator updates in real-time
- **WHEN** sync status changes
- **THEN** indicator updates within 500ms

#### Scenario: Indicator subscribes to real status stream
- **WHEN** home screen loads
- **THEN** system subscribes to `getSyncStatusStream()` from Rust
- **AND** receives real-time status updates from P2PSyncService

#### Scenario: Indicator unsubscribes on dispose
- **WHEN** home screen is disposed
- **THEN** system unsubscribes from status stream
- **AND** releases all stream resources

#### Scenario: Indicator handles stream errors gracefully
- **WHEN** status stream emits an error
- **THEN** indicator falls back to disconnected state
- **AND** logs the error for debugging

---

### Requirement: User can tap indicator to view details
**Modified from**: SP-FLUT-010 - User can tap indicator to view details

The system SHALL allow users to tap the sync status indicator to view synchronization details and trigger retry.

**Changes**:
- MODIFIED: Retry button calls real `retrySync()` API instead of mock
- ADDED: Retry button shows loading state during retry
- ADDED: Error handling for retry failures

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

#### Scenario: Tapping retry triggers real sync
- **WHEN** user taps retry button in details dialog
- **THEN** system calls `retrySync()` from Rust API
- **AND** button shows loading state during retry
- **AND** dialog closes on successful retry

#### Scenario: Retry failure shows error message
- **WHEN** retry_sync() fails (e.g., no peers available)
- **THEN** system displays error message in dialog
- **AND** retry button returns to enabled state

---

### Requirement: System handles sync status updates efficiently
**Modified from**: SP-FLUT-010 - System handles sync status updates efficiently

The system SHALL optimize sync status updates from real stream to avoid excessive UI rebuilds.

**Changes**:
- MODIFIED: Apply distinct() and debounce to real stream from Rust
- ADDED: Handle stream reconnection on errors
- ADDED: Monitor stream health and log issues

#### Scenario: Duplicate status updates are filtered
- **WHEN** status stream emits duplicate status from Rust
- **THEN** system does NOT rebuild UI
- **AND** distinct() filter prevents redundant updates

#### Scenario: Status updates are debounced
- **WHEN** status changes rapidly (< 500ms between changes)
- **THEN** system debounces updates to avoid flicker
- **AND** only last status in window is displayed

#### Scenario: Stream subscription is managed properly
- **WHEN** widget is disposed
- **THEN** system cancels stream subscription
- **AND** no memory leaks occur

#### Scenario: Stream reconnects on error
- **WHEN** status stream encounters an error
- **THEN** system logs the error
- **AND** falls back to disconnected state
- **AND** attempts to resubscribe after delay

---

## ADDED Requirements

### Requirement: System integrates with Rust stream API
The system SHALL integrate with the Rust-side stream API for real-time sync status updates.

#### Scenario: Subscribe to Rust status stream on init
- **WHEN** SyncStatusIndicator initializes
- **THEN** system calls `getSyncStatusStream()` from flutter_rust_bridge
- **AND** receives Stream<SyncStatus> from Rust

#### Scenario: Handle initial status emission
- **WHEN** subscribing to status stream
- **THEN** stream immediately emits current status
- **AND** indicator displays the initial status

#### Scenario: Handle status updates from Rust
- **WHEN** Rust P2PSyncService broadcasts status change
- **THEN** Flutter receives the update via stream
- **AND** indicator updates to reflect new status

#### Scenario: Handle stream completion
- **WHEN** status stream completes (e.g., service shutdown)
- **THEN** indicator falls back to disconnected state
- **AND** logs the completion event

---

### Requirement: System provides retry functionality
The system SHALL allow users to retry synchronization after failure using real Rust API.

#### Scenario: Retry button is visible when failed
- **WHEN** sync status is failed
- **THEN** details dialog shows retry button
- **AND** button is enabled

#### Scenario: Retry calls Rust API
- **WHEN** user taps retry button
- **THEN** system calls `retrySync()` from Rust
- **AND** awaits the result

#### Scenario: Retry success updates status
- **WHEN** retrySync() succeeds
- **THEN** status stream emits syncing status
- **AND** indicator updates to show syncing state
- **AND** dialog closes

#### Scenario: Retry failure shows error
- **WHEN** retrySync() returns error
- **THEN** system displays error message in dialog
- **AND** retry button remains enabled for another attempt

#### Scenario: Retry is disabled during operation
- **WHEN** retry is in progress
- **THEN** retry button shows loading indicator
- **AND** button is disabled to prevent duplicate retries

---

## Test Coverage

### Modified Widget Tests
- `it_should_subscribe_to_real_sync_api_stream()` - verify real stream integration
- `it_should_trigger_real_sync_on_retry()` - verify real retry API call
- `it_should_handle_stream_errors_gracefully()` - verify error handling

### New Widget Tests
- `it_should_emit_initial_status_on_subscription()`
- `it_should_apply_distinct_filter_to_stream()`
- `it_should_apply_debounce_to_stream()`
- `it_should_show_loading_state_during_retry()`
- `it_should_display_retry_error_message()`
- `it_should_disable_retry_button_during_operation()`
- `it_should_reconnect_stream_on_error()`

### New Integration Tests
- `it_should_receive_status_from_rust_stream()`
- `it_should_call_rust_retry_api()`
- `it_should_handle_rust_api_errors()`

---

## Implementation Notes

### Stream Integration
```dart
class _HomeScreenState extends State<HomeScreen> {
  late Stream<SyncStatus> _statusStream;

  @override
  void initState() {
    super.initState();
    // Use real stream from Rust
    _statusStream = getSyncStatusStream()
        .distinct()  // Filter duplicates
        .debounceTime(const Duration(milliseconds: 500))  // Debounce
        .handleError((error) {
          debugPrint('Sync status stream error: $error');
          return SyncStatus.disconnected();
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          StreamBuilder<SyncStatus>(
            stream: _statusStream,
            initialData: SyncStatus.disconnected(),
            builder: (context, snapshot) {
              final status = snapshot.data ?? SyncStatus.disconnected();
              return SyncStatusIndicator(
                status: status,
                onTap: () => _showSyncDetails(context, status),
              );
            },
          ),
        ],
      ),
      // ...
    );
  }
}
```

### Retry Implementation
```dart
class SyncDetailsDialog extends StatefulWidget {
  final SyncStatus status;

  const SyncDetailsDialog({required this.status});

  @override
  State<SyncDetailsDialog> createState() => _SyncDetailsDialogState();
}

class _SyncDetailsDialogState extends State<SyncDetailsDialog> {
  bool _isRetrying = false;
  String? _retryError;

  Future<void> _handleRetry() async {
    setState(() {
      _isRetrying = true;
      _retryError = null;
    });

    try {
      // Call real Rust API
      await retrySync();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _retryError = e.toString();
      });
    } finally {
      setState(() {
        _isRetrying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('同步详情'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ... status display
          if (widget.status.state == SyncState.failed) ...[
            Text('错误: ${widget.status.errorMessage}'),
            if (_retryError != null)
              Text('重试失败: $_retryError', style: TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        if (widget.status.state == SyncState.failed)
          ElevatedButton(
            onPressed: _isRetrying ? null : _handleRetry,
            child: _isRetrying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('重试'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
```

### Stream Error Handling
```dart
extension StreamErrorHandling on Stream<SyncStatus> {
  Stream<SyncStatus> withErrorHandling() {
    return handleError((error, stackTrace) {
      debugPrint('Sync status stream error: $error');
      debugPrint('Stack trace: $stackTrace');
      // Return disconnected state on error
      return SyncStatus.disconnected();
    }).onErrorReturn(SyncStatus.disconnected());
  }
}
```

---

## Migration Notes

### Before (Mock Implementation)
```dart
// Old: Mock stream
Stream<SyncStatus> _getMockStatusStream() async* {
  yield SyncStatus.disconnected();
  await Future.delayed(Duration(seconds: 2));
  yield SyncStatus.syncing(1);
  // ...
}
```

### After (Real Implementation)
```dart
// New: Real stream from Rust
Stream<SyncStatus> _statusStream = getSyncStatusStream()
    .distinct()
    .debounceTime(const Duration(milliseconds: 500));
```

### Breaking Changes
None - this is an internal implementation change. The UI API remains the same.

---

## Acceptance Criteria

- [ ] All existing SP-FLUT-010 tests still pass
- [ ] All new tests pass
- [ ] Stream integration with Rust works correctly
- [ ] Retry functionality calls real Rust API
- [ ] Stream errors are handled gracefully
- [ ] No memory leaks (stream properly disposed)
- [ ] UI updates in real-time (< 500ms)
- [ ] Retry button shows loading state
- [ ] Retry errors are displayed to user
- [ ] Code review approved

---

**最后更新**: 2026-01-17
**作者**: CardMind Team
