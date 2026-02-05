# 同步反馈交互规格(共享)

**状态**: 活跃
**依赖**: [../../architecture/sync/service.md](../../architecture/sync/service.md), [../../domain/types.md](../../domain/types.md)
**相关测试**: `flutter/test/features/sync_feedback/shared_sync_indicator_test.dart`

---

## 概述

本规格定义 CardMind 的同步反馈交互需求，提供跨平台的同步状态可视化，确保实时状态展示、四状态状态机、状态流订阅机制与清晰的交互反馈。

**适用平台**:
- iOS
- Android
- macOS
- Windows
- Linux

**技术栈**:
- Flutter StreamBuilder - 状态流订阅
- Provider/Riverpod - 状态管理
- AnimationController - 动画控制

---

## 需求：应用栏同步状态指示器

系统应在应用栏中显示同步状态指示器，显示当前同步状态。

### 场景：指示器在应用栏中可见

- **前置条件**: 用户在主屏幕上
- **操作**: 渲染主屏幕
- **预期结果**: 同步状态指示器在应用栏右侧可见

### 场景：指示器实时更新

- **前置条件**: 同步状态改变
- **操作**: 同步服务发出状态更新
- **预期结果**: 指示器在 500ms 内更新

### 场景：指示器订阅状态流

- **前置条件**: 主屏幕加载
- **操作**: 初始化同步指示器
- **预期结果**: 系统订阅 `SyncApi.statusStream`

### 场景：销毁时取消订阅

- **前置条件**: 主屏幕销毁
- **操作**: 清理资源
- **预期结果**: 系统取消订阅状态流

**实现逻辑**:

```
structure SyncStatusIndicator:
    statusSubscription: StreamSubscription?
    currentStatus: SyncStatus = DISCONNECTED

    // 初始化指示器
    function init():
        // 步骤1:订阅状态流
        statusSubscription = SyncApi.statusStream.listen(
            onData: (status) => {
                currentStatus = status
                updateUI()
            }
        )

        // 步骤2:获取初始状态
        currentStatus = SyncApi.getCurrentStatus()

    // 渲染指示器
    function render():
        return Positioned(
            right: 16,
            child: StreamBuilder<SyncStatus>(
                stream: SyncApi.statusStream,
                initialData: currentStatus,
                builder: (context, snapshot) => {
                    if not snapshot.hasData:
                        return SizedBox.shrink()

                    return renderStatusBadge(snapshot.data)
                }
            )
        )

    // 清理资源
    function dispose():
        statusSubscription?.cancel()
        statusSubscription = null
```

---

## 需求：同步状态机

系统应实现四状态同步状态机。

### 场景：初始状态为断开连接

- **前置条件**: 应用启动且无对等设备
- **操作**: 初始化同步服务
- **预期结果**: 同步状态为 `disconnected`

### 场景：从断开连接转换到同步中

- **前置条件**: 同步状态为 `disconnected`
- **操作**: 系统发现对等设备并开始同步
- **预期结果**: 同步状态转换为 `syncing`

### 场景：从同步中转换到已同步

- **前置条件**: 同步状态为 `syncing`
- **操作**: 同步成功完成
- **预期结果**: 同步状态转换为 `synced`

### 场景：从同步中转换到失败

- **前置条件**: 同步状态为 `syncing`
- **操作**: 同步因错误失败
- **预期结果**: 同步状态转换为 `failed`

### 场景：从已同步转换到同步中

- **前置条件**: 同步状态为 `synced`
- **操作**: 检测到新更改
- **预期结果**: 同步状态转换为 `syncing`

### 场景：从失败转换到同步中

- **前置条件**: 同步状态为 `failed`
- **操作**: 用户重试同步
- **预期结果**: 同步状态转换为 `syncing`

**实现逻辑**:

```
structure SyncStateMachine:
    currentState: SyncState = DISCONNECTED
    stateController: StreamController<SyncState>

    // 状态转换
    function transitionTo(newState, context):
        oldState = currentState

        switch newState:
            case DISCONNECTED:
                currentState = DISCONNECTED

            case SYNCING:
                if oldState in [DISCONNECTED, SYNCED, FAILED]:
                    currentState = SYNCING

            case SYNCED:
                if oldState == SYNCING:
                    currentState = SYNCED

            case FAILED:
                if oldState == SYNCING:
                    currentState = FAILED

        // 发出状态更新
        if currentState != oldState:
            stateController.add(currentState)

    // 获取状态流
    function getStatusStream():
        return stateController.stream
```

---

## 需求：断开连接状态

系统应在无可用对等设备时显示断开指示器。

### 场景：断开连接显示 cloud_off 图标

