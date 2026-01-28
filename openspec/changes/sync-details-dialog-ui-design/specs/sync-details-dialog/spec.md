## ADDED Requirements

### Requirement: Display desktop-only sync details dialog
The system SHALL display a comprehensive sync details dialog only on desktop platforms.

#### Scenario: Show current sync status with real-time updates
- **WHEN** sync details dialog is opened
- **THEN** system displays current sync status in prominent position
- **AND** shows appropriate status icon and color
- **AND** displays last sync time if available
- **AND** provides error message if status is failed
- **AND** updates status in real-time via Stream subscription

#### Scenario: Display device list with online status
- **WHEN** dialog shows device list section
- **THEN** system displays all devices from data pool
- **AND** shows device name, type, and online status
- **AND** displays last online time with proper formatting
- **AND** identifies current device with "本机" label
- **AND** sorts devices with online devices first, then by last seen time

#### Scenario: Show sync statistics and metrics
- **WHEN** dialog displays statistics section
- **THEN** system shows total card count in database
- **AND** displays total data size with proper formatting (B/KB/MB)
- **AND** shows last successful sync time if available
- **AND** displays sync interval in seconds
- **AND** updates statistics when new sync completes

#### Scenario: Display sync history with detailed entries
- **WHEN** dialog displays history section
- **THEN** system shows most recent 20 sync entries
- **AND** each entry shows timestamp, result, card count, device name, data size, duration
- **AND** displays error message for failed syncs
- **AND** formats data size appropriately (B/KB/MB)
- **AND** formats duration appropriately (ms/s)

#### Scenario: Show empty states with helpful guidance
- **WHEN** no devices are available
- **THEN** system displays "暂无设备" with icon and guidance text
- **AND** suggests adding devices through device manager
- **WHEN** no sync history exists
- **THEN** system displays "暂无同步记录" message
- **AND** hides history section gracefully

### Requirement: Provide real-time updates via Stream subscriptions
The system SHALL update all displayed information in real-time as changes occur.

#### Scenario: Update sync status in real-time
- **WHEN** sync status changes while dialog is open
- **THEN** system immediately updates status display
- **AND** shows new status icon and color
- **AND** provides smooth transition animation
- **AND** maintains scroll position and dialog state

#### Scenario: Update device list in real-time
- **WHEN** device comes online or goes offline
- **THEN** system immediately updates device list
- **AND** shows new online/offline status
- **AND** updates last seen time
- **AND** provides smooth status change animation

#### Scenario: Add new sync history entry
- **WHEN** new sync operation completes
- **THEN** system adds new entry to top of history list
- **AND** scrolls to show new entry
- **AND** maintains 20 entry limit (removes oldest if needed)
- **AND** provides success feedback if dialog is open

#### Scenario: Update statistics in real-time
- **WHEN** sync completes with new data
- **THEN** system updates all statistics values
- **AND** shows total card count and data size changes
- **AND** updates last sync time
- **AND** provides visual feedback for changes

### Requirement: Handle desktop-specific dialog interactions
The system SHALL provide desktop-appropriate dialog opening and closing mechanisms.

#### Scenario: Open dialog from sync status indicator
- **WHEN** user clicks sync status indicator on desktop
- **THEN** system opens sync details dialog
- **AND** dialog appears with fade-in and scale animation (200ms)
- **AND** dialog is properly positioned and sized (600px width)
- **AND** focus remains on main application

#### Scenario: Close dialog with multiple methods
- **WHEN** user clicks close button in dialog
- **THEN** system closes dialog with fade-out and scale animation (150ms)
- **AND** returns focus to main application
- **WHEN** user clicks outside dialog area
- **THEN** system closes dialog with same animation
- **WHEN** user presses Escape key
- **THEN** system closes dialog with same animation

#### Scenario: Handle keyboard navigation
- **WHEN** user presses Tab key in dialog
- **THEN** system provides visual focus indicator
- **AND** supports Escape key for closing
- **WHEN** user uses arrow keys for navigation
- **THEN** system navigates between sections if supported
- **AND** maintains proper focus management

### Requirement: Display comprehensive sync status information
The system SHALL display detailed sync status information for all possible states.

