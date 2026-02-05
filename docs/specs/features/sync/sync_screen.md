# 同步屏幕规格

**状态**: 活跃
**依赖**: [../../architecture/sync/service.md](../../architecture/sync/service.md), [../../domain/types.md](../../domain/types.md)
**相关测试**: `flutter/test/features/sync/sync_screen_test.dart`

---

## 概述

本规格定义同步屏幕，显示全面的同步信息、设备管理与同步控制，确保展示详细状态、设备列表、同步历史、手动控制、统计信息与冲突解决能力。

**适用平台**:
- iOS
- Android
- macOS
- Windows
- Linux

**技术栈**:
- Flutter Scaffold - 页面框架
- ListView - 列表展示
- Provider/Riverpod - 状态管理

---

## 需求：显示同步状态

系统应提供显示详细同步信息的专用屏幕。

### 场景：显示总体同步状态

- **前置条件**: 同步屏幕已加载
- **操作**: 查看同步状态
- **预期结果**: 系统应显示当前同步状态(已同步、同步中、错误)
- **并且**: 显示上次成功同步的时间戳
- **并且**: 显示已同步卡片的总数

**实现逻辑**:

```
structure SyncScreen:
    syncStatus: SyncStatus
    lastSyncTime: Timestamp
    totalCards: int

    // 渲染同步状态
    function renderSyncStatus():
        return Card(
            child: Column([
                Row([
                    Icon(getSyncStatusIcon(syncStatus)),
                    Column([
                        Text(getSyncStatusText(syncStatus), style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold
                        )),
                        Text("上次同步: {formatTimestamp(lastSyncTime)}", style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey
                        ))
                    ])
                ]),
                Divider(),
                Text("已同步 {totalCards} 张卡片")
            ])
        )

    // 获取同步状态图标
    function getSyncStatusIcon(status):
        switch status:
            case SYNCED:
                return Icons.check_circle
            case SYNCING:
                return Icons.sync
            case ERROR:
                return Icons.error
            default:
                return Icons.cloud_off

    // 获取同步状态文本
    function getSyncStatusText(status):
        switch status:
            case SYNCED:
                return "已同步"
            case SYNCING:
                return "同步中"
            case ERROR:
                return "同步错误"
            default:
                return "未连接"
```

---

## 需求：设备列表

系统应显示所有发现的对等设备及其连接状态。

### 场景：显示设备列表

- **前置条件**: 同步屏幕已加载
- **操作**: 查看设备列表
- **预期结果**: 系统应列出所有发现的设备
- **并且**: 显示每个设备的在线/离线状态
- **并且**: 显示设备类型(手机、笔记本、平板)
- **并且**: 显示离线设备的上次可见时间戳

### 场景：刷新设备列表

- **前置条件**: 同步屏幕已打开
- **操作**: 用户触发刷新操作
- **预期结果**: 系统应重新扫描可用设备
- **并且**: 更新设备列表

**实现逻辑**:

```
structure DeviceList:
    devices: List<Device>

    // 渲染设备列表
    function renderDeviceList():
        return Column([
            Row([
                Text("已发现设备", style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold
                )),
                Spacer(),
                IconButton(
                    icon: Icons.refresh,
                    onPressed: refreshDevices
                )
            ]),
            ListView(
                devices.map((device) => DeviceListItem(
                    name: device.name,
                    type: device.type,
                    isOnline: device.isOnline,
                    lastSeen: device.isOnline ? null : formatTimestamp(device.lastSeen),
                    icon: getDeviceIcon(device.type),
                    statusColor: device.isOnline ? Colors.green : Colors.grey
                ))
            )
        ])

    // 刷新设备列表
    function refreshDevices():
        // 步骤1:显示刷新指示器
        showRefreshIndicator()

        // 步骤2:重新扫描设备
        newDevices = syncService.discoverDevices()

        // 步骤3:更新设备列表
        devices = newDevices

        // 步骤4:隐藏刷新指示器
        hideRefreshIndicator()

        // 步骤5:显示结果
        showToast("发现 {devices.length} 台设备")
```

---

## 需求：同步历史

系统应显示最近同步事件的时间顺序列表。

### 场景：显示同步事件日志

- **前置条件**: 同步屏幕已打开
- **操作**: 查看同步历史部分
- **预期结果**: 系统应显示带有时间戳的最近同步事件
- **并且**: 指示每个事件的成功或失败
- **并且**: 显示每次同步涉及的设备

