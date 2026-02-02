# 设备管理面板规格

**版本**: 1.0.0

**状态**: 活跃

**依赖**: [device_config.md](../../../architecture/storage/device_config.md), [sync/protocol.md](../../../architecture/sync/service.md)

**相关测试**: `test/widgets/device_manager_panel_test.dart`

---

## 概述


本规格定义了设备管理面板，显示当前设备信息、配对设备和设备管理操作。

---

## 需求：显示当前设备信息


系统应显示当前设备的信息，包括名称、类型和状态。

### 场景：显示当前设备卡片

- **前置条件**：设备管理面板已显示
- **操作**：渲染面板
- **预期结果**：系统应在独立的"当前设备"部分显示当前设备
- **并且**：显示设备名称、类型（手机/笔记本/平板）和 ID

### 场景：显示设备在线状态

- **前置条件**：设备管理面板已显示
- **操作**：显示设备信息
- **预期结果**：系统应使用视觉指示器指示在线/离线状态

---

## 需求：允许编辑当前设备名称


系统应允许用户重命名当前设备。

### 场景：编辑设备名称

- **前置条件**：当前设备已显示
- **操作**：用户点击设备名称字段
- **预期结果**：系统应启用编辑模式
- **并且**：允许用户输入新的设备名称

### 场景：保存设备名称

- **前置条件**：用户已输入新设备名称
- **操作**：用户确认新设备名称
- **预期结果**：系统应使用新名称调用 onDeviceNameChange 回调
- **并且**：持久化名称更改

---

## 需求：显示配对设备列表


系统应显示所有配对设备的列表，并进行适当的排序和状态指示。

### Device List Sorting Rules

1. Online devices first
2. Last seen time descending (for same status)

1. 在线设备优先
2. 最后在线时间倒序（相同状态）

- Phone: phone icon
- Laptop: laptop icon
- Tablet: tablet icon

- 手机：phone 图标
- 笔记本：laptop 图标
- 平板：tablet 图标

- Online: Green badge with "Online" text
- Offline: Gray badge with "Offline" text

- 在线：绿色徽章，显示"在线"
- 离线：灰色徽章，显示"离线"

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

### 场景：显示配对设备

- **前置条件**：设备管理面板已显示
- **操作**：渲染面板
- **预期结果**：系统应在"配对设备"部分显示所有配对设备
- **并且**：为每个设备显示设备名称、类型、在线状态和上次可见时间戳
- **并且**：按在线状态优先排序，然后按最后可见时间排序

### 场景：显示空状态

- **前置条件**：设备管理面板已显示
- **操作**：没有配对设备
- **预期结果**：系统应显示空状态消息
- **并且**：显示添加设备的说明

---

## 需求：支持通过二维码添加新设备


系统应提供使用二维码扫描配对新设备的功能。

### Mobile Platform Design Details

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

- Online devices first + Last seen time descending
- 在线设备优先 + 最后在线时间倒序

- Current device: Theme color 10% background with "This Device" badge
- Verification code input: 6 independent input boxes with auto-jump
- Empty state: WiFi Off icon + prompt text
- Not in pool state: Gray overlay + prompt card

- 当前设备：主题色 10% 背景，带"本机"标识
- 验证码输入：6 个独立输入框，自动跳转
- 空状态：WiFi Off 图标 + 提示文字
- 未加入数据池：灰色遮罩 + 提示卡片

### Desktop Platform Design Details

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

- Use libp2p PeerId as device ID
- Completely replace mDNS for initial pairing
- Retain mDNS for address discovery of paired devices
- Keypair storage: `{ApplicationSupportDirectory}/identity/keypair.bin`

- 使用 libp2p PeerId 作为设备 ID
- 完全替代 mDNS 用于首次配对
- 保留 mDNS 用于已配对设备的地址发现
- 密钥对存储：`{ApplicationSupportDirectory}/identity/keypair.bin`

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

### 场景：添加新设备

- **前置条件**：设备管理面板已显示
- **操作**：用户触发"添加设备"操作
- **预期结果**：系统应调用 onAddDevice 回调
- **并且**：启动设备配对流程

### 场景：扫描二维码（移动端）

