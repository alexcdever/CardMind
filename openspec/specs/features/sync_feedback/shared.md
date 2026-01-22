# Sync Feedback Interaction Specification (Shared)
# 同步反馈交互规格（通用）

**Version** | **版本**: 1.0.0
**Status** | **状态**: Active | 已完成
**Dependencies** | **依赖**: [sync_protocol.md](../../domain/sync_protocol.md), [home_screen/shared.md](../home_screen/shared.md)

---

## 1. Overview | 概述

This specification defines the sync feedback interaction requirements for CardMind.

本规格定义 CardMind 的同步反馈交互需求。

---

## 2. Sync Status Indicator | 同步状态指示器

### Requirement: System displays sync status indicator
### 需求：系统显示同步状态指示器

The system SHALL display a sync status indicator in the AppBar that shows the current synchronization state.

系统应在应用栏中显示同步状态指示器，显示当前同步状态。

#### Scenario: Indicator is visible in AppBar
#### 场景：指示器在应用栏中可见

- **WHEN** user is on the home screen
- **操作**：用户在主屏幕上
- **THEN** sync status indicator is visible in the AppBar at the right side
- **预期结果**：同步状态指示器在应用栏右侧可见

#### Scenario: Indicator updates in real-time
#### 场景：指示器实时更新

- **WHEN** sync status changes
- **操作**：同步状态改变
- **THEN** indicator updates within 500ms
- **预期结果**：指示器在 500ms 内更新

#### Scenario: Indicator subscribes to status stream
#### 场景：指示器订阅状态流

- **WHEN** home screen loads
- **操作**：主屏幕加载
- **THEN** system subscribes to `SyncApi.statusStream`
- **预期结果**：系统订阅 `SyncApi.statusStream`

#### Scenario: Indicator unsubscribes on dispose
#### 场景：销毁时取消订阅

- **WHEN** home screen is disposed
- **操作**：主屏幕销毁
- **THEN** system unsubscribes from status stream
- **预期结果**：系统取消订阅状态流

---

## 3. Sync State Machine | 同步状态机

### Requirement: System defines sync state machine
### 需求：系统定义同步状态机

The system SHALL implement a 4-state state machine for synchronization status.

系统应实现四状态同步状态机。

#### Scenario: Initial state is disconnected
#### 场景：初始状态为断开

- **WHEN** app starts with no peers
- **操作**：应用启动且无对等设备
- **THEN** sync status is `disconnected`
- **预期结果**：同步状态为 `disconnected`

#### Scenario: Transition from disconnected to syncing
#### 场景：从断开转换到同步中

- **WHEN** system discovers a peer and starts sync
- **操作**：系统发现对等设备并开始同步
- **THEN** sync status transitions to `syncing`
- **预期结果**：同步状态转换为 `syncing`

#### Scenario: Transition from syncing to synced
#### 场景：从同步中转换到已同步

- **WHEN** sync completes successfully
- **操作**：同步成功完成
- **THEN** sync status transitions to `synced`
- **预期结果**：同步状态转换为 `synced`

#### Scenario: Transition from syncing to failed
#### 场景：从同步中转换到失败

- **WHEN** sync fails due to error
- **操作**：同步因错误失败
- **THEN** sync status transitions to `failed`
- **预期结果**：同步状态转换为 `failed`

#### Scenario: Transition from synced to syncing
#### 场景：从已同步转换到同步中

- **WHEN** new changes are detected
- **操作**：检测到新更改
- **THEN** sync status transitions to `syncing`
- **预期结果**：同步状态转换为 `syncing`

#### Scenario: Transition from failed to syncing
#### 场景：从失败转换到同步中

- **WHEN** user retries sync
- **操作**：用户重试同步
- **THEN** sync status transitions to `syncing`
- **预期结果**：同步状态转换为 `syncing`

---

## 4. Disconnected State | 断开状态

### Requirement: System displays disconnected state
### 需求：系统显示断开状态

The system SHALL display a disconnected indicator when no peers are available.

系统应在无可用对等设备时显示断开指示器。

#### Scenario: Disconnected shows cloud_off icon
#### 场景：断开显示 cloud_off 图标

