# 同步状态 UI 设计文档（桌面端）

**日期**: 2026-01-25
**状态**: 已验证
**基于**: React UI 参考实现
**适用平台**: macOS, Windows, Linux

---

## 设计概述

本设计文档定义了 CardMind **桌面端**同步状态指示器的完整 UI 设计，包括状态机、视觉规范、交互行为、边界条件和测试策略。设计基于 `react_ui_reference/src/app/components/sync-status.tsx` 的实现。

**重要说明**：根据项目的平台特定设计原则，同步状态指示器**仅在桌面端显示**。移动端（Android、iOS、iPadOS）不在应用栏中显示同步状态指示器，用户可以通过设置或设备标签页访问同步信息。

---

## 1. 状态定义和视觉规范

### 1.1 状态机设计

**4个核心状态**：

1. **尚未同步（Not Yet Synced）**
   - 触发条件：应用首次启动，尚未执行过同步操作
   - 视觉：灰色 Badge + CloudOff 图标
   - 文本：显示"尚未同步"
   - 动画：无

2. **同步中（Syncing）**
   - 触发条件：正在执行同步操作
   - 视觉：次要色 Badge + RefreshCw 图标
   - 文本：显示"同步中..."
   - 动画：图标持续旋转（360° 每2秒）

3. **已同步（Synced）**
   - 触发条件：同步成功完成
   - 视觉：白色边框 Badge + 绿色 Check 图标
   - 文本：10秒内显示"刚刚"，超过10秒显示"已同步"
   - 动画：无

4. **同步失败（Failed）**
   - 触发条件：同步过程中发生错误
   - 视觉：红色 Badge + AlertCircle 图标
   - 文本：显示"同步失败"
   - 动画：无

### 1.2 状态转换规则

```
尚未同步 → 同步中（用户触发同步或自动同步启动）
同步中 → 已同步（同步成功）
同步中 → 同步失败（同步出错）
同步失败 → 同步中（用户重试）
已同步 → 同步中（检测到新变更或用户手动触发）
```

**约束**：
- 不允许从 `已同步` 直接转换到 `同步失败`（必须经过 `同步中`）
- 不允许从 `尚未同步` 直接转换到 `已同步` 或 `同步失败`（必须经过 `同步中`）
- 允许从任何状态转换到 `同步中`（用户可随时手动触发同步）

---

## 2. 交互行为和数据模型

### 2.1 交互行为

**点击行为**：
- 用户点击同步状态指示器 → 打开"同步详情对话框"
- 对话框显示：
  - 当前同步状态和描述
  - 已发现的设备列表（显示设备名称、连接状态、上次可见时间）
  - 同步统计信息（已同步卡片数、数据大小）
  - 最近同步历史（最近10条同步事件）
  - 手动操作按钮（"立即同步"、"刷新设备列表"）
  - 如果是失败状态，显示错误信息和"重试"按钮

**无障碍支持**：
- 尚未同步：语义标签"尚未同步，点击查看详情"
- 同步中：语义标签"正在同步数据，点击查看详情"
- 已同步：语义标签"已同步，数据最新，点击查看详情"
- 同步失败：语义标签"同步失败，点击查看详情并重试"

### 2.2 数据模型

```dart
enum SyncState {
  notYetSynced,  // 尚未同步
  syncing,       // 同步中
  synced,        // 已同步
  failed,        // 同步失败
}

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

## 3. 边界条件和错误处理

### 3.1 边界条件

**时间显示边界**：
- `lastSyncTime == null` → 状态必须是 `notYetSynced`
- `lastSyncTime != null` 且距离现在 ≤ 10秒 → 显示"刚刚"
- `lastSyncTime != null` 且距离现在 > 10秒 → 显示"已同步"

**状态一致性约束**：
- `state == notYetSynced` 时，`lastSyncTime` 必须为 `null`
- `state == failed` 时，`errorMessage` 必须非空
- `state == syncing` 时，不更新 `lastSyncTime`（保持上次成功同步的时间）
- `state == synced` 时，`lastSyncTime` 必须非空且为最新同步时间

**状态转换约束**：
- 不允许从 `synced` 直接转换到 `failed`（必须经过 `syncing`）
- 不允许从 `notYetSynced` 直接转换到 `synced` 或 `failed`（必须经过 `syncing`）
- 允许从任何状态转换到 `syncing`（用户可随时手动触发同步）

### 3.2 错误处理

**网络错误**：
- 无可用对等设备 → 转换到 `failed` 状态，错误信息："未发现可用设备"
- 连接超时 → 转换到 `failed` 状态，错误信息："连接超时"
- 数据传输失败 → 转换到 `failed` 状态，错误信息："数据传输失败"

**数据错误**：
- CRDT 合并失败 → 转换到 `failed` 状态，错误信息："数据合并失败"
- 本地存储错误 → 转换到 `failed` 状态，错误信息："本地存储错误"

**UI 错误处理**：
- 状态流订阅失败 → 显示默认状态 `notYetSynced`
- 时间计算溢出 → 显示"已同步"（不显示具体时间）
- 对话框打开失败 → 静默失败，不影响指示器显示

---

## 4. 性能优化

### 4.1 状态更新优化

- 使用 `Stream.distinct()` 过滤重复状态，避免不必要的 UI 重建
- 相对时间更新：仅在 `synced` 状态且距离同步时间 ≤ 10秒时，每秒更新一次；超过10秒后停止定时器
- 动画优化：仅在 `syncing` 状态时启动旋转动画，其他状态立即停止动画控制器

### 4.2 内存管理

- Widget dispose 时取消状态流订阅
- Widget dispose 时取消相对时间定时器
- Widget dispose 时释放动画控制器

### 4.3 防抖处理

- 状态快速切换（< 300ms）时，延迟 UI 更新以避免闪烁
- 例外：从 `syncing` 到 `synced` 立即更新，不延迟（用户期望即时反馈）

---

## 5. 测试策略

### 5.1 单元测试（SyncStatus 模型）

**测试文件**: `test/models/sync_status_test.dart`

1. `it_should_create_not_yet_synced_status()` - 创建尚未同步状态
2. `it_should_create_syncing_status()` - 创建同步中状态
3. `it_should_create_synced_status_with_time()` - 创建已同步状态（带时间）
4. `it_should_create_failed_status_with_error()` - 创建失败状态（带错误信息）
5. `it_should_enforce_not_yet_synced_has_null_time()` - 验证尚未同步状态时间为空
6. `it_should_enforce_failed_has_error_message()` - 验证失败状态有错误信息
7. `it_should_enforce_synced_has_non_null_time()` - 验证已同步状态时间非空

### 5.2 Widget 测试（SyncStatusIndicator）

**测试文件**: `test/widgets/sync_status_indicator_test.dart`

#### 渲染测试

1. `it_should_show_not_yet_synced_badge()` - 显示尚未同步徽章
   - ✅ 验证显示灰色 Badge
   - ✅ 验证显示 CloudOff 图标
   - ✅ 验证显示"尚未同步"文本
   - ✅ 验证无动画

2. `it_should_show_syncing_badge_with_animation()` - 显示同步中徽章（带动画）
   - ✅ 验证显示次要色 Badge
   - ✅ 验证显示 RefreshCw 图标
   - ✅ 验证显示"同步中..."文本
   - ✅ 验证图标旋转动画（360° 每2秒）

3. `it_should_show_synced_badge_with_just_now_text()` - 显示"刚刚"文本（10秒内）
   - ✅ 验证显示白色边框 Badge
   - ✅ 验证显示绿色 Check 图标
   - ✅ 验证显示"刚刚"文本
   - ✅ 验证无动画

4. `it_should_show_synced_badge_with_synced_text()` - 显示"已同步"文本（超过10秒）
   - ✅ 验证显示白色边框 Badge
   - ✅ 验证显示绿色 Check 图标
   - ✅ 验证显示"已同步"文本
   - ✅ 验证无动画

5. `it_should_show_failed_badge()` - 显示同步失败徽章
   - ✅ 验证显示红色 Badge
   - ✅ 验证显示 AlertCircle 图标
   - ✅ 验证显示"同步失败"文本
   - ✅ 验证无动画

6. `it_should_use_correct_colors_for_each_state()` - 验证每个状态的颜色正确
   - ✅ 尚未同步：灰色
   - ✅ 同步中：次要色
   - ✅ 已同步：白色边框
   - ✅ 同步失败：红色

7. `it_should_use_correct_icons_for_each_state()` - 验证每个状态的图标正确
   - ✅ 尚未同步：CloudOff
   - ✅ 同步中：RefreshCw
   - ✅ 已同步：Check（绿色）
   - ✅ 同步失败：AlertCircle

#### 交互测试

8. `it_should_open_details_dialog_on_tap()` - 点击打开详情对话框
   - ✅ 模拟用户点击指示器
   - ✅ 验证详情对话框显示
   - ✅ 验证对话框包含当前状态信息
   - ✅ 验证对话框包含设备列表
   - ✅ 验证对话框包含同步历史

9. `it_should_have_correct_semantic_labels()` - 验证无障碍标签正确
   - ✅ 尚未同步：语义标签"尚未同步，点击查看详情"
   - ✅ 同步中：语义标签"正在同步数据，点击查看详情"
   - ✅ 已同步：语义标签"已同步，数据最新，点击查看详情"
   - ✅ 同步失败：语义标签"同步失败，点击查看详情并重试"

#### 状态更新测试

10. `it_should_update_when_status_changes()` - 状态变化时更新显示
    - ✅ 创建初始状态为"尚未同步"的指示器
    - ✅ 模拟状态流发出"同步中"状态
    - ✅ 验证指示器更新为"同步中"样式
    - ✅ 模拟状态流发出"已同步"状态
    - ✅ 验证指示器更新为"已同步"样式
    - ✅ 验证过渡动画流畅

11. `it_should_filter_duplicate_status_updates()` - 过滤重复状态更新
    - ✅ 创建指示器
    - ✅ 模拟状态流连续发出3次相同状态
    - ✅ 验证 UI 只重建1次
    - ✅ 验证性能优化生效

12. `it_should_update_relative_time_display()` - 更新相对时间显示
    - ✅ 创建"已同步"状态（5秒前）
    - ✅ 验证显示"刚刚"
    - ✅ 等待10秒
    - ✅ 验证显示"已同步"
    - ✅ 验证定时器停止

#### 资源管理测试

13. `it_should_stop_timer_when_disposed()` - dispose 时停止定时器
    - ✅ 创建"已同步"状态指示器（启动定时器）
    - ✅ 调用 dispose
    - ✅ 验证定时器被取消
    - ✅ 验证不再有内存泄漏

14. `it_should_cancel_subscription_when_disposed()` - dispose 时取消订阅
    - ✅ 创建指示器（订阅状态流）
    - ✅ 调用 dispose
    - ✅ 验证流订阅被取消
    - ✅ 验证不再接收状态更新

### 5.3 Widget 测试（SyncDetailsDialog）

**测试文件**: `test/widgets/sync_details_dialog_test.dart`

#### 渲染测试

1. `it_should_show_current_status()` - 显示当前状态
   - ✅ 打开对话框
   - ✅ 验证显示当前同步状态（尚未同步/同步中/已同步/同步失败）
   - ✅ 验证显示状态描述文本
   - ✅ 验证状态图标正确

2. `it_should_show_device_list()` - 显示设备列表
   - ✅ 打开对话框（有3个已发现设备）
   - ✅ 验证显示设备列表
   - ✅ 验证每个设备显示名称
   - ✅ 验证显示连接状态（已连接/未连接）
   - ✅ 验证显示上次可见时间

3. `it_should_show_sync_statistics()` - 显示同步统计
   - ✅ 打开对话框
   - ✅ 验证显示已同步卡片数量
   - ✅ 验证显示同步数据大小
   - ✅ 验证显示成功/失败同步次数

4. `it_should_show_sync_history()` - 显示同步历史
   - ✅ 打开对话框（有同步历史）
   - ✅ 验证显示最近10条同步事件
   - ✅ 验证每个事件显示时间戳
   - ✅ 验证每个事件显示成功/失败状态
   - ✅ 验证每个事件显示涉及的设备

#### 错误状态测试

5. `it_should_show_error_message_when_failed()` - 失败时显示错误信息
   - ✅ 打开对话框（状态为失败）
   - ✅ 验证显示错误消息
   - ✅ 验证错误消息内容正确（"未发现可用设备"等）
   - ✅ 验证显示错误图标

6. `it_should_show_retry_button_when_failed()` - 失败时显示重试按钮
   - ✅ 打开对话框（状态为失败）
   - ✅ 验证显示"重试"按钮
   - ✅ 验证按钮可点击
   - ✅ 验证按钮样式正确

#### 交互测试

7. `it_should_trigger_sync_on_retry()` - 点击重试触发同步
   - ✅ 打开对话框（状态为失败）
   - ✅ 模拟点击"重试"按钮
   - ✅ 验证调用同步 API
   - ✅ 验证状态更新为"同步中"
   - ✅ 验证按钮变为禁用状态（防止重复点击）

8. `it_should_trigger_sync_on_sync_now_button()` - 点击立即同步按钮触发同步
   - ✅ 打开对话框（任意状态）
   - ✅ 模拟点击"立即同步"按钮
   - ✅ 验证调用同步 API
   - ✅ 验证状态更新为"同步中"
   - ✅ 验证显示同步进度

9. `it_should_refresh_devices_on_refresh_button()` - 点击刷新按钮刷新设备列表
   - ✅ 打开对话框
   - ✅ 模拟点击"刷新设备列表"按钮
   - ✅ 验证调用设备扫描 API
   - ✅ 验证设备列表更新
   - ✅ 验证显示刷新动画

10. `it_should_dismiss_on_close()` - 点击关闭按钮关闭对话框
    - ✅ 打开对话框
    - ✅ 模拟点击关闭按钮
    - ✅ 验证对话框关闭
    - ✅ 验证关闭动画流畅

#### 实时更新测试

11. `it_should_update_status_in_realtime()` - 实时更新状态
    - ✅ 打开对话框（状态为"同步中"）
    - ✅ 模拟状态流发出"已同步"状态
    - ✅ 验证对话框内状态实时更新
    - ✅ 验证不需要手动刷新

12. `it_should_update_device_list_in_realtime()` - 实时更新设备列表
    - ✅ 打开对话框
    - ✅ 模拟发现新设备
    - ✅ 验证设备列表自动更新
    - ✅ 验证新设备显示在列表中

---

## 6. 实现文件结构

### 6.1 规格文档

- `openspec/specs/features/sync_feedback/desktop.md` - 桌面端同步状态指示器规格（已更新）
- `openspec/specs/features/sync_feedback/sync_details_dialog.md` - 同步详情对话框规格（保持现有）
- `openspec/specs/features/sync_feedback/shared.md` - 通用规格（定义状态机等共享逻辑）

**注意**：移动端不需要 `mobile.md` 规格文档，因为移动端不显示同步状态指示器。

### 6.2 Flutter 实现

- `lib/models/sync_status.dart` - SyncStatus 数据模型
- `lib/widgets/sync_status_indicator.dart` - 同步状态指示器 Widget
- `lib/widgets/sync_details_dialog.dart` - 同步详情对话框 Widget

### 6.3 测试文件

- `test/models/sync_status_test.dart` - SyncStatus 模型单元测试（7个测试）
- `test/widgets/sync_status_indicator_test.dart` - 指示器 Widget 测试（13个测试）
- `test/widgets/sync_details_dialog_test.dart` - 对话框 Widget 测试（10个测试）

---

## 7. 验收标准

### 7.1 功能完整性

- [ ] 4个状态（尚未同步、同步中、已同步、同步失败）正确显示
- [ ] 相对时间显示正确（10秒内"刚刚"，超过10秒"已同步"）
- [ ] 同步中状态图标旋转动画流畅
- [ ] 点击指示器打开详情对话框
- [ ] 详情对话框显示设备列表、统计信息、同步历史
- [ ] 失败状态显示错误信息和重试按钮
- [ ] 重试按钮触发同步操作

### 7.2 测试覆盖

- [ ] 所有单元测试通过（7个测试）
- [ ] 所有 Widget 测试通过（23个测试）
- [ ] 测试覆盖率 ≥ 90%

### 7.3 代码质量

- [ ] 遵循 Project Guardian 约束
- [ ] 通过 `flutter analyze` 静态检查
- [ ] 通过 `dart format` 格式检查
- [ ] 代码审查通过

### 7.4 文档完整性

- [ ] 规格文档更新完成
- [ ] 测试用例与规格对应
- [ ] 代码注释清晰

---

## 8. 状态机图

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

## 9. 设计决策记录

### 9.1 为什么选择 Badge 组件？

- **简洁性**：Badge 组件提供了紧凑的视觉表达，适合在 AppBar 中显示
- **一致性**：与 React UI 参考保持一致，降低设计和实现成本
- **可扩展性**：Badge 支持多种变体（outline、secondary、destructive），满足不同状态的视觉需求

### 9.2 为什么选择10秒作为相对时间阈值？

- **用户感知**：10秒内用户仍然感知为"刚刚发生"
- **性能考虑**：超过10秒后停止定时器，避免不必要的 UI 更新
- **简化实现**：相比 React UI 的多级时间显示（秒、分钟），简化版本更易维护

### 9.3 为什么添加"尚未同步"状态？

- **用户体验**：明确告知用户应用尚未执行过同步，避免混淆
- **状态完整性**：覆盖应用首次启动的初始状态
- **文案优化**："尚未同步"比"从未同步"更温和，强调临时性而非永久性

### 9.4 为什么移动端不显示同步状态指示器？

- **屏幕空间**：移动端屏幕空间有限，AppBar 需要优先显示核心功能
- **交互模式**：移动端用户通过底部导航访问设备和设置标签页，可以在那里查看同步信息
- **平台一致性**：遵循项目的平台特定设计原则，移动端和桌面端采用不同的 UI 布局
- **React UI 参考**：React UI 参考实现中使用 `hidden lg:flex` 隐藏移动端的同步状态指示器

---

**最后更新**: 2026-01-25
**作者**: CardMind Team
