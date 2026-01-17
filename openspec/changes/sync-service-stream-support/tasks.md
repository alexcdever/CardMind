# Implementation Tasks

## 1. Rust - Broadcast Channel Setup

- [x] 1.1 在 `P2PSyncService` 结构体中添加 `status_tx: broadcast::Sender<SyncStatus>` 字段
- [x] 1.2 在 `P2PSyncService` 结构体中添加 `last_status: Option<SyncStatus>` 字段用于去重
- [x] 1.3 在 `P2PSyncService::new()` 中初始化 broadcast channel（容量 100）
- [x] 1.4 实现 `notify_status_change(&mut self, new_status: SyncStatus)` 方法
- [x] 1.5 在 `notify_status_change()` 中实现状态去重逻辑
- [x] 1.6 在 `notify_status_change()` 中添加状态变化日志（使用 tracing::info）

## 2. Rust - Status Change Triggers

- [x] 2.1 在 `handle_peer_discovered()` 中调用 `notify_status_change()` 触发 syncing 状态
- [x] 2.2 在 `handle_sync_complete()` 中调用 `notify_status_change()` 触发 synced 状态
- [x] 2.3 在 `handle_sync_error()` 中调用 `notify_status_change()` 触发 failed 状态
- [x] 2.4 在 `handle_peer_disconnected()` 中检查是否所有 peer 断开，触发 disconnected 状态
- [x] 2.5 确保所有状态转换都包含完整的 SyncStatus 信息（peer count, error message 等）

## 3. Rust - Stream API Implementation

- [x] 3.1 在 `rust/src/api/sync.rs` 中实现 `get_sync_status_stream()` 函数
- [x] 3.2 添加 `#[flutter_rust_bridge::frb]` 注解到 `get_sync_status_stream()`
- [x] 3.3 使用 `tokio_stream::wrappers::BroadcastStream` 包装 broadcast receiver
- [x] 3.4 实现 `filter_map(|r| r.ok())` 过滤 lagged 错误
- [x] 3.5 确保 Stream 在订阅时立即发送当前状态
- [x] 3.6 添加依赖：`tokio-stream = { version = "0.1", features = ["sync"] }` 到 Cargo.toml

## 4. Rust - Retry Functionality

- [x] 4.1 在 `P2PSyncService` 中实现 `clear_error()` 方法
- [x] 4.2 在 `P2PSyncService` 中实现 `restart_sync()` 方法
- [x] 4.3 在 `rust/src/api/sync.rs` 中实现 `retry_sync()` 函数
- [x] 4.4 添加 `#[flutter_rust_bridge::frb]` 注解到 `retry_sync()`
- [x] 4.5 在 `retry_sync()` 中清除错误状态并触发 syncing 状态
- [x] 4.6 实现并发重试保护（使用 Mutex 或 atomic flag）
- [x] 4.7 处理无可用 peer 的情况，返回适当的错误

## 5. Rust - Unit Tests

- [x] 5.1 编写测试：`it_should_broadcast_status_to_all_subscribers()`
- [x] 5.2 编写测试：`it_should_not_broadcast_duplicate_status()`
- [x] 5.3 编写测试：`it_should_broadcast_when_peer_discovered()`
- [x] 5.4 编写测试：`it_should_broadcast_when_sync_completes()`
- [x] 5.5 编写测试：`it_should_broadcast_when_sync_fails()`
- [x] 5.6 编写测试：`it_should_broadcast_when_peer_disconnects()`
- [x] 5.7 编写测试：`it_should_handle_no_subscribers_gracefully()`
- [x] 5.8 编写测试：`it_should_support_multiple_concurrent_subscriptions()`
- [ ] 5.9 编写测试：`it_should_emit_current_status_on_subscription()`
- [ ] 5.10 编写测试：`it_should_clear_error_on_retry()`
- [ ] 5.11 编写测试：`it_should_restart_sync_on_retry()`
- [ ] 5.12 编写测试：`it_should_handle_concurrent_retries_safely()`

## 6. Rust - Integration Tests

- [x] 6.1 创建 `rust/tests/sp_sync_007_spec.rs` 规格测试文件
- [x] 6.2 编写测试：`it_should_stream_status_to_flutter()`
- [x] 6.3 编写测试：`it_should_handle_flutter_subscription_cancellation()`
- [x] 6.4 编写测试：`it_should_handle_slow_flutter_subscriber()`
- [x] 6.5 编写测试：`it_should_integrate_with_flutter_rust_bridge()`

## 7. Flutter Rust Bridge Generation

- [x] 7.1 运行 `dart tool/generate_bridge.dart` 生成新的 bridge 代码
- [x] 7.2 验证 `getSyncStatusStream()` 在 Dart 中生成为 `Stream<SyncStatus>`
- [x] 7.3 验证 `retrySync()` 在 Dart 中生成为 `Future<void>`
- [x] 7.4 检查生成的代码是否有编译错误
- [x] 7.5 提交生成的 bridge 代码到 git

