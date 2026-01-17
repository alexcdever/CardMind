## Context

### 背景
SP-FLUT-010 同步反馈交互规格已完成 Flutter UI 实现，包括：
- 4 状态状态机（disconnected → syncing → synced / failed）
- SyncStatusIndicator 组件（图标、动画、颜色）
- SyncDetailsDialog 详情对话框
- 27 个 Flutter 测试全部通过

Rust 端已扩展 `SyncStatus` 结构体和 `SyncState` 枚举，但 `get_sync_status_stream()` 和 `retry_sync()` 只是框架实现，缺少实际功能。

### 当前状态
- `P2PSyncService` 维护同步状态，但没有状态变化通知机制
- `get_sync_status()` 只能获取当前状态快照
- Flutter 端使用静态的 `SyncStatus.disconnected()` 作为占位符
- 无法实时响应同步状态变化

### 约束
- 必须使用 flutter_rust_bridge 2.11.1 的 Stream 支持
- 必须支持多个订阅者（Flutter 可能有多个 widget 订阅）
- 状态变化必须在 500ms 内推送到 Flutter
- 必须避免内存泄漏（正确管理订阅生命周期）

### 利益相关者
- **Flutter 开发者**: 需要简单的 Stream API 订阅状态
- **Rust 开发者**: 需要清晰的状态变化触发点
- **用户**: 需要实时、准确的同步状态反馈

---

## Goals / Non-Goals

### Goals
1. **实现状态变化通知机制**: 在 P2PSyncService 中添加状态变化事件系统
2. **实现真正的 Stream API**: `get_sync_status_stream()` 返回可订阅的 Stream
3. **实现重试功能**: `retry_sync()` 能够重新启动同步
4. **支持多订阅者**: 使用 broadcast channel 支持多个 Flutter widget 订阅
5. **Flutter 端集成**: 在 HomeScreen 中使用 StreamBuilder 订阅状态

### Non-Goals
1. **不实现同步逻辑**: P2P 同步逻辑已存在，本 change 只添加状态通知
2. **不修改状态机**: 4 状态状态机已在 SP-FLUT-010 中定义，不做修改
3. **不实现 UI 组件**: Flutter UI 组件已完成，只需集成 Stream
4. **不实现持久化**: 状态变化不需要持久化到数据库

---

## Decisions

### Decision 1: 使用 tokio broadcast channel 实现状态广播

**选择**: 使用 `tokio::sync::broadcast` channel

**理由**:
- 原生支持多个订阅者（broadcast 语义）
- 与 tokio 异步运行时集成良好
- 自动处理慢消费者（lagged 机制）
- 性能优秀，适合高频状态更新

**替代方案**:
- `tokio::sync::watch`: 只保留最新值，订阅者可能错过中间状态
- `async_broadcast`: 第三方库，增加依赖
- 手动管理订阅者列表: 复杂度高，容易出错

**实现**:
```rust
use tokio::sync::broadcast;

pub struct P2PSyncService {
    status_tx: broadcast::Sender<SyncStatus>,
    // ... 其他字段
}

impl P2PSyncService {
    pub fn new() -> Self {
        let (status_tx, _) = broadcast::channel(100); // 缓冲 100 个状态
        Self { status_tx, /* ... */ }
    }

    fn notify_status_change(&self, status: SyncStatus) {
        let _ = self.status_tx.send(status); // 忽略发送错误（无订阅者时）
    }
}
```

### Decision 2: 在关键同步事件点触发状态变化

**选择**: 在以下时机触发状态通知
1. 发现新对等设备 → `syncing`
2. 同步完成 → `synced`
3. 同步失败 → `failed`
4. 所有对等设备断开 → `disconnected`
5. 重试同步 → `syncing`

**理由**:
- 覆盖所有状态转换
- 与 SP-FLUT-010 定义的状态机一致
- 触发点明确，易于实现和测试

**实现位置**:
- `P2PSyncService::handle_peer_discovered()` → syncing
- `P2PSyncService::handle_sync_complete()` → synced
- `P2PSyncService::handle_sync_error()` → failed
- `P2PSyncService::handle_peer_disconnected()` → disconnected (如果无其他 peer)

### Decision 3: flutter_rust_bridge Stream 集成方式

**选择**: 使用 `StreamSink` 模式

**理由**:
- flutter_rust_bridge 2.11.1 原生支持
- 自动处理跨语言 Stream 转换
- Flutter 端可直接使用 `Stream<SyncStatus>`

**实现**:
```rust
#[flutter_rust_bridge::frb]
pub fn get_sync_status_stream() -> impl Stream<Item = SyncStatus> {
    let rx = SYNC_SERVICE.with(|s| {
        s.borrow()
            .as_ref()
            .map(|service| service.status_tx.subscribe())
    });

    // 转换为 Stream
    tokio_stream::wrappers::BroadcastStream::new(rx)
        .filter_map(|r| r.ok())
}
```

**Flutter 端使用**:
```dart
StreamBuilder<SyncStatus>(
  stream: getSyncStatusStream(),
  builder: (context, snapshot) {
    final status = snapshot.data ?? SyncStatus.disconnected();
    return SyncStatusIndicator(status: status);
  },
)
```

### Decision 4: 状态去重和 debounce 策略

**选择**: 在 Rust 端实现去重，在 Flutter 端实现 debounce

**理由**:
- **Rust 端去重**: 避免发送重复状态，减少跨语言通信开销
- **Flutter 端 debounce**: 避免 UI 闪烁，Flutter Stream API 更方便