- **WHEN** sync status is `disconnected`
- **操作**：同步状态为 `disconnected`
- **THEN** indicator displays `Icons.cloud_off`
- **预期结果**：指示器显示 `Icons.cloud_off`

#### Scenario: Disconnected icon is grey
#### 场景：断开图标为灰色

- **WHEN** sync status is `disconnected`
- **操作**：同步状态为 `disconnected`
- **THEN** icon color is grey (#757575)
- **预期结果**：图标颜色为灰色（#757575）

#### Scenario: Disconnected shows text
#### 场景：断开显示文本

- **WHEN** sync status is `disconnected`
- **操作**：同步状态为 `disconnected`
- **THEN** indicator displays text "未同步"
- **预期结果**：指示器显示文本"未同步"

#### Scenario: Disconnected has no animation
#### 场景：断开无动画

- **WHEN** sync status is `disconnected`
- **操作**：同步状态为 `disconnected`
- **THEN** icon is static (no animation)
- **预期结果**：图标静止（无动画）

---

## 5. Syncing State | 同步中状态

### Requirement: System displays syncing state
### 需求：系统显示同步中状态

The system SHALL display a syncing indicator when synchronization is in progress.

系统应在同步进行中时显示同步中指示器。

#### Scenario: Syncing shows sync icon
#### 场景：同步中显示同步图标

- **WHEN** sync status is `syncing`
- **操作**：同步状态为 `syncing`
- **THEN** indicator displays `Icons.sync`
- **预期结果**：指示器显示 `Icons.sync`

#### Scenario: Syncing icon is primary color
#### 场景：同步中图标为主色

- **WHEN** sync status is `syncing`
- **操作**：同步状态为 `syncing`
- **THEN** icon color is primary color (#00897B)
- **预期结果**：图标颜色为主色（#00897B）

#### Scenario: Syncing shows text
#### 场景：同步中显示文本

- **WHEN** sync status is `syncing`
- **操作**：同步状态为 `syncing`
- **THEN** indicator displays text "同步中..."
- **预期结果**：指示器显示文本"同步中..."

#### Scenario: Syncing icon rotates
#### 场景：同步中图标旋转

- **WHEN** sync status is `syncing`
- **操作**：同步状态为 `syncing`
- **THEN** icon rotates continuously (360° every 2 seconds)
- **预期结果**：图标持续旋转（每 2 秒 360°）

#### Scenario: Syncing shows peer count
#### 场景：同步中显示对等设备数量

- **WHEN** sync status is `syncing` with N peers
- **操作**：同步状态为 `syncing` 且有 N 台对等设备
- **THEN** indicator displays "同步中 (N 台设备)"
- **预期结果**：指示器显示"同步中（N 台设备）"

---

## 6. Synced State | 已同步状态

### Requirement: System displays synced state
### 需求：系统显示已同步状态

The system SHALL display a synced indicator when synchronization is complete.

系统应在同步完成时显示已同步指示器。

#### Scenario: Synced shows cloud_done icon
#### 场景：已同步显示 cloud_done 图标

- **WHEN** sync status is `synced`
- **操作**：同步状态为 `synced`
- **THEN** indicator displays `Icons.cloud_done`
- **预期结果**：指示器显示 `Icons.cloud_done`

#### Scenario: Synced icon is green
#### 场景：已同步图标为绿色

- **WHEN** sync status is `synced`
- **操作**：同步状态为 `synced`
- **THEN** icon color is green (#43A047)
- **预期结果**：图标颜色为绿色（#43A047）

#### Scenario: Synced shows text
#### 场景：已同步显示文本

- **WHEN** sync status is `synced`
- **操作**：同步状态为 `synced`
- **THEN** indicator displays text "已同步"
- **预期结果**：指示器显示文本"已同步"

#### Scenario: Synced has no animation
#### 场景：已同步无动画

- **WHEN** sync status is `synced`
- **操作**：同步状态为 `synced`
- **THEN** icon is static (no animation)
- **预期结果**：图标静止（无动画）

#### Scenario: Synced shows last sync time
#### 场景：已同步显示最后同步时间

- **WHEN** sync status is `synced`
- **操作**：同步状态为 `synced`
- **THEN** indicator displays "已同步 (刚刚)" or relative time
- **预期结果**：指示器显示"已同步（刚刚）"或相对时间

---

## 7. Failed State | 失败状态

### Requirement: System displays failed state
### 需求：系统显示失败状态

The system SHALL display a failed indicator when synchronization fails.

系统应在同步失败时显示失败指示器。

#### Scenario: Failed shows cloud_off icon with warning
#### 场景：失败显示带警告的 cloud_off 图标

- **WHEN** sync status is `failed`
- **操作**：同步状态为 `failed`
- **THEN** indicator displays `Icons.cloud_off` with warning badge
- **预期结果**：指示器显示带警告徽章的 `Icons.cloud_off`

#### Scenario: Failed icon is orange
#### 场景：失败图标为橙色

- **WHEN** sync status is `failed`
- **操作**：同步状态为 `failed`
- **THEN** icon color is orange (#FB8C00)
- **预期结果**：图标颜色为橙色（#FB8C00）

#### Scenario: Failed shows text
#### 场景：失败显示文本

- **WHEN** sync status is `failed`
- **操作**：同步状态为 `failed`
- **THEN** indicator displays text "同步失败"
- **预期结果**：指示器显示文本"同步失败"

#### Scenario: Failed has no animation
#### 场景：失败无动画

- **WHEN** sync status is `failed`
- **操作**：同步状态为 `failed`
- **THEN** icon is static (no animation)
- **预期结果**：图标静止（无动画）

---

## 8. Indicator Interaction | 指示器交互

### Requirement: User can tap indicator to view details
### 需求：用户可点击指示器查看详情

The system SHALL allow users to tap the sync status indicator to view synchronization details.

系统应允许用户点击同步状态指示器查看同步详情。

#### Scenario: Tapping indicator shows details dialog
#### 场景：点击指示器显示详情对话框

- **WHEN** user taps sync status indicator
- **操作**：用户点击同步状态指示器
- **THEN** system displays sync details dialog
- **预期结果**：系统显示同步详情对话框

#### Scenario: Details dialog shows current status
#### 场景：详情对话框显示当前状态

- **WHEN** details dialog is displayed
- **操作**：详情对话框已显示
- **THEN** dialog shows current sync status and description
- **预期结果**：对话框显示当前同步状态和描述

#### Scenario: Details dialog shows peer list
#### 场景：详情对话框显示对等设备列表

- **WHEN** details dialog is displayed with active peers
- **操作**：详情对话框已显示且有活动对等设备
- **THEN** dialog shows list of connected peers
- **预期结果**：对话框显示已连接对等设备列表

#### Scenario: Details dialog shows error message
#### 场景：详情对话框显示错误消息

- **WHEN** details dialog is displayed with failed status
- **操作**：详情对话框已显示且状态为失败
- **THEN** dialog shows error message and retry button
- **预期结果**：对话框显示错误消息和重试按钮

#### Scenario: Tapping retry triggers sync
#### 场景：点击重试触发同步

- **WHEN** user taps retry button in details dialog
- **操作**：用户点击详情对话框中的重试按钮
- **THEN** system attempts to restart synchronization
- **预期结果**：系统尝试重新启动同步

---

## 9. Performance Optimization | 性能优化

### Requirement: System handles sync status updates efficiently
### 需求：系统高效处理同步状态更新

The system SHALL optimize sync status updates to avoid excessive UI rebuilds.

系统应优化同步状态更新以避免过多的 UI 重建。

#### Scenario: Duplicate status updates are filtered
#### 场景：过滤重复状态更新

- **WHEN** status stream emits duplicate status
- **操作**：状态流发出重复状态
- **THEN** system does NOT rebuild UI
- **预期结果**：系统不重建 UI

#### Scenario: Status updates are debounced
#### 场景：状态更新防抖

- **WHEN** status changes rapidly (< 500ms between changes)
- **操作**：状态快速变化（变化间隔 < 500ms）
- **THEN** system debounces updates to avoid flicker
- **预期结果**：系统对更新防抖以避免闪烁

#### Scenario: Stream subscription is managed properly
#### 场景：正确管理流订阅

- **WHEN** widget is disposed
- **操作**：组件销毁
- **THEN** system cancels stream subscription
- **预期结果**：系统取消流订阅

---

## 10. Accessibility | 可访问性

### Requirement: System provides accessibility support
### 需求：系统提供可访问性支持

The system SHALL provide accessibility labels for sync status indicator.

系统应为同步状态指示器提供可访问性标签。

#### Scenario: Disconnected has semantic label
#### 场景：断开有语义标签

- **WHEN** sync status is `disconnected`
- **操作**：同步状态为 `disconnected`
- **THEN** indicator has semantic label "未同步，无可用设备"
- **预期结果**：指示器有语义标签"未同步，无可用设备"

#### Scenario: Syncing has semantic label
#### 场景：同步中有语义标签

- **WHEN** sync status is `syncing`
- **操作**：同步状态为 `syncing`
- **THEN** indicator has semantic label "正在同步数据"
- **预期结果**：指示器有语义标签"正在同步数据"

#### Scenario: Synced has semantic label
#### 场景：已同步有语义标签

- **WHEN** sync status is `synced`
- **操作**：同步状态为 `synced`
- **THEN** indicator has semantic label "已同步，数据最新"
- **预期结果**：指示器有语义标签"已同步，数据最新"

#### Scenario: Failed has semantic label
#### 场景：失败有语义标签

- **WHEN** sync status is `failed`
- **操作**：同步状态为 `failed`
- **THEN** indicator has semantic label "同步失败，点击查看详情"
- **预期结果**：指示器有语义标签"同步失败，点击查看详情"

---

## State Machine Diagram | 状态机图

```
┌─────────────┐
│ disconnected│◄─────┐
└──────┬──────┘      │
       │             │
       │ discover    │ disconnect
       │ peer        │
       ▼             │
┌─────────────┐      │
│   syncing   │──────┤
└──────┬──────┘      │
       │             │
       ├─────────────┘
       │ success
       ▼
┌─────────────┐
│   synced    │
└──────┬──────┘
       │
       │ new changes
       │
       └──────────────► syncing

       syncing ──error──► failed ──retry──► syncing
```

---

## Implementation Notes | 实现说明

### SyncStatus Model | SyncStatus 模型
```dart
enum SyncState {
  disconnected,
  syncing,
  synced,
  failed,
}

class SyncStatus {
  final SyncState state;
  final int syncingPeers;
  final DateTime? lastSyncTime;
  final String? errorMessage;

  bool get isActive => state == SyncState.syncing || state == SyncState.synced;
}
```

### Stream Integration | 流集成
```dart
StreamBuilder<SyncStatus>(
  stream: SyncApi.statusStream.distinct(),
  builder: (context, snapshot) {
    final status = snapshot.data ?? SyncStatus.disconnected();
    return SyncStatusIndicator(status: status);
  },
)
```

### Animation | 动画
```dart
AnimatedRotation(
  turns: _isRotating ? _rotationController.value : 0,
  child: Icon(Icons.sync),
)
```

---

## Test Coverage | 测试覆盖

### Unit Tests | 单元测试
- `it_should_initialize_with_disconnected_state()`
- `it_should_transition_from_disconnected_to_syncing()`
- `it_should_transition_from_syncing_to_synced()`
- `it_should_transition_from_syncing_to_failed()`
- `it_should_filter_duplicate_status_updates()`
- `it_should_debounce_rapid_status_changes()`
- `it_should_cancel_subscription_on_dispose()`

### Widget Tests | 组件测试
- `it_should_render_sync_status_indicator()`
- `it_should_show_cloud_off_icon_when_disconnected()`
- `it_should_show_rotating_sync_icon_when_syncing()`
- `it_should_show_cloud_done_icon_when_synced()`
- `it_should_show_warning_icon_when_failed()`
- `it_should_display_correct_text_for_each_state()`
- `it_should_use_correct_color_for_each_state()`
- `it_should_show_details_dialog_on_tap()`
- `it_should_show_retry_button_when_failed()`

### Integration Tests | 集成测试
- `it_should_update_indicator_when_sync_status_changes()`
- `it_should_subscribe_to_sync_api_stream()`
- `it_should_trigger_sync_on_retry()`
- `it_should_display_peer_count_when_syncing()`

---

**Last Updated** | **最后更新**: 2026-01-21
**Authors** | **作者**: CardMind Team