### 场景：过滤同步历史

- **前置条件**: 同步历史已显示
- **操作**: 用户应用历史过滤器
- **预期结果**: 系统应按设备、状态或时间范围过滤事件

**实现逻辑**:

```
structure SyncHistory:
    events: List<SyncEvent>
    filter: HistoryFilter?

    // 渲染同步历史
    function renderSyncHistory():
        filteredEvents = applyFilter(events, filter)

        return Column([
            Row([
                Text("同步历史", style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold
                )),
                Spacer(),
                IconButton(
                    icon: Icons.filter_list,
                    onPressed: showFilterDialog
                )
            ]),
            ListView(
                filteredEvents.map((event) => SyncEventItem(
                    timestamp: formatTimestamp(event.timestamp),
                    status: event.success ? "成功" : "失败",
                    device: event.deviceName,
                    details: event.details,
                    icon: event.success ? Icons.check : Icons.error,
                    color: event.success ? Colors.green : Colors.red
                ))
            )
        ])

    // 应用过滤器
    function applyFilter(events, filter):
        if not filter:
            return events

        filtered = events

        if filter.device:
            filtered = filtered.where((e) => e.deviceId == filter.device)

        if filter.status:
            filtered = filtered.where((e) => e.success == filter.status)

        if filter.timeRange:
            filtered = filtered.where((e) =>
                e.timestamp >= filter.timeRange.start and
                e.timestamp <= filter.timeRange.end
            )

        return filtered
```

---

## 需求：手动同步控制

系统应提供手动同步操作。

### 场景：触发立即同步

- **前置条件**: 同步屏幕已打开
- **操作**: 用户点击"立即同步"按钮
- **预期结果**: 系统应立即尝试与可用设备同步
- **并且**: 显示同步进度指示器
- **并且**: 完成时更新状态

### 场景：强制完全同步

- **前置条件**: 同步屏幕已打开
- **操作**: 用户触发完全同步操作
- **预期结果**: 系统应执行所有数据的完全重新同步
- **并且**: 显示详细的进度信息

**实现逻辑**:

```
structure ManualSyncControl:
    isSyncing: bool = false
    syncProgress: SyncProgress?

    // 触发立即同步
    function triggerSync():
        // 步骤1:检查可用设备
        if devices.isEmpty():
            showToast("没有可用设备")
            return

        // 步骤2:开始同步
        isSyncing = true
        showProgressIndicator()

        // 步骤3:执行同步
        result = syncService.syncNow()

        // 步骤4:更新状态
        isSyncing = false
        hideProgressIndicator()

        if result.success:
            showToast("同步完成")
            refreshSyncStatus()
        else:
            showToast("同步失败: {result.error}")

    // 强制完全同步
    function forceFullSync():
        // 步骤1:显示确认对话框
        confirmed = showConfirmDialog(
            title: "完全同步",
            message: "这将重新同步所有数据,可能需要较长时间。确定继续?"
        )

        if not confirmed:
            return

        // 步骤2:开始完全同步
        isSyncing = true
        syncProgress = SyncProgress(total: 0, completed: 0)

        // 步骤3:执行完全同步
        syncService.fullSync(
            onProgress: (progress) => {
                syncProgress = progress
                updateProgressDisplay()
            },
            onComplete: (result) => {
                isSyncing = false
                syncProgress = null

                if result.success:
                    showToast("完全同步完成")
                    refreshSyncStatus()
                else:
                    showToast("完全同步失败: {result.error}")
            }
        )
```

---

## 需求：同步统计

系统应显示同步指标和统计信息。

### 场景：显示数据量统计

- **前置条件**: 同步屏幕已打开
- **操作**: 查看同步统计信息
- **预期结果**: 系统应显示已同步的总数据量
- **并且**: 显示每个设备同步的数据

### 场景：显示成功率统计

- **前置条件**: 同步屏幕已打开
- **操作**: 查看同步统计信息
- **预期结果**: 系统应显示成功同步的百分比
- **并且**: 显示失败同步的次数及原因

**实现逻辑**:

```
structure SyncStatistics:
    statistics: SyncStats

    // 渲染同步统计
    function renderStatistics():
        return Card(
            child: Column([
                Text("同步统计", style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold
                )),
                StatItem(
                    label: "总数据量",
                    value: formatBytes(statistics.totalBytes)
                ),
                StatItem(
                    label: "成功率",
                    value: "{statistics.successRate}%"
                ),
                StatItem(
                    label: "失败次数",
                    value: statistics.failureCount.toString(),
                    color: statistics.failureCount > 0 ? Colors.red : Colors.grey
                )
            ])
        )
```

