# 桌面端同步状态指示器规格

**状态**: 活跃
**依赖**: [../../architecture/sync/service.md](../../architecture/sync/service.md), [../../domain/types.md](../../domain/types.md)
**相关测试**: `flutter/test/features/sync_feedback/desktop_sync_indicator_test.dart`

---

## 概述

本规格定义桌面端同步状态指示器 widget，使用 Badge 组件提供同步状态的实时视觉反馈，覆盖四状态状态机、实时更新、视觉一致性与交互响应。

**适用平台**:
- macOS
- Windows
- Linux

**注意**: 移动端平台(Android、iOS、iPadOS)不在应用栏中显示同步状态指示器。移动端用户可以通过设置或设备标签页访问同步信息。

**技术栈**:
- Flutter Badge - 徽章组件
- AnimationController - 动画控制
- StreamBuilder - 状态流订阅

---

## 需求：同步状态机

系统应实现四状态同步状态机。

### 场景：初始状态为尚未同步

- **前置条件**: 应用启动且从未同步过
- **操作**: 初始化同步状态
- **预期结果**: 同步状态为 `notYetSynced`
- **并且**: lastSyncTime 为 null

### 场景：转换到同步中状态

- **前置条件**: 同步状态为 `notYetSynced` 或 `synced` 或 `failed`
- **操作**: 用户触发同步或自动同步启动
- **预期结果**: 同步状态转换为 `syncing`

### 场景：转换到已同步状态

- **前置条件**: 同步状态为 `syncing`
- **操作**: 同步成功完成
- **预期结果**: 同步状态转换为 `synced`
- **并且**: lastSyncTime 设置为当前时间戳

### 场景：转换到失败状态

- **前置条件**: 同步状态为 `syncing`
- **操作**: 同步因错误失败
- **预期结果**: 同步状态转换为 `failed`
- **并且**: errorMessage 被设置

### 场景：从失败状态重试

- **前置条件**: 同步状态为 `failed`
- **操作**: 用户重试同步
- **预期结果**: 同步状态转换为 `syncing`

**实现逻辑**:

```
structure SyncStateMachine:
    currentState: SyncState = NOT_YET_SYNCED
    lastSyncTime: Timestamp?
    errorMessage: String?

    // 状态转换
    function transitionTo(newState, context):
        switch newState:
            case SYNCING:
                currentState = SYNCING
                errorMessage = null

            case SYNCED:
                if currentState == SYNCING:
                    currentState = SYNCED
                    lastSyncTime = now()
                    errorMessage = null

            case FAILED:
                if currentState == SYNCING:
                    currentState = FAILED
                    errorMessage = context.error

            case NOT_YET_SYNCED:
                currentState = NOT_YET_SYNCED
                lastSyncTime = null
                errorMessage = null

    // 获取当前状态
    function getCurrentState():
        return currentState
```

---

## 需求：尚未同步指示器

系统应在应用从未同步时显示尚未同步指示器。

### 场景：显示灰色徽章

- **前置条件**: 同步状态为 `notYetSynced`
- **操作**: 渲染指示器
- **预期结果**: 指示器显示灰色 Badge 组件

### 场景：显示 CloudOff 图标

- **前置条件**: 同步状态为 `notYetSynced`
- **操作**: 渲染指示器
- **预期结果**: Badge 显示 CloudOff 图标

### 场景：显示文本标签

- **前置条件**: 同步状态为 `notYetSynced`
- **操作**: 渲染指示器
- **预期结果**: Badge 显示文本"尚未同步"

### 场景：图标静止

- **前置条件**: 同步状态为 `notYetSynced`
- **操作**: 渲染指示器
- **预期结果**: 图标静止(无动画)

**实现逻辑**:

```
structure NotYetSyncedIndicator:
    // 渲染尚未同步指示器
    function render():
        return Badge(
            backgroundColor: Colors.grey[300],
            child: Row([
                Icon(
                    Icons.cloud_off,
                    size: 16,
                    color: Colors.grey[600]
                ),
                SizedBox(width: 6),
                Text(
                    "尚未同步",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[800]
                    )
                )
            ]),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    offset: Offset(0, 1)
                )
            ]
        )
```

---

## 需求：同步中指示器

系统应在同步进行中时显示同步中指示器。

### 场景：显示次要色徽章

