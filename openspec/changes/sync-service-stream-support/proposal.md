## Why

当前 SP-FLUT-010 同步反馈交互规格的 Flutter UI 已完整实现，但 Rust 端的 `P2PSyncService` 缺少状态变化通知机制。现有的 `get_sync_status()` 只能获取当前状态快照，无法实时推送状态变化。需要实现基于 Stream 的状态通知机制，使 Flutter 端能够实时响应同步状态变化。

## What Changes

- **新增** `P2PSyncService` 状态变化事件系统
- **新增** 状态变化广播机制（支持多个订阅者）
- **修改** `get_sync_status_stream()` 从框架实现改为真正的 Stream
- **修改** `retry_sync()` 实现实际的重试逻辑
- **新增** 状态转换日志和监控
- **修改** `P2PSyncService` 在状态变化时触发通知
- **新增** Flutter 端 StreamBuilder 集成示例

## Capabilities

### New Capabilities
- `sync-status-stream`: P2PSyncService 实时状态推送机制，包括状态变化事件、广播系统、订阅管理

### Modified Capabilities
- `SP-SYNC-006`: 同步层规格 - 添加状态变化通知要求
- `SP-FLUT-010`: 同步反馈交互规格 - 从 Mock 数据改为真实 Stream 集成

## Impact

**受影响的 Rust 代码**:
- `rust/src/p2p/sync_service.rs` - 添加状态变化通知
- `rust/src/api/sync.rs` - 实现真正的 Stream API
- `rust/src/p2p/network.rs` - 可能需要触发状态变化事件

**受影响的 Flutter 代码**:
- `lib/screens/home_screen.dart` - 使用 StreamBuilder 订阅状态
- `lib/widgets/sync_status_indicator.dart` - 可能需要调整以支持 Stream

**依赖**:
- 依赖 flutter_rust_bridge 的 Stream 支持
- 依赖 Rust tokio 的 broadcast channel 或类似机制

**测试**:
- 需要新增 Rust 单元测试验证状态通知
- 需要新增 Flutter 集成测试验证 Stream 订阅
