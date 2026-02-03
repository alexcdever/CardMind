# 设备管理面板规格

**状态**: 活跃
**依赖**: [../../architecture/storage/device_config.md](../../architecture/storage/device_config.md), [../../architecture/sync/service.md](../../architecture/sync/service.md)
**相关测试**: `flutter/test/features/settings/device_manager_panel_test.dart`

---

## 概述

本规格定义设备管理面板，显示当前设备信息、配对设备列表和设备管理操作，确保设备信息清晰可见、名称可编辑、配对设备可管理并正确显示设备状态。

**适用平台**:
- iOS
- Android
- macOS
- Windows
- Linux

**技术栈**:
- Flutter ListView - 设备列表
- TextEditingController - 名称编辑
- Provider/Riverpod - 状态管理

---

## 需求：显示当前设备信息

系统应显示当前设备的信息，包括名称、类型和状态。

### 场景：显示当前设备卡片

- **前置条件**: 设备管理面板已打开
- **操作**: 渲染设备管理面板
- **预期结果**: 系统应在独立的"当前设备"部分显示当前设备
- **并且**: 显示设备名称、类型(手机/笔记本/平板)和ID
- **并且**: 使用不同的背景色突出显示

### 场景：显示设备在线状态

- **前置条件**: 设备管理面板已打开
- **操作**: 显示设备信息
- **预期结果**: 系统应使用绿色圆点指示在线状态
- **并且**: 显示"当前在线"文本

**实现逻辑**:

```
structure DeviceManagerPanel:
    currentDevice: Device
    pairedDevices: List<Device>

    // 渲染当前设备卡片
    function renderCurrentDevice():
        return Card(
            color: Colors.blue[50],
            child: Column([
                Row([
                    Icon(getDeviceIcon(currentDevice.type)),
                    Column([
                        Text(currentDevice.name, style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold
                        )),
                        Text("ID: {currentDevice.id}", style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey
                        ))
                    ]),
                    Spacer(),
                    StatusIndicator(
                        color: Colors.green,
                        text: "当前在线"
                    )
                ]),
                Divider(),
                EditButton(onTap: enableNameEditing)
            ])
        )

    // 获取设备类型图标
    function getDeviceIcon(deviceType):
        switch deviceType:
            case "phone":
                return Icons.phone_android
            case "laptop":
                return Icons.laptop
            case "tablet":
                return Icons.tablet
            default:
                return Icons.devices
```

---

## 需求：允许编辑当前设备名称

系统应允许用户重命名当前设备。

### 场景：编辑设备名称

- **前置条件**: 当前设备卡片已显示
- **操作**: 用户点击设备名称字段或编辑按钮
- **预期结果**: 系统应启用编辑模式
- **并且**: 显示文本输入框
- **并且**: 输入框应包含当前名称
- **并且**: 输入框应获得焦点

### 场景：保存设备名称

- **前置条件**: 用户正在编辑设备名称
- **操作**: 用户输入新名称并确认
- **预期结果**: 系统应验证名称不为空
- **并且**: 调用 onDeviceNameChange 回调
- **并且**: 持久化名称更改
- **并且**: 退出编辑模式

### 场景：取消编辑

- **前置条件**: 用户正在编辑设备名称
- **操作**: 用户点击取消按钮
- **预期结果**: 系统应恢复原始名称
- **并且**: 退出编辑模式

**实现逻辑**:

```
structure DeviceNameEditor:
    isEditing: bool = false
    nameController: TextEditingController
    originalName: String

    // 启用编辑模式
    function enableNameEditing():
        isEditing = true
        originalName = currentDevice.name
        nameController.text = currentDevice.name
        nameFocusNode.requestFocus()

    // 保存设备名称
    function saveDeviceName():
        // 步骤1:验证名称
        newName = nameController.text.trim()

        if newName.isEmpty():
            showToast("设备名称不能为空")
            return

        // 步骤2:更新设备名称
        currentDevice.name = newName

        // 步骤3:调用回调
        onDeviceNameChange(currentDevice.id, newName)

        // 步骤4:退出编辑模式
        isEditing = false

    // 取消编辑
    function cancelEditing():
        nameController.text = originalName
        isEditing = false
```

---

## 需求：显示配对设备列表

系统应显示所有配对设备的列表。

### 场景：显示配对设备

- **前置条件**: 存在配对设备
- **操作**: 渲染设备管理面板
- **预期结果**: 系统应在"配对设备"部分显示所有配对设备
- **并且**: 为每个设备显示名称、类型、在线状态
- **并且**: 显示上次可见时间戳(离线设备)

### 场景：显示空状态

- **前置条件**: 没有配对设备
- **操作**: 渲染配对设备列表
- **预期结果**: 系统应显示空状态消息"暂无配对设备"
- **并且**: 显示添加设备的说明
- **并且**: 显示"添加设备"按钮

**实现逻辑**:

```
structure PairedDevicesList:
    pairedDevices: List<Device>

    // 渲染配对设备列表
    function renderPairedDevices():
        if pairedDevices.isEmpty():
            return EmptyState(
                icon: Icons.devices_other,
                title: "暂无配对设备",
                subtitle: "添加设备以开始同步",
                action: Button(
                    text: "添加设备",
                    onPressed: onAddDevice
                )
            )

        return Column([
            Text("配对设备", style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold
            )),
            ListView(
                pairedDevices.map((device) => DeviceListItem(
                    name: device.name,
                    type: device.type,
                    icon: getDeviceIcon(device.type),
                    status: device.isOnline ? "在线" : "离线",
                    statusColor: device.isOnline ? Colors.green : Colors.grey,
                    lastSeen: device.isOnline ? null : formatTimestamp(device.lastSeen),
                    onRemove: () => removeDevice(device.id)
                ))
            )
        ])

    // 格式化时间戳
    function formatTimestamp(timestamp):
        now = currentTime()
        diff = now - timestamp

        if diff < 3600:
            return "{diff / 60} 分钟前"
        else if diff < 86400:
            return "{diff / 3600} 小时前"
        else:
            return "{diff / 86400} 天前"
```

