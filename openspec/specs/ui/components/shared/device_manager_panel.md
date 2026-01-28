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

The system SHALL show a list of all paired devices with proper sorting and status indicators.

系统应显示所有配对设备的列表，并进行适当的排序和状态指示。

### Device List Sorting Rules | 设备列表排序规则

**Sorting Priority** | **排序优先级**:
1. Online devices first
2. Last seen time descending (for same status)

1. 在线设备优先
2. 最后在线时间倒序（相同状态）

**Device Type Icons** | **设备类型图标**:
- Phone: phone icon
- Laptop: laptop icon
- Tablet: tablet icon

- 手机：phone 图标
- 笔记本：laptop 图标
- 平板：tablet 图标

**Online Status Badges** | **在线状态徽章**:
- Online: Green badge with "Online" text
- Offline: Gray badge with "Offline" text

- 在线：绿色徽章，显示"在线"
- 离线：灰色徽章，显示"离线"

**Time Format** | **时间格式**:
- Just now (< 1 minute)
- X minutes ago (1-59 minutes)
- X hours ago (1-23 hours)
- X days ago (1-6 days)
- Full date (≥ 7 days)

- 刚刚（< 1 分钟）
- X 分钟前（1-59 分钟）
- X 小时前（1-23 小时）
- X 天前（1-6 天）
- 完整日期（≥ 7 天）

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
- **AND**: sort devices by online status first, then by last seen time
- **并且**：按在线状态优先排序，然后按最后可见时间排序

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

## Requirement: Support adding new devices via QR code
## 需求：支持通过二维码添加新设备

The system SHALL provide functionality to pair new devices using QR code scanning.

系统应提供使用二维码扫描配对新设备的功能。

### Mobile Platform Design Details | 移动端平台设计细节

**Pairing Flow** | **配对流程**:
1. Two tabs: "Show QR Code" and "Scan QR Code"
2. Show QR Code tab: Display device QR code (240x240px)
3. Scan QR Code tab: Embedded camera view for scanning
4. Security verification: 6-digit verification code
5. Code validity: 5 minutes

**配对流程**:
1. 两个标签页："显示二维码"和"扫描二维码"
2. 显示二维码标签：显示设备二维码（240x240px）
3. 扫描二维码标签：内嵌相机扫描视图
4. 安全验证：6 位数字验证码
5. 验证码有效期：5 分钟

**Device List Sorting** | **设备列表排序**:
- Online devices first + Last seen time descending
- 在线设备优先 + 最后在线时间倒序

**Visual Design** | **视觉设计**:
- Current device: Theme color 10% background with "This Device" badge
- Verification code input: 6 independent input boxes with auto-jump
- Empty state: WiFi Off icon + prompt text
- Not in pool state: Gray overlay + prompt card

- 当前设备：主题色 10% 背景，带"本机"标识
- 验证码输入：6 个独立输入框，自动跳转
- 空状态：WiFi Off 图标 + 提示文字
- 未加入数据池：灰色遮罩 + 提示卡片

### Desktop Platform Design Details | 桌面端平台设计细节

**Pairing Flow** | **配对流程**:
1. Two tabs: "Show QR Code" and "Upload QR Code"
2. Show QR Code tab: Display device QR code (240x240px)
3. Upload QR Code tab: Upload QR code image file for pairing
4. Drag-and-drop support for image upload
5. QR code contains: PeerId + Multiaddrs list

**配对流程**:
1. 两个标签页："显示二维码"和"上传二维码"
2. 显示二维码标签：显示设备二维码（240x240px）
3. 上传二维码标签：上传二维码图片文件进行配对
4. 支持拖拽上传图片
5. 二维码包含：PeerId + Multiaddrs 列表

**Key Technical Decisions** | **关键技术决策**:
- Use libp2p PeerId as device ID
- Completely replace mDNS for initial pairing
- Retain mDNS for address discovery of paired devices
- Keypair storage: `{ApplicationSupportDirectory}/identity/keypair.bin`

- 使用 libp2p PeerId 作为设备 ID
- 完全替代 mDNS 用于首次配对
- 保留 mDNS 用于已配对设备的地址发现
- 密钥对存储：`{ApplicationSupportDirectory}/identity/keypair.bin`

**Visual Design** | **视觉设计**:
- Card layout with max width 800px
- Current device: Theme color 10% background, inline editing
- Verification code input: 6 independent input boxes (56x64px)
- Upload area: 400x240px with drag-and-drop support
- Desktop-specific interactions: Hover effects, keyboard shortcuts

- Card 卡片布局，最大宽度 800px
- 当前设备：主题色 10% 背景，内联编辑
- 验证码输入：6 个独立输入框（56x64px）
- 上传区域：400x240px，支持拖拽
- 桌面端特定交互：悬停效果、键盘快捷键

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

### Scenario: Scan QR code (Mobile)
### 场景：扫描二维码（移动端）

- **GIVEN**: user is on "Scan QR Code" tab
- **前置条件**：用户在"扫描二维码"标签页
- **WHEN**: QR code is successfully scanned
- **操作**：二维码扫描成功
- **THEN**: the system SHALL parse device information from QR code
- **预期结果**：系统应从二维码解析设备信息
- **AND**: display verification code input dialog
- **并且**：显示验证码输入对话框
- **AND**: show the other device's name
- **并且**：显示对方设备名称

