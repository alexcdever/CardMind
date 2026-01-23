# Device Manager Panel Specification
# 设备管理面板规格

**Version**: 1.0.0
**版本**: 1.0.0

**Status**: Active
**状态**: Active

**Dependencies**: [device_config.md](../../../architecture/storage/device_config.md), [sync/protocol.md](../../../architecture/sync/service.md)
**依赖**: [device_config.md](../../../architecture/storage/device_config.md), [sync/protocol.md](../../../architecture/sync/service.md)

**Related Tests**: `test/widgets/device_manager_panel_test.dart`
**相关测试**: `test/widgets/device_manager_panel_test.dart`

---

## Overview
## 概述

This specification defines the device manager panel that displays current device information, paired devices, and device management actions.

本规格定义了设备管理面板，显示当前设备信息、配对设备和设备管理操作。

---

## Requirement: Display current device information
## 需求：显示当前设备信息

The system SHALL show information about the current device including name, type, and status.

系统应显示当前设备的信息，包括名称、类型和状态。

### Scenario: Show current device card
### 场景：显示当前设备卡片

- **GIVEN**: the device manager panel is displayed
- **前置条件**：设备管理面板已显示
- **WHEN**: rendering the panel
- **操作**：渲染面板
- **THEN**: the system SHALL display the current device in a distinct "Current Device" section
- **预期结果**：系统应在独立的"当前设备"部分显示当前设备
- **AND**: show device name, type (phone/laptop/tablet), and ID
- **并且**：显示设备名称、类型（手机/笔记本/平板）和 ID

### Scenario: Show device online status
### 场景：显示设备在线状态

- **GIVEN**: the device manager panel is displayed
- **前置条件**：设备管理面板已显示
- **WHEN**: displaying device information
- **操作**：显示设备信息
- **THEN**: the system SHALL indicate online/offline status with visual indicators
- **预期结果**：系统应使用视觉指示器指示在线/离线状态

---

## Requirement: Allow editing current device name
## 需求：允许编辑当前设备名称

The system SHALL allow users to rename the current device.

系统应允许用户重命名当前设备。

### Scenario: Edit device name
### 场景：编辑设备名称

- **GIVEN**: the current device is displayed
- **前置条件**：当前设备已显示
- **WHEN**: user clicks on the device name field
- **操作**：用户点击设备名称字段
- **THEN**: the system SHALL enable editing mode
- **预期结果**：系统应启用编辑模式
- **AND**: allow user to enter a new device name
- **并且**：允许用户输入新的设备名称

### Scenario: Save device name
### 场景：保存设备名称

- **GIVEN**: user has entered a new device name
- **前置条件**：用户已输入新设备名称
- **WHEN**: user confirms the new device name
- **操作**：用户确认新设备名称
- **THEN**: the system SHALL call onDeviceNameChange callback with the new name
- **预期结果**：系统应使用新名称调用 onDeviceNameChange 回调
- **AND**: persist the name change
- **并且**：持久化名称更改

---

## Requirement: Display paired devices list
## 需求：显示配对设备列表

The system SHALL show a list of all paired devices.

系统应显示所有配对设备的列表。

### Scenario: Show paired devices
### 场景：显示配对设备

- **GIVEN**: the device manager panel is displayed
- **前置条件**：设备管理面板已显示
- **WHEN**: rendering the panel
- **操作**：渲染面板
- **THEN**: the system SHALL display all paired devices in a "Paired Devices" section
- **预期结果**：系统应在"配对设备"部分显示所有配对设备
- **AND**: show device name, type, online status, and last seen timestamp for each device
- **并且**：为每个设备显示设备名称、类型、在线状态和上次可见时间戳

### Scenario: Show empty state
### 场景：显示空状态

- **GIVEN**: the device manager panel is displayed
- **前置条件**：设备管理面板已显示
- **WHEN**: there are no paired devices
- **操作**：没有配对设备
- **THEN**: the system SHALL display an empty state message
- **预期结果**：系统应显示空状态消息
- **AND**: show instructions for adding devices
- **并且**：显示添加设备的说明

---

## Requirement: Support adding new devices
## 需求：支持添加新设备

The system SHALL provide functionality to pair new devices.

系统应提供配对新设备的功能。

### Scenario: Add new device
### 场景：添加新设备

- **GIVEN**: the device manager panel is displayed
- **前置条件**：设备管理面板已显示
- **WHEN**: user triggers the "Add Device" action
- **操作**：用户触发"添加设备"操作
- **THEN**: the system SHALL call onAddDevice callback
- **预期结果**：系统应调用 onAddDevice 回调
- **AND**: initiate the device pairing flow
- **并且**：启动设备配对流程

---

## Requirement: Support removing paired devices
## 需求：支持移除配对设备

The system SHALL allow users to unpair devices.

系统应允许用户取消设备配对。

### Scenario: Remove paired device
### 场景：移除配对设备

- **GIVEN**: paired devices exist
- **前置条件**：存在配对设备
- **WHEN**: user selects "Remove" action on a paired device
- **操作**：用户对配对设备选择"移除"操作
- **THEN**: the system SHALL show a confirmation dialog
- **预期结果**：系统应显示确认对话框
- **AND**: call onRemoveDevice callback with the device ID upon confirmation
- **并且**：确认后使用设备 ID 调用 onRemoveDevice 回调