- **前置条件**: 同步状态为 `syncing`
- **操作**: 渲染指示器
- **预期结果**: 指示器显示次要色 Badge 组件

### 场景：显示 RefreshCw 图标

- **前置条件**: 同步状态为 `syncing`
- **操作**: 渲染指示器
- **预期结果**: Badge 显示 RefreshCw 图标

### 场景：显示同步中文本

- **前置条件**: 同步状态为 `syncing`
- **操作**: 渲染指示器
- **预期结果**: Badge 显示文本"同步中..."

### 场景：图标持续旋转

- **前置条件**: 同步状态为 `syncing`
- **操作**: 渲染指示器
- **预期结果**: 图标持续旋转(每 2 秒 360°)

**实现逻辑**:

```
structure SyncingIndicator:
    animationController: AnimationController

    // 初始化动画
    function initAnimation():
        animationController = AnimationController(
            duration: Duration(seconds: 2),
            vsync: this
        )
        animationController.repeat()

    // 渲染同步中指示器
    function render():
        return Badge(
            backgroundColor: Theme.of(context).colorScheme.secondary,
            child: Row([
                RotationTransition(
                    turns: animationController,
                    child: Icon(
                        Icons.refresh,
                        size: 16,
                        color: Colors.white
                    )
                ),
                SizedBox(width: 6),
                Text(
                    "同步中...",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white
                    )
                )
            ]),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    offset: Offset(0, 1)
                )
            ]
        )

    // 清理动画
    function dispose():
        animationController.dispose()
```

---

## 需求：已同步指示器

系统应在同步完成时显示已同步指示器。

### 场景：显示绿色徽章

- **前置条件**: 同步状态为 `synced`
- **操作**: 渲染指示器
- **预期结果**: 指示器显示绿色 Badge 组件

### 场景：显示 CloudCheck 图标

- **前置条件**: 同步状态为 `synced`
- **操作**: 渲染指示器
- **预期结果**: Badge 显示 CloudCheck 图标

### 场景：显示已同步文本

- **前置条件**: 同步状态为 `synced`
- **操作**: 渲染指示器
- **预期结果**: Badge 显示文本"已同步"

### 场景：图标静止

- **前置条件**: 同步状态为 `synced`
- **操作**: 渲染指示器
- **预期结果**: 图标静止(无动画)

### 场景：显示相对时间

- **前置条件**: 同步状态为 `synced`
- **操作**: 渲染指示器
- **预期结果**: 显示相对时间(例如"刚刚"、"5 分钟前")

**实现逻辑**:

```
structure SyncedIndicator:
    lastSyncTime: Timestamp

    // 渲染已同步指示器
    function render():
        relativeTime = formatRelativeTime(lastSyncTime)

        return Badge(
            backgroundColor: Colors.green[600],
            child: Row([
                Icon(
                    Icons.cloud_done,
                    size: 16,
                    color: Colors.white
                ),
                SizedBox(width: 6),
                Text(
                    "已同步",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white
                    )
                ),
                if relativeTime:
                    Text(
                        " ({relativeTime})",
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.8)
                        )
                    )
            ]),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    offset: Offset(0, 1)
                )
            ]
        )

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

## 需求：失败指示器

系统应在同步失败时显示失败指示器。

### 场景：显示红色徽章

- **前置条件**: 同步状态为 `failed`
- **操作**: 渲染指示器
- **预期结果**: 指示器显示红色 Badge 组件

### 场景：显示带警告的 CloudOff 图标

- **前置条件**: 同步状态为 `failed`
- **操作**: 渲染指示器
- **预期结果**: Badge 显示 CloudOff 图标带警告徽章

### 场景：显示失败文本

- **前置条件**: 同步状态为 `failed`
- **操作**: 渲染指示器
- **预期结果**: Badge 显示文本"同步失败"

### 场景：图标静止

- **前置条件**: 同步状态为 `failed`
- **操作**: 渲染指示器
- **预期结果**: 图标静止(无动画)

### 场景：点击显示错误详情

- **前置条件**: 同步状态为 `failed`
- **操作**: 用户点击指示器
- **预期结果**: 显示错误详情和重试按钮

**实现逻辑**:

```
structure FailedIndicator:
    errorMessage: String

    // 渲染失败指示器
    function render():
        return GestureDetector(
            onTap: showErrorDialog,
            child: Badge(
                backgroundColor: Colors.red[600],
                child: Row([
                    Stack([
                        Icon(
                            Icons.cloud_off,
                            size: 16,
                            color: Colors.white
                        ),
                        Positioned(
                            right: 0,
                            top: 0,
                            child: Icon(
                                Icons.warning,
                                size: 8,
                                color: Colors.yellow[700]
                            )
                        )
                    ]),
                    SizedBox(width: 6),
                    Text(
                        "同步失败",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white
                        )
                    )
                ]),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 2,
                        offset: Offset(0, 1)
                    )
                ]
            )
        )

    // 显示错误对话框
    function showErrorDialog():
        showDialog(
            context: context,
            builder: (context) => AlertDialog(
                title: Text("同步失败"),
                content: Text(errorMessage),
                actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("关闭")
                    ),
                    ElevatedButton(
                        onPressed: () => {
                            Navigator.pop(context)
                            retrySync()
                        },
                        child: Text("重试")
                    )
                ]
            )
        )

    // 重试同步
    function retrySync():
        syncService.syncNow()
