# Sync Details Dialog Specification
# 同步详情对话框规格

**版本**: 1.0.0

**状态**: 活跃

**依赖**: [sync/protocol.md](../../../architecture/sync/service.md), [sync_status_indicator.md](sync_status_indicator.md)

**相关测试**: `test/widgets/sync_details_dialog_test.dart`

---

## 概述


本规格定义了同步详情对话框，提供全面的同步信息，包括设备列表、同步历史和配置。

---

## 需求：显示全面的同步信息


系统应提供显示详细同步信息的对话框，包括设备列表、同步历史和配置。

### 场景：显示已连接设备

- **前置条件**：同步详情对话框已打开
- **操作**：显示对话框
- **预期结果**：系统应显示所有发现的对等设备列表
- **并且**：指示当前连接的设备
- **并且**：显示每个设备的上次可见时间戳

### 场景：显示同步统计信息

- **前置条件**：同步详情对话框已打开
- **操作**：显示对话框
- **预期结果**：系统应显示已同步卡片的总数
- **并且**：显示同步的总数据大小
- **并且**：显示同步会话统计信息（成功/失败的同步）

---

## 需求：显示最近的同步历史


系统应显示最近同步事件的时间顺序列表。

### 场景：显示同步事件日志

- **前置条件**：已发生同步事件
- **操作**：显示同步历史
- **预期结果**：系统应列出带有时间戳的最近同步事件
- **并且**：指示每个事件的成功或失败状态
- **并且**：显示每个同步事件涉及的设备

### 场景：显示同步冲突信息

- **前置条件**：已发生同步冲突
- **操作**：显示同步历史
- **预期结果**：系统应在历史中突出显示冲突事件
- **并且**：提供有关如何解决冲突的详细信息

---

## 需求：提供手动同步控制


系统应允许用户手动触发同步操作。

### 场景：触发手动同步

- **前置条件**：同步详情对话框已打开
- **操作**：用户点击"立即同步"按钮
- **预期结果**：系统应立即尝试与可用对等点同步
- **并且**：实时更新同步状态

### 场景：刷新设备列表

- **前置条件**：同步详情对话框已打开
- **操作**：用户点击"刷新设备"按钮
- **预期结果**：系统应重新扫描可用的对等设备
- **并且**：更新设备列表显示

---

## 需求：显示同步配置


系统应显示当前的同步配置设置。

### 场景：显示自动同步状态

- **前置条件**：同步详情对话框已打开
- **操作**：显示同步配置
- **预期结果**：系统应指示自动同步是启用还是禁用

### 场景：显示同步协议信息

- **前置条件**：同步详情对话框已打开
- **操作**：显示同步配置
- **预期结果**：系统应显示当前同步协议版本
- **并且**：显示网络配置（WiFi、蓝牙等）

---

## 需求：处理对话框关闭


系统应提供明确的操作来关闭对话框。

### 场景：关闭对话框

- **前置条件**：同步详情对话框已打开
- **操作**：用户点击对话框外部或按下关闭按钮
- **预期结果**：系统应关闭对话框
- **并且**：返回到上一个屏幕

---

## 设计详情

### Functional Scope
### 功能范围

- Real-time display of sync status (unsynced/syncing/synced/failed)
- Display all devices in data pool and their online status
- Display sync statistics (total card count, data size, sync interval)
- Display recent 20 sync history records

- 实时显示同步状态（未同步/同步中/已同步/失败）
- 显示数据池中所有设备及在线状态
- 显示同步统计信息（总卡片数、数据大小、同步间隔）
- 显示最近 20 条同步历史记录

### Trigger Method
### 触发方式

- Click the sync status indicator in desktop top bar

- 点击桌面端顶部的同步状态指示器

### Real-time Updates
### 实时更新

- Subscribe to sync status updates via Stream
- Subscribe to device list updates via Stream
- New sync records automatically added to top of history list

- 通过 Stream 订阅实时更新同步状态
- 通过 Stream 订阅实时更新设备列表
- 新增同步记录自动添加到历史列表顶部

### Visual Design
### 视觉设计

- Dialog width: 600px (fixed)
- Dialog height: max 80vh, scroll when content overflows
- Status colors: unsynced (gray), syncing (blue with rotation animation), synced (green), failed (red)
- Device status: online (green badge), offline (gray text)

