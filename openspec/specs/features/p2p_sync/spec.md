# P2P Sync Feature Specification
# P2P 同步功能规格

**Version**: 1.0.0
**版本**: 1.0.0

**Status**: Active
**状态**: 生效中

**Dependencies**: [sync_protocol.md](../../architecture/sync/service.md), [types.md](../../domain/types.md)
**依赖**: [sync_protocol.md](../../architecture/sync/service.md), [types.md](../../domain/types.md)

**Related Tests**: `test/features/p2p_sync_test.dart`
**相关测试**: `test/features/p2p_sync_test.dart`

---

## Overview
## 概述

This specification defines the P2P synchronization feature from the user's perspective. Users can view sync status, manage connected devices, manually trigger synchronization, view sync history, and configure sync settings.

本规格从用户视角定义 P2P 同步功能。用户可以查看同步状态、管理已连接设备、手动触发同步、查看同步历史以及配置同步设置。

---

## Requirement: View real-time sync status
## 需求：查看实时同步状态

The system SHALL provide users with real-time visual feedback about the current synchronization status.

系统应向用户提供关于当前同步状态的实时视觉反馈。

### Scenario: View synced status
### 场景：查看已同步状态

- **GIVEN**: all local changes are synchronized with peer devices
- **前置条件**：所有本地更改都已与对等设备同步
- **WHEN**: user views the sync status indicator
- **操作**：用户查看同步状态指示器
- **THEN**: the system SHALL display a "synced" state with success indicator
- **预期结果**：系统应显示带有成功指示的"已同步"状态
- **AND**: show the timestamp of last successful sync
- **并且**：显示上次成功同步的时间戳

### Scenario: View syncing status
### 场景：查看同步中状态

- **GIVEN**: synchronization is currently in progress
- **前置条件**：同步正在进行中
- **WHEN**: user views the sync status indicator
- **操作**：用户查看同步状态指示器
- **THEN**: the system SHALL display a "syncing" state with animated indicator
- **预期结果**：系统应显示带有动画指示的"同步中"状态
- **AND**: show the number of devices being synced with
- **并且**：显示正在同步的设备数量

### Scenario: View pending changes status
### 场景：查看待同步更改状态

- **GIVEN**: there are local changes not yet synchronized
- **前置条件**：存在尚未同步的本地更改
- **WHEN**: user views the sync status indicator
- **操作**：用户查看同步状态指示器
- **THEN**: the system SHALL display a "pending" state with warning indicator
- **预期结果**：系统应显示带有警告指示的"待同步"状态

### Scenario: View sync error status
### 场景：查看同步错误状态

- **GIVEN**: synchronization has encountered an error
- **前置条件**：同步遇到错误
- **WHEN**: user views the sync status indicator
- **操作**：用户查看同步状态指示器
- **THEN**: the system SHALL display an "error" state with error indicator
- **预期结果**：系统应显示带有错误指示的"错误"状态
- **AND**: provide option to view error details
- **并且**：提供查看错误详情的选项

### Scenario: View disconnected status
### 场景：查看断开连接状态

- **GIVEN**: no peer devices are available for synchronization
- **前置条件**：没有可用于同步的对等设备
- **WHEN**: user views the sync status indicator
- **操作**：用户查看同步状态指示器
- **THEN**: the system SHALL display a "disconnected" state
- **预期结果**：系统应显示"断开连接"状态
- **AND**: indicate that no devices are available
- **并且**：指示没有可用设备

---

## Requirement: View detailed sync information
## 需求：查看详细同步信息

The system SHALL allow users to access comprehensive synchronization information including device list, sync history, and statistics.

系统应允许用户访问全面的同步信息，包括设备列表、同步历史和统计信息。

### Scenario: Open sync details
### 场景：打开同步详情

- **GIVEN**: user is viewing the sync status indicator
- **前置条件**：用户正在查看同步状态指示器
- **WHEN**: user taps on the sync status indicator
- **操作**：用户点击同步状态指示器
- **THEN**: the system SHALL display a detailed sync information view
- **预期结果**：系统应显示详细的同步信息视图
- **AND**: show current sync state and description
- **并且**：显示当前同步状态和描述

### Scenario: View connected devices
### 场景：查看已连接设备

