## ADDED Requirements

### Requirement: Display sync details dialog when indicator is tapped
The system SHALL open a comprehensive sync details dialog when user taps the sync status indicator.

#### Scenario: Open dialog with current status
- **WHEN** user taps the sync status indicator
- **THEN** system opens a modal dialog showing current sync status
- **AND** displays appropriate status icon and description
- **AND** includes current timestamp for last sync

#### Scenario: Show device list in dialog
- **WHEN** sync details dialog is opened
- **AND** devices have been discovered
- **THEN** system displays list of discovered devices
- **AND** each device shows name, connection status, and last seen time
- **AND** devices are sorted by connection status (connected first)

#### Scenario: Show sync statistics
- **WHEN** sync details dialog is opened
- **THEN** system displays synchronization statistics
- **AND** shows total synced cards count
- **AND** shows total data size synchronized
- **AND** shows successful/failed sync attempt counts

#### Scenario: Show sync history
- **WHEN** sync details dialog is opened
- **AND** sync history exists
- **THEN** system displays recent 10 sync events
- **AND** each event shows timestamp, status (success/failed), and involved devices
- **AND** events are ordered chronologically (newest first)

### Requirement: Provide error information for failed sync status
The system SHALL display detailed error information when sync status is failed.

#### Scenario: Show error message
- **WHEN** sync details dialog is opened with failed status
- **THEN** system displays error message
- **AND** message content corresponds to specific error type
- **AND** error is displayed with appropriate visual styling

#### Scenario: Show retry functionality
- **WHEN** sync details dialog is opened with failed status
- **THEN** system displays a "重试" button
- **AND** button is enabled and clickable
- **AND** button triggers immediate sync retry when tapped

#### Scenario: Handle different error types
- **WHEN** sync failed due to no available peers
- **THEN** system displays "未发现可用设备" error message
- **WHEN** sync failed due to connection timeout
- **THEN** system displays "连接超时" error message
- **WHEN** sync failed due to data transmission failure
- **THEN** system displays "数据传输失败" error message
- **WHEN** sync failed due to CRDT merge failure
- **THEN** system displays "数据合并失败" error message
- **WHEN** sync failed due to local storage error
- **THEN** system displays "本地存储错误" error message

### Requirement: Provide manual sync controls
The system SHALL allow users to manually trigger synchronization and device discovery from the dialog.

#### Scenario: Trigger immediate sync
- **WHEN** user taps "立即同步" button
- **THEN** system initiates synchronization process
- **AND** button becomes disabled during sync operation
- **AND** dialog shows sync progress indicators
- **AND** status updates in real-time

#### Scenario: Refresh device list
- **WHEN** user taps "刷新设备列表" button
- **THEN** system initiates device discovery process
- **AND** button shows loading state during discovery
- **AND** device list updates when discovery completes
- **AND** refresh animation is displayed

### Requirement: Update dialog content in real-time
The system SHALL update dialog content dynamically while the dialog remains open.

#### Scenario: Real-time status updates
- **WHEN** sync status changes while dialog is open
- **THEN** dialog status section updates immediately
- **AND** visual indicators reflect new state
- **AND** no manual refresh is required

#### Scenario: Real-time device list updates
- **WHEN** new devices are discovered while dialog is open
- **THEN** device list updates automatically
- **AND** new devices appear in the list
- **AND** existing device status updates in real-time

#### Scenario: Real-time statistics updates
- **WHEN** sync statistics change while dialog is open
- **THEN** statistics section updates immediately
- **AND** counts and totals reflect latest values
- **AND** progress indicators update accordingly

### Requirement: Handle dialog dismissal and cleanup
The system SHALL provide proper dialog dismissal and resource cleanup.

#### Scenario: Dismiss on close button
- **WHEN** user taps close button in dialog
- **THEN** dialog closes with smooth animation
- **AND** all real-time subscriptions are cancelled
- **AND** dialog resources are properly cleaned up

#### Scenario: Dismiss on backdrop tap
- **WHEN** user taps outside the dialog area
- **THEN** dialog closes with smooth animation
- **AND** all real-time subscriptions are cancelled
- **AND** dialog resources are properly cleaned up

#### Scenario: Handle disposal during operations
- **WHEN** dialog is disposed during active operations
- **THEN** system cancels all pending operations
- **AND** properly disposes of Stream subscriptions
- **AND** prevents memory leaks

### Requirement: Support accessibility in sync details dialog
The system SHALL provide comprehensive accessibility support for the sync details dialog.

#### Scenario: Screen reader navigation
- **WHEN** screen reader encounters dialog content
- **THEN** system provides proper semantic labels for all interactive elements
- **AND** reading order follows logical content hierarchy
- **AND** status changes are announced appropriately

#### Scenario: Keyboard navigation
- **WHEN** user navigates dialog with keyboard
- **THEN** all interactive elements are focusable
- **AND** tab order follows logical sequence
- **AND** dialog can be dismissed with Escape key

#### Scenario: High contrast support
- **WHEN** system uses high contrast mode
- **THEN** dialog colors and contrasts remain accessible
- **AND** all text remains readable
- **AND** visual indicators remain distinguishable

### Requirement: Handle edge cases and error states
The system SHALL gracefully handle edge cases and error conditions within the dialog.

#### Scenario: Handle empty device list
- **WHEN** no devices have been discovered
- **THEN** system displays appropriate empty state message
- **AND** provides instructions for device discovery
- **AND** shows refresh device list button

#### Scenario: Handle no sync history
- **WHEN** no sync history exists
- **THEN** system displays appropriate empty state message
- **AND** explains that sync history will appear after first sync
- **AND** maintains consistent dialog layout

#### Scenario: Handle data loading errors
- **WHEN** dialog data fails to load
- **THEN** system displays error message with retry option
- **AND** gracefully degrades dialog functionality
- **AND** provides user feedback for troubleshooting