- **前置条件**：用户在"扫描二维码"标签页
- **操作**：二维码扫描成功
- **预期结果**：系统应从二维码解析设备信息
- **并且**：显示验证码输入对话框
- **并且**：显示对方设备名称

### 场景：上传二维码（桌面端）

- **前置条件**：用户在"上传二维码"标签页
- **操作**：用户上传或拖拽二维码图片
- **预期结果**：系统应从图片解析设备信息
- **并且**：显示验证码输入对话框

### 场景：使用验证码验证配对

- **前置条件**：验证码输入对话框已显示
- **操作**：用户输入 6 位验证码
- **预期结果**：系统应验证验证码
- **并且**：成功时将设备添加到配对设备列表
- **并且**：失败时显示错误消息

---

## 需求：支持移除配对设备


系统应允许用户取消设备配对。

### 场景：移除配对设备

- **前置条件**：存在配对设备
- **操作**：用户对配对设备选择"移除"操作
- **预期结果**：系统应显示确认对话框
- **并且**：确认后使用设备 ID 调用 onRemoveDevice 回调

### 场景：防止移除当前设备

- **前置条件**：设备管理面板已显示
- **操作**：显示设备操作
- **预期结果**：系统不应为当前设备显示移除操作

---

## 需求：显示设备类型图标


系统应为不同设备类型显示适当的图标。

### 场景：显示设备类型图标

- **前置条件**：设备显示在列表中
- **操作**：渲染设备
- **预期结果**：系统应为手机设备显示手机图标
- **并且**：为笔记本设备显示笔记本图标
- **并且**：为平板设备显示平板图标

---

## 需求：显示上次可见时间戳


系统应为离线设备显示上次活动时间戳。

### 场景：为离线设备显示上次可见时间

- **前置条件**：配对设备处于离线状态
- **操作**：显示设备
- **预期结果**：系统应以相对时间格式显示"上次可见：[时间戳]"（例如，"2 小时前"）

### 场景：为在线设备显示"当前在线"

- **前置条件**：配对设备处于在线状态
- **操作**：显示设备
- **预期结果**：系统应显示"当前在线"而不是上次可见时间戳

---

## 测试覆盖

**测试文件**: `test/widgets/device_manager_panel_test.dart`

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

- `it_should_show_current_device_card()` - 显示当前设备
- `it_should_show_device_online_status()` - 在线状态
- `it_should_enable_device_name_editing()` - 启用编辑
- `it_should_save_device_name()` - 保存名称
- `it_should_show_paired_devices()` - 显示配对设备
- `it_should_show_empty_state()` - 空状态
- `it_should_add_new_device()` - 添加设备
- `it_should_remove_paired_device()` - 移除设备
- `it_should_prevent_removing_current_device()` - 防止自移除
- `it_should_show_device_type_icons()` - 设备类型图标
- `it_should_show_last_seen_for_offline()` - 离线设备最后在线时间
- `it_should_show_online_now()` - 在线指示器
- `it_should_scan_qr_code()` - 扫描二维码（移动端）
- `it_should_upload_qr_code()` - 上传二维码（桌面端）
- `it_should_verify_pairing_code()` - 验证配对码
- `it_should_show_verification_code_dialog()` - 显示验证码对话框
- `it_should_handle_verification_failure()` - 处理验证失败
- `it_should_sort_devices_by_status()` - 按状态排序设备
- `it_should_format_time_correctly()` - 正确格式化时间
- ...（另外26个交互和边界情况测试）

**验收标准**:
- [ ] 所有 53 个测试通过（8 个单元测试 + 45 个 Widget 测试）
- [ ] 设备名称编辑正常工作
- [ ] 二维码配对流程流畅（移动端和桌面端）
- [ ] 验证码验证正常工作
- [ ] 设备列表排序准确
- [ ] 状态指示器准确
- [ ] 代码审查通过
- [ ] 文档已更新

---

## 相关文档

**相关规格**:
- [device_config.md](../../../architecture/storage/device_config.md) - 设备配置
- [sync/protocol.md](../../../architecture/sync/service.md) - 同步协议
- [settings_screen.md](../../screens/mobile/settings_screen.md) - 设置屏幕

---

**最后更新**: 2026-01-27

**作者**: CardMind Team
