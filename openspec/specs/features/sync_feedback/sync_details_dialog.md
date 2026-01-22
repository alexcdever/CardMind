# Sync Details Dialog Specification
# 同步详情对话框规格

**Version** | **版本**: 1.0.0
**Status** | **状态**: Active
**Dependencies** | **依赖**: [sync_protocol.md](../../domain/sync_protocol.md), [sync_status_indicator.md](sync_status_indicator.md)
**Related Tests** | **相关测试**: `test/widgets/sync_details_dialog_test.dart`

---

## Overview | 概述

This specification defines the sync details dialog that provides comprehensive synchronization information including device list, sync history, and configuration.

本规格定义了同步详情对话框，提供全面的同步信息，包括设备列表、同步历史和配置。

---

## Requirement: Display comprehensive sync information
## 需求：显示全面的同步信息

The system SHALL provide a dialog showing detailed synchronization information including device list, sync history, and configuration.

系统应提供显示详细同步信息的对话框，包括设备列表、同步历史和配置。

### Scenario: Show connected devices
### 场景：显示已连接设备

- **WHEN** dialog is opened
- **操作**：打开对话框
- **THEN** the system SHALL display a list of all discovered peer devices
- **预期结果**：系统应显示所有发现的对等设备列表
- **AND** indicate which devices are currently connected
- **并且**：指示当前连接的设备
- **AND** show last seen timestamp for each device
- **并且**：显示每个设备的上次可见时间戳

### Scenario: Show sync statistics
### 场景：显示同步统计信息

- **WHEN** dialog is opened
- **操作**：打开对话框
- **THEN** the system SHALL display total number of synced cards
- **预期结果**：系统应显示已同步卡片的总数
- **AND** show total data size synchronized
- **并且**：显示同步的总数据大小
- **AND** display sync session statistics (successful/failed syncs)
- **并且**：显示同步会话统计信息（成功/失败的同步）

---

## Requirement: Display recent sync history
## 需求：显示最近的同步历史

The system SHALL show a chronological list of recent synchronization events.

系统应显示最近同步事件的时间顺序列表。

### Scenario: Show sync event log
### 场景：显示同步事件日志

- **WHEN** displaying sync history
- **操作**：显示同步历史
- **THEN** the system SHALL list recent sync events with timestamps
- **预期结果**：系统应列出带有时间戳的最近同步事件
- **AND** indicate success or failure status for each event
- **并且**：指示每个事件的成功或失败状态
- **AND** show which device was involved in each sync event
- **并且**：显示每个同步事件涉及的设备

### Scenario: Show sync conflict information
### 场景：显示同步冲突信息

- **WHEN** sync conflicts occurred
- **操作**：发生同步冲突
- **THEN** the system SHALL highlight conflict events in the history
- **预期结果**：系统应在历史中突出显示冲突事件
- **AND** provide details about how conflicts were resolved
- **并且**：提供有关如何解决冲突的详细信息

---

## Requirement: Provide manual sync controls
## 需求：提供手动同步控制

The system SHALL allow users to manually trigger synchronization actions.

系统应允许用户手动触发同步操作。

### Scenario: Trigger manual sync
### 场景：触发手动同步

- **WHEN** user taps the "Sync Now" button
- **操作**：用户点击"立即同步"按钮
- **THEN** the system SHALL immediately attempt to synchronize with available peers
- **预期结果**：系统应立即尝试与可用对等点同步
- **AND** update the sync status in real-time
- **并且**：实时更新同步状态

### Scenario: Refresh device list
### 场景：刷新设备列表

- **WHEN** user taps the "Refresh Devices" button
- **操作**：用户点击"刷新设备"按钮
- **THEN** the system SHALL re-scan for available peer devices
- **预期结果**：系统应重新扫描可用的对等设备
- **AND** update the device list display
- **并且**：更新设备列表显示

---

## Requirement: Show sync configuration
## 需求：显示同步配置

The system SHALL display current sync configuration settings.

系统应显示当前的同步配置设置。

### Scenario: Show auto-sync status
### 场景：显示自动同步状态

- **WHEN** displaying sync configuration
- **操作**：显示同步配置
- **THEN** the system SHALL indicate whether auto-sync is enabled or disabled
- **预期结果**：系统应指示自动同步是启用还是禁用

### Scenario: Show sync protocol info
### 场景：显示同步协议信息

- **WHEN** displaying sync configuration
- **操作**：显示同步配置
- **THEN** the system SHALL show the current sync protocol version
- **预期结果**：系统应显示当前同步协议版本
- **AND** display network configuration (WiFi, Bluetooth, etc.)
- **并且**：显示网络配置（WiFi、蓝牙等）

---

## Requirement: Handle dialog dismissal
## 需求：处理对话框关闭

The system SHALL provide clear actions to close the dialog.

系统应提供明确的操作来关闭对话框。

### Scenario: Close dialog
### 场景：关闭对话框

- **WHEN** user taps outside the dialog or presses the close button
- **操作**：用户点击对话框外部或按下关闭按钮
- **THEN** the system SHALL dismiss the dialog
- **预期结果**：系统应关闭对话框
- **AND** return to the previous screen
- **并且**：返回到上一个屏幕

---

## Test Coverage | 测试覆盖

**Test File** | **测试文件**: `test/widgets/sync_details_dialog_test.dart`

**Widget Tests** | **Widget 测试**:
- `it_should_show_discovered_devices()` - Display device list | 显示设备列表
- `it_should_indicate_connected_devices()` - Indicate connected status | 指示连接状态
- `it_should_show_last_seen_timestamps()` - Show last seen time | 显示上次可见时间
- `it_should_show_sync_statistics()` - Display sync stats | 显示同步统计
- `it_should_show_sync_event_log()` - Display event log | 显示事件日志
- `it_should_highlight_conflicts()` - Highlight conflicts | 突出显示冲突
- `it_should_trigger_manual_sync()` - Trigger manual sync | 触发手动同步
- `it_should_refresh_device_list()` - Refresh devices | 刷新设备列表
- `it_should_show_auto_sync_status()` - Show auto-sync status | 显示自动同步状态
- `it_should_show_protocol_info()` - Show protocol info | 显示协议信息
- `it_should_dismiss_on_close()` - Dismiss dialog | 关闭对话框

**Acceptance Criteria** | **验收标准**:
- [ ] All widget tests pass | 所有 Widget 测试通过
- [ ] Device list updates correctly | 设备列表正确更新
- [ ] Sync history displays accurately | 同步历史准确显示
- [ ] Manual sync controls work reliably | 手动同步控制可靠工作
- [ ] Code review approved | 代码审查通过
- [ ] Documentation updated | 文档已更新

---

## Related Documents | 相关文档

**Related Specs** | **相关规格**:
- [sync_status_indicator.md](sync_status_indicator.md) - Sync status indicator | 同步状态指示器
- [sync_protocol.md](../../domain/sync_protocol.md) - Sync protocol | 同步协议

---

**Last Updated** | **最后更新**: 2026-01-21
**Authors** | **作者**: CardMind Team