### Scenario: Prevent removing current device
### 场景：防止移除当前设备

- **GIVEN**: the device manager panel is displayed
- **前置条件**：设备管理面板已显示
- **WHEN**: displaying device actions
- **操作**：显示设备操作
- **THEN**: the system SHALL NOT show remove action for the current device
- **预期结果**：系统不应为当前设备显示移除操作

---

## Requirement: Show device type icons
## 需求：显示设备类型图标

The system SHALL display appropriate icons for different device types.

系统应为不同设备类型显示适当的图标。

### Scenario: Display device type icon
### 场景：显示设备类型图标

- **GIVEN**: a device is displayed in the list
- **前置条件**：设备显示在列表中
- **WHEN**: rendering a device
- **操作**：渲染设备
- **THEN**: the system SHALL show phone icon for phone devices
- **预期结果**：系统应为手机设备显示手机图标
- **AND**: show laptop icon for laptop devices
- **并且**：为笔记本设备显示笔记本图标
- **AND**: show tablet icon for tablet devices
- **并且**：为平板设备显示平板图标

---

## Requirement: Show last seen timestamps
## 需求：显示上次可见时间戳

The system SHALL display last activity timestamps for offline devices.

系统应为离线设备显示上次活动时间戳。

### Scenario: Show last seen for offline devices
### 场景：为离线设备显示上次可见时间

- **GIVEN**: a paired device is offline
- **前置条件**：配对设备处于离线状态
- **WHEN**: displaying the device
- **操作**：显示设备
- **THEN**: the system SHALL display "Last seen: [timestamp]" in relative time format (e.g., "2 hours ago")
- **预期结果**：系统应以相对时间格式显示"上次可见：[时间戳]"（例如，"2 小时前"）

### Scenario: Show "online now" for online devices
### 场景：为在线设备显示"当前在线"

- **GIVEN**: a paired device is online
- **前置条件**：配对设备处于在线状态
- **WHEN**: displaying the device
- **操作**：显示设备
- **THEN**: the system SHALL display "Online now" instead of last seen timestamp
- **预期结果**：系统应显示"当前在线"而不是上次可见时间戳

---

## Test Coverage
## 测试覆盖

**Test File**: `test/widgets/device_manager_panel_test.dart`
**测试文件**: `test/widgets/device_manager_panel_test.dart`

**Widget Tests**:
**Widget 测试**:
- `it_should_show_current_device_card()` - Display current device
- `it_should_show_current_device_card()` - 显示当前设备
- `it_should_show_device_online_status()` - Online status
- `it_should_show_device_online_status()` - 在线状态
- `it_should_enable_device_name_editing()` - Enable editing
- `it_should_enable_device_name_editing()` - 启用编辑
- `it_should_save_device_name()` - Save name
- `it_should_save_device_name()` - 保存名称
- `it_should_show_paired_devices()` - Display paired devices
- `it_should_show_paired_devices()` - 显示配对设备
- `it_should_show_empty_state()` - Empty state
- `it_should_show_empty_state()` - 空状态
- `it_should_add_new_device()` - Add device
- `it_should_add_new_device()` - 添加设备
- `it_should_remove_paired_device()` - Remove device
- `it_should_remove_paired_device()` - 移除设备
- `it_should_prevent_removing_current_device()` - Prevent self-removal
- `it_should_prevent_removing_current_device()` - 防止移除自身
- `it_should_show_device_type_icons()` - Device type icons
- `it_should_show_device_type_icons()` - 设备类型图标
- `it_should_show_last_seen_for_offline()` - Last seen timestamp
- `it_should_show_last_seen_for_offline()` - 上次可见时间戳
- `it_should_show_online_now()` - Online now indicator
- `it_should_show_online_now()` - 当前在线指示器

**Acceptance Criteria**:
**验收标准**:
- [ ] All widget tests pass
- [ ] 所有 Widget 测试通过
- [ ] Device name editing works correctly
- [ ] 设备名称编辑正常工作
- [ ] Device pairing/unpairing flows are smooth
- [ ] 设备配对/取消配对流程流畅
- [ ] Status indicators are accurate
- [ ] 状态指示器准确
- [ ] Code review approved
- [ ] 代码审查通过
- [ ] Documentation updated
- [ ] 文档已更新

---

## Related Documents
## 相关文档

**Related Specs**:
**相关规格**:
- [device_config.md](../../../architecture/storage/device_config.md) - Device configuration
- [device_config.md](../../../architecture/storage/device_config.md) - 设备配置
- [sync/protocol.md](../../../architecture/sync/service.md) - Sync protocol
- [sync/protocol.md](../../../architecture/sync/service.md) - 同步协议
- [settings_screen.md](../../screens/mobile/settings_screen.md) - Settings screen
- [settings_screen.md](../../screens/mobile/settings_screen.md) - 设置屏幕

---

**Last Updated**: 2026-01-24
**最后更新**: 2026-01-24

**Authors**: CardMind Team
**作者**: CardMind Team
