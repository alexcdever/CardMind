# desktop-device-manager Specification

## Purpose
TBD - created by archiving change device-manager-desktop-ui-design. Update Purpose after archive.
## Requirements
### Requirement: Display desktop device manager page with optimized layout
The system SHALL display a desktop-optimized device manager page that maximizes screen space utilization.

#### Scenario: Show current device with inline editing
- **WHEN** user opens device manager page
- **AND** has joined a data pool
- **THEN** system displays current device with special blue background
- **AND** enables inline name editing without dialog popup
- **AND** shows device icon, name, "本机" label, and online status
- **AND** provides direct text editing with save/cancel buttons

#### Scenario: Show paired devices in large format
- **WHEN** user opens device manager page
- **AND** has paired devices
- **THEN** system displays devices in large list format
- **AND** shows detailed device information (type, status, addresses)
- **AND** displays device count in title "已配对设备 ({count})"
- **AND** sorts devices with online优先 + last seen descending

#### Scenario: Show empty state with clear instructions
- **WHEN** user opens device manager page
- **AND** has no paired devices
- **THEN** system displays large empty state with WiFi Off icon
- **AND** shows "暂无配对设备" prominent text
- **AND** displays "配对新设备开始同步数据" subtitle

#### Scenario: Show not in pool state with disabled controls
- **WHEN** user opens device manager page
- **AND** has not joined any data pool
- **THEN** system displays gray overlay covering entire page
- **AND** shows centered card with warning icon
- **AND** displays "请先加入数据池" text
- **AND** disables all interactive elements

### Requirement: Support QR code upload for device pairing
The system SHALL support QR code image file upload as primary pairing method for desktop.

#### Scenario: Upload QR code file for pairing
- **WHEN** user clicks "配对设备" button
- **THEN** system opens pairing dialog with "上传二维码" tab selected
- **AND** displays file upload area with drag-drop support
- **AND** shows "拖拽或点击选择二维码图片文件" text
- **AND** supports PNG, JPG, SVG file formats

#### Scenario: Parse uploaded QR code data
- **WHEN** user uploads QR code image file
- **THEN** system parses QR code and validates JSON structure
- **AND** extracts peerId, deviceName, deviceType, multiaddrs, poolId
- **AND** verifies timestamp is within 10 minutes
- **AND** switches to verification code input dialog

#### Scenario: Support drag-and-drop QR code upload
- **WHEN** user drags QR code image file to upload area
- **THEN** system displays visual feedback for drag-over state
- **AND** automatically processes file when dropped
- **AND** shows loading indicator during processing

#### Scenario: Handle invalid QR code file
- **WHEN** user uploads invalid or corrupted QR code file
- **THEN** system displays "无效的二维码文件" toast
- **AND** returns to upload state for retry
- **AND** provides clear error feedback

### Requirement: Implement inline device name editing
The system SHALL allow inline editing of current device name without popup dialogs.

#### Scenario: Enable inline editing on click
- **WHEN** user clicks on current device name
- **THEN** system converts name to editable text field
- **AND** automatically selects all text for easy replacement
- **AND** shows save and cancel buttons next to input field
- **AND** maintains focus in the text field

#### Scenario: Validate device name inline
- **WHEN** user enters empty string or only spaces
- **THEN** system disables save button
- **WHEN** user enters more than 32 characters
- **THEN** system truncates input to 32 characters
- **WHEN** user enters valid name
- **THEN** system enables save button

#### Scenario: Save device name inline
- **WHEN** user enters valid name and clicks save
- **THEN** system calls onDeviceNameChange callback with new name
- **AND** reverts to display mode with 200ms animation
- **AND** updates device name immediately without dialog close

#### Scenario: Cancel inline editing
- **WHEN** user clicks cancel button or presses Escape
- **THEN** system reverts to display mode with original name
- **AND** discards any changes made during editing
- **AND** maintains smooth transition animation

### Requirement: Display device addresses and connection details
The system SHALL display multiaddr information for devices with detailed connection status.

#### Scenario: Show device addresses in list
- **WHEN** device has multiple multiaddrs
- **THEN** system displays all available addresses in device details
- **AND** formats addresses as readable (e.g., "192.168.1.100:4001")
- **AND** shows protocol types (TCP, UDP, QUIC) with icons
- **AND** prioritizes local network addresses over external ones

#### Scenario: Show connection status details
- **WHEN** device is online
- **THEN** system shows green "在线" badge with active address
- **AND** displays connection protocol and port information
- **WHEN** device is offline
- **THEN** system shows gray "离线" badge
- **AND** displays last connection attempt time
- **AND** shows "最后在线：{time}" formatted appropriately

### Requirement: Implement peerId-based device identification
The system SHALL use libp2p peerId as the unique device identifier throughout the system.

#### Scenario: Use peerId in all device operations
- **WHEN** performing any device-related operation
- **THEN** system uses peerId as the primary identifier
- **AND** includes peerId in QR code data
- **AND** stores peerId in trusted devices database
- **AND** displays peerId in debugging information

