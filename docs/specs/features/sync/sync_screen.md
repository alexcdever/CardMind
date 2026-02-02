# 同步屏幕规格


---



本规格定义了一个专门的屏幕，显示全面的同步信息、设备管理和同步控制。

---



系统应提供显示详细同步信息的专用屏幕。


- **操作**：同步屏幕加载
- **预期结果**：系统应显示当前同步状态（已同步、同步中、错误）
- **并且**：显示上次成功同步的时间戳
- **并且**：显示已同步卡片的总数

---



系统应显示所有发现的对等设备及其连接状态。


- **操作**：同步屏幕加载
- **预期结果**：系统应列出所有发现的设备
- **并且**：显示每个设备的在线/离线状态
- **并且**：显示设备类型（手机、笔记本、平板）
- **并且**：显示离线设备的上次可见时间戳


- **操作**：用户触发刷新操作
- **预期结果**：系统应重新扫描可用设备
- **并且**：更新设备列表

---



系统应显示最近同步事件的时间顺序列表。


- **操作**：查看同步历史部分
- **预期结果**：系统应显示带有时间戳的最近同步事件
- **并且**：指示每个事件的成功或失败
- **并且**：显示每次同步涉及的设备


- **操作**：用户应用历史过滤器
- **预期结果**：系统应按设备、状态或时间范围过滤事件

---



系统应提供手动同步操作。


- **操作**：用户点击"立即同步"按钮
- **预期结果**：系统应立即尝试与可用设备同步
- **并且**：显示同步进度指示器
- **并且**：完成时更新状态


- **操作**：用户触发完全同步操作
- **预期结果**：系统应执行所有数据的完全重新同步
- **并且**：显示详细的进度信息

---



系统应显示同步指标和统计信息。


- **操作**：显示同步统计信息
- **预期结果**：系统应显示已同步的总数据量
- **并且**：显示每个设备同步的数据


- **操作**：显示同步统计信息
- **预期结果**：系统应显示成功同步的百分比
- **并且**：显示失败同步的次数及原因

---



系统应允许用户配置同步首选项。


- **操作**：用户切换自动同步设置
- **预期结果**：系统应启用或禁用自动同步


- **操作**：自动同步已启用
- **预期结果**：系统应允许用户设置同步频率（立即、每 N 分钟等）

---



系统应显示并帮助解决同步冲突。


- **操作**：存在同步冲突
- **预期结果**：系统应显示冲突部分
- **并且**：列出所有未解决的冲突


- **操作**：用户点击冲突
- **预期结果**：系统应显示冲突数据的两个版本
- **并且**：允许用户选择保留哪个版本

---



- `it_should_show_overall_sync_status()` - 总体状态
- `it_should_list_discovered_devices()` - 设备列表
- `it_should_show_device_status()` - 设备状态
- `it_should_refresh_device_list()` - 刷新devices
- `it_should_display_sync_event_log()` - 事件日志
- `it_should_filter_sync_history()` - 过滤history
- `it_should_trigger_manual_sync()` - 手动同步
- `it_should_force_full_sync()` - 完整同步
- `it_should_show_sync_statistics()` - 统计信息
- `it_should_toggle_auto_sync()` - 切换auto-sync
- `it_should_set_sync_frequency()` - 设置frequency
- `it_should_list_conflicts()` - 列出conflicts
- `it_should_show_conflict_details()` - 冲突详情

- [ ] 所有screen测试通过
- [ ] Device discovery works correctly
- [ ] Manual sync controls are reliable
- [ ] Conflict resolution is clear
- [ ] 代码审查通过
- [ ] 文档已更新

---


- [sync_protocol.md](../../architecture/sync/service.md) - Sync protocol
- [sync_status_indicator.md](../sync_feedback/sync_status_indicator.md) - Status indicator
- [sync_details_dialog.md](../sync_feedback/sync_details_dialog.md) - Details dialog

---

