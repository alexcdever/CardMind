# P2P 同步功能规格

**状态**: 生效中
**依赖**: [../../architecture/sync/service.md](../../architecture/sync/service.md), [../../domain/types.md](../../domain/types.md)
**相关测试**: `test/features/p2p_sync_test.dart`

---

## 概述

本规格从用户视角定义 P2P 同步功能，覆盖状态展示、设备管理、手动同步、历史记录与冲突处理。

---

## 需求：查看实时同步状态

系统应向用户提供当前同步状态的实时视觉反馈。

### 场景：查看已同步状态

- **前置条件**: 所有本地更改都已与对等设备同步
- **操作**: 用户查看同步状态指示器
- **预期结果**: 系统应显示带有成功指示的"已同步"状态
- **并且**: 显示上次成功同步的时间戳

### 场景：查看同步中状态

- **前置条件**: 同步正在进行中
- **操作**: 用户查看同步状态指示器
- **预期结果**: 系统应显示带有动画指示的"同步中"状态
- **并且**: 显示正在同步的设备数量

### 场景：查看待同步更改状态

- **前置条件**: 存在尚未同步的本地更改
- **操作**: 用户查看同步状态指示器
- **预期结果**: 系统应显示带有警告指示的"待同步"状态

### 场景：查看同步错误状态

- **前置条件**: 同步遇到错误
- **操作**: 用户查看同步状态指示器
- **预期结果**: 系统应显示带有错误指示的"错误"状态
- **并且**: 提供查看错误详情的选项

### 场景：查看断开连接状态

- **前置条件**: 没有可用于同步的对等设备
- **操作**: 用户查看同步状态指示器
- **预期结果**: 系统应显示"断开连接"状态
- **并且**: 指示没有可用设备

**实现逻辑**:

```
structure SyncStatusDisplay:
    syncStatus: SyncStatus
    lastSyncTime: Timestamp
    connectedDevices: List<Device>

    // 获取当前同步状态
    function getCurrentSyncStatus():
        // 步骤1：查询同步服务
        status = syncService.getStatus()

        // 步骤2：检查连接状态
        if connectedDevices.isEmpty():
            return SyncStatus.DISCONNECTED

        // 步骤3：检查同步状态
        if status.isSyncing:
            return SyncStatus.SYNCING

        if status.hasError:
            return SyncStatus.ERROR

        if status.pendingChanges > 0:
            return SyncStatus.PENDING

        return SyncStatus.SYNCED

    // 渲染同步状态指示器
    function renderStatusIndicator():
        status = getCurrentSyncStatus()

        switch status:
            case SYNCED:
                return StatusIndicator(
                    icon: Icons.check_circle,
                    color: Colors.green,
                    text: "已同步",
                    subtitle: formatTimestamp(lastSyncTime)
                )

            case SYNCING:
                return StatusIndicator(
                    icon: Icons.sync,
                    color: Colors.blue,
                    text: "同步中",
                    subtitle: "正在与 {connectedDevices.length} 台设备同步",
                    animated: true
                )

            case PENDING:
                return StatusIndicator(
                    icon: Icons.warning,
                    color: Colors.orange,
                    text: "待同步",
                    subtitle: "{status.pendingChanges} 个更改待同步"
                )

            case ERROR:
                return StatusIndicator(
                    icon: Icons.error,
                    color: Colors.red,
                    text: "错误",
                    subtitle: "点击查看详情",
                    onTap: showErrorDetails
                )

            case DISCONNECTED:
                return StatusIndicator(
                    icon: Icons.cloud_off,
                    color: Colors.grey,
                    text: "断开连接",
                    subtitle: "没有可用设备"
                )
```

---

## 需求：查看详细同步信息

系统应允许用户访问全面的同步信息，包括设备列表、同步历史和统计信息。

### 场景：打开同步详情

- **前置条件**: 用户正在查看同步状态指示器
- **操作**: 用户点击同步状态指示器
- **预期结果**: 系统应显示详细的同步信息视图
- **并且**: 显示当前同步状态和描述

### 场景：查看已连接设备

- **前置条件**: 同步详情视图已打开
- **操作**: 用户查看设备列表部分
- **预期结果**: 系统应显示所有发现的对等设备
- **并且**: 指示每个设备的在线/离线状态
- **并且**: 显示设备类型（手机、笔记本、平板）
- **并且**: 显示离线设备的上次可见时间戳