- **GIVEN**: sync details view is open
- **前置条件**：同步详情视图已打开
- **WHEN**: user views the device list section
- **操作**：用户查看设备列表部分
- **THEN**: the system SHALL display all discovered peer devices
- **预期结果**：系统应显示所有发现的对等设备
- **AND**: indicate online/offline status for each device
- **并且**：指示每个设备的在线/离线状态
- **AND**: show device type (phone, laptop, tablet)
- **并且**：显示设备类型（手机、笔记本、平板）
- **AND**: display last seen timestamp for offline devices
- **并且**：显示离线设备的上次可见时间戳

### Scenario: View sync statistics
### 场景：查看同步统计信息

- **GIVEN**: sync details view is open
- **前置条件**：同步详情视图已打开
- **WHEN**: user views the statistics section
- **操作**：用户查看统计信息部分
- **THEN**: the system SHALL display total number of synced cards
- **预期结果**：系统应显示已同步卡片的总数
- **AND**: show total data size synchronized
- **并且**：显示同步的总数据大小
- **AND**: display sync success rate
- **并且**：显示同步成功率
- **AND**: show number of failed syncs with reasons
- **并且**：显示失败同步的次数及原因

### Scenario: View sync history
### 场景：查看同步历史

- **GIVEN**: sync details view is open
- **前置条件**：同步详情视图已打开
- **WHEN**: user views the sync history section
- **操作**：用户查看同步历史部分
- **THEN**: the system SHALL display recent sync events with timestamps
- **预期结果**：系统应显示带有时间戳的最近同步事件
- **AND**: indicate success or failure for each event
- **并且**：指示每个事件的成功或失败
- **AND**: show which device was involved in each sync
- **并且**：显示每次同步涉及的设备

### Scenario: Filter sync history
### 场景：过滤同步历史

- **GIVEN**: sync history is displayed
- **前置条件**：同步历史已显示
- **WHEN**: user applies history filters
- **操作**：用户应用历史过滤器
- **THEN**: the system SHALL filter events by device, status, or time range
- **预期结果**：系统应按设备、状态或时间范围过滤事件

---

## Requirement: Manually trigger synchronization
## 需求：手动触发同步

The system SHALL allow users to manually initiate synchronization with available peer devices.

系统应允许用户手动启动与可用对等设备的同步。

### Scenario: Trigger manual sync
### 场景：触发手动同步

- **GIVEN**: at least one peer device is available
- **前置条件**：至少有一个对等设备可用
- **WHEN**: user taps the "Sync Now" button
- **操作**：用户点击"立即同步"按钮
- **THEN**: the system SHALL immediately attempt synchronization with available devices
- **预期结果**：系统应立即尝试与可用设备同步
- **AND**: display sync progress indicator
- **并且**：显示同步进度指示器
- **AND**: update status when sync completes
- **并且**：同步完成时更新状态

### Scenario: Trigger manual sync when no devices available
### 场景：无可用设备时触发手动同步

- **GIVEN**: no peer devices are available
- **前置条件**：没有可用的对等设备
- **WHEN**: user taps the "Sync Now" button
- **操作**：用户点击"立即同步"按钮
- **THEN**: the system SHALL display an error message indicating no devices are available
- **预期结果**：系统应显示错误消息，指示没有可用设备
- **AND**: suggest actions to discover devices
- **并且**：建议发现设备的操作

### Scenario: Force full synchronization
### 场景：强制完全同步

- **GIVEN**: user wants to perform a complete resynchronization
- **前置条件**：用户想要执行完全重新同步
- **WHEN**: user triggers the "Full Sync" action
- **操作**：用户触发"完全同步"操作
- **THEN**: the system SHALL perform a complete resynchronization of all data
- **预期结果**：系统应执行所有数据的完全重新同步
- **AND**: display detailed progress information
- **并且**：显示详细的进度信息

### Scenario: Refresh device list
### 场景：刷新设备列表

- **GIVEN**: user wants to discover new devices
- **前置条件**：用户想要发现新设备
- **WHEN**: user taps the "Refresh Devices" button
- **操作**：用户点击"刷新设备"按钮
- **THEN**: the system SHALL re-scan for available peer devices
- **预期结果**：系统应重新扫描可用的对等设备
- **AND**: update the device list display
- **并且**：更新设备列表显示

---

## Requirement: Retry failed synchronization
## 需求：重试失败的同步

The system SHALL allow users to retry synchronization after a failure.

系统应允许用户在失败后重试同步。

### Scenario: Retry sync after error
### 场景：错误后重试同步

- **GIVEN**: synchronization has failed with an error
- **前置条件**：同步因错误而失败
- **WHEN**: user taps the "Retry" button in error details
- **操作**：用户点击错误详情中的"重试"按钮
- **THEN**: the system SHALL attempt to restart synchronization
- **预期结果**：系统应尝试重新启动同步
- **AND**: clear the previous error state
- **并且**：清除之前的错误状态
- **AND**: display syncing status
- **并且**：显示同步中状态