- 对话框宽度：600px（固定）
- 对话框高度：最大 80vh，内容超出时滚动
- 状态颜色：未同步（灰色）、同步中（蓝色+旋转动画）、已同步（绿色）、失败（红色）
- 设备状态：在线（绿色徽章）、离线（灰色文字）

### Key Decisions
### 关键决策

- Display information only, no operation functions (keep simple)
- Limit history records to 20 entries (performance optimization)
- Use Stream instead of polling (better real-time performance)
- Desktop-only (mobile has limited screen space)

- 仅显示信息，不提供操作功能（保持简洁）
- 限制历史记录为 20 条（性能优化）
- 使用 Stream 而不是轮询（实时性更好）
- 桌面端专用（移动端屏幕空间有限）

---

## 测试覆盖

**测试文件**: 
- `test/unit/sync_details_dialog_test.dart` - Unit tests
- `test/unit/sync_details_dialog_test.dart` - 单元测试
- `test/widgets/sync_details_dialog_test.dart` - Widget tests
- `test/widgets/sync_details_dialog_test.dart` - Widget 测试

**单元测试（共 10 个）**:
- `it_should_display_sync_status_correctly()` - Display correct sync status
- `it_should_display_sync_status_correctly()` - 显示正确的同步状态
- `it_should_update_device_list_on_stream_event()` - Update device list on stream
- `it_should_update_device_list_on_stream_event()` - 通过流更新设备列表
- `it_should_format_sync_statistics_properly()` - Format sync statistics
- `it_should_format_sync_statistics_properly()` - 正确格式化同步统计
- `it_should_filter_sync_history_to_20_items()` - Limit history to 20 items
- `it_should_filter_sync_history_to_20_items()` - 限制历史记录为 20 条
- `it_should_handle_real_time_status_updates()` - Handle real-time updates
- `it_should_handle_real_time_status_updates()` - 处理实时状态更新
- Additional unit tests covering edge cases and business logic
- 覆盖边界情况和业务逻辑的额外单元测试

- `it_should_show_discovered_devices()` - Display device list
- `it_should_show_discovered_devices()` - 显示设备列表
- `it_should_indicate_connected_devices()` - Indicate connected status
- `it_should_indicate_connected_devices()` - 指示连接状态
- `it_should_show_last_seen_timestamps()` - Show last seen time
- `it_should_show_last_seen_timestamps()` - 显示上次可见时间
- `it_should_show_sync_statistics()` - Display sync stats
- `it_should_show_sync_statistics()` - 显示同步统计
- `it_should_show_sync_event_log()` - Display event log
- `it_should_show_sync_event_log()` - 显示事件日志
- `it_should_highlight_conflicts()` - Highlight conflicts
- `it_should_highlight_conflicts()` - 突出显示冲突
- `it_should_trigger_manual_sync()` - Trigger manual sync
- `it_should_trigger_manual_sync()` - 触发手动同步
- `it_should_refresh_device_list()` - Refresh devices
- `it_should_refresh_device_list()` - 刷新设备列表
- `it_should_show_auto_sync_status()` - Show auto-sync status
- `it_should_show_auto_sync_status()` - 显示自动同步状态
- `it_should_show_protocol_info()` - Show protocol info
- `it_should_show_protocol_info()` - 显示协议信息
- `it_should_dismiss_on_close()` - Dismiss dialog
- `it_should_dismiss_on_close()` - 关闭对话框
- Additional widget tests covering UI interactions and visual states
- 覆盖 UI 交互和视觉状态的额外 Widget 测试

**验收标准**:
- [ ] All widget tests pass
- [ ] 所有 Widget 测试通过
- [ ] Device list updates correctly
- [ ] 设备列表正确更新
- [ ] Sync history displays accurately
- [ ] 同步历史准确显示
- [ ] Manual sync controls work reliably
- [ ] 手动同步控制可靠工作
- [ ] Code review approved
- [ ] 代码审查通过
- [ ] Documentation updated
- [ ] 文档已更新

---

## 相关文档

**相关规格**:
- [sync_status_indicator.md](sync_status_indicator.md) - Sync status indicator
- [sync_status_indicator.md](sync_status_indicator.md) - 同步状态指示器
- [sync/protocol.md](../../../architecture/sync/service.md) - Sync protocol
- [sync/protocol.md](../../../architecture/sync/service.md) - 同步协议

---

**最后更新**: 2026-01-27

**作者**: CardMind Team
