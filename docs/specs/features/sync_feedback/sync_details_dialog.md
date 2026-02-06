# 同步详情对话框规格

**状态**: 活跃
**依赖**: [../../architecture/sync/service.md](../../architecture/sync/service.md), [../../domain/types.md](../../domain/types.md)
**相关测试**: `test/feature/widgets/sync_details_dialog/sync_details_dialog_widget_feature_test.dart`

---

## 概述

本规格定义同步详情对话框，提供全面的同步信息，包括设备列表、同步历史和配置，确保显示详细信息、支持手动同步，并提供明确的对话框交互。

**适用平台**:
- iOS
- Android
- macOS
- Windows
- Linux

**技术栈**:
- Flutter Dialog - 对话框
- ListView - 列表展示
- Provider/Riverpod - 状态管理

---

## 需求：显示设备列表

系统应显示所有发现的对等设备列表。

### 场景：显示发现的设备

- **前置条件**: 同步详情对话框已打开
- **操作**: 查看设备列表
- **预期结果**: 系统应显示所有发现的对等设备
- **并且**: 指示当前连接的设备
- **并且**: 显示每个设备的上次可见时间戳

### 场景：显示同步统计信息

- **前置条件**: 同步详情对话框已打开
- **操作**: 查看统计信息
- **预期结果**: 系统应显示已同步卡片的总数
- **并且**: 显示同步的总数据大小
- **并且**: 显示同步会话统计信息(成功/失败)

**实现逻辑**:

```
structure SyncDetailsDialog:
    devices: List<Device>
    statistics: SyncStatistics

    // 渲染设备列表
    function renderDeviceList():
        return Column([
            Text("已发现设备", style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold
            )),
            ListView(
                devices.map((device) => DeviceListItem(
                    name: device.name,
                    type: device.type,
                    isConnected: device.isConnected,
                    lastSeen: formatTimestamp(device.lastSeen),
                    icon: getDeviceIcon(device.type),
                    statusColor: device.isConnected ? Colors.green : Colors.grey
                ))
            )
        ])

    // 渲染统计信息
    function renderStatistics():
        return Card(
            child: Column([
                StatItem(
                    label: "已同步卡片",
                    value: statistics.totalCards.toString()
                ),
                StatItem(
                    label: "数据大小",
                    value: formatBytes(statistics.totalBytes)
                ),
                StatItem(
                    label: "成功同步",
                    value: statistics.successCount.toString()
                ),
                StatItem(
                    label: "失败同步",
                    value: statistics.failureCount.toString(),
                    color: statistics.failureCount > 0 ? Colors.red : Colors.grey
                )
            ])
        )
```

---

## 需求：显示同步历史

系统应显示最近同步事件的时间顺序列表。

### 场景：显示同步事件日志

- **前置条件**: 同步详情对话框已打开
- **操作**: 查看同步历史
- **预期结果**: 系统应列出带有时间戳的最近同步事件
- **并且**: 指示每个事件的成功或失败状态
- **并且**: 显示每个同步事件涉及的设备

### 场景：高亮冲突事件

- **前置条件**: 发生同步冲突
- **操作**: 查看同步历史
- **预期结果**: 系统应在历史中突出显示冲突事件
- **并且**: 提供有关如何解决冲突的详细信息

**实现逻辑**:

```
structure SyncHistory:
    events: List<SyncEvent>

    // 渲染同步历史
    function renderSyncHistory():
        return Column([
            Text("同步历史", style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold
            )),
            ListView(
                events.map((event) => SyncEventItem(
                    timestamp: formatTimestamp(event.timestamp),
                    status: event.success ? "成功" : "失败",
                    device: event.deviceName,
                    details: event.details,
                    icon: event.success ? Icons.check : Icons.error,
                    color: event.success ? Colors.green : Colors.red,
                    isConflict: event.hasConflict,
                    onTap: event.hasConflict ? () => showConflictDetails(event) : null
                ))
            )
        ])

    // 显示冲突详情
    function showConflictDetails(event):
        showDialog(ConflictDetailsDialog(
            event: event,
            onResolve: (resolution) => {
                syncService.resolveConflict(event.conflictId, resolution)
                refreshHistory()
            }
        ))
```

---

## 需求：手动同步操作

系统应允许用户手动触发同步操作。

### 场景：触发立即同步

- **前置条件**: 同步详情对话框已打开
- **操作**: 用户点击"立即同步"按钮
- **预期结果**: 系统应立即尝试与可用对等点同步
- **并且**: 实时更新同步状态

