# Desktop Sync Status Indicator Specification | 桌面端同步状态指示器规格

**Version** | **版本**: 2.0.0
**Status** | **状态**: Active
**Dependencies** | **依赖**: [sync_protocol.md](../../architecture/sync/service.md), [shared.md](shared.md)
**Related Tests** | **相关测试**: `test/widgets/sync_status_indicator_test.dart`, `test/models/sync_status_test.dart`

---

## Overview | 概述

This specification defines the desktop sync status indicator widget that provides real-time visual feedback about synchronization status using a Badge component. The design is based on the React UI reference implementation.

本规格定义了桌面端同步状态指示器 widget，使用 Badge 组件提供关于同步状态的实时视觉反馈。设计基于 React UI 参考实现。

### Applicable Platforms | 适用平台

- macOS
- Windows
- Linux

**Note**: Mobile platforms (Android, iOS, iPadOS) do NOT display the sync status indicator in the AppBar. Mobile users can access sync information through the settings or devices tab.

**注意**：移动端平台（Android、iOS、iPadOS）不在应用栏中显示同步状态指示器。移动端用户可以通过设置或设备标签页访问同步信息。

---

## Requirement: Define sync state machine | 需求：定义同步状态机

The system SHALL implement a 4-state state machine for synchronization status.

系统应实现四状态同步状态机。

### Scenario: State is not yet synced initially | 场景：初始状态为尚未同步

- **WHEN** app starts and has never synchronized
- **操作**：应用启动且从未同步过
- **THEN** sync status is `notYetSynced`
- **预期结果**：同步状态为 `notYetSynced`
- **AND** lastSyncTime is null
- **并且**：lastSyncTime 为 null

### Scenario: Transition from not yet synced to syncing | 场景：从尚未同步转换到同步中

- **WHEN** user triggers sync or auto-sync starts
- **操作**：用户触发同步或自动同步启动
- **THEN** sync status transitions to `syncing`
- **预期结果**：同步状态转换为 `syncing`

### Scenario: Transition from syncing to synced | 场景：从同步中转换到已同步

- **WHEN** sync completes successfully
- **操作**：同步成功完成
- **THEN** sync status transitions to `synced`
- **预期结果**：同步状态转换为 `synced`
- **AND** lastSyncTime is set to current timestamp
- **并且**：lastSyncTime 设置为当前时间戳

### Scenario: Transition from syncing to failed | 场景：从同步中转换到失败

- **WHEN** sync fails due to error
- **操作**：同步因错误失败
- **THEN** sync status transitions to `failed`
- **预期结果**：同步状态转换为 `failed`
- **AND** errorMessage is set
- **并且**：errorMessage 被设置

### Scenario: Transition from synced to syncing | 场景：从已同步转换到同步中

- **WHEN** new changes are detected or user manually triggers sync
- **操作**：检测到新更改或用户手动触发同步
- **THEN** sync status transitions to `syncing`
- **预期结果**：同步状态转换为 `syncing`

### Scenario: Transition from failed to syncing | 场景：从失败转换到同步中

- **WHEN** user retries sync
- **操作**：用户重试同步
- **THEN** sync status transitions to `syncing`
- **预期结果**：同步状态转换为 `syncing`

---

## Requirement: Display not yet synced state | 需求：显示尚未同步状态

The system SHALL display a not yet synced indicator when the app has never synchronized.

系统应在应用从未同步时显示尚未同步指示器。

### Scenario: Not yet synced shows grey badge | 场景：尚未同步显示灰色徽章

- **WHEN** sync status is `notYetSynced`
- **操作**：同步状态为 `notYetSynced`
- **THEN** indicator displays a grey Badge component
- **预期结果**：指示器显示灰色 Badge 组件

### Scenario: Not yet synced shows cloud off icon | 场景：尚未同步显示云关闭图标

- **WHEN** sync status is `notYetSynced`
- **操作**：同步状态为 `notYetSynced`
- **THEN** Badge displays CloudOff icon
- **预期结果**：Badge 显示 CloudOff 图标

### Scenario: Not yet synced shows text | 场景：尚未同步显示文本

- **WHEN** sync status is `notYetSynced`
- **操作**：同步状态为 `notYetSynced`
- **THEN** Badge displays text "尚未同步"
- **预期结果**：Badge 显示文本"尚未同步"

### Scenario: Not yet synced has no animation | 场景：尚未同步无动画