## 8. Flutter - Stream Integration

- [ ] 8.1 在 `HomeScreen` 的 `initState()` 中订阅 `getSyncStatusStream()`
- [ ] 8.2 对 stream 应用 `distinct()` 过滤器
- [ ] 8.3 对 stream 应用 `debounceTime(Duration(milliseconds: 500))`
- [ ] 8.4 实现 stream 错误处理，fallback 到 `SyncStatus.disconnected()`
- [ ] 8.5 在 `dispose()` 中取消 stream 订阅
- [ ] 8.6 移除 mock stream 实现代码
- [ ] 8.7 更新 `StreamBuilder` 使用真实的 stream

## 9. Flutter - Retry Implementation

- [ ] 9.1 在 `SyncDetailsDialog` 中添加 `_isRetrying` 状态变量
- [ ] 9.2 在 `SyncDetailsDialog` 中添加 `_retryError` 状态变量
- [ ] 9.3 实现 `_handleRetry()` 方法调用 `retrySync()`
- [ ] 9.4 在重试期间显示 loading 状态（CircularProgressIndicator）
- [ ] 9.5 在重试期间禁用重试按钮
- [ ] 9.6 处理重试成功：关闭对话框
- [ ] 9.7 处理重试失败：显示错误消息
- [ ] 9.8 添加重试错误的用户友好提示文本

## 10. Flutter - Widget Tests

- [ ] 10.1 更新测试：`it_should_subscribe_to_real_sync_api_stream()`
- [ ] 10.2 更新测试：`it_should_trigger_real_sync_on_retry()`
- [ ] 10.3 编写测试：`it_should_handle_stream_errors_gracefully()`
- [ ] 10.4 编写测试：`it_should_emit_initial_status_on_subscription()`
- [ ] 10.5 编写测试：`it_should_apply_distinct_filter_to_stream()`
- [ ] 10.6 编写测试：`it_should_apply_debounce_to_stream()`
- [ ] 10.7 编写测试：`it_should_show_loading_state_during_retry()`
- [ ] 10.8 编写测试：`it_should_display_retry_error_message()`
- [ ] 10.9 编写测试：`it_should_disable_retry_button_during_operation()`
- [ ] 10.10 编写测试：`it_should_reconnect_stream_on_error()`

## 11. Flutter - Integration Tests

- [ ] 11.1 编写测试：`it_should_receive_status_from_rust_stream()`
- [ ] 11.2 编写测试：`it_should_call_rust_retry_api()`
- [ ] 11.3 编写测试：`it_should_handle_rust_api_errors()`
- [ ] 11.4 验证 stream 订阅和取消订阅的内存管理

## 12. Testing and Validation

- [ ] 12.1 运行所有 Rust 单元测试：`cd rust && cargo test`
- [ ] 12.2 运行 SP-SYNC-007 规格测试：`cd rust && cargo test --test sp_sync_007_spec`
- [ ] 12.3 运行所有 Flutter 测试：`flutter test`
- [ ] 12.4 运行 Flutter widget 测试：`flutter test test/widgets/sync_status_indicator_test.dart`
- [ ] 12.5 运行 Flutter screen 测试：`flutter test test/screens/home_screen_test.dart`
- [ ] 12.6 手动测试：启动应用，观察状态转换
- [ ] 12.7 手动测试：触发同步失败，验证重试功能
- [ ] 12.8 性能测试：验证状态更新延迟 < 500ms
- [ ] 12.9 内存测试：验证无内存泄漏（多次打开关闭页面）
- [ ] 12.10 运行约束验证：`dart tool/validate_constraints.dart`

## 13. Documentation and Cleanup

- [ ] 13.1 更新 `openspec/specs/README.md` 添加 SP-SYNC-007 规格
- [ ] 13.2 在 design.md 中标记所有 Open Questions 为已解决
- [ ] 13.3 添加代码注释说明 broadcast channel 的使用
- [ ] 13.4 添加代码注释说明状态转换触发点
- [ ] 13.5 更新 CHANGELOG.md 记录此次变更
- [ ] 13.6 检查所有文件使用 Unix 换行符（LF）
- [ ] 13.7 运行 `dart tool/fix_lint.dart` 修复 lint 问题

## 14. Code Review and Finalization

- [ ] 14.1 自我代码审查：检查是否遵循 Project Guardian 约束
- [ ] 14.2 验证没有使用 `unwrap()` 或 `expect()`
- [ ] 14.3 验证所有 API 返回 `Result<T, Error>`
- [ ] 14.4 验证没有直接写 SQLite（只通过 Loro）
- [ ] 14.5 验证所有 Loro 修改后调用了 `commit()`
- [ ] 14.6 准备 PR 描述和测试计划
- [ ] 14.7 创建 git commit
- [ ] 14.8 推送到远程分支并创建 PR