### 场景：查看同步统计信息

- **前置条件**: 同步详情视图已打开
- **操作**: 用户查看统计信息部分
- **预期结果**: 系统应显示已同步卡片的总数
- **并且**: 显示同步的总数据大小
- **并且**: 显示同步成功率
- **并且**: 显示失败同步的次数及原因

### 场景：查看同步历史

- **前置条件**: 同步详情视图已打开
- **操作**: 用户查看同步历史部分
- **预期结果**: 系统应显示带有时间戳的最近同步事件
- **并且**: 指示每个事件的成功或失败
- **并且**: 显示每次同步涉及的设备

### 场景：过滤同步历史

- **前置条件**: 同步历史已显示
- **操作**: 用户应用历史过滤器
- **预期结果**: 系统应按设备、状态或时间范围过滤事件

**实现逻辑**:

```
structure SyncDetailsView:
    devices: List<Device>
    statistics: SyncStatistics
    history: List<SyncEvent>

    // 打开同步详情
    function openSyncDetails():
        // 步骤1：加载设备列表
        devices = syncService.getDiscoveredDevices()

        // 步骤2：加载统计信息
        statistics = syncService.getStatistics()

        // 步骤3：加载同步历史
        history = syncService.getHistory(limit: 50)

        // 步骤4：显示详情视图
        showDialog(SyncDetailsDialog(
            devices: devices,
            statistics: statistics,
            history: history
        ))

    // 渲染设备列表
    function renderDeviceList():
        return Column(
            devices.map((device) => DeviceListItem(
                name: device.name,
                type: device.type,
                status: device.isOnline ? "在线" : "离线",
                lastSeen: device.isOnline ? null : formatTimestamp(device.lastSeen),
                icon: getDeviceIcon(device.type),
                statusColor: device.isOnline ? Colors.green : Colors.grey
            ))
        )

    // 渲染统计信息
    function renderStatistics():
        return StatisticsPanel(
            items: [
                StatItem(
                    label: "已同步卡片",
                    value: statistics.totalCards.toString()
                ),
                StatItem(
                    label: "同步数据量",
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
            ]
        )

    // 渲染同步历史
    function renderHistory(filter):
        filteredHistory = applyFilter(history, filter)

        return ListView(
            filteredHistory.map((event) => HistoryListItem(
                timestamp: formatTimestamp(event.timestamp),
                status: event.success ? "成功" : "失败",
                device: event.deviceName,
                details: event.details,
                icon: event.success ? Icons.check : Icons.error,
                color: event.success ? Colors.green : Colors.red
            ))
        )

    // 应用过滤器
    function applyFilter(history, filter):
        filtered = history

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

## 需求：手动触发同步

系统应允许用户手动启动与可用对等设备的同步。

### 场景：触发手动同步

- **前置条件**: 至少有一个对等设备可用
- **操作**: 用户点击"立即同步"按钮
- **预期结果**: 系统应立即尝试与可用设备同步
- **并且**: 显示同步进度指示器
- **并且**: 同步完成时更新状态

### 场景：无可用设备时触发手动同步

- **前置条件**: 没有可用的对等设备
- **操作**: 用户点击"立即同步"按钮
- **预期结果**: 系统应显示错误消息，指示没有可用设备
- **并且**: 建议发现设备的操作

### 场景：强制完全同步

- **前置条件**: 用户想要执行完全重新同步
- **操作**: 用户触发"完全同步"操作
- **预期结果**: 系统应执行所有数据的完全重新同步
- **并且**: 显示详细的进度信息

### 场景：刷新设备列表

- **前置条件**: 用户想要发现新设备
- **操作**: 用户点击"刷新设备"按钮
- **预期结果**: 系统应重新扫描可用的对等设备
- **并且**: 更新设备列表显示

**实现逻辑**:

```
structure ManualSync:
    isSyncing: bool = false
    syncProgress: SyncProgress?

    // 触发手动同步
    function triggerManualSync():
        // 步骤1：检查可用设备
        devices = syncService.getAvailableDevices()

        if devices.isEmpty():
            showToast("没有可用设备，请先发现设备")
            return

        // 步骤2：开始同步
        isSyncing = true
        showProgressIndicator()

        // 步骤3：执行同步
        result = syncService.syncNow(devices)

        // 步骤4：处理结果
        isSyncing = false
        hideProgressIndicator()

        if result.success:
            showToast("同步完成")
            updateSyncStatus()
        else:
            showToast("同步失败：{result.error}")

    // 强制完全同步
    function forceFullSync():
        // 步骤1：显示确认对话框
        confirmed = showConfirmDialog(
            title: "完全同步",
            message: "这将重新同步所有数据，可能需要较长时间。确定继续？"
        )

        if not confirmed:
            return

        // 步骤2：开始完全同步
        isSyncing = true
        syncProgress = SyncProgress(
            total: 0,
            completed: 0,
            phase: "准备中"
        )

        // 步骤3：执行完全同步
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
                else:
                    showToast("完全同步失败：{result.error}")
            }
        )

    // 刷新设备列表
    function refreshDevices():
        // 步骤1：显示刷新指示器
        showRefreshIndicator()

        // 步骤2：重新扫描设备
        devices = syncService.discoverDevices()

        // 步骤3：更新设备列表
        updateDeviceList(devices)

        // 步骤4：隐藏刷新指示器
        hideRefreshIndicator()

        // 步骤5：显示结果
        showToast("发现 {devices.length} 台设备")