- **WHEN** sync status is `notYetSynced`
- **操作**：同步状态为 `notYetSynced`
- **THEN** icon is static (no animation)
- **预期结果**：图标静止（无动画）

---

## Requirement: Display syncing state | 需求：显示同步中状态

The system SHALL display a syncing indicator when synchronization is in progress.

系统应在同步进行中时显示同步中指示器。

### Scenario: Syncing shows secondary badge | 场景：同步中显示次要色徽章

- **WHEN** sync status is `syncing`
- **操作**：同步状态为 `syncing`
- **THEN** indicator displays a secondary color Badge component
- **预期结果**：指示器显示次要色 Badge 组件

### Scenario: Syncing shows refresh icon | 场景：同步中显示刷新图标

- **WHEN** sync status is `syncing`
- **操作**：同步状态为 `syncing`
- **THEN** Badge displays RefreshCw icon
- **预期结果**：Badge 显示 RefreshCw 图标

### Scenario: Syncing shows text | 场景：同步中显示文本

- **WHEN** sync status is `syncing`
- **操作**：同步状态为 `syncing`
- **THEN** Badge displays text "同步中..."
- **预期结果**：Badge 显示文本"同步中..."

### Scenario: Syncing icon rotates | 场景：同步中图标旋转

- **WHEN** sync status is `syncing`
- **操作**：同步状态为 `syncing`
- **THEN** icon rotates continuously (360° every 2 seconds)
- **预期结果**：图标持续旋转（每 2 秒 360°）

---

## Requirement: Display synced state | 需求：显示已同步状态

The system SHALL display a synced indicator when synchronization is complete.

系统应在同步完成时显示已同步指示器。

### Scenario: Synced shows outline badge | 场景：已同步显示边框徽章

- **WHEN** sync status is `synced`
- **操作**：同步状态为 `synced`
- **THEN** indicator displays a white outline Badge component
- **预期结果**：指示器显示白色边框 Badge 组件

### Scenario: Synced shows check icon | 场景：已同步显示勾选图标

- **WHEN** sync status is `synced`
- **操作**：同步状态为 `synced`
- **THEN** Badge displays green Check icon
- **预期结果**：Badge 显示绿色 Check 图标

### Scenario: Synced shows just now text within 10 seconds | 场景：10秒内已同步显示刚刚文本

- **WHEN** sync status is `synced` and time since sync ≤ 10 seconds
- **操作**：同步状态为 `synced` 且距离同步时间 ≤ 10 秒
- **THEN** Badge displays text "刚刚"
- **预期结果**：Badge 显示文本"刚刚"

### Scenario: Synced shows synced text after 10 seconds | 场景：10秒后已同步显示已同步文本

- **WHEN** sync status is `synced` and time since sync > 10 seconds
- **操作**：同步状态为 `synced` 且距离同步时间 > 10 秒
- **THEN** Badge displays text "已同步"
- **预期结果**：Badge 显示文本"已同步"

### Scenario: Synced has no animation | 场景：已同步无动画

- **WHEN** sync status is `synced`
- **操作**：同步状态为 `synced`
- **THEN** icon is static (no animation)
- **预期结果**：图标静止（无动画）

---

## Requirement: Display failed state | 需求：显示失败状态

The system SHALL display a failed indicator when synchronization fails.

系统应在同步失败时显示失败指示器。

### Scenario: Failed shows destructive badge | 场景：失败显示破坏性徽章

- **WHEN** sync status is `failed`
- **操作**：同步状态为 `failed`
- **THEN** indicator displays a red destructive Badge component
- **预期结果**：指示器显示红色破坏性 Badge 组件

### Scenario: Failed shows alert icon | 场景：失败显示警告图标

- **WHEN** sync status is `failed`
- **操作**：同步状态为 `failed`
- **THEN** Badge displays AlertCircle icon
- **预期结果**：Badge 显示 AlertCircle 图标

### Scenario: Failed shows text | 场景：失败显示文本

- **WHEN** sync status is `failed`
- **操作**：同步状态为 `failed`
- **THEN** Badge displays text "同步失败"
- **预期结果**：Badge 显示文本"同步失败"

### Scenario: Failed has no animation | 场景：失败无动画

- **WHEN** sync status is `failed`
- **操作**：同步状态为 `failed`
- **THEN** icon is static (no animation)
- **预期结果**：图标静止（无动画）

