# Sync Screen Specification | 同步屏幕规格

**Version** | **版本**: 1.0.0
**Status** | **状态**: Active
**Dependencies** | **依赖**: [sync_protocol.md](../../domain/sync_protocol.md)
**Related Tests** | **相关测试**: `test/screens/sync_screen_test.dart`

---

## Overview | 概述

This specification defines a dedicated screen showing comprehensive synchronization information, device management, and sync controls.

本规格定义了一个专门的屏幕，显示全面的同步信息、设备管理和同步控制。

---

## Requirement: Display comprehensive sync status | 需求：显示全面的同步状态

The system SHALL provide a dedicated screen showing detailed synchronization information.

系统应提供显示详细同步信息的专用屏幕。

### Scenario: Show overall sync status | 场景：显示整体同步状态

- **WHEN** sync screen loads
- **操作**：同步屏幕加载
- **THEN** the system SHALL display current sync state (synced, syncing, error)
- **预期结果**：系统应显示当前同步状态（已同步、同步中、错误）
- **AND** show last successful sync timestamp
- **并且**：显示上次成功同步的时间戳
- **AND** display total number of synced cards
- **并且**：显示已同步卡片的总数

---

## Requirement: List discovered devices | 需求：列出发现的设备

The system SHALL show all discovered peer devices and their connection status.

系统应显示所有发现的对等设备及其连接状态。

### Scenario: Display device list | 场景：显示设备列表

- **WHEN** sync screen loads
- **操作**：同步屏幕加载
- **THEN** the system SHALL list all discovered devices
- **预期结果**：系统应列出所有发现的设备
- **AND** show online/offline status for each device
- **并且**：显示每个设备的在线/离线状态
- **AND** display device type (phone, laptop, tablet)
- **并且**：显示设备类型（手机、笔记本、平板）
- **AND** show last seen timestamp for offline devices
- **并且**：显示离线设备的上次可见时间戳

### Scenario: Refresh device list | 场景：刷新设备列表

- **WHEN** user triggers refresh action
- **操作**：用户触发刷新操作
- **THEN** the system SHALL re-scan for available devices
- **预期结果**：系统应重新扫描可用设备
- **AND** update the device list
- **并且**：更新设备列表

---

## Requirement: Show sync history | 需求：显示同步历史

The system SHALL display a chronological list of recent sync events.

系统应显示最近同步事件的时间顺序列表。

### Scenario: Display sync event log | 场景：显示同步事件日志

- **WHEN** viewing sync history section
- **操作**：查看同步历史部分
- **THEN** the system SHALL show recent sync events with timestamps
- **预期结果**：系统应显示带有时间戳的最近同步事件
- **AND** indicate success or failure for each event
- **并且**：指示每个事件的成功或失败
- **AND** show which device was involved in each sync
- **并且**：显示每次同步涉及的设备

### Scenario: Filter sync history | 场景：过滤同步历史

- **WHEN** user applies history filters
- **操作**：用户应用历史过滤器
- **THEN** the system SHALL filter events by device, status, or time range
- **预期结果**：系统应按设备、状态或时间范围过滤事件

---

## Requirement: Provide manual sync controls | 需求：提供手动同步控制

The system SHALL offer manual synchronization actions.

系统应提供手动同步操作。

### Scenario: Trigger manual sync | 场景：触发手动同步

- **WHEN** user taps "Sync Now" button
- **操作**：用户点击"立即同步"按钮
- **THEN** the system SHALL immediately attempt sync with available devices
- **预期结果**：系统应立即尝试与可用设备同步
- **AND** show sync progress indicator
- **并且**：显示同步进度指示器
- **AND** update status when complete
- **并且**：完成时更新状态

### Scenario: Force full sync | 场景：强制完全同步

- **WHEN** user triggers full sync action
- **操作**：用户触发完全同步操作
- **THEN** the system SHALL perform a complete resynchronization of all data
- **预期结果**：系统应执行所有数据的完全重新同步
- **AND** show detailed progress information
- **并且**：显示详细的进度信息

---

## Requirement: Display sync statistics | 需求：显示同步统计信息

The system SHALL show synchronization metrics and statistics.

系统应显示同步指标和统计信息。

### Scenario: Show data volume | 场景：显示数据量

