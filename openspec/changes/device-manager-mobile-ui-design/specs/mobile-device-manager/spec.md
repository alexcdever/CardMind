## ADDED Requirements

### Requirement: Display mobile device manager page with current device and paired devices
The system SHALL display a mobile-optimized device manager page that shows the current device and all paired devices.

#### Scenario: Show current device card at top
- **WHEN** user opens device manager page
- **AND** has joined a data pool
- **THEN** system displays current device at top with special blue background
- **AND** shows device icon, name, "本机" label, and online status badge
- **AND** includes an "编辑" button for name editing

#### Scenario: Show paired devices list
- **WHEN** user opens device manager page
- **AND** has paired devices
- **THEN** system displays devices list below current device
- **AND** shows device count in title "已配对设备 ({count})"
- **AND** sorts devices with online优先 + last seen descending

#### Scenario: Show empty state when no paired devices
- **WHEN** user opens device manager page
- **AND** has no paired devices
- **THEN** system displays empty state with WiFi Off icon
- **AND** shows "暂无配对设备" text
- **AND** shows "点击上方按钮配对新设备" subtitle

#### Scenario: Show not in pool state
- **WHEN** user opens device manager page
- **AND** has not joined any data pool
- **THEN** system displays gray overlay covering entire page
- **AND** shows centered card with warning icon
- **AND** displays "请先加入数据池" text
- **AND** disables all interactions

### Requirement: Support device name editing with validation
The system SHALL allow users to edit the current device name with proper validation and constraints.

#### Scenario: Open edit dialog
- **WHEN** user taps "编辑" button on current device card
- **THEN** system opens edit dialog with current device name pre-filled
- **AND** input field auto-focuses and selects all text
- **AND** shows "编辑设备名称" title
- **AND** displays "取消" and "保存" buttons

#### Scenario: Validate device name input
- **WHEN** user enters empty string or only spaces
- **THEN** system disables "保存" button
- **WHEN** user enters more than 32 characters
- **THEN** system truncates input to 32 characters
- **WHEN** user enters valid name
- **THEN** system enables "保存" button

#### Scenario: Save device name successfully
- **WHEN** user enters valid name and taps "保存"
- **THEN** system calls onDeviceNameChange callback with new name
- **AND** closes dialog with 200ms animation
- **AND** updates device name display on current device card

#### Scenario: Cancel device name editing
- **WHEN** user taps "取消" button
- **THEN** system closes dialog without saving
- **AND** device name remains unchanged

### Requirement: Provide secure device pairing with QR code and verification
The system SHALL provide secure device pairing using QR code display/scan and 6-digit verification code.

#### Scenario: Show QR code for pairing
- **WHEN** user taps "配对设备" button
- **THEN** system opens pairing dialog with "显示二维码" tab selected
- **AND** displays 240x240px QR code containing device info
- **AND** shows "请在另一台设备上扫描此二维码" text
- **AND** QR code includes version, type, deviceId, deviceName, deviceType, timestamp, poolId

#### Scenario: Scan QR code for pairing
- **WHEN** user switches to "扫描二维码" tab
- **THEN** system requests camera permission if not granted
- **AND** displays camera preview with 240x240px view
- **AND** shows scanning frame with corner markers
- **AND** displays "对准二维码进行扫描" text

#### Scenario: Handle camera permission denied
- **WHEN** user denies camera permission
- **THEN** system shows permission denied message
- **AND** displays "需要相机权限才能扫描二维码" text
- **AND** provides "去设置" button to open system settings

#### Scenario: Parse scanned QR code
- **WHEN** camera successfully scans QR code
- **THEN** system parses JSON data and validates format
- **AND** verifies timestamp is within 10 minutes
- **AND** extracts deviceId, deviceName, deviceType, poolId
- **AND** switches to verification code input dialog

#### Scenario: Handle invalid QR code
- **WHEN** camera scans invalid QR code format
- **THEN** system displays "无效的二维码" toast
- **AND** continues scanning for valid QR code

### Requirement: Implement 6-digit verification code input and validation
The system SHALL implement 6-digit verification code input with auto-advance and validation.

#### Scenario: Show verification code input dialog
- **WHEN** QR code is successfully scanned
- **THEN** system shows verification dialog with device name
- **AND** displays "输入验证码" title
- **AND** shows 6 separate input boxes with auto-focus on first
- **AND** each input accepts only single digit (0-9)
- **AND** displays "请输入设备 '{deviceName}' 显示的验证码" text