---

## 需求：同步配置

系统应允许用户配置同步首选项。

### 场景：切换自动同步

- **前置条件**: 同步屏幕已打开
- **操作**: 用户切换自动同步设置
- **预期结果**: 系统应启用或禁用自动同步

### 场景：设置同步频率

- **前置条件**: 自动同步已启用
- **操作**: 用户设置同步频率
- **预期结果**: 系统应允许用户设置同步频率(立即、每N分钟等)

**实现逻辑**:

```
structure SyncConfiguration:
    autoSyncEnabled: bool
    syncFrequency: Duration

    // 渲染同步配置
    function renderSyncConfig():
        return Card(
            child: Column([
                SwitchListTile(
                    title: "自动同步",
                    subtitle: "检测到更改时自动同步",
                    value: autoSyncEnabled,
                    onChanged: toggleAutoSync
                ),
                if autoSyncEnabled:
                    ListTile(
                        title: "同步频率",
                        subtitle: formatFrequency(syncFrequency),
                        onTap: showFrequencyPicker
                    )
            ])
        )

    // 切换自动同步
    function toggleAutoSync(enabled):
        autoSyncEnabled = enabled
        syncService.setAutoSync(enabled)
        deviceConfig.saveSyncSettings(autoSyncEnabled, syncFrequency)
```

---

## 需求：冲突解决

系统应显示并帮助解决同步冲突。

### 场景：显示冲突列表

- **前置条件**: 存在同步冲突
- **操作**: 查看冲突部分
- **预期结果**: 系统应显示冲突部分
- **并且**: 列出所有未解决的冲突

### 场景：解决冲突

- **前置条件**: 存在未解决的冲突
- **操作**: 用户点击冲突
- **预期结果**: 系统应显示冲突数据的两个版本
- **并且**: 允许用户选择保留哪个版本

**实现逻辑**:

```
structure ConflictResolution:
    conflicts: List<SyncConflict>

    // 渲染冲突列表
    function renderConflicts():
        if conflicts.isEmpty():
            return EmptyState(
                icon: Icons.check_circle,
                text: "没有冲突"
            )

        return Column([
            Text("未解决的冲突: {conflicts.length}", style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red
            )),
            ListView(
                conflicts.map((conflict) => ConflictListItem(
                    cardTitle: conflict.cardTitle,
                    timestamp: formatTimestamp(conflict.timestamp),
                    devices: conflict.conflictingDevices,
                    onTap: () => showConflictDetails(conflict)
                ))
            )
        ])

    // 显示冲突详情
    function showConflictDetails(conflict):
        showDialog(ConflictResolutionDialog(
            conflict: conflict,
            onResolved: (resolution) => {
                syncService.resolveConflict(conflict.id, resolution)
                refreshConflicts()
            }
        ))
```

---

## 测试覆盖

**测试文件**: `flutter/test/features/sync/sync_screen_test.dart`

**单元测试**:
- `test_show_overall_sync_status()` - 显示总体同步状态
- `test_list_discovered_devices()` - 列出发现的设备
- `test_show_device_status()` - 显示设备状态
- `test_refresh_device_list()` - 刷新设备列表
- `test_display_sync_event_log()` - 显示同步事件日志
- `test_filter_sync_history()` - 过滤同步历史
- `test_trigger_manual_sync()` - 触发手动同步
- `test_force_full_sync()` - 强制完全同步
- `test_show_sync_statistics()` - 显示同步统计
- `test_toggle_auto_sync()` - 切换自动同步
- `test_set_sync_frequency()` - 设置同步频率
- `test_list_conflicts()` - 列出冲突
- `test_show_conflict_details()` - 显示冲突详情

**功能测试**:
- `test_complete_sync_screen_workflow()` - 完整同步屏幕流程
- `test_manual_sync_workflow()` - 手动同步流程
- `test_conflict_resolution_workflow()` - 冲突解决流程

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 所有功能测试通过
- [ ] 设备发现正常工作
- [ ] 手动同步控制可靠
- [ ] 冲突解决清晰明了
- [ ] 代码审查通过
- [ ] 文档已更新