- **前置条件**: 同步状态为 `disconnected`
- **操作**: 渲染指示器
- **预期结果**: 指示器显示 `Icons.cloud_off`

### 场景：断开连接图标为灰色

- **前置条件**: 同步状态为 `disconnected`
- **操作**: 渲染指示器
- **预期结果**: 图标颜色为灰色(#757575)

### 场景：断开连接显示文本

- **前置条件**: 同步状态为 `disconnected`
- **操作**: 渲染指示器
- **预期结果**: 指示器显示文本"未同步"

### 场景：断开连接无动画

- **前置条件**: 同步状态为 `disconnected`
- **操作**: 渲染指示器
- **预期结果**: 图标静止(无动画)

**实现逻辑**:

```
structure DisconnectedIndicator:
    // 渲染断开连接指示器
    function render():
        return Row([
            Icon(
                Icons.cloud_off,
                size: 20,
                color: Color(0xFF757575)
            ),
            SizedBox(width: 8),
            Text(
                "未同步",
                style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF757575)
                )
            )
        ])
```

---

## 需求：同步中状态

系统应在同步进行中时显示同步中指示器。

### 场景：同步中显示同步图标

- **前置条件**: 同步状态为 `syncing`
- **操作**: 渲染指示器
- **预期结果**: 指示器显示 `Icons.sync`

### 场景：同步中图标为主色

- **前置条件**: 同步状态为 `syncing`
- **操作**: 渲染指示器
- **预期结果**: 图标颜色为主色(#00897B)

### 场景：同步中显示文本

- **前置条件**: 同步状态为 `syncing`
- **操作**: 渲染指示器
- **预期结果**: 指示器显示文本"同步中..."

### 场景：同步中图标旋转

- **前置条件**: 同步状态为 `syncing`
- **操作**: 渲染指示器
- **预期结果**: 图标持续旋转(每 2 秒 360°)

### 场景：同步中显示对等设备数量

- **前置条件**: 同步状态为 `syncing` 且有 N 台对等设备
- **操作**: 渲染指示器
- **预期结果**: 指示器显示"同步中(N 台设备)"

**实现逻辑**:

```
structure SyncingIndicator:
    animationController: AnimationController
    peerCount: int

    // 初始化动画
    function init():
        animationController = AnimationController(
            duration: Duration(seconds: 2),
            vsync: this
        )
        animationController.repeat()

    // 渲染同步中指示器
    function render():
        text = peerCount > 0 ? "同步中({peerCount} 台设备)" : "同步中..."

        return Row([
            RotationTransition(
                turns: animationController,
                child: Icon(
                    Icons.sync,
                    size: 20,
                    color: Color(0xFF00897B)
                )
            ),
            SizedBox(width: 8),
            Text(
                text,
                style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF00897B)
                )
            )
        ])

    // 清理动画
    function dispose():
        animationController.dispose()
```

---

## 需求：已同步状态

系统应在同步完成时显示已同步指示器。

### 场景：已同步显示 cloud_done 图标

- **前置条件**: 同步状态为 `synced`
- **操作**: 渲染指示器
- **预期结果**: 指示器显示 `Icons.cloud_done`

### 场景：已同步图标为绿色

- **前置条件**: 同步状态为 `synced`
- **操作**: 渲染指示器
- **预期结果**: 图标颜色为绿色(#43A047)

### 场景：已同步显示文本

- **前置条件**: 同步状态为 `synced`
- **操作**: 渲染指示器
- **预期结果**: 指示器显示文本"已同步"

### 场景：已同步无动画

- **前置条件**: 同步状态为 `synced`
- **操作**: 渲染指示器
- **预期结果**: 图标静止(无动画)

### 场景：已同步显示上次同步时间

- **前置条件**: 同步状态为 `synced`
- **操作**: 渲染指示器
- **预期结果**: 指示器显示"已同步(刚刚)"或相对时间

**实现逻辑**:

```
structure SyncedIndicator:
    lastSyncTime: Timestamp

    // 渲染已同步指示器
    function render():
        relativeTime = formatRelativeTime(lastSyncTime)
        text = "已同步({relativeTime})"

        return Row([
            Icon(
                Icons.cloud_done,
                size: 20,
                color: Color(0xFF43A047)
            ),
            SizedBox(width: 8),
            Text(
                text,
                style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF43A047)
                )
            )
        ])

    // 格式化相对时间
    function formatRelativeTime(timestamp):
        now = DateTime.now()
        diff = now.difference(timestamp)

        if diff.inSeconds < 60:
            return "刚刚"
        else if diff.inMinutes < 60:
            return "{diff.inMinutes} 分钟前"
        else if diff.inHours < 24:
            return "{diff.inHours} 小时前"
        else:
            return "{diff.inDays} 天前"
```

---

## 需求：失败状态

系统应在同步失败时显示失败指示器。

### 场景：失败显示带警告的 cloud_off 图标

- **前置条件**: 同步状态为 `failed`
- **操作**: 渲染指示器
- **预期结果**: 指示器显示带警告徽章的 `Icons.cloud_off`

### 场景：失败图标为橙色

- **前置条件**: 同步状态为 `failed`
- **操作**: 渲染指示器
- **预期结果**: 图标颜色为橙色(#FB8C00)

### 场景：失败显示文本

- **前置条件**: 同步状态为 `failed`
- **操作**: 渲染指示器
- **预期结果**: 指示器显示文本"同步失败"

### 场景：失败无动画

- **前置条件**: 同步状态为 `failed`
- **操作**: 渲染指示器
- **预期结果**: 图标静止(无动画)

**实现逻辑**:

```
structure FailedIndicator:
    errorMessage: String

    // 渲染失败指示器
    function render():
        return Row([
            Stack([
                Icon(
                    Icons.cloud_off,
                    size: 20,
                    color: Color(0xFFFB8C00)
                ),
                Positioned(
                    right: 0,
                    top: 0,
                    child: Icon(
                        Icons.warning,
                        size: 10,
                        color: Colors.red
                    )
                )
            ]),
            SizedBox(width: 8),
            Text(
                "同步失败",
                style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFFFB8C00)
                )
            )
        ])
```

---

## 需求：指示器点击处理

系统应处理同步状态指示器的点击。

### 场景：点击打开同步详情

- **前置条件**: 用户在主屏幕上
- **操作**: 用户点击同步状态指示器
- **预期结果**: 系统应导航到同步详情屏幕

### 场景：点击失败状态显示重试

- **前置条件**: 同步状态为 `failed`
- **操作**: 用户点击指示器
- **预期结果**: 系统应显示重试选项

**实现逻辑**:

```
structure IndicatorClickHandler:
    currentStatus: SyncStatus

    // 处理点击
    function handleClick():
        switch currentStatus:
            case DISCONNECTED:
                navigateToSyncDetails()

            case SYNCING:
                navigateToSyncDetails()

            case SYNCED:
                navigateToSyncDetails()

            case FAILED:
                showRetryDialog()

    // 导航到同步详情
    function navigateToSyncDetails():
        navigator.push(SyncDetailsScreen())

    // 显示重试对话框
    function showRetryDialog():
        showDialog(
            context: context,
            builder: (context) => AlertDialog(
                title: Text("同步失败"),
                content: Text("是否重试同步?"),
                actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("取消")
                    ),
                    ElevatedButton(
                        onPressed: () => {
                            Navigator.pop(context)
                            syncService.retrySync()
                        },
                        child: Text("重试")
                    )
                ]
            )
        )
```

---

## 测试覆盖

**测试文件**: `flutter/test/features/sync_feedback/shared_sync_indicator_test.dart`

**单元测试**:
- `test_indicator_visible_in_appbar()` - 指示器在应用栏中可见
- `test_indicator_updates_realtime()` - 指示器实时更新
- `test_subscribe_to_status_stream()` - 订阅状态流
- `test_unsubscribe_on_dispose()` - 销毁时取消订阅
- `test_initial_state_disconnected()` - 初始状态为断开连接
- `test_transition_disconnected_to_syncing()` - 从断开连接转换到同步中
- `test_transition_syncing_to_synced()` - 从同步中转换到已同步
- `test_transition_syncing_to_failed()` - 从同步中转换到失败
- `test_transition_synced_to_syncing()` - 从已同步转换到同步中
- `test_transition_failed_to_syncing()` - 从失败转换到同步中
- `test_render_disconnected_indicator()` - 渲染断开连接指示器
- `test_render_syncing_indicator()` - 渲染同步中指示器
- `test_render_synced_indicator()` - 渲染已同步指示器
- `test_render_failed_indicator()` - 渲染失败指示器
- `test_syncing_icon_animation()` - 同步中图标动画
- `test_show_peer_count()` - 显示对等设备数量
- `test_show_relative_time()` - 显示相对时间
- `test_click_opens_sync_details()` - 点击打开同步详情
- `test_click_failed_shows_retry()` - 点击失败显示重试

**功能测试**:
- `test_complete_sync_state_flow()` - 完整同步状态流程
- `test_indicator_interaction_workflow()` - 指示器交互流程

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 所有功能测试通过
- [ ] 状态转换正确
- [ ] 实时更新及时
- [ ] 动画流畅
- [ ] 交互响应正常
- [ ] 代码审查通过
- [ ] 文档已更新