---

## 需求：支持添加新设备

系统应提供配对新设备的功能。

### 场景：添加新设备

- **前置条件**: 设备管理面板已打开
- **操作**: 用户点击"添加设备"按钮
- **预期结果**: 系统应调用 onAddDevice 回调
- **并且**: 启动设备配对流程
- **并且**: 显示配对说明

**实现逻辑**:

```
structure DeviceAddition:
    // 添加新设备
    function addDevice():
        // 步骤1:调用回调
        onAddDevice()

        // 步骤2:显示配对说明
        showDialog(PairingInstructionsDialog(
            title: "添加设备",
            message: "在新设备上打开 CardMind 并加入同一个池",
            steps: [
                "1. 在新设备上打开 CardMind",
                "2. 选择'加入现有池'",
                "3. 输入池密码",
                "4. 设备将自动配对"
            ]
        ))
```

---

## 需求：支持移除配对设备

系统应允许用户取消设备配对。

### 场景：移除配对设备

- **前置条件**: 存在配对设备
- **操作**: 用户对配对设备选择"移除"操作
- **预期结果**: 系统应显示确认对话框"确定要移除此设备吗?"
- **并且**: 确认后调用 onRemoveDevice 回调
- **并且**: 从列表中移除设备

### 场景：防止移除当前设备

- **前置条件**: 显示设备列表
- **操作**: 查看当前设备的操作
- **预期结果**: 系统不应为当前设备显示移除按钮
- **并且**: 当前设备应在独立部分显示

**实现逻辑**:

```
structure DeviceRemoval:
    // 移除配对设备
    function removeDevice(deviceId):
        // 步骤1:防止移除当前设备
        if deviceId == currentDevice.id:
            showToast("无法移除当前设备")
            return

        // 步骤2:显示确认对话框
        confirmed = showConfirmDialog(
            title: "移除设备",
            message: "确定要移除此设备吗？移除后该设备将无法访问池中的数据。",
            confirmText: "移除",
            cancelText: "取消"
        )

        if not confirmed:
            return

        // 步骤3:调用回调
        onRemoveDevice(deviceId)

        // 步骤4:从列表移除
        pairedDevices.removeWhere((d) => d.id == deviceId)

        // 步骤5:显示确认
        showToast("设备已移除")
```

---

## 需求：显示设备类型图标

系统应为不同设备类型显示适当的图标。

### 场景：显示设备类型图标

- **前置条件**: 设备列表已显示
- **操作**: 渲染设备项
- **预期结果**: 手机设备应显示手机图标
- **并且**: 笔记本设备应显示笔记本图标
- **并且**: 平板设备应显示平板图标
- **并且**: 未知类型应显示通用设备图标

**实现逻辑**:

```
structure DeviceIcons:
    // 获取设备类型图标
    function getDeviceIcon(deviceType):
        iconMap = {
            "phone": Icons.phone_android,
            "laptop": Icons.laptop,
            "tablet": Icons.tablet,
            "desktop": Icons.computer,
            "unknown": Icons.devices
        }

        return iconMap[deviceType] ?? Icons.devices
```

---

## 需求：显示上次可见时间戳

系统应为离线设备显示上次活动时间戳。

### 场景：为离线设备显示上次可见时间

- **前置条件**: 配对设备处于离线状态
- **操作**: 渲染设备项
- **预期结果**: 系统应显示"上次可见: [时间]"
- **并且**: 使用相对时间格式(例如"2小时前")
- **并且**: 使用灰色文本

### 场景：为在线设备显示"当前在线"

- **前置条件**: 配对设备处于在线状态
- **操作**: 渲染设备项
- **预期结果**: 系统应显示"当前在线"
- **并且**: 使用绿色文本
- **并且**: 不显示上次可见时间

**实现逻辑**:

```
structure DeviceStatus:
    // 渲染设备状态
    function renderDeviceStatus(device):
        if device.isOnline:
            return Text(
                "当前在线",
                style: TextStyle(
                    color: Colors.green,
                    fontSize: 12
                )
            )
        else:
            return Text(
                "上次可见: {formatTimestamp(device.lastSeen)}",
                style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12
                )
            )
```

---

## 测试覆盖

**测试文件**: `flutter/test/features/settings/device_manager_panel_test.dart`

**单元测试**:
- `test_show_current_device_card()` - 显示当前设备卡片
- `test_show_device_online_status()` - 显示在线状态
- `test_enable_device_name_editing()` - 启用名称编辑
- `test_save_device_name()` - 保存设备名称
- `test_cancel_name_editing()` - 取消编辑
- `test_show_paired_devices()` - 显示配对设备
- `test_show_empty_state()` - 显示空状态
- `test_add_new_device()` - 添加新设备
- `test_remove_paired_device()` - 移除配对设备
- `test_prevent_removing_current_device()` - 防止移除当前设备
- `test_show_device_type_icons()` - 显示设备类型图标
- `test_show_last_seen_for_offline()` - 显示离线设备上次可见时间
- `test_show_online_now()` - 显示在线指示器

**集成测试**:
- `test_complete_device_management_workflow()` - 完整设备管理流程
- `test_device_name_editing_workflow()` - 设备名称编辑流程

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 所有集成测试通过
- [ ] 设备名称编辑正常工作
- [ ] 设备配对/取消配对流程流畅
- [ ] 状态指示器准确
- [ ] 代码审查通过
- [ ] 文档已更新
