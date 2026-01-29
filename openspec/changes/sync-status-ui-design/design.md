## Context

CardMind 基于 Loro CRDT 的双层架构已经实现，但缺少用户层面的同步状态反馈。当前同步引擎运行在后台，用户无法了解同步进度、发现问题或获取详细统计信息。

根据原始设计文档，React UI 参考实现已经提供了完整的同步状态指示器设计，我们需要将其适配到 Flutter 桌面端，并遵循项目的平台特定设计原则（仅在桌面端显示）。

## Goals / Non-Goals

**Goals:**
- 实现直观的 4 状态同步状态指示器（尚未同步、同步中、已同步、同步失败）
- 提供实时的状态反馈和相对时间显示
- 创建完整的同步详情对话框，包含设备列表、统计信息和历史记录
- 优化性能，避免不必要的 UI 重建和内存泄漏
- 支持无障碍访问和国际化

**Non-Goals:**
- 不修改核心同步引擎逻辑
- 不在移动端显示同步状态指示器
- 不改变现有的数据模型架构

## Decisions

### 1. 使用 Badge 组件作为视觉容器
**决策**: 选择 shadcn/ui 风格的 Badge 组件作为同步状态的视觉容器
**理由**: 
- 提供紧凑的视觉表达，适合在 AppBar 中显示
- 支持多种变体（outline、secondary、destructive），满足不同状态的视觉需求
- 与 React UI 参考保持一致，降低设计和实现成本

### 2. 4 状态机设计
**决策**: 实现 `notYetSynced` → `syncing` → `synced/failed` 的状态机
**理由**:
- 覆盖应用完整的同步生命周期
- 提供明确的状态转换规则和约束
- 避免模糊的状态定义，减少用户困惑

### 3. 相对时间显示策略
**决策**: 10秒内显示"刚刚"，超过10秒显示"已同步"
**理由**:
- 用户在10秒内仍然感知为"刚刚发生"
- 超过10秒后停止定时器，优化性能
- 相比 React UI 的多级时间显示，简化版本更易维护

### 4. 平台特定显示策略
**决策**: 同步状态指示器仅在桌面端显示
**理由**:
- 遵循项目的平台特定设计原则
- 移动端屏幕空间有限，需要优先显示核心功能
- 移动端用户可通过设备和设置标签页访问同步信息

### 5. Stream-based 状态管理
**决策**: 使用 Dart Stream 进行状态管理，配合 `distinct()` 过滤重复更新
**理由**:
- 提供响应式的状态更新机制
- 自然支持防抖和性能优化
- 与 Flutter 生态系统良好集成

## Visual Specifications

### State Visual Mapping

| 状态 | Badge 样式 | 图标 | 图标颜色 | 文本 | 动画 |
|------|-----------|------|---------|------|------|
| `notYetSynced` | 灰色 Badge | `CloudOff` | 灰色 | "尚未同步" | 无 |
| `syncing` | 次要色 Badge | `RefreshCw` | 次要色 | "同步中..." | 360° 旋转，2秒/周 |
| `synced` (≤10s) | 白色边框 Badge | `Check` | 绿色 | "刚刚" | 无 |
| `synced` (>10s) | 白色边框 Badge | `Check` | 绿色 | "已同步" | 无 |
| `failed` | 红色 Badge | `AlertCircle` | 红色 | "同步失败" | 无 |

### Animation Parameters

**同步中旋转动画**:
- 旋转角度: 360°
- 动画时长: 2000ms (2秒)
- 动画曲线: `Curves.linear`
- 重复模式: 无限循环 (`repeat: true`)

**相对时间更新**:
- 更新间隔: 1000ms (1秒)
- 触发条件: `state == synced` 且 `lastSyncTime` 距离现在 ≤ 10秒
- 停止条件: 超过 10秒后停止定时器

### Accessibility Labels

| 状态 | 语义标签 |
|------|---------|
| `notYetSynced` | "尚未同步，点击查看详情" |
| `syncing` | "正在同步数据，点击查看详情" |
| `synced` | "已同步，数据最新，点击查看详情" |
| `failed` | "同步失败，点击查看详情并重试" |

## Performance Optimization Strategies

### 1. State Update Optimization

**Stream 去重**:
```dart
syncStatusStream
  .distinct((prev, next) => prev.state == next.state &&
                            prev.lastSyncTime == next.lastSyncTime &&
                            prev.errorMessage == next.errorMessage)
  .listen((status) {
    // 仅在状态真正变化时更新 UI
  });
```

**防抖处理**:
- 状态快速切换（< 300ms）时，延迟 UI 更新以避免闪烁
- 例外：从 `syncing` 到 `synced` 立即更新，不延迟（用户期望即时反馈）

```dart
syncStatusStream
  .debounceTime(Duration(milliseconds: 300))
  .listen((status) {
    // 延迟更新，避免闪烁
  });
```

### 2. Timer Management

**相对时间定时器**:
- 仅在 `synced` 状态且距离同步时间 ≤ 10秒时启动
- 每秒更新一次显示文本
- 超过 10秒后自动停止定时器