#### Scenario: Show not yet synced status
- **WHEN** sync status is "not yet synced"
- **THEN** system displays gray "not yet synced" icon (#9E9E9E)
- **AND** shows "从未同步" status text
- **AND** displays information about initial sync setup
- **AND** provides guidance for first sync

#### Scenario: Show syncing status with animation
- **WHEN** sync status is "syncing"
- **THEN** system displays blue "syncing" icon (#2196F3)
- **AND** shows "同步中" status text
- **AND** provides rotation animation (360° every 2 seconds)
- **AND** displays progress indicator or animation

#### Scenario: Show synced status with time information
- **WHEN** sync status is "synced"
- **THEN** system displays white border badge with green check icon (#4CAF50)
- **AND** shows "刚刚" if synced within 10 seconds
- **AND** shows "已同步" if synced more than 10 seconds ago
- **AND** displays actual last sync time

#### Scenario: Show failed status with error details
- **WHEN** sync status is "failed"
- **THEN** system displays red "failed" icon (#F44336)
- **AND** shows "同步失败" status text
- **AND** displays error message if available
- **AND** provides retry mechanism if available

### Requirement: Handle edge cases and errors gracefully
The system SHALL handle various error states and edge cases with appropriate feedback.

#### Scenario: Handle network disconnection
- **WHEN** network disconnects during active sync
- **THEN** system updates sync status to "failed"
- **AND** displays appropriate error message
- **AND** shows all devices as offline
- **AND** provides retry option in dialog

#### Scenario: Handle data corruption issues
- **WHEN** sync detects data corruption
- **THEN** system updates sync status to "failed"
- **AND** displays "数据损坏" error message
- **AND** provides data recovery guidance
- **AND** continues monitoring for new sync attempts

#### Scenario: Handle device removal from pool
- **WHEN** device is removed from data pool
- **THEN** system removes device from device list
- **AND** updates device count in statistics
- **AND** shows informational message in status
- **AND** updates sync history with device removal event

#### Scenario: Handle sync statistics calculation errors
- **WHEN** statistics calculation fails
- **THEN** system displays "统计信息不可用" message
- **AND** continues to show other available information
- **AND** logs error for debugging
- **AND** provides retry mechanism

### Requirement: Optimize performance for desktop usage
The system SHALL optimize rendering and memory usage for desktop platforms.

#### Scenario: Handle large device lists efficiently
- **WHEN** device list contains many devices
- **THEN** system uses ListView.builder for lazy loading
- **AND** only renders visible items in viewport
- **AND** maintains smooth 60fps scrolling
- **AND** caches rendered device items

#### Scenario: Optimize history rendering
- **WHEN** sync history contains many entries
- **THEN** system limits display to 20 most recent entries
- **AND** renders history items on demand
- **AND** provides "查看完整历史" option if needed

#### Scenario: Optimize real-time update frequency
- **WHEN** receiving frequent status updates
- **THEN** system applies debouncing for rapid changes
- **AND** skips duplicate status updates
- **AND** maintains UI responsiveness
- **AND** provides smooth visual transitions

#### Scenario: Optimize memory usage
- **WHEN** dialog is open for extended periods
- **THEN** system properly manages Stream subscriptions
- **AND** disposes unused resources
- **AND** maintains reasonable memory footprint
- **AND** provides performance metrics if needed

### Requirement: Provide accessibility support for dialog
The system SHALL provide comprehensive accessibility support for screen readers and keyboard navigation.

#### Scenario: Screen reader announcements
- **WHEN** screen reader encounters sync status
- **THEN** system provides semantic label describing current status
- **AND** announces status changes when they occur
- **WHEN** screen reader encounters device list
- **THEN** system announces device name, type, and status
- **AND** provides device count information
- **AND** announces current device identification

#### Scenario: Keyboard navigation and focus
- **WHEN** user navigates with Tab key
- **THEN** system moves focus between dialog sections
- **AND** provides visual focus indicators
- **AND** supports Escape key for dialog dismissal
- **AND** maintains logical tab order

#### Scenario: High contrast color scheme
- **WHEN** displaying dialog content
- **THEN** system maintains 4.5:1 text contrast ratio
- **AND** ensures status colors are distinguishable
- **AND** supports both light and dark themes
- **AND** provides sufficient icon contrast