- **WHEN** displaying sync statistics
- **操作**：显示同步统计信息
- **THEN** the system SHALL show total data synchronized
- **预期结果**：系统应显示已同步的总数据量
- **AND** display data synced per device
- **并且**：显示每个设备同步的数据

### Scenario: Show sync success rate | 场景：显示同步成功率

- **WHEN** displaying sync statistics
- **操作**：显示同步统计信息
- **THEN** the system SHALL show percentage of successful syncs
- **预期结果**：系统应显示成功同步的百分比
- **AND** display number of failed syncs with reasons
- **并且**：显示失败同步的次数及原因

---

## Requirement: Configure sync settings | 需求：配置同步设置

The system SHALL allow users to configure synchronization preferences.

系统应允许用户配置同步首选项。

### Scenario: Toggle auto-sync | 场景：切换自动同步

- **WHEN** user toggles auto-sync setting
- **操作**：用户切换自动同步设置
- **THEN** the system SHALL enable or disable automatic synchronization
- **预期结果**：系统应启用或禁用自动同步

### Scenario: Set sync frequency | 场景：设置同步频率

- **WHEN** auto-sync is enabled
- **操作**：自动同步已启用
- **THEN** the system SHALL allow user to set sync frequency (immediate, every N minutes, etc.)
- **预期结果**：系统应允许用户设置同步频率（立即、每 N 分钟等）

---

## Requirement: Show sync conflicts | 需求：显示同步冲突

The system SHALL display and help resolve synchronization conflicts.

系统应显示并帮助解决同步冲突。

### Scenario: List conflicts | 场景：列出冲突

- **WHEN** sync conflicts exist
- **操作**：存在同步冲突
- **THEN** the system SHALL show a conflicts section
- **预期结果**：系统应显示冲突部分
- **AND** list all unresolved conflicts
- **并且**：列出所有未解决的冲突

### Scenario: View conflict details | 场景：查看冲突详情

- **WHEN** user taps on a conflict
- **操作**：用户点击冲突
- **THEN** the system SHALL show both versions of the conflicting data
- **预期结果**：系统应显示冲突数据的两个版本
- **AND** allow user to choose which version to keep
- **并且**：允许用户选择保留哪个版本

---

## Test Coverage | 测试覆盖

**Test File** | **测试文件**: `test/screens/sync_screen_test.dart`

**Screen Tests** | **屏幕测试**:
- `it_should_show_overall_sync_status()` - Overall status | 整体状态
- `it_should_list_discovered_devices()` - Device list | 设备列表
- `it_should_show_device_status()` - Device status | 设备状态
- `it_should_refresh_device_list()` - Refresh devices | 刷新设备
- `it_should_display_sync_event_log()` - Event log | 事件日志
- `it_should_filter_sync_history()` - Filter history | 过滤历史
- `it_should_trigger_manual_sync()` - Manual sync | 手动同步
- `it_should_force_full_sync()` - Full sync | 完全同步
- `it_should_show_sync_statistics()` - Statistics | 统计信息
- `it_should_toggle_auto_sync()` - Toggle auto-sync | 切换自动同步
- `it_should_set_sync_frequency()` - Set frequency | 设置频率
- `it_should_list_conflicts()` - List conflicts | 列出冲突
- `it_should_show_conflict_details()` - Conflict details | 冲突详情

**Acceptance Criteria** | **验收标准**:
- [ ] All screen tests pass | 所有屏幕测试通过
- [ ] Device discovery works correctly | 设备发现正常工作
- [ ] Manual sync controls are reliable | 手动同步控制可靠
- [ ] Conflict resolution is clear | 冲突解决清晰
- [ ] Code review approved | 代码审查通过
- [ ] Documentation updated | 文档已更新

---

## Related Documents | 相关文档

**Related Specs** | **相关规格**:
- [sync_protocol.md](../../domain/sync_protocol.md) - Sync protocol | 同步协议
- [sync_status_indicator.md](../sync_feedback/sync_status_indicator.md) - Status indicator | 状态指示器
- [sync_details_dialog.md](../sync_feedback/sync_details_dialog.md) - Details dialog | 详情对话框

---

**Last Updated** | **最后更新**: 2026-01-21
**Authors** | **作者**: CardMind Team
