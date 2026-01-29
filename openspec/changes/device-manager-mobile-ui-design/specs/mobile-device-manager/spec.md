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

## ADDED Visual Design Specifications

### Requirement: Follow precise visual design specifications for all UI components
The system SHALL implement all UI components according to detailed visual specifications for consistency and quality.

#### Scenario: Page layout specifications
- **WHEN** rendering device manager page
- **THEN** system uses white background in light mode
- **AND** uses dark background in dark mode
- **AND** applies 16px horizontal padding
- **AND** applies 16px top and bottom padding
- **AND** uses 16px spacing between components
- **AND** makes entire page scrollable

#### Scenario: Not in pool overlay specifications
- **WHEN** displaying not in pool state
- **THEN** system shows semi-transparent gray overlay (rgba(0, 0, 0, 0.5))
- **AND** displays centered white card with 12px border radius
- **AND** applies 24px padding to card
- **AND** shows gray warning icon at 48x48px
- **AND** displays "请先加入数据池" text at 16px in gray color

#### Scenario: Current device card visual design
- **WHEN** rendering current device card
- **THEN** system uses theme color at 10% opacity for background (#007AFF 10%)
- **AND** applies 1px border with theme color at 20% opacity
- **AND** uses 12px border radius
- **AND** applies 16px padding
- **AND** shows device icon at 24x24px in theme color
- **AND** displays device name at 16px bold in black
- **AND** shows "本机" subtitle at 12px in gray
- **AND** displays online badge with green background (#34C759)
- **AND** shows "在线" text at 12px in white
- **AND** includes WiFi icon at 12x12px
- **AND** applies 4px border radius to badge with 4px 8px padding
- **AND** shows "编辑" button at 14px in theme color
- **AND** ensures edit button has minimum 48x48px touch area

#### Scenario: Pair device button specifications
- **WHEN** rendering pair device button
- **THEN** system uses theme color fill
- **AND** sets button height to 36px with 12px 16px padding
- **AND** applies 8px border radius
- **AND** shows Plus icon at 16x16px in white
- **AND** displays "配对设备" text at 14px in white

#### Scenario: Pair device dialog specifications
- **WHEN** displaying pair device dialog
- **THEN** system sets width to screen width minus 32px (16px margins)
- **AND** limits maximum width to 400px
- **AND** uses white background with 16px border radius
- **AND** applies 24px padding
- **AND** shows "配对新设备" title at 18px bold

#### Scenario: Tab bar design specifications
- **WHEN** rendering tab bar in pair dialog
- **THEN** system sets tab bar height to 48px
- **AND** shows unselected tabs with gray text and no background
- **AND** shows selected tab with theme color text and light background
- **AND** displays tab icons at 16x16px
- **AND** shows tab text at 14px
- **AND** uses 8px spacing between icon and text

#### Scenario: QR code display tab specifications
- **WHEN** showing QR code display tab
- **THEN** system renders QR code at exactly 240x240px
- **AND** centers QR code in view
- **AND** displays hint text 16px below QR code
- **AND** shows "请在另一台设备上扫描此二维码" at 14px gray centered

#### Scenario: QR code scanning tab specifications
- **WHEN** showing QR code scanning tab
- **THEN** system displays camera view at 240x240px
- **AND** applies 12px border radius to camera view
- **AND** centers camera view
- **AND** shows scanning frame at 200x200px
- **AND** uses 2px white dashed border for frame
- **AND** adds rounded corner markers
- **AND** displays hint text 16px below camera view
- **AND** shows "对准二维码进行扫描" at 14px gray centered

#### Scenario: Verification code display dialog specifications
- **WHEN** showing verification code to scanned user
- **THEN** system sets dialog width to screen width minus 32px
- **AND** limits maximum width to 360px
- **AND** uses white background with 16px border radius
- **AND** applies 24px padding
- **AND** shows "配对请求" title at 18px bold centered
- **AND** displays device info text 16px below title
- **AND** shows "设备 '{deviceName}' 正在请求配对" at 14px gray centered
- **AND** displays verification code 24px below device info
- **AND** uses light gray background (#F5F5F5) for code container
- **AND** applies 12px border radius with 20px padding
- **AND** shows verification code at 32px bold monospace black centered
- **AND** uses 8px character spacing
- **AND** displays hint text 16px below code
- **AND** shows "请将此验证码告知对方" at 12px gray centered
- **AND** shows "关闭" button at 16px theme color with 48px height full width

#### Scenario: Verification code input dialog specifications
- **WHEN** showing verification code input dialog
- **THEN** system sets dialog width to screen width minus 32px
- **AND** limits maximum width to 360px
- **AND** uses white background with 16px border radius
- **AND** applies 24px padding
- **AND** shows "输入验证码" title at 18px bold centered
- **AND** displays device info text 16px below title
- **AND** shows "请输入设备 '{deviceName}' 显示的验证码" at 14px gray centered
- **AND** displays 6 input boxes 24px below device info
- **AND** sizes each input box at 48x56px
- **AND** applies 1px gray border with 8px border radius
- **AND** uses 24px bold monospace font centered
- **AND** spaces input boxes 8px apart
- **AND** changes border to theme color 2px when focused
- **AND** uses light blue background (#F0F8FF) when filled
- **AND** shows error text 8px below inputs when verification fails
- **AND** displays "验证码错误，请重试" at 12px red
- **AND** shows button group at bottom with 12px spacing
- **AND** renders cancel button with gray border and gray text at 48px height
- **AND** renders confirm button with theme color fill and white text at 48px height
- **AND** disables confirm button when input incomplete (gray and unclickable)

#### Scenario: Device list design specifications
- **WHEN** rendering device list
- **THEN** system shows list title "已配对设备 ({count})" at 14px gray
- **AND** positions title left of pair button
- **AND** adds 12px spacing below title

#### Scenario: Empty state specifications
- **WHEN** displaying empty device list
- **THEN** system shows WiFi Off icon at 64x64px gray with 50% opacity
- **AND** displays "暂无配对设备" text at 14px gray
- **AND** shows "点击上方按钮配对新设备" subtitle at 12px light gray
- **AND** arranges vertically centered with 8px spacing
- **AND** applies 48px top and bottom padding

#### Scenario: Device list item specifications
- **WHEN** rendering device list item
- **THEN** system uses light gray background (#F5F5F5)
- **AND** applies 1px gray border (#E0E0E0)
- **AND** uses 12px border radius
- **AND** applies 16px padding
- **AND** spaces list items 8px apart
- **AND** auto-adjusts height to content
- **AND** shows device icon at 24x24px in gray
- **AND** displays device name at 16px bold black
- **AND** shows last seen time at 12px gray
- **AND** formats online devices as "在线"
- **AND** formats offline devices as "最后在线：{time}"
- **AND** shows online badge with green background (#34C759) and white text
- **AND** shows offline badge with gray background (#8E8E93) and white text
- **AND** applies 4px 8px padding to badges with 4px border radius
- **AND** uses 12px font for badge text

## ADDED Performance Constraints

### Requirement: Meet strict performance benchmarks for mobile experience
The system SHALL meet specific performance benchmarks to ensure smooth mobile experience.

#### Scenario: Page loading performance
- **WHEN** user opens device manager page
- **THEN** system completes page load in less than 500ms
- **AND** displays initial content without visible delay

#### Scenario: Device list rendering performance
- **WHEN** rendering device list with any number of devices
- **THEN** system completes list rendering in less than 200ms
- **AND** maintains smooth scrolling at 60fps
- **AND** caches up to 1000 devices maximum

#### Scenario: QR code generation performance
- **WHEN** generating QR code for device
- **THEN** system completes generation in less than 100ms
- **AND** produces image smaller than 50KB
- **AND** caches generated QR code for reuse

#### Scenario: Camera initialization performance
- **WHEN** activating camera for scanning
- **THEN** system initializes camera in less than 1000ms
- **AND** uses 720p resolution for preview
- **AND** minimizes battery and memory usage

#### Scenario: Verification response performance
- **WHEN** submitting verification code
- **THEN** system responds within 2000ms
- **AND** provides loading feedback during verification

#### Scenario: Animation frame rate performance
- **WHEN** performing any UI animation
- **THEN** system maintains minimum 60fps frame rate
- **AND** ensures smooth dialog open/close transitions
- **AND** provides fluid list update animations
- **AND** maintains smooth tab switching animations

## ADDED Boundary Conditions and Error Handling

### Requirement: Handle all data boundary conditions correctly
The system SHALL handle all data boundary conditions with proper validation and constraints.

#### Scenario: Device name validation boundaries
- **WHEN** device name is empty string
- **THEN** system disables save button
- **WHEN** device name contains only spaces
- **THEN** system disables save button
- **WHEN** device name length exceeds 32 characters
- **THEN** system limits input to first 32 characters
- **WHEN** device name contains special characters
- **THEN** system allows and saves normally
- **WHEN** device name duplicates another device
- **THEN** system allows (different devices can share names)

#### Scenario: Device list boundary conditions
- **WHEN** device count is 0
- **THEN** system displays empty state
- **WHEN** device count exceeds 100
- **THEN** system displays all devices with scrollable list
- **WHEN** device ID is empty
- **THEN** system excludes device from display
- **WHEN** device lastSeen is null
- **THEN** system displays "未知" for time
- **WHEN** device type is unknown
- **THEN** system displays default laptop icon

#### Scenario: Verification code validation boundaries
- **WHEN** verification code length is not 6 digits
- **THEN** system disables confirm button
- **WHEN** verification code contains non-digit characters
- **THEN** system rejects input (input field only accepts digits)
- **WHEN** verification code has expired (over 5 minutes)
- **THEN** system shows timeout message and closes dialog
- **WHEN** verification code error count exceeds 3
- **THEN** system continues allowing retries (no lockout)

#### Scenario: QR code validation boundaries
- **WHEN** QR code data format is invalid
- **THEN** system displays "无效的二维码" toast
- **WHEN** user scans own QR code
- **THEN** system displays "不能配对自己" toast and prevents pairing
- **WHEN** user scans already paired device
- **THEN** system displays "设备已配对" toast
- **WHEN** QR code generation fails
- **THEN** system displays error message in dialog

#### Scenario: Network error handling
- **WHEN** network request times out
- **THEN** system displays "网络超时，请重试" toast
- **WHEN** other device is offline during pairing
- **THEN** system displays "对方设备离线，无法配对" toast
- **WHEN** server returns error
- **THEN** system displays "配对失败，请稍后重试" toast
- **WHEN** user has not joined data pool
- **THEN** system displays "请先加入数据池" toast
- **WHEN** device list loading fails
- **THEN** system displays retry button
- **WHEN** data parsing fails
- **THEN** system displays empty state
- **WHEN** device name save fails
- **THEN** system displays "保存失败，请重试" toast and keeps dialog open

#### Scenario: Camera permission error handling
- **WHEN** camera permission not yet requested
- **THEN** system automatically requests permission
- **WHEN** camera permission is granted
- **THEN** system displays camera preview
- **WHEN** camera permission is denied
- **THEN** system displays permission message with "去设置" button
- **WHEN** camera permission is permanently denied
- **THEN** system displays permission message with "去设置" button
- **WHEN** camera initialization fails
- **THEN** system displays "相机启动失败" toast
- **WHEN** camera is occupied by another app
- **THEN** system displays "相机被其他应用占用" toast
- **WHEN** device has no camera
- **THEN** system displays "设备不支持相机" message