### 场景：刷新设备列表

- **前置条件**: 同步详情对话框已打开
- **操作**: 用户点击"刷新设备"按钮
- **预期结果**: 系统应重新扫描可用的对等设备
- **并且**: 更新设备列表显示

**实现逻辑**:

```
structure ManualSyncActions:
    isSyncing: bool = false

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
            refreshHistory()
        else:
            showToast("同步失败: {result.error}")

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

## 需求：显示同步配置

系统应显示当前的同步配置设置。

### 场景：显示自动同步状态

- **前置条件**: 同步详情对话框已打开
- **操作**: 查看同步配置
- **预期结果**: 系统应指示自动同步是启用还是禁用

### 场景：显示协议信息

- **前置条件**: 同步详情对话框已打开
- **操作**: 查看同步配置
- **预期结果**: 系统应显示当前同步协议版本
- **并且**: 显示网络配置(WiFi、蓝牙等)

**实现逻辑**:

```
structure SyncConfiguration:
    config: SyncConfig

    // 渲染同步配置
    function renderSyncConfig():
        return Card(
            child: Column([
                ConfigItem(
                    label: "自动同步",
                    value: config.autoSyncEnabled ? "已启用" : "已禁用",
                    icon: config.autoSyncEnabled ? Icons.check : Icons.close
                ),
                ConfigItem(
                    label: "协议版本",
                    value: config.protocolVersion
                ),
                ConfigItem(
                    label: "网络配置",
                    value: formatNetworkConfig(config.networkConfig)
                )
            ])
        )

    // 格式化网络配置
    function formatNetworkConfig(networkConfig):
        enabled = []
        if networkConfig.wifiEnabled:
            enabled.add("WiFi")
        if networkConfig.bluetoothEnabled:
            enabled.add("蓝牙")
        return enabled.join(", ")
```

---

## 需求：对话框操作

系统应提供明确的操作来关闭对话框。

### 场景：关闭对话框

- **前置条件**: 同步详情对话框已打开
- **操作**: 用户点击对话框外部或按下关闭按钮
- **预期结果**: 系统应关闭对话框
- **并且**: 返回到上一个屏幕

**实现逻辑**:

```
structure DialogActions:
    // 渲染对话框
    function render():
        return Dialog(
            child: Column([
                // 标题栏
                AppBar(
                    title: Text("同步详情"),
                    actions: [
                        IconButton(
                            icon: Icons.close,
                            onPressed: closeDialog
                        )
                    ]
                ),

                // 内容区域
                Expanded(
                    child: SingleChildScrollView(
                        child: Column([
                            renderStatistics(),
                            Divider(),
                            renderDeviceList(),
                            Divider(),
                            renderSyncHistory(),
                            Divider(),
                            renderSyncConfig()
                        ])
                    )
                ),

                // 操作按钮
                ButtonBar(
                    children: [
                        TextButton(
                            text: "刷新设备",
                            onPressed: refreshDevices
                        ),
                        ElevatedButton(
                            text: "立即同步",
                            onPressed: triggerSync
                        )
                    ]
                )
            ])
        )

    // 关闭对话框
    function closeDialog():
        navigator.pop()
```

---

## 测试覆盖

**测试文件**: `test/feature/widgets/sync_details_dialog/sync_details_dialog_widget_feature_test.dart`

**单元测试**:
- `test_show_discovered_devices()` - 显示发现的设备
- `test_indicate_connected_devices()` - 指示连接状态
- `test_show_last_seen_timestamps()` - 显示上次可见时间
- `test_show_sync_statistics()` - 显示同步统计
- `test_show_sync_event_log()` - 显示同步事件日志
- `test_highlight_conflicts()` - 高亮冲突事件
- `test_trigger_manual_sync()` - 触发手动同步
- `test_refresh_device_list()` - 刷新设备列表
- `test_show_auto_sync_status()` - 显示自动同步状态
- `test_show_protocol_info()` - 显示协议信息
- `test_close_dialog()` - 关闭对话框

**功能测试**:
- `test_complete_sync_details_workflow()` - 完整同步详情流程
- `test_manual_sync_from_dialog()` - 从对话框手动同步

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 所有功能测试通过
- [ ] 设备列表正确显示
- [ ] 同步历史准确记录
- [ ] 手动同步操作正常
- [ ] 对话框交互流畅
- [ ] 代码审查通过
- [ ] 文档已更新