### Scenario: Upload QR code (Desktop)
### 场景：上传二维码（桌面端）

- **GIVEN**: user is on "Upload QR Code" tab
- **前置条件**：用户在"上传二维码"标签页
- **WHEN**: user uploads or drags a QR code image
- **操作**：用户上传或拖拽二维码图片
- **THEN**: the system SHALL parse device information from the image
- **预期结果**：系统应从图片解析设备信息
- **AND**: display verification code input dialog
- **并且**：显示验证码输入对话框

### Scenario: Verify pairing with code
### 场景：使用验证码验证配对

- **GIVEN**: verification code input dialog is displayed
- **前置条件**：验证码输入对话框已显示
- **WHEN**: user enters the 6-digit verification code
- **操作**：用户输入 6 位验证码
- **THEN**: the system SHALL validate the code
- **预期结果**：系统应验证验证码
- **AND**: add device to paired devices list on success
- **并且**：成功时将设备添加到配对设备列表
- **AND**: show error message on failure
- **并且**：失败时显示错误消息

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

**Unit Tests (8 tests)** | **单元测试（8 个）**:
- Device model creation
- Device type enumeration
- Device status enumeration
- PairingRequest model creation
- Verification code generation
- Device list sorting logic
- Time formatting
- Device name validation

**单元测试（8 个）**:
- Device 模型创建
- 设备类型枚举
- 设备状态枚举
- PairingRequest 模型创建
- 验证码生成
- 设备列表排序逻辑
- 时间格式化
- 设备名称验证

**Widget Tests (45 tests)** | **Widget 测试（45 个）**:

**Rendering Tests (12 tests)** | **渲染测试（12 个）**:
- `it_should_render_page_basic()` - Basic page rendering
- `it_should_show_not_in_pool_state()` - Not in pool state
- `it_should_show_current_device_card()` - Current device card
- `it_should_show_device_type_icons()` - Device type icons
- `it_should_show_empty_device_list()` - Empty device list
- `it_should_show_device_list()` - Device list rendering
- `it_should_show_online_device_badge()` - Online device badge
- `it_should_show_offline_device_badge()` - Offline device badge
- `it_should_show_pair_device_button()` - Pair device button
- `it_should_show_device_list_title()` - Device list title
- `it_should_show_current_device_special_background()` - Current device special background
- `it_should_show_device_list_sorted()` - Device list sorted display

**Interaction Tests (20 tests)** | **交互测试（20 个）**:
- Click edit button
- Edit device name
- Cancel editing
- Empty name save disabled
- Click pair button
- Default tab in pair dialog
- Switch to scan/upload tab
- Show QR code
- Verification code input auto-jump
- Verification code delete jump
- Verification code paste
- Verification code input complete
- Verification code confirm
- Verification failure display
- Close pair dialog
- Verification code display dialog
- Close verification code display dialog
- Tab switch animation
- Device list scroll
- Edit dialog auto-focus

**Boundary Tests (13 tests)** | **边界测试（13 个）**:
- Device name max length
- Device name only spaces
- Empty device list display
- Large device list
- Verification code only accepts digits
- Verification code length insufficient
- Unknown device type
- lastSeen is null
- Device ID is empty
- QR code generation failure
- Camera permission denied
- Network error
- Verification code expired

**Widget 测试（45 个）**:
- `it_should_show_current_device_card()` - Display current device
- `it_should_show_device_online_status()` - Online status
- `it_should_enable_device_name_editing()` - Enable editing
- `it_should_save_device_name()` - Save name
- `it_should_show_paired_devices()` - Display paired devices
- `it_should_show_empty_state()` - Empty state
- `it_should_add_new_device()` - Add device
- `it_should_remove_paired_device()` - Remove device
- `it_should_prevent_removing_current_device()` - Prevent self-removal
- `it_should_show_device_type_icons()` - Device type icons
- `it_should_show_last_seen_for_offline()` - Last seen timestamp
- `it_should_show_online_now()` - Online now indicator
- `it_should_scan_qr_code()` - Scan QR code (Mobile)
- `it_should_upload_qr_code()` - Upload QR code (Desktop)
- `it_should_verify_pairing_code()` - Verify pairing code
- `it_should_show_verification_code_dialog()` - Show verification code dialog
- `it_should_handle_verification_failure()` - Handle verification failure
- `it_should_sort_devices_by_status()` - Sort devices by status
- `it_should_format_time_correctly()` - Format time correctly
- ... (additional 26 tests for interactions and boundary cases)

**Acceptance Criteria**:
**验收标准**:
- [ ] All 53 tests pass (8 unit + 45 widget)
- [ ] 所有 53 个测试通过（8 个单元测试 + 45 个 Widget 测试）
- [ ] Device name editing works correctly
- [ ] 设备名称编辑正常工作
- [ ] QR code pairing flows are smooth (both mobile and desktop)
- [ ] 二维码配对流程流畅（移动端和桌面端）
- [ ] Verification code validation works correctly
- [ ] 验证码验证正常工作
- [ ] Device list sorting is accurate
- [ ] 设备列表排序准确
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

**Last Updated**: 2026-01-27
**最后更新**: 2026-01-27

**Authors**: CardMind Team
**作者**: CardMind Team