#### Scenario: Auto-advance between input fields
- **WHEN** user enters digit in input field
- **THEN** system auto-focuses next input field
- **AND** changes filled input background to light blue (#F0F8FF)
- **WHEN** user presses backspace in empty field
- **THEN** system focuses previous input field

#### Scenario: Support paste functionality
- **WHEN** user pastes 6-digit number
- **THEN** system distributes digits across 6 input fields
- **AND** auto-focuses "确认" button if all fields filled
- **WHEN** user pastes invalid format
- **THEN** system ignores paste and maintains current state

#### Scenario: Enable submit when complete
- **WHEN** all 6 input fields contain digits
- **THEN** system enables "确认" button
- **WHEN** any input field is empty
- **THEN** system disables "确认" button

#### Scenario: Submit verification code
- **WHEN** user enters 6 digits and taps "确认"
- **THEN** system calls onPairDevice callback with deviceId and verificationCode
- **AND** shows loading state on button
- **AND** disables all input fields during verification

### Requirement: Handle pairing process on scanned device (verification display)
The system SHALL handle pairing process on the device being scanned by displaying verification code.

#### Scenario: Show verification code to scanned user
- **WHEN** another device scans this device's QR code
- **THEN** system generates 6-digit random verification code
- **AND** displays verification code dialog
- **AND** shows "配对请求" title
- **AND** displays "设备 '{deviceName}' 正在请求配对" text
- **AND** shows verification code in large font with 8px character spacing

#### Scenario: Wait for verification input
- **WHEN** verification code dialog is displayed
- **THEN** system shows "请将此验证码告知对方" text
- **AND** includes "关闭" button
- **AND** automatically expires after 5 minutes

#### Scenario: Handle successful verification
- **WHEN** other user inputs correct verification code
- **THEN** system automatically closes verification dialog
- **AND** shows "配对成功" toast
- **AND** updates paired devices list to include new device
- **AND** refreshes device count in list title

#### Scenario: Handle verification timeout
- **WHEN** 5 minutes pass without successful verification
- **THEN** system automatically closes verification dialog
- **AND** shows "验证码已过期，请重新扫描" toast

### Requirement: Display device list with proper sorting and status
The system SHALL display device list with online priority sorting and accurate status indicators.

#### Scenario: Sort devices by online status
- **WHEN** device list contains mixed online/offline devices
- **THEN** system displays online devices first
- **AND** offline devices after online ones
- **AND** both groups sorted by last seen time descending

#### Scenario: Show device status badges
- **WHEN** device is online
- **THEN** system shows green "在线" badge
- **AND** badge background color is #34C759
- **WHEN** device is offline
- **THEN** system shows gray "离线" badge
- **AND** displays last seen time in format "最后在线：{time}"
- **AND** badge background color is #8E8E93

#### Scenario: Format last seen time appropriately
- **WHEN** device was seen within 1 minute
- **THEN** system displays "刚刚"
- **WHEN** device was seen within 1 hour
- **THEN** system displays "{X} 分钟前"
- **WHEN** device was seen within 24 hours
- **THEN** system displays "{X} 小时前"
- **WHEN** device was seen within 7 days
- **THEN** system displays "{X} 天前"
- **WHEN** device was seen more than 7 days ago
- **THEN** system displays "yyyy-MM-dd HH:mm" format

#### Scenario: Display device type icons
- **WHEN** device type is phone
- **THEN** system shows phone icon
- **WHEN** device type is laptop
- **THEN** system shows laptop icon
- **WHEN** device type is tablet
- **THEN** system shows tablet icon
- **WHEN** device type is unknown
- **THEN** system shows default laptop icon

### Requirement: Handle error states and edge cases gracefully
The system SHALL handle various error states and edge cases with proper user feedback.

#### Scenario: Handle network timeout during pairing
- **WHEN** pairing request times out
- **THEN** system shows "网络超时，请重试" toast
- **AND** returns to device manager page

#### Scenario: Handle pairing verification failure
- **WHEN** verification code is incorrect
- **THEN** system shows "验证码错误，请重试" text in verification dialog
- **AND** changes input borders to red color
- **AND** clears all input fields
- **AND** focuses first input field

#### Scenario: Handle pairing to already paired device
- **WHEN** user tries to pair with already paired device
- **THEN** system shows "设备已配对" toast
- **AND** does not add duplicate device to list

#### Scenario: Handle trying to pair with self
- **WHEN** user scans own QR code
- **THEN** system shows "不能配对自己" toast
- **AND** prevents pairing process

#### Scenario: Handle device name save failure
- **WHEN** device name save fails
- **THEN** system shows "保存失败，请重试" toast
- **AND** keeps edit dialog open for retry

### Requirement: Provide accessibility support for mobile interactions
The system SHALL provide comprehensive accessibility support for screen readers and keyboard navigation.

#### Scenario: Screen reader announcements
- **WHEN** screen reader encounters current device card
- **THEN** system announces "当前设备，{设备名称}，本机，在线"
- **WHEN** screen reader encounters device list item
- **THEN** system announces "{设备名称}，{设备类型}，{在线状态}"
- **WHEN** screen reader encounters edit button
- **THEN** system announces "编辑设备名称"

#### Scenario: Minimum touch targets
- **WHEN** user interacts with any clickable element
- **THEN** system provides minimum 48x48px touch area
- **AND** buttons have adequate padding for easy tapping
- **AND** input fields are at least 48px high

#### Scenario: Color contrast compliance
- **WHEN** system displays text and backgrounds
- **THEN** text-to-background contrast ratio is ≥ 4.5:1
- **AND** icon-to-background contrast ratio is ≥ 3:1
- **AND** supports both light and dark modes

### Requirement: Optimize performance for mobile devices
The system SHALL optimize performance for smooth mobile experience.

#### Scenario: Lazy load device list
- **WHEN** device list contains many devices
- **THEN** system uses ListView.builder for lazy loading
- **AND** only renders visible devices
- **AND** maintains smooth 60fps scrolling

#### Scenario: Efficient camera usage
- **WHEN** user switches to scanning tab
- **THEN** system initializes camera at 720p resolution
- **AND** releases camera when leaving tab
- **AND** minimizes battery and memory usage

#### Scenario: QR code generation optimization
- **WHEN** generating QR code for same device ID
- **THEN** system caches generated QR code image
- **AND** reuses cached image for subsequent displays
- **AND** reduces generation time to < 100ms

#### Scenario: Animation performance
- **WHEN** performing any UI transitions
- **THEN** system maintains 60fps animation frame rate
- **AND** uses RepaintBoundary for expensive widgets
- **AND** minimizes widget rebuilds