```

---

## 需求：徽章样式一致性

系统应使用一致的 Badge 组件样式。

### 场景：统一圆角

- **前置条件**: Badge 显示
- **操作**: 渲染徽章
- **预期结果**: 使用圆角(borderRadius: 4)
- **并且**: 有适当的内边距(padding: 8px 12px)
- **并且**: 有微妙的阴影

### 场景：统一图标尺寸

- **前置条件**: Badge 图标显示
- **操作**: 渲染图标
- **预期结果**: 图标大小为 16px
- **并且**: 图标与文本间距为 6px

### 场景：统一文本样式

- **前置条件**: Badge 文本显示
- **操作**: 渲染文本
- **预期结果**: 文本大小为 12px
- **并且**: 文本粗细为中等

**实现逻辑**:

```
structure BadgeStyle:
    // 徽章样式常量
    const BORDER_RADIUS = 4.0
    const PADDING_HORIZONTAL = 12.0
    const PADDING_VERTICAL = 8.0
    const ICON_SIZE = 16.0
    const ICON_TEXT_SPACING = 6.0
    const TEXT_SIZE = 12.0
    const TEXT_WEIGHT = FontWeight.w500

    // 创建徽章容器
    function createBadge(backgroundColor, child):
        return Container(
            padding: EdgeInsets.symmetric(
                horizontal: PADDING_HORIZONTAL,
                vertical: PADDING_VERTICAL
            ),
            decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(BORDER_RADIUS),
                boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 2,
                        offset: Offset(0, 1)
                    )
                ]
            ),
            child: child
        )

    // 创建图标文本行
    function createIconTextRow(icon, text, color):
        return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
                Icon(
                    icon,
                    size: ICON_SIZE,
                    color: color
                ),
                SizedBox(width: ICON_TEXT_SPACING),
                Text(
                    text,
                    style: TextStyle(
                        fontSize: TEXT_SIZE,
                        fontWeight: TEXT_WEIGHT,
                        color: color
                    )
                )
            ]
        )
```

---

## 测试覆盖

**测试文件**: `flutter/test/features/sync_feedback/desktop_sync_indicator_test.dart`

**单元测试**:
- `test_initial_state_not_yet_synced()` - 初始状态为尚未同步
- `test_transition_to_syncing()` - 转换到同步中状态
- `test_transition_to_synced()` - 转换到已同步状态
- `test_transition_to_failed()` - 转换到失败状态
- `test_retry_from_failed()` - 从失败状态重试
- `test_render_not_yet_synced_badge()` - 渲染尚未同步徽章
- `test_render_syncing_badge()` - 渲染同步中徽章
- `test_render_synced_badge()` - 渲染已同步徽章
- `test_render_failed_badge()` - 渲染失败徽章
- `test_syncing_icon_animation()` - 同步中图标动画
- `test_show_relative_time()` - 显示相对时间
- `test_click_failed_shows_error()` - 点击失败显示错误
- `test_badge_style_consistency()` - 徽章样式一致性

**集成测试**:
- `test_complete_sync_state_flow()` - 完整同步状态流程
- `test_error_recovery_workflow()` - 错误恢复流程

**验收标准**:
- [ ] 所有单元测试通过
- [ ] 所有集成测试通过
- [ ] 状态转换正确
- [ ] 动画流畅
- [ ] 样式一致
- [ ] 代码审查通过
- [ ] 文档已更新
