## ADDED Requirements

# Testing Specification for Sync Status UI

## Unit Tests: SyncStatus Model

**测试文件**: `test/models/sync_status_test.dart`

### Test 1: it_should_create_not_yet_synced_status
- **目的**: 验证创建尚未同步状态
- **WHEN** 创建 `SyncStatus` with `state: SyncState.notYetSynced`
- **THEN** `state` 应为 `notYetSynced`
- **AND** `lastSyncTime` 应为 `null`
- **AND** `errorMessage` 应为 `null`
- **AND** `isValid()` 应返回 `true`

### Test 2: it_should_create_syncing_status
- **目的**: 验证创建同步中状态
- **WHEN** 创建 `SyncStatus` with `state: SyncState.syncing`
- **THEN** `state` 应为 `syncing`
- **AND** `lastSyncTime` 可以为 `null` 或非 `null`
- **AND** `errorMessage` 应为 `null`
- **AND** `isValid()` 应返回 `true`

### Test 3: it_should_create_synced_status_with_time
- **目的**: 验证创建已同步状态（带时间）
- **WHEN** 创建 `SyncStatus` with `state: SyncState.synced` and `lastSyncTime: DateTime.now()`
- **THEN** `state` 应为 `synced`
- **AND** `lastSyncTime` 应非空
- **AND** `errorMessage` 应为 `null`
- **AND** `isValid()` 应返回 `true`

### Test 4: it_should_create_failed_status_with_error
- **目的**: 验证创建失败状态（带错误信息）
- **WHEN** 创建 `SyncStatus` with `state: SyncState.failed` and `errorMessage: "未发现可用设备"`
- **THEN** `state` 应为 `failed`
- **AND** `errorMessage` 应为 "未发现可用设备"
- **AND** `isValid()` 应返回 `true`

### Test 5: it_should_enforce_not_yet_synced_has_null_time
- **目的**: 验证尚未同步状态时间为空约束
- **WHEN** 创建 `SyncStatus` with `state: SyncState.notYetSynced` and `lastSyncTime: DateTime.now()`
- **THEN** `isValid()` 应返回 `false`

### Test 6: it_should_enforce_failed_has_error_message
- **目的**: 验证失败状态有错误信息约束
- **WHEN** 创建 `SyncStatus` with `state: SyncState.failed` and `errorMessage: null`
- **THEN** `isValid()` 应返回 `false`
- **WHEN** 创建 `SyncStatus` with `state: SyncState.failed` and `errorMessage: ""`
- **THEN** `isValid()` 应返回 `false`

### Test 7: it_should_enforce_synced_has_non_null_time
- **目的**: 验证已同步状态时间非空约束
- **WHEN** 创建 `SyncStatus` with `state: SyncState.synced` and `lastSyncTime: null`
- **THEN** `isValid()` 应返回 `false`

## Widget Tests: SyncStatusIndicator

**测试文件**: `test/widgets/sync_status_indicator_test.dart`

### Rendering Tests

#### Test 1: it_should_show_not_yet_synced_badge
- **目的**: 显示尚未同步徽章
- **WHEN** 创建指示器 with `state: notYetSynced`
- **THEN** 应显示灰色 Badge
- **AND** 应显示 `CloudOff` 图标
- **AND** 应显示 "尚未同步" 文本
- **AND** 不应有动画

#### Test 2: it_should_show_syncing_badge_with_animation
- **目的**: 显示同步中徽章（带动画）
- **WHEN** 创建指示器 with `state: syncing`
- **THEN** 应显示次要色 Badge
- **AND** 应显示 `RefreshCw` 图标
- **AND** 应显示 "同步中..." 文本
- **AND** 图标应旋转动画（360° 每2秒）

#### Test 3: it_should_show_synced_badge_with_just_now_text
- **目的**: 显示"刚刚"文本（10秒内）
- **WHEN** 创建指示器 with `state: synced` and `lastSyncTime: 5秒前`
- **THEN** 应显示白色边框 Badge
- **AND** 应显示绿色 `Check` 图标
- **AND** 应显示 "刚刚" 文本
- **AND** 不应有动画

#### Test 4: it_should_show_synced_badge_with_synced_text
- **目的**: 显示"已同步"文本（超过10秒）
- **WHEN** 创建指示器 with `state: synced` and `lastSyncTime: 15秒前`
- **THEN** 应显示白色边框 Badge
- **AND** 应显示绿色 `Check` 图标
- **AND** 应显示 "已同步" 文本
- **AND** 不应有动画

#### Test 5: it_should_show_failed_badge
- **目的**: 显示同步失败徽章
- **WHEN** 创建指示器 with `state: failed`
- **THEN** 应显示红色 Badge
- **AND** 应显示 `AlertCircle` 图标
- **AND** 应显示 "同步失败" 文本
- **AND** 不应有动画

#### Test 6: it_should_use_correct_colors_for_each_state
- **目的**: 验证每个状态的颜色正确
- **WHEN** 遍历所有状态
- **THEN** `notYetSynced` 应为灰色
- **AND** `syncing` 应为次要色
- **AND** `synced` 应为白色边框
- **AND** `failed` 应为红色

#### Test 7: it_should_use_correct_icons_for_each_state
- **目的**: 验证每个状态的图标正确
- **WHEN** 遍历所有状态
- **THEN** `notYetSynced` 应为 `CloudOff`
- **AND** `syncing` 应为 `RefreshCw`
- **AND** `synced` 应为 `Check`（绿色）
- **AND** `failed` 应为 `AlertCircle`

### Interaction Tests

#### Test 8: it_should_open_details_dialog_on_tap
- **目的**: 点击打开详情对话框
- **WHEN** 用户点击指示器
- **THEN** 应显示详情对话框
- **AND** 对话框应包含当前状态信息
- **AND** 对话框应包含设备列表
- **AND** 对话框应包含同步历史

#### Test 9: it_should_have_correct_semantic_labels
- **目的**: 验证无障碍标签正确
- **WHEN** 遍历所有状态
- **THEN** `notYetSynced` 语义标签应为 "尚未同步，点击查看详情"
- **AND** `syncing` 语义标签应为 "正在同步数据，点击查看详情"
- **AND** `synced` 语义标签应为 "已同步，数据最新，点击查看详情"
- **AND** `failed` 语义标签应为 "同步失败，点击查看详情并重试"

### State Update Tests

#### Test 10: it_should_update_when_status_changes
- **目的**: 状态变化时更新显示
- **WHEN** 创建初始状态为 `notYetSynced` 的指示器
- **AND** 模拟状态流发出 `syncing` 状态
- **THEN** 指示器应更新为 "同步中" 样式
- **WHEN** 模拟状态流发出 `synced` 状态
- **THEN** 指示器应更新为 "已同步" 样式
- **AND** 过渡动画应流畅

#### Test 11: it_should_filter_duplicate_status_updates
- **目的**: 过滤重复状态更新
- **WHEN** 创建指示器
- **AND** 模拟状态流连续发出3次相同状态
- **THEN** UI 应只重建1次
- **AND** 性能优化应生效

#### Test 12: it_should_update_relative_time_display
- **目的**: 更新相对时间显示
- **WHEN** 创建 `synced` 状态（5秒前）
- **THEN** 应显示 "刚刚"
- **WHEN** 等待10秒
- **THEN** 应显示 "已同步"
- **AND** 定时器应停止

### Resource Management Tests

#### Test 13: it_should_stop_timer_when_disposed
- **目的**: dispose 时停止定时器
- **WHEN** 创建 `synced` 状态指示器（启动定时器）
- **AND** 调用 `dispose`
- **THEN** 定时器应被取消
- **AND** 不应有内存泄漏

#### Test 14: it_should_cancel_subscription_when_disposed
- **目的**: dispose 时取消订阅
- **WHEN** 创建指示器（订阅状态流）
- **AND** 调用 `dispose`
- **THEN** 流订阅应被取消
- **AND** 不应再接收状态更新

## Widget Tests: SyncDetailsDialog

**测试文件**: `test/widgets/sync_details_dialog_test.dart`

### Rendering Tests

#### Test 1: it_should_show_current_status
- **目的**: 显示当前状态
- **WHEN** 打开对话框
- **THEN** 应显示当前同步状态（尚未同步/同步中/已同步/同步失败）
- **AND** 应显示状态描述文本
- **AND** 状态图标应正确

#### Test 2: it_should_show_device_list
- **目的**: 显示设备列表
- **WHEN** 打开对话框（有3个已发现设备）
- **THEN** 应显示设备列表
- **AND** 每个设备应显示名称
- **AND** 应显示连接状态（已连接/未连接）
- **AND** 应显示上次可见时间

#### Test 3: it_should_show_sync_statistics
- **目的**: 显示同步统计
- **WHEN** 打开对话框
- **THEN** 应显示已同步卡片数量
- **AND** 应显示同步数据大小
- **AND** 应显示成功/失败同步次数

#### Test 4: it_should_show_sync_history
- **目的**: 显示同步历史
- **WHEN** 打开对话框（有同步历史）
- **THEN** 应显示最近10条同步事件
- **AND** 每个事件应显示时间戳
- **AND** 每个事件应显示成功/失败状态
- **AND** 每个事件应显示涉及的设备

### Error State Tests

#### Test 5: it_should_show_error_message_when_failed
- **目的**: 失败时显示错误信息
- **WHEN** 打开对话框（状态为失败）
- **THEN** 应显示错误消息
- **AND** 错误消息内容应正确（"未发现可用设备"等）
- **AND** 应显示错误图标

#### Test 6: it_should_show_retry_button_when_failed
- **目的**: 失败时显示重试按钮
- **WHEN** 打开对话框（状态为失败）
- **THEN** 应显示 "重试" 按钮
- **AND** 按钮应可点击
- **AND** 按钮样式应正确

### Interaction Tests

#### Test 7: it_should_trigger_sync_on_retry
- **目的**: 点击重试触发同步
- **WHEN** 打开对话框（状态为失败）
- **AND** 模拟点击 "重试" 按钮
- **THEN** 应调用同步 API
- **AND** 状态应更新为 "同步中"
- **AND** 按钮应变为禁用状态（防止重复点击）

#### Test 8: it_should_trigger_sync_on_sync_now_button
- **目的**: 点击立即同步按钮触发同步
- **WHEN** 打开对话框（任意状态）
- **AND** 模拟点击 "立即同步" 按钮
- **THEN** 应调用同步 API
- **AND** 状态应更新为 "同步中"
- **AND** 应显示同步进度

#### Test 9: it_should_refresh_devices_on_refresh_button
- **目的**: 点击刷新按钮刷新设备列表
- **WHEN** 打开对话框
- **AND** 模拟点击 "刷新设备列表" 按钮
- **THEN** 应调用设备扫描 API
- **AND** 设备列表应更新
- **AND** 应显示刷新动画

#### Test 10: it_should_dismiss_on_close
- **目的**: 点击关闭按钮关闭对话框
- **WHEN** 打开对话框
- **AND** 模拟点击关闭按钮
- **THEN** 对话框应关闭
- **AND** 关闭动画应流畅

### Real-time Update Tests

#### Test 11: it_should_update_status_in_realtime
- **目的**: 实时更新状态
- **WHEN** 打开对话框（状态为 "同步中"）
- **AND** 模拟状态流发出 "已同步" 状态
- **THEN** 对话框内状态应实时更新
- **AND** 不需要手动刷新

#### Test 12: it_should_update_device_list_in_realtime
- **目的**: 实时更新设备列表
- **WHEN** 打开对话框
- **AND** 模拟发现新设备
- **THEN** 设备列表应自动更新
- **AND** 新设备应显示在列表中

## Test Coverage Requirements

- **单元测试**: 7个测试用例
- **SyncStatusIndicator Widget 测试**: 14个测试用例
- **SyncDetailsDialog Widget 测试**: 12个测试用例
- **总计**: 33个测试用例
- **覆盖率目标**: ≥ 90%

## Test Execution Commands

```bash
# 运行所有测试
flutter test

# 运行单元测试
flutter test test/models/sync_status_test.dart

# 运行 Widget 测试
flutter test test/widgets/sync_status_indicator_test.dart
flutter test test/widgets/sync_details_dialog_test.dart

# 生成覆盖率报告
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```