---

## Requirement: Interactive status details | 需求：交互式状态详情

The system SHALL allow users to tap the indicator to view detailed sync information.

系统应允许用户点击指示器以查看详细的同步信息。

### Scenario: Tap to open sync details dialog | 场景：点击打开同步详情对话框

- **WHEN** user taps on the sync status indicator
- **操作**：用户点击同步状态指示器
- **THEN** the system SHALL open sync details dialog
- **预期结果**：系统应打开同步详情对话框

---

## Requirement: Handle state consistency | 需求：处理状态一致性

The system SHALL enforce state consistency constraints.

系统应强制执行状态一致性约束。

### Scenario: Not yet synced has null time | 场景：尚未同步时间为空

- **WHEN** sync status is `notYetSynced`
- **操作**：同步状态为 `notYetSynced`
- **THEN** lastSyncTime must be null
- **预期结果**：lastSyncTime 必须为 null

### Scenario: Failed has error message | 场景：失败有错误信息

- **WHEN** sync status is `failed`
- **操作**：同步状态为 `failed`
- **THEN** errorMessage must be non-empty
- **预期结果**：errorMessage 必须非空

### Scenario: Synced has non-null time | 场景：已同步时间非空

- **WHEN** sync status is `synced`
- **操作**：同步状态为 `synced`
- **THEN** lastSyncTime must be non-null
- **预期结果**：lastSyncTime 必须非空

### Scenario: Syncing preserves last sync time | 场景：同步中保持上次同步时间

- **WHEN** sync status is `syncing`
- **操作**：同步状态为 `syncing`
- **THEN** lastSyncTime is not updated (preserves previous value)
- **预期结果**：lastSyncTime 不更新（保持之前的值）

---

## Requirement: Optimize performance | 需求：优化性能

The system SHALL optimize sync status updates to avoid excessive UI rebuilds.

系统应优化同步状态更新以避免过多的 UI 重建。

### Scenario: Duplicate status updates are filtered | 场景：过滤重复状态更新

- **WHEN** status stream emits duplicate status
- **操作**：状态流发出重复状态
- **THEN** system does NOT rebuild UI
- **预期结果**：系统不重建 UI

### Scenario: Timer stops after 10 seconds | 场景：10秒后停止定时器

- **WHEN** sync status is `synced` and time since sync > 10 seconds
- **操作**：同步状态为 `synced` 且距离同步时间 > 10 秒
- **THEN** system stops the relative time update timer
- **预期结果**：系统停止相对时间更新定时器

### Scenario: Timer runs within 10 seconds | 场景：10秒内运行定时器

- **WHEN** sync status is `synced` and time since sync ≤ 10 seconds
- **操作**：同步状态为 `synced` 且距离同步时间 ≤ 10 秒
- **THEN** system updates display every 1 second
- **预期结果**：系统每 1 秒更新显示

### Scenario: Animation starts only when syncing | 场景：仅同步中时启动动画

- **WHEN** sync status transitions to `syncing`
- **操作**：同步状态转换为 `syncing`
- **THEN** system starts rotation animation controller
- **预期结果**：系统启动旋转动画控制器

### Scenario: Animation stops when not syncing | 场景：非同步中时停止动画

- **WHEN** sync status transitions from `syncing` to any other state
- **操作**：同步状态从 `syncing` 转换到任何其他状态
- **THEN** system stops rotation animation controller
- **预期结果**：系统停止旋转动画控制器

### Scenario: Stream subscription is cancelled on dispose | 场景：销毁时取消流订阅

- **WHEN** widget is disposed
- **操作**：组件销毁
- **THEN** system cancels stream subscription
- **预期结果**：系统取消流订阅

### Scenario: Timer is cancelled on dispose | 场景：销毁时取消定时器

- **WHEN** widget is disposed
- **操作**：组件销毁
- **THEN** system cancels relative time update timer
- **预期结果**：系统取消相对时间更新定时器

### Scenario: Animation controller is disposed | 场景：销毁动画控制器

- **WHEN** widget is disposed
- **操作**：组件销毁
- **THEN** system disposes animation controller
- **预期结果**：系统销毁动画控制器

---

## Requirement: Provide accessibility support | 需求：提供可访问性支持

The system SHALL provide accessibility labels for sync status indicator.

系统应为同步状态指示器提供可访问性标签。

### Scenario: Not yet synced has semantic label | 场景：尚未同步有语义标签

- **WHEN** sync status is `notYetSynced`
- **操作**：同步状态为 `notYetSynced`
- **THEN** indicator has semantic label "尚未同步，点击查看详情"
- **预期结果**：指示器有语义标签"尚未同步，点击查看详情"

### Scenario: Syncing has semantic label | 场景：同步中有语义标签

- **WHEN** sync status is `syncing`
- **操作**：同步状态为 `syncing`
- **THEN** indicator has semantic label "正在同步数据，点击查看详情"
- **预期结果**：指示器有语义标签"正在同步数据，点击查看详情"

### Scenario: Synced has semantic label | 场景：已同步有语义标签

- **WHEN** sync status is `synced`
- **操作**：同步状态为 `synced`
- **THEN** indicator has semantic label "已同步，数据最新，点击查看详情"
- **预期结果**：指示器有语义标签"已同步，数据最新，点击查看详情"

### Scenario: Failed has semantic label | 场景：失败有语义标签

- **WHEN** sync status is `failed`
- **操作**：同步状态为 `failed`
- **THEN** indicator has semantic label "同步失败，点击查看详情并重试"
- **预期结果**：指示器有语义标签"同步失败，点击查看详情并重试"

---

## Requirement: Handle error cases | 需求：处理错误情况

The system SHALL handle various error scenarios gracefully.

系统应优雅地处理各种错误场景。

### Scenario: No available peers error | 场景：无可用对等设备错误

- **WHEN** sync fails due to no available peers
- **操作**：同步因无可用对等设备失败
- **THEN** status transitions to `failed` with errorMessage "未发现可用设备"
- **预期结果**：状态转换为 `failed`，errorMessage 为"未发现可用设备"

### Scenario: Connection timeout error | 场景：连接超时错误

- **WHEN** sync fails due to connection timeout
- **操作**：同步因连接超时失败
- **THEN** status transitions to `failed` with errorMessage "连接超时"
- **预期结果**：状态转换为 `failed`，errorMessage 为"连接超时"

### Scenario: Data transfer error | 场景：数据传输错误

- **WHEN** sync fails due to data transfer failure
- **操作**：同步因数据传输失败
- **THEN** status transitions to `failed` with errorMessage "数据传输失败"
- **预期结果**：状态转换为 `failed`，errorMessage 为"数据传输失败"

### Scenario: CRDT merge error | 场景：CRDT 合并错误

- **WHEN** sync fails due to CRDT merge failure
- **操作**：同步因 CRDT 合并失败
- **THEN** status transitions to `failed` with errorMessage "数据合并失败"
- **预期结果**：状态转换为 `failed`，errorMessage 为"数据合并失败"

### Scenario: Local storage error | 场景：本地存储错误

- **WHEN** sync fails due to local storage error
- **操作**：同步因本地存储错误失败
- **THEN** status transitions to `failed` with errorMessage "本地存储错误"
- **预期结果**：状态转换为 `failed`，errorMessage 为"本地存储错误"

### Scenario: Stream subscription failure | 场景：流订阅失败

- **WHEN** status stream subscription fails
- **操作**：状态流订阅失败
- **THEN** system displays default state `notYetSynced`
- **预期结果**：系统显示默认状态 `notYetSynced`

### Scenario: Time calculation overflow | 场景：时间计算溢出

- **WHEN** time calculation results in overflow
- **操作**：时间计算导致溢出
- **THEN** system displays "已同步" without specific time
- **预期结果**：系统显示"已同步"不显示具体时间

---

## Data Model | 数据模型

### SyncState Enum | SyncState 枚举

```dart
enum SyncState {
  notYetSynced,  // 尚未同步
  syncing,       // 同步中
  synced,        // 已同步
  failed,        // 同步失败
}
```

### SyncStatus Class | SyncStatus 类

```dart
class SyncStatus {
  final SyncState state;
  final DateTime? lastSyncTime;  // 上次同步时间，null 表示从未同步
  final String? errorMessage;    // 错误信息，仅在 failed 状态时有值

  SyncStatus({
    required this.state,
    this.lastSyncTime,
    this.errorMessage,
  });

  // State consistency validation
  bool isValid() {
    if (state == SyncState.notYetSynced && lastSyncTime != null) {
      return false;
    }
    if (state == SyncState.failed && (errorMessage == null || errorMessage!.isEmpty)) {
      return false;
    }
    if (state == SyncState.synced && lastSyncTime == null) {
      return false;
    }
    return true;
  }
}
```

---

## State Machine Diagram | 状态机图

```
┌──────────────┐
│ notYetSynced │
└──────┬───────┘
       │
       │ trigger sync
       ▼
┌──────────────┐      success      ┌──────────────┐
│   syncing    │──────────────────►│   synced     │
└──────┬───────┘                   └──────┬───────┘
       │                                  │
       │ error                            │ new changes
       ▼                                  │
┌──────────────┐                          │
│   failed     │                          │
└──────┬───────┘                          │
       │                                  │
       │ retry                            │
       └──────────────────────────────────┘
                      │
                      ▼
                  syncing
```

---

## Test Coverage | 测试覆盖

**Test File** | **测试文件**: `test/models/sync_status_test.dart`

**Unit Tests** | **单元测试**:
- `it_should_create_not_yet_synced_status()` - Create not yet synced status | 创建尚未同步状态
- `it_should_create_syncing_status()` - Create syncing status | 创建同步中状态
- `it_should_create_synced_status_with_time()` - Create synced status with time | 创建已同步状态（带时间）
- `it_should_create_failed_status_with_error()` - Create failed status with error | 创建失败状态（带错误信息）
- `it_should_enforce_not_yet_synced_has_null_time()` - Validate not yet synced has null time | 验证尚未同步状态时间为空
- `it_should_enforce_failed_has_error_message()` - Validate failed has error message | 验证失败状态有错误信息
- `it_should_enforce_synced_has_non_null_time()` - Validate synced has non-null time | 验证已同步状态时间非空

**Test File** | **测试文件**: `test/widgets/sync_status_indicator_test.dart`

**Widget Tests** | **Widget 测试**:
- `it_should_show_not_yet_synced_badge()` - Display not yet synced badge | 显示尚未同步徽章
- `it_should_show_syncing_badge_with_animation()` - Display syncing badge with animation | 显示同步中徽章（带动画）
- `it_should_show_synced_badge_with_just_now_text()` - Display "刚刚" text within 10s | 显示"刚刚"文本（10秒内）
- `it_should_show_synced_badge_with_synced_text()` - Display "已同步" text after 10s | 显示"已同步"文本（超过10秒）
- `it_should_show_failed_badge()` - Display failed badge | 显示同步失败徽章
- `it_should_use_correct_colors_for_each_state()` - Validate colors for each state | 验证每个状态的颜色正确
- `it_should_use_correct_icons_for_each_state()` - Validate icons for each state | 验证每个状态的图标正确
- `it_should_open_details_dialog_on_tap()` - Open details dialog on tap | 点击打开详情对话框
- `it_should_have_correct_semantic_labels()` - Validate semantic labels | 验证无障碍标签正确
- `it_should_update_when_status_changes()` - Update when status changes | 状态变化时更新显示
- `it_should_filter_duplicate_status_updates()` - Filter duplicate updates | 过滤重复状态更新
- `it_should_stop_timer_when_disposed()` - Stop timer on dispose | dispose 时停止定时器
- `it_should_cancel_subscription_when_disposed()` - Cancel subscription on dispose | dispose 时取消订阅

**Acceptance Criteria** | **验收标准**:
- [ ] All unit tests pass (7 tests) | 所有单元测试通过（7个测试）
- [ ] All widget tests pass (13 tests) | 所有 Widget 测试通过（13个测试）
- [ ] Visual states are clearly distinguishable | 可视状态清晰可辨
- [ ] Animations are smooth and performant | 动画流畅且性能良好
- [ ] Status updates respond quickly to state changes | 状态更新快速响应状态变化
- [ ] Test coverage ≥ 90% | 测试覆盖率 ≥ 90%
- [ ] Code review approved | 代码审查通过
- [ ] Documentation updated | 文档已更新

---

## Related Documents | 相关文档

**Related Specs** | **相关规格**:
- [sync_details_dialog.md](sync_details_dialog.md) - Sync details dialog | 同步详情对话框
- [shared.md](shared.md) - Shared sync feedback spec | 通用同步反馈规格
- [sync_protocol.md](../../architecture/sync/service.md) - Sync protocol | 同步协议

---

**Last Updated** | **最后更新**: 2026-01-25
**Authors** | **作者**: CardMind Team
