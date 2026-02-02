# Sync Screen Specification
# 同步屏幕规格

**版本**: 1.0.0

**状态**: 活跃

**平台**: 移动端

**依赖**: [sync/protocol.md](../../../architecture/sync/service.md)

**相关测试**: `test/screens/sync_screen_test.dart`

---

## 概述


本规格定义了一个专门的移动端屏幕，显示全面的同步信息、设备管理和同步控制。

---

## 需求：显示全面的同步状态


系统应提供显示详细同步信息的专用屏幕。

### 场景：显示整体同步状态

- **前置条件**：用户导航到同步屏幕
- **操作**：同步屏幕加载
- **预期结果**：系统应显示当前同步状态（已同步、同步中、错误）
- **并且**：显示上次成功同步的时间戳
- **并且**：显示已同步卡片的总数

---

## 需求：列出发现的设备


系统应显示所有发现的对等设备及其连接状态。

### 场景：显示设备列表

- **前置条件**：同步屏幕已显示
- **操作**：同步屏幕加载
- **预期结果**：系统应列出所有发现的设备
- **并且**：显示每个设备的在线/离线状态
- **并且**：显示设备类型（手机、笔记本、平板）
- **并且**：显示离线设备的上次可见时间戳

### 场景：刷新设备列表

- **前置条件**：设备列表已显示
- **操作**：用户触发刷新操作
- **预期结果**：系统应重新扫描可用设备
- **并且**：更新设备列表

---

## 需求：显示同步历史


系统应显示最近同步事件的时间顺序列表。

### 场景：显示同步事件日志

- **前置条件**：同步屏幕已显示
- **操作**：查看同步历史部分
- **预期结果**：系统应显示带有时间戳的最近同步事件
- **并且**：指示每个事件的成功或失败
- **并且**：显示每次同步涉及的设备

### 场景：过滤同步历史

- **前置条件**：同步历史已显示
- **操作**：用户应用历史过滤器
- **预期结果**：系统应按设备、状态或时间范围过滤事件

---

## 需求：提供手动同步控制


系统应提供手动同步操作。

### 场景：触发手动同步

- **前置条件**：同步屏幕已显示
- **操作**：用户点击"立即同步"按钮
- **预期结果**：系统应立即尝试与可用设备同步
- **并且**：显示同步进度指示器
- **并且**：完成时更新状态

### 场景：强制完全同步

- **前置条件**：同步屏幕已显示
- **操作**：用户触发完全同步操作
- **预期结果**：系统应执行所有数据的完全重新同步
- **并且**：显示详细的进度信息

---

## 需求：显示同步统计信息


系统应显示同步指标和统计信息。

### 场景：显示数据量

- **前置条件**：同步屏幕已显示
- **操作**：显示同步统计信息
- **预期结果**：系统应显示已同步的总数据量
- **并且**：显示每个设备同步的数据

### 场景：显示同步成功率

- **前置条件**：同步屏幕已显示
- **操作**：显示同步统计信息
- **预期结果**：系统应显示成功同步的百分比
- **并且**：显示失败同步的次数及原因

---

## 需求：配置同步设置


系统应允许用户配置同步首选项。

### 场景：切换自动同步

- **前置条件**：同步屏幕已显示
- **操作**：用户切换自动同步设置
- **预期结果**：系统应启用或禁用自动同步

### 场景：设置同步频率

- **前置条件**：自动同步已启用
- **操作**：用户配置同步频率
- **预期结果**：系统应允许用户设置同步频率（立即、每 N 分钟等）

---

## 需求：显示同步冲突


系统应显示并帮助解决同步冲突。

### 场景：列出冲突

- **前置条件**：存在同步冲突
- **操作**：同步屏幕加载
- **预期结果**：系统应显示冲突部分
- **并且**：列出所有未解决的冲突

### 场景：查看冲突详情

- **前置条件**：冲突已列出
- **操作**：用户点击冲突
- **预期结果**：系统应显示冲突数据的两个版本
- **并且**：允许用户选择保留哪个版本

---

## 移动端特定模式

### Pull-to-Refresh
### 下拉刷新


系统应支持下拉刷新手势来更新设备列表和同步状态。

### Floating Action Button
### 浮动操作按钮


系统应提供浮动操作按钮以快速手动同步。

---

## 测试覆盖

**测试文件**: `test/screens/sync_screen_test.dart`

**屏幕测试**:
- `it_should_show_overall_sync_status()` - Overall status
- `it_should_show_overall_sync_status()` - 整体状态
- `it_should_list_discovered_devices()` - Device list
- `it_should_list_discovered_devices()` - 设备列表
- `it_should_show_device_status()` - Device status
- `it_should_show_device_status()` - 设备状态
- `it_should_refresh_device_list()` - Refresh devices
- `it_should_refresh_device_list()` - 刷新设备
- `it_should_display_sync_event_log()` - Event log
- `it_should_display_sync_event_log()` - 事件日志
- `it_should_filter_sync_history()` - Filter history
- `it_should_filter_sync_history()` - 过滤历史
- `it_should_trigger_manual_sync()` - Manual sync
- `it_should_trigger_manual_sync()` - 手动同步
- `it_should_force_full_sync()` - Full sync
- `it_should_force_full_sync()` - 完全同步
- `it_should_show_sync_statistics()` - Statistics
- `it_should_show_sync_statistics()` - 统计信息
- `it_should_toggle_auto_sync()` - Toggle auto-sync
- `it_should_toggle_auto_sync()` - 切换自动同步
- `it_should_set_sync_frequency()` - Set frequency
- `it_should_set_sync_frequency()` - 设置频率
- `it_should_list_conflicts()` - List conflicts
- `it_should_list_conflicts()` - 列出冲突
- `it_should_show_conflict_details()` - Conflict details
- `it_should_show_conflict_details()` - 冲突详情

**验收标准**:
- [ ] All screen tests pass
- [ ] 所有屏幕测试通过
- [ ] Device discovery works correctly
- [ ] 设备发现正常工作
- [ ] Manual sync controls are reliable
- [ ] 手动同步控制可靠
- [ ] Conflict resolution is clear
- [ ] 冲突解决清晰
- [ ] Code review approved
- [ ] 代码审查通过
- [ ] Documentation updated
- [ ] 文档已更新

---

## 相关文档

**相关规格**:
- [sync/protocol.md](../../../architecture/sync/service.md) - Sync protocol
- [sync/protocol.md](../../../architecture/sync/service.md) - 同步协议
- [sync_status_indicator.md](../../components/shared/sync_status_indicator.md) - Status indicator
- [sync_status_indicator.md](../../components/shared/sync_status_indicator.md) - 状态指示器
- [sync_details_dialog.md](../../components/shared/sync_details_dialog.md) - Details dialog
- [sync_details_dialog.md](../../components/shared/sync_details_dialog.md) - 详情对话框

---

**最后更新**: 2026-01-24

**作者**: CardMind Team