**实现**:
```rust
// Rust 端去重
fn notify_status_change(&mut self, new_status: SyncStatus) {
    if self.last_status != Some(new_status.clone()) {
        self.last_status = Some(new_status.clone());
        let _ = self.status_tx.send(new_status);
    }
}
```

```dart
// Flutter 端 debounce
stream: getSyncStatusStream()
    .distinct()  // 额外保险
    .debounceTime(Duration(milliseconds: 500)),
```

### Decision 5: 重试逻辑实现

**选择**: `retry_sync()` 清除错误状态并重新触发同步

**理由**:
- 简单直接，不需要复杂的重试策略
- 用户主动触发，不需要自动重试
- 可以复用现有的同步逻辑

**实现**:
```rust
pub async fn retry_sync() -> Result<()> {
    with_sync_service(|service| {
        // 清除错误状态
        service.clear_error();

        // 触发状态变化
        service.notify_status_change(SyncStatus::syncing(0));

        // 重新启动同步（如果有已知的 peer）
        service.restart_sync()?;

        Ok(())
    })
}
```

---

## Risks / Trade-offs

### Risk 1: broadcast channel 缓冲区溢出

**风险**: 如果状态变化频率过高，缓冲区可能溢出，导致订阅者错过状态

**缓解措施**:
- 设置合理的缓冲区大小（100 个状态）
- 在 Rust 端实现去重，减少状态发送频率
- 监控 `RecvError::Lagged` 错误，记录日志
- 在 Flutter 端使用 debounce 减少处理频率

### Risk 2: 内存泄漏（订阅未取消）

**风险**: 如果 Flutter widget dispose 时未取消订阅，可能导致内存泄漏

**缓解措施**:
- 使用 StreamBuilder（自动管理订阅）
- 在 widget dispose 时确保 Stream 被取消
- 添加内存泄漏检测测试
- broadcast channel 会自动清理断开的订阅者

### Risk 3: 状态不一致（竞态条件）

**风险**: 多个线程同时修改状态，可能导致状态不一致

**缓解措施**:
- 使用 `Arc<Mutex<P2PSyncService>>` 保护状态
- 所有状态修改都通过 `notify_status_change()` 方法
- 添加状态转换验证（确保合法的状态转换）
- 添加单元测试验证并发场景

### Risk 4: flutter_rust_bridge Stream 性能

**风险**: 跨语言 Stream 可能有性能开销

**缓解措施**:
- 在 Rust 端实现去重，减少跨语言调用
- 使用 debounce 减少 Flutter 端处理频率
- 监控性能指标，确保状态更新在 500ms 内
- 如果性能不足，考虑使用轮询作为降级方案

### Risk 5: 与现有代码的兼容性

**风险**: 修改 P2PSyncService 可能影响现有功能

**缓解措施**:
- 保持现有 API 不变（`get_sync_status()` 仍然可用）
- 新增功能向后兼容
- 运行所有现有测试确保无回归
- 逐步迁移，先实现 Stream，再集成到 Flutter

---

## Migration Plan

### 实施步骤

#### Phase 1: Rust 端状态通知机制（1-2 小时）
1. 在 `P2PSyncService` 中添加 `broadcast::Sender<SyncStatus>`
2. 实现 `notify_status_change()` 方法
3. 在关键同步事件点调用 `notify_status_change()`
4. 编写 Rust 单元测试验证状态通知

#### Phase 2: Stream API 实现（1 小时）
1. 实现 `get_sync_status_stream()` 返回真正的 Stream
2. 实现 `retry_sync()` 重试逻辑
3. 重新生成 flutter_rust_bridge 代码
4. 编写 Rust 集成测试验证 Stream

#### Phase 3: Flutter 端集成（1 小时）
1. 在 `HomeScreen` 中使用 StreamBuilder 订阅状态
2. 实现 `distinct()` 和 `debounceTime()`
3. 连接重试按钮到 `retrySync()`
4. 运行 Flutter 测试验证集成

#### Phase 4: 测试和验证（1 小时）
1. 运行所有 Rust 测试
2. 运行所有 Flutter 测试
3. 手动测试状态转换
4. 性能测试（确保 < 500ms）
5. 内存泄漏测试

### 回滚策略
- 如果 Stream 实现有问题，可以回退到轮询方式
- 保留 `get_sync_status()` API 作为降级方案
- 使用 feature flag 控制 Stream 功能开关

### 验证标准
- [ ] 所有 Rust 测试通过
- [ ] 所有 Flutter 测试通过
- [ ] 状态更新延迟 < 500ms
- [ ] 无内存泄漏
- [ ] 代码审查通过

---

## Open Questions

### Q1: 是否需要持久化状态变化历史？

**状态**: ✅ 已解决

**决定**: 不持久化，只保留当前状态（简单）

**理由**: 当前实现已满足需求，状态变化通过 Stream 实时推送，无需持久化历史。

### Q2: 是否需要支持状态变化回调？

**状态**: ✅ 已解决

**决定**: 仅支持 Stream（简单）

**理由**: Stream 已足够灵活，Flutter 端可以使用 StreamBuilder 或 listen 方法订阅。

### Q3: 是否需要在 Rust 端实现 debounce？

**状态**: ✅ 已解决

**决定**: 仅在 Flutter 端 debounce（简单）

**理由**: Flutter 端使用 rxdart 的 debounceTime 实现，性能满足需求（< 500ms）。

### Q4: 是否需要支持状态变化过滤？

**状态**: ✅ 已解决

**决定**: 订阅所有状态变化（简单）

**理由**: Flutter 端可以使用 `distinct()` 和 `where()` 过滤，无需在 Rust 端实现。