```

---

## 需求：重试失败的同步

系统应允许用户在失败后重试同步。

### 场景：错误后重试同步

- **前置条件**: 同步因错误而失败
- **操作**: 用户点击错误详情中的"重试"按钮
- **预期结果**: 系统应尝试重新启动同步
- **并且**: 清除之前的错误状态
- **并且**: 显示同步中状态

**实现逻辑**:

```
structure SyncRetry:
    lastError: SyncError?

    // 重试失败的同步
    function retrySync():
        // 步骤1：清除错误状态
        lastError = null
        updateSyncStatus(SyncStatus.SYNCING)

        // 步骤2：重新尝试同步
        result = syncService.retry()

        // 步骤3：处理结果
        if result.success:
            updateSyncStatus(SyncStatus.SYNCED)
            showToast("同步成功")
        else:
            lastError = result.error
            updateSyncStatus(SyncStatus.ERROR)
            showToast("同步失败：{result.error.message}")

    // 显示错误详情
    function showErrorDetails():
        if lastError:
            showDialog(ErrorDetailsDialog(
                error: lastError,
                onRetry: retrySync
            ))
```

---

## 需求：配置同步设置

系统应允许用户配置同步首选项和行为。

### 场景：启用自动同步

- **前置条件**: 自动同步当前已禁用
- **操作**: 用户启用自动同步设置
- **预期结果**: 系统应在检测到更改时自动同步
- **并且**: 显示确认消息

### 场景：禁用自动同步

- **前置条件**: 自动同步当前已启用
- **操作**: 用户禁用自动同步设置
- **预期结果**: 系统应停止自动同步
- **并且**: 需要手动触发同步
- **并且**: 显示确认消息

### 场景：设置同步频率

- **前置条件**: 自动同步已启用
- **操作**: 用户将同步频率设置为特定间隔
- **预期结果**: 系统应按指定频率同步
- **并且**: 在设置中显示配置的频率

**实现逻辑**:

```
structure SyncSettings:
    autoSyncEnabled: bool
    syncFrequency: Duration

    // 启用自动同步
    function enableAutoSync():
        // 步骤1：更新设置
        autoSyncEnabled = true
        saveSettings()

        // 步骤2：启动自动同步服务
        syncService.enableAutoSync()

        // 步骤3：显示确认
        showToast("自动同步已启用")

    // 禁用自动同步
    function disableAutoSync():
        // 步骤1：更新设置
        autoSyncEnabled = false
        saveSettings()

        // 步骤2：停止自动同步服务
        syncService.disableAutoSync()

        // 步骤3：显示确认
        showToast("自动同步已禁用，需要手动触发同步")

    // 设置同步频率
    function setSyncFrequency(frequency):
        // 步骤1：验证频率
        if frequency < 60:
            showToast("同步频率不能小于60秒")
            return

        // 步骤2：更新设置
        syncFrequency = frequency
        saveSettings()

        // 步骤3：更新同步服务
        if autoSyncEnabled:
            syncService.setSyncInterval(frequency)

        // 步骤4：显示确认
        showToast("同步频率已设置为 {frequency} 秒")

    // 保存设置
    function saveSettings():
        settings = SyncSettings(
            autoSyncEnabled: autoSyncEnabled,
            syncFrequency: syncFrequency
        )

        deviceConfig.saveSyncSettings(settings)
```

---

## 需求：查看和解决同步冲突

系统应显示同步冲突并帮助用户解决它们。

### 场景：查看冲突列表

- **前置条件**: 存在同步冲突
- **操作**: 用户查看同步详情
- **预期结果**: 系统应显示冲突部分
- **并且**: 列出所有未解决的冲突
- **并且**: 指示冲突数量

**实现逻辑**:

```
structure ConflictResolution:
    conflicts: List<SyncConflict>

    // 获取冲突列表
    function getConflicts():
        // 步骤1：查询同步服务
        conflicts = syncService.getConflicts()

        // 步骤2：按时间排序
        conflicts.sortBy((c) => c.timestamp, descending: true)

        return conflicts

    // 渲染冲突列表
    function renderConflictList():
        conflicts = getConflicts()

        if conflicts.isEmpty():
            return EmptyState(
                icon: Icons.check_circle,
                text: "没有冲突"
            )

        return Column([
            Text("未解决的冲突：{conflicts.length}"),
            ListView(
                conflicts.map((conflict) => ConflictListItem(
                    cardTitle: conflict.cardTitle,
                    timestamp: formatTimestamp(conflict.timestamp),
                    devices: conflict.conflictingDevices,
                    onResolve: () => resolveConflict(conflict)
                ))
            )
        ])

    // 解决冲突
    function resolveConflict(conflict):
        // 显示冲突解决对话框
        showDialog(ConflictResolutionDialog(
            conflict: conflict,
            onResolved: (resolution) => {
                syncService.resolveConflict(conflict.id, resolution)
                updateConflictList()
            }
        ))
```

---

## 相关文档

**相关规格**:
- [../../architecture/sync/service.md](../../architecture/sync/service.md) - 同步服务
- [../../domain/types.md](../../domain/types.md) - 类型定义
- [../../architecture/sync/conflict_resolution.md](../../architecture/sync/conflict_resolution.md) - 冲突解决

---

## 测试覆盖

**测试文件**: `test/features/p2p_sync_test.dart`

**单元测试**:
- `test_view_synced_status()` - 查看已同步状态
- `test_view_syncing_status()` - 查看同步中状态
- `test_view_pending_status()` - 查看待同步状态
- `test_view_error_status()` - 查看错误状态
- `test_view_disconnected_status()` - 查看断开连接状态
- `test_open_sync_details()` - 打开同步详情
- `test_view_connected_devices()` - 查看已连接设备
- `test_view_sync_statistics()` - 查看同步统计信息
- `test_view_sync_history()` - 查看同步历史
- `test_filter_sync_history()` - 过滤同步历史
- `test_trigger_manual_sync()` - 触发手动同步
- `test_manual_sync_no_devices()` - 无设备时手动同步
- `test_force_full_sync()` - 强制完全同步
- `test_refresh_device_list()` - 刷新设备列表
- `test_retry_failed_sync()` - 重试失败同步
- `test_enable_auto_sync()` - 启用自动同步
- `test_disable_auto_sync()` - 禁用自动同步
- `test_set_sync_frequency()` - 设置同步频率
- `test_view_conflict_list()` - 查看冲突列表

**功能测试**:
- `test_sync_status_updates_in_realtime()` - 同步状态实时更新
- `test_device_list_updates_automatically()` - 设备列表自动更新
- `test_sync_history_records_all_events()` - 同步历史记录所有事件

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 所有功能测试通过
- [ ] 同步状态显示在所有平台上正常工作
- [ ] 同步详情视图在所有平台上正常工作
- [ ] 手动同步在所有平台上正常工作
- [ ] 同步设置在所有平台上正常工作
- [ ] 冲突解决在所有平台上正常工作
- [ ] 代码审查通过
- [ ] 文档已更新
