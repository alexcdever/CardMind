# 设备管理面板规格


---



本规格定义了设备管理面板，显示当前设备信息、配对设备和设备管理操作。

---

## 需求：显示当前设备信息


系统应显示当前设备的信息，包括名称、类型和状态。

### 场景：显示当前设备卡片

- **操作**：渲染设备管理面板
- **预期结果**：系统应在独立的"当前设备"部分显示当前设备
- **并且**：显示设备名称、类型（手机/笔记本/平板）和 ID

### 场景：显示设备在线状态

- **操作**：显示设备信息
- **预期结果**：系统应使用视觉指示器指示在线/离线状态

---

## 需求：允许编辑当前设备名称


系统应允许用户重命名当前设备。

### 场景：编辑设备名称

- **操作**：用户点击设备名称字段
- **预期结果**：系统应启用编辑模式
- **并且**：允许用户输入新的设备名称

### 场景：保存设备名称

- **操作**：用户确认新设备名称
- **预期结果**：系统应使用新名称调用 onDeviceNameChange 回调
- **并且**：持久化名称更改

---

## 需求：显示配对设备列表


系统应显示所有配对设备的列表。

### 场景：显示配对设备

- **操作**：渲染设备管理面板
- **预期结果**：系统应在"配对设备"部分显示所有配对设备
- **并且**：为每个设备显示设备名称、类型、在线状态和上次可见时间戳

### 场景：显示空状态

- **操作**：没有配对设备
- **预期结果**：系统应显示空状态消息
- **并且**：显示添加设备的说明

---

## 需求：支持添加新设备


系统应提供配对新设备的功能。

### 场景：添加新设备

- **操作**：用户触发"添加设备"操作
- **预期结果**：系统应调用 onAddDevice 回调
- **并且**：启动设备配对流程

---

## 需求：支持移除配对设备


系统应允许用户取消设备配对。

### 场景：移除配对设备

- **操作**：用户对配对设备选择"移除"操作
- **预期结果**：系统应显示确认对话框
- **并且**：确认后使用设备 ID 调用 onRemoveDevice 回调

### 场景：防止移除当前设备

- **操作**：显示设备操作
- **预期结果**：系统不应为当前设备显示移除操作

---

## 需求：显示设备类型图标


系统应为不同设备类型显示适当的图标。

### 场景：显示设备类型图标

- **操作**：在列表中渲染设备
- **预期结果**：系统应为手机设备显示手机图标
- **并且**：为笔记本设备显示笔记本图标
- **并且**：为平板设备显示平板图标

---

## 需求：显示上次可见时间戳


系统应为离线设备显示上次活动时间戳。

### 场景：为离线设备显示上次可见时间

- **操作**：配对设备处于离线状态
- **预期结果**：系统应以相对时间格式显示"上次可见：[时间戳]"（例如，"2 小时前"）

### 场景：为在线设备显示"当前在线"

- **操作**：配对设备处于在线状态
- **预期结果**：系统应显示"当前在线"而不是上次可见时间戳

---



- `it_should_show_current_device_card()` - 显示current device
- `it_should_show_device_online_status()` - 在线状态
- `it_should_enable_device_name_editing()` - 启用editing
- `it_should_save_device_name()` - 保存name
- `it_should_show_paired_devices()` - 显示paired devices
- `it_should_show_empty_state()` - 空状态
- `it_should_add_new_device()` - 添加device
- `it_should_remove_paired_device()` - 移除device
- `it_should_prevent_removing_current_device()` - 阻止self-removal
- `it_should_show_device_type_icons()` - 设备类型图标
- `it_should_show_last_seen_for_offline()` - 最后看见时间戳
- `it_should_show_online_now()` - 当前在线指示器

- [ ] 所有widget测试通过
- [ ] Device name editing works correctly
- [ ] Device pairing/unpairing flows are smooth
- [ ] Status indicators are accurate
- [ ] 代码审查通过
- [ ] 文档已更新

---


- [device_config.md](../../architecture/storage/device_config.md) - Device configuration
- [sync_protocol.md](../../architecture/sync/service.md) - Sync protocol
- [settings_screen.md](settings_screen.md) - Settings screen

---