#### Scenario: Generate QR code with peerId and multiaddrs
- **WHEN** generating QR code for pairing
- **THEN** system includes current device's peerId in JSON data
- **AND** includes all current multiaddr addresses
- **AND** includes device metadata (name, type, poolId)
- **AND** includes timestamp for security (10-minute expiry)

#### Scenario: Validate peerId format and validity
- **WHEN** parsing QR code with peerId
- **THEN** system validates peerId format using libp2p
- **AND** rejects invalid peerId formats
- **AND** logs validation errors for debugging

### Requirement: Support drag-and-drop file uploads
The system SHALL support drag-and-drop functionality for QR code image uploads.

#### Scenario: Enable drag-over state
- **WHEN** user drags file over upload area
- **THEN** system displays visual drag-over feedback
- **AND** changes upload area border style to indicate ready state
- **AND** shows "释放文件以上传" overlay text

#### Scenario: Process dropped file automatically
- **WHEN** user drops QR code image file in upload area
- **THEN** system automatically processes the file
- **AND** shows loading indicator during processing
- **AND** validates file format and content
- **AND** transitions to next step upon success

#### Scenario: Handle multiple file drops
- **WHEN** user drops multiple files
- **THEN** system processes only first valid file
- **AND** shows "只处理第一个文件" toast
- **AND** ignores additional files

### Requirement: Implement trust list management
The system SHALL maintain a trusted devices list using SQLite database with peerId as key.

#### Scenario: Add device to trust list after pairing
- **WHEN** pairing verification succeeds
- **THEN** system adds peerId to trusted_devices table
- **AND** stores device name, type, paired_at timestamp
- **AND** updates device list display immediately
- **AND** logs trust list operation for debugging

#### Scenario: Query trusted devices for display
- **WHEN** loading device manager page
- **THEN** system queries trusted_devices table
- **AND** returns list of all trusted devices
- **AND** includes current connection status for each device
- **AND** sorts by online status and last seen time

#### Scenario: Remove device from trust list (if supported)
- **WHEN** user removes device (future feature)
- **THEN** system removes peerId from trusted_devices table
- **AND** updates device list display
- **AND** terminates active connections to removed device
- **AND** logs removal operation

### Requirement: Handle mDNS for trusted device discovery
The system SHALL use mDNS only for discovering already paired devices' addresses.

#### Scenario: Broadcast current device via mDNS
- **WHEN** device manager is open
- **AND** device has joined a pool
- **THEN** system broadcasts peerId and multiaddrs via mDNS
- **AND** only broadcasts to local network
- **AND** updates broadcast when addresses change

#### Scenario: Discover trusted devices via mDNS
- **WHEN** mDNS service discovers devices
- **THEN** system checks if discovered peerId is in trusted list
- **AND** only connects to trusted peerIds
- **AND** ignores untrusted mDNS broadcasts
- **AND** updates device online status accordingly

#### Scenario: Handle mDNS address changes
- **WHEN** trusted device's IP address changes
- **THEN** system updates mDNS broadcast with new multiaddrs
- **AND** other devices automatically discover new address
- **AND** maintains connection without re-pairing

### Requirement: Provide desktop-specific error handling
The system SHALL handle desktop-specific errors and edge cases gracefully.

#### Scenario: Handle file permission errors
- **WHEN** file access is denied during QR code upload
- **THEN** system shows "文件访问被拒绝，请选择其他文件" toast
- **AND** provides clear instructions for resolution
- **AND** does not crash or hang

#### Scenario: Handle large QR code files
- **WHEN** uploaded QR code file size exceeds limit
- **THEN** system shows "文件过大，请选择小于10MB的文件" toast
- **AND** rejects file and returns to upload state
- **AND** suggests alternative methods (screenshot, smaller file)

#### Scenario: Handle network interface errors
- **WHEN** no network interfaces are available
- **THEN** system shows "无可用网络接口" error message
- **AND** displays troubleshooting steps
- **AND** provides retry mechanism when network becomes available

#### Scenario: Handle keypair generation errors
- **WHEN** libp2p keypair generation fails
- **THEN** system shows "密钥对生成失败" error message
- **AND** attempts regeneration with different seed
- **AND** logs detailed error information
- **AND** provides fallback option if all attempts fail

### Requirement: Optimize for desktop performance
The system SHALL optimize for desktop performance with large device lists and complex layouts.

#### Scenario: Lazy load device list
- **WHEN** device list contains many devices
- **THEN** system uses ListView.builder for lazy loading
- **AND** only renders visible devices
- **AND** maintains smooth 60fps scrolling
- **AND** caches rendered device items

#### Scenario: Efficient QR code generation
- **WHEN** generating QR code for same device
- **THEN** system caches generated QR code image
- **AND** reuses cached image for subsequent displays
- **AND** generates QR code in < 100ms
- **AND** uses error correction level M

#### Scenario: Optimize layout for large screens
- **WHEN** displaying on desktop screen
- **THEN** system uses maximum width of 800px for main content
- **AND** utilizes available horizontal space effectively
- **AND** provides responsive spacing and padding
- **AND** maintains readability on high-resolution displays