```dart
Timer? _relativeTimeTimer;

void _startRelativeTimeTimer() {
  _relativeTimeTimer?.cancel();
  if (state == SyncState.synced && _isWithin10Seconds()) {
    _relativeTimeTimer = Timer.periodic(Duration(seconds: 1), (_) {
      if (!_isWithin10Seconds()) {
        _relativeTimeTimer?.cancel();
      }
      setState(() {});
    });
  }
}
```

### 3. Animation Controller Management

**动画控制器生命周期**:
- 仅在 `syncing` 状态时启动旋转动画
- 其他状态立即停止动画控制器
- Widget dispose 时释放动画控制器

```dart
AnimationController? _rotationController;

void _updateAnimation() {
  if (state == SyncState.syncing) {
    _rotationController?.repeat();
  } else {
    _rotationController?.stop();
  }
}

@override
void dispose() {
  _rotationController?.dispose();
  super.dispose();
}
```

### 4. Resource Cleanup

**Widget dispose 清理清单**:
- ✅ 取消 Stream 订阅
- ✅ 取消相对时间定时器
- ✅ 释放动画控制器
- ✅ 清理对话框资源

```dart
@override
void dispose() {
  _statusSubscription?.cancel();
  _relativeTimeTimer?.cancel();
  _rotationController?.dispose();
  super.dispose();
}
```

## Data Models

### 性能风险: 状态更新频率过高
**风险**: 同步状态可能频繁变化，导致 UI 过度重建
**缓解**: 
- 使用 `Stream.distinct()` 过滤重复状态
- 实现防抖机制（300ms 延迟）
- 仅在必要时启动定时器和动画

### 内存风险: 资源泄漏
**风险**: Stream 订阅、定时器、动画控制器未正确释放
**缓解**:
- 在 Widget dispose 时严格取消所有订阅
- 实现资源清理检查清单
- 添加内存泄漏测试用例

### 用户体验风险: 状态不一致
**风险**: UI 状态与实际同步状态不同步
**缓解**:
- 实现严格的状态一致性验证
- 添加边界条件检查和错误处理
- 提供手动刷新机制

### 复杂性风险: 状态机过于复杂
**风险**: 4 状态机可能难以维护和测试
**缓解**:
- 使用枚举明确定义状态
- 实现状态转换验证逻辑
- 提供完整的测试覆盖

## Data Models

### SyncState Enum

```dart
enum SyncState {
  notYetSynced,  // 尚未同步
  syncing,       // 同步中
  synced,        // 已同步
  failed,        // 同步失败
}
```

### SyncStatus Class

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
    // notYetSynced 状态时，lastSyncTime 必须为 null
    if (state == SyncState.notYetSynced && lastSyncTime != null) {
      return false;
    }
    // failed 状态时，errorMessage 必须非空
    if (state == SyncState.failed && (errorMessage == null || errorMessage!.isEmpty)) {
      return false;
    }
    // synced 状态时，lastSyncTime 必须非空
    if (state == SyncState.synced && lastSyncTime == null) {
      return false;
    }
    return true;
  }
}
```

### State Transition Rules

**允许的状态转换**:
- `notYetSynced` → `syncing` (用户触发同步或自动同步启动)
- `syncing` → `synced` (同步成功)
- `syncing` → `failed` (同步出错)
- `failed` → `syncing` (用户重试)
- `synced` → `syncing` (检测到新变更或用户手动触发)

**禁止的状态转换**:
- `synced` → `failed` (必须经过 `syncing`)
- `notYetSynced` → `synced` (必须经过 `syncing`)
- `notYetSynced` → `failed` (必须经过 `syncing`)

### Error Types

系统定义以下错误类型和对应的中文错误消息：

| 错误类型 | 错误消息 | 触发条件 |
|---------|---------|---------|
| `NO_AVAILABLE_PEERS` | "未发现可用设备" | 无可用对等设备 |
| `CONNECTION_TIMEOUT` | "连接超时" | 连接超时 |
| `DATA_TRANSMISSION_FAILED` | "数据传输失败" | 数据传输失败 |
| `CRDT_MERGE_FAILED` | "数据合并失败" | CRDT 合并失败 |
| `LOCAL_STORAGE_ERROR` | "本地存储错误" | 本地存储错误 |

## Migration Plan

### Phase 1: 基础模型和状态机
1. 创建 `SyncStatus` 和 `SyncState` 数据模型
2. 实现状态转换逻辑和验证
3. 添加单元测试覆盖

### Phase 2: UI 组件实现
1. 实现 `SyncStatusIndicator` Widget
2. 添加视觉效果和动画
3. 实现点击交互和对话框

### Phase 3: 性能优化和错误处理
1. 添加 Stream 防抖和去重
2. 实现资源管理和清理
3. 添加边界条件处理

### Phase 4: 测试和验证
1. 完善 Widget 测试覆盖
2. 添加集成测试
3. 进行性能基准测试

## Open Questions

1. **动画性能**: 360° 每2秒的旋转动画在低端设备上的性能表现如何？
2. **错误信息格式**: 不同类型的同步错误是否需要不同的用户提示？
3. **历史记录保留**: 同步历史记录需要保留多长时间？
4. **国际化细节**: "刚刚"、"已同步"等文本在不同语言下的最佳实践？