---

## Requirement: Configure sync settings
## 需求：配置同步设置

The system SHALL allow users to configure synchronization preferences and behavior.

系统应允许用户配置同步首选项和行为。

### Scenario: Enable auto-sync
### 场景：启用自动同步

- **GIVEN**: auto-sync is currently disabled
- **前置条件**：自动同步当前已禁用
- **WHEN**: user enables the auto-sync setting
- **操作**：用户启用自动同步设置
- **THEN**: the system SHALL automatically synchronize when changes are detected
- **预期结果**：系统应在检测到更改时自动同步
- **AND**: display confirmation message
- **并且**：显示确认消息

### Scenario: Disable auto-sync
### 场景：禁用自动同步

- **GIVEN**: auto-sync is currently enabled
- **前置条件**：自动同步当前已启用
- **WHEN**: user disables the auto-sync setting
- **操作**：用户禁用自动同步设置
- **THEN**: the system SHALL stop automatic synchronization
- **预期结果**：系统应停止自动同步
- **AND**: require manual sync triggers
- **并且**：需要手动触发同步
- **AND**: display confirmation message
- **并且**：显示确认消息

### Scenario: Set sync frequency
### 场景：设置同步频率

- **GIVEN**: auto-sync is enabled
- **前置条件**：自动同步已启用
- **WHEN**: user sets sync frequency to a specific interval
- **操作**：用户将同步频率设置为特定间隔
- **THEN**: the system SHALL synchronize at the specified frequency
- **预期结果**：系统应按指定频率同步
- **AND**: display the configured frequency in settings
- **并且**：在设置中显示配置的频率

---

## Requirement: View and resolve sync conflicts
## 需求：查看和解决同步冲突

The system SHALL display synchronization conflicts and help users resolve them.

系统应显示同步冲突并帮助用户解决它们。

### Scenario: View conflict list
### 场景：查看冲突列表

- **GIVEN**: sync conflicts exist
- **前置条件**：存在同步冲突
- **WHEN**: user views the sync details
- **操作**：用户查看同步详情
- **THEN**: the system SHALL display a conflicts section
- **预期结果**：系统应显示冲突部分
- **AND**: list all unresolved conflicts
- **并且**：列出所有未解决的冲突
- **AND**: indicate the number of conflicts
- **并且**：指示冲突数量

### Scenario: View conflict details
### 场景：查看冲突详情

- **GIVEN**: user is viewing the conflict list
- **前置条件**：用户正在查看冲突列表
- **WHEN**: user taps on a specific conflict
- **操作**：用户点击特定冲突
- **THEN**: the system SHALL display both versions of the conflicting data
- **预期结果**：系统应显示冲突数据的两个版本
- **AND**: show which devices created each version
- **并且**：显示哪些设备创建了每个版本
- **AND**: display timestamps for each version
- **并且**：显示每个版本的时间戳

### Scenario: Resolve conflict by choosing version
### 场景：通过选择版本解决冲突

- **GIVEN**: user is viewing conflict details
- **前置条件**：用户正在查看冲突详情
- **WHEN**: user selects which version to keep
- **操作**：用户选择保留哪个版本
- **THEN**: the system SHALL apply the selected version
- **预期结果**：系统应应用所选版本
- **AND**: mark the conflict as resolved
- **并且**：将冲突标记为已解决
- **AND**: synchronize the resolution with other devices
- **并且**：将解决方案与其他设备同步

### Scenario: Auto-resolve conflicts
### 场景：自动解决冲突

- **GIVEN**: CRDT-based conflict resolution is enabled
- **前置条件**：基于 CRDT 的冲突解决已启用
- **WHEN**: a conflict occurs
- **操作**：发生冲突
- **THEN**: the system SHALL automatically resolve the conflict using CRDT merge rules
- **预期结果**：系统应使用 CRDT 合并规则自动解决冲突
- **AND**: log the conflict resolution in sync history
- **并且**：在同步历史中记录冲突解决

---

## Requirement: Access dedicated sync screen
## 需求：访问专用同步屏幕

The system SHALL provide a dedicated screen for comprehensive synchronization management.

系统应提供专用屏幕用于全面的同步管理。

### Scenario: Navigate to sync screen
### 场景：导航到同步屏幕

- **GIVEN**: user wants to manage synchronization
- **前置条件**：用户想要管理同步
- **WHEN**: user navigates to the sync screen from settings or main menu
- **操作**：用户从设置或主菜单导航到同步屏幕
- **THEN**: the system SHALL display the dedicated sync screen
- **预期结果**：系统应显示专用同步屏幕
- **AND**: show overall sync status
- **并且**：显示整体同步状态
- **AND**: display device list
- **并且**：显示设备列表
- **AND**: show sync history
- **并且**：显示同步历史
- **AND**: provide sync controls
- **并且**：提供同步控制

### Scenario: View comprehensive sync information
### 场景：查看全面的同步信息

- **GIVEN**: sync screen is displayed
- **前置条件**：同步屏幕已显示
- **WHEN**: user views the screen
- **操作**：用户查看屏幕
- **THEN**: the system SHALL display current sync state
- **预期结果**：系统应显示当前同步状态
- **AND**: show last successful sync timestamp
- **并且**：显示上次成功同步的时间戳
- **AND**: display total number of synced cards
- **并且**：显示已同步卡片的总数
- **AND**: list all discovered devices with their status
- **并且**：列出所有发现的设备及其状态
- **AND**: show recent sync events
- **并且**：显示最近的同步事件

---

## Requirement: Receive sync status updates
## 需求：接收同步状态更新

The system SHALL automatically update sync status display when synchronization state changes.

系统应在同步状态更改时自动更新同步状态显示。

### Scenario: Auto-update on state change
### 场景：状态更改时自动更新

- **GIVEN**: user is viewing sync status
- **前置条件**：用户正在查看同步状态
- **WHEN**: the underlying synchronization state changes
- **操作**：底层同步状态更改
- **THEN**: the system SHALL update the display within 1 second
- **预期结果**：系统应在 1 秒内更新显示
- **AND**: animate the transition between states
- **并且**：在状态之间添加过渡动画

### Scenario: Update device list on discovery
### 场景：发现时更新设备列表

- **GIVEN**: user is viewing the device list
- **前置条件**：用户正在查看设备列表
- **WHEN**: a new peer device is discovered
- **操作**：发现新的对等设备
- **THEN**: the system SHALL add the device to the list
- **预期结果**：系统应将设备添加到列表
- **AND**: display notification of new device
- **并且**：显示新设备的通知

### Scenario: Update device status on connection change
### 场景：连接更改时更新设备状态

- **GIVEN**: user is viewing the device list
- **前置条件**：用户正在查看设备列表
- **WHEN**: a device's connection status changes
- **操作**：设备的连接状态更改
- **THEN**: the system SHALL update the device's status indicator
- **预期结果**：系统应更新设备的状态指示器
- **AND**: update last seen timestamp if device goes offline
- **并且**：如果设备离线，更新上次可见时间戳

---

## Test Coverage
## 测试覆盖

**Test File**: `test/features/p2p_sync_test.dart`
**测试文件**: `test/features/p2p_sync_test.dart`

**Feature Tests**:
**功能测试**:
- `it_should_display_synced_status()` - Display synced state
- `it_should_display_synced_status()` - 显示已同步状态
- `it_should_display_syncing_status_with_device_count()` - Display syncing state
- `it_should_display_syncing_status_with_device_count()` - 显示同步中状态
- `it_should_display_pending_status()` - Display pending state
- `it_should_display_pending_status()` - 显示待同步状态
- `it_should_display_error_status()` - Display error state
- `it_should_display_error_status()` - 显示错误状态
- `it_should_display_disconnected_status()` - Display disconnected state
- `it_should_display_disconnected_status()` - 显示断开连接状态
- `it_should_open_sync_details_on_tap()` - Open details on tap
- `it_should_open_sync_details_on_tap()` - 点击打开详情
- `it_should_display_device_list()` - Display device list
- `it_should_display_device_list()` - 显示设备列表
- `it_should_display_sync_statistics()` - Display statistics
- `it_should_display_sync_statistics()` - 显示统计信息
- `it_should_display_sync_history()` - Display sync history
- `it_should_display_sync_history()` - 显示同步历史
- `it_should_filter_sync_history()` - Filter history
- `it_should_filter_sync_history()` - 过滤历史
- `it_should_trigger_manual_sync()` - Trigger manual sync
- `it_should_trigger_manual_sync()` - 触发手动同步
- `it_should_show_error_when_no_devices()` - Show error when no devices
- `it_should_show_error_when_no_devices()` - 无设备时显示错误
- `it_should_force_full_sync()` - Force full sync
- `it_should_force_full_sync()` - 强制完全同步
- `it_should_refresh_device_list()` - Refresh device list
- `it_should_refresh_device_list()` - 刷新设备列表
- `it_should_retry_failed_sync()` - Retry failed sync
- `it_should_retry_failed_sync()` - 重试失败的同步
- `it_should_enable_auto_sync()` - Enable auto-sync
- `it_should_enable_auto_sync()` - 启用自动同步
- `it_should_disable_auto_sync()` - Disable auto-sync
- `it_should_disable_auto_sync()` - 禁用自动同步
- `it_should_set_sync_frequency()` - Set sync frequency
- `it_should_set_sync_frequency()` - 设置同步频率
- `it_should_display_conflict_list()` - Display conflict list
- `it_should_display_conflict_list()` - 显示冲突列表
- `it_should_display_conflict_details()` - Display conflict details
- `it_should_display_conflict_details()` - 显示冲突详情
- `it_should_resolve_conflict_by_choosing_version()` - Resolve conflict
- `it_should_resolve_conflict_by_choosing_version()` - 解决冲突
- `it_should_auto_resolve_crdt_conflicts()` - Auto-resolve CRDT conflicts
- `it_should_auto_resolve_crdt_conflicts()` - 自动解决 CRDT 冲突
- `it_should_navigate_to_sync_screen()` - Navigate to sync screen
- `it_should_navigate_to_sync_screen()` - 导航到同步屏幕
- `it_should_update_status_within_1_second()` - Update within 1s
- `it_should_update_status_within_1_second()` - 1秒内更新
- `it_should_update_device_list_on_discovery()` - Update on discovery
- `it_should_update_device_list_on_discovery()` - 发现时更新
- `it_should_update_device_status_on_connection_change()` - Update on connection change
- `it_should_update_device_status_on_connection_change()` - 连接更改时更新

**Acceptance Criteria**:
**验收标准**:
- [ ] All feature tests pass
- [ ] 所有功能测试通过
- [ ] Sync status updates in real-time
- [ ] 同步状态实时更新
- [ ] Manual sync controls work reliably
- [ ] 手动同步控制可靠工作
- [ ] Device discovery and list updates correctly
- [ ] 设备发现和列表正确更新
- [ ] Conflict resolution is clear and functional
- [ ] 冲突解决清晰且功能正常
- [ ] Auto-sync settings work as expected
- [ ] 自动同步设置按预期工作
- [ ] Code review approved
- [ ] 代码审查通过
- [ ] Documentation updated
- [ ] 文档已更新

---

## Related Documents
## 相关文档

**Domain Specs**:
**领域规格**:
- [sync_protocol.md](../../architecture/sync/service.md) - Sync protocol and business rules
- [sync_protocol.md](../../architecture/sync/service.md) - 同步协议和业务规则
- [types.md](../../domain/types.md) - Common domain types
- [types.md](../../domain/types.md) - 通用领域类型

**Architecture Specs**:
**架构规格**:
- [architecture/sync/service.md](../../architecture/sync/service.md) - Sync service implementation
- [architecture/sync/service.md](../../architecture/sync/service.md) - 同步服务实现
- [architecture/sync/peer_discovery.md](../../architecture/sync/peer_discovery.md) - Peer discovery mechanism
- [architecture/sync/peer_discovery.md](../../architecture/sync/peer_discovery.md) - 对等设备发现机制
- [architecture/sync/conflict_resolution.md](../../architecture/sync/conflict_resolution.md) - Conflict resolution
- [architecture/sync/conflict_resolution.md](../../architecture/sync/conflict_resolution.md) - 冲突解决

**UI Specs**:
**UI 规格**:
- [ui/components/shared/sync_status_indicator.md](../../ui/components/shared/sync_status_indicator.md) - Status indicator component
- [ui/components/shared/sync_status_indicator.md](../../ui/components/shared/sync_status_indicator.md) - 状态指示器组件
- [ui/components/shared/sync_details_dialog.md](../../ui/components/shared/sync_details_dialog.md) - Details dialog component
- [ui/components/shared/sync_details_dialog.md](../../ui/components/shared/sync_details_dialog.md) - 详情对话框组件
- [ui/screens/mobile/sync_screen.md](../../ui/screens/mobile/sync_screen.md) - Sync screen
- [ui/screens/mobile/sync_screen.md](../../ui/screens/mobile/sync_screen.md) - 同步屏幕

---

**Last Updated**: 2026-01-23
**最后更新**: 2026-01-23

**Authors**: CardMind Team
**作者**: CardMind Team
