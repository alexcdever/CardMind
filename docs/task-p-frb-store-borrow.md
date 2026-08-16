## 任务 P

修复任务 O 在真实 Windows + Android FRB 平台联调中暴露的 **RustArc 被 start_receiver 消费** 缺陷。

## 真实双端证据

任务 O 合并、重新生成 FRB、重新构建 Windows/Android 后，两端日志一致：

```text
event=receiver.start action=success
# 下一周期：
event=sync.cycle
error="DroppableDisposedException: Try to use RustArc<dynamic> after it has been disposed"
```

Windows 和 Android 都复现，说明不是平台网络问题。

## 根因

Rust API 当前签名：

```rust
pub async fn start_receiver(svc: &SyncService, store: NoteStore) -> anyhow::Result<()>
```

Flutter 调用：

```dart
api.startReceiver(svc: _sync, store: _store)
```

`store: NoteStore` 按值跨 FRB 边界，生成绑定把 Dart `_store` 对应 RustArc 视为 move/消费；`startReceiver` 返回后 `_store` 在 Dart 侧已 disposed。下一次 `runSyncCycle(svc: _sync, store: _store)` 立即抛 `DroppableDisposedException`。

接收器内部确实需要持有 store clone，但应在 Rust API 内 clone：

```rust
pub async fn start_receiver(svc: &SyncService, store: &NoteStore) -> anyhow::Result<()> {
    svc.start_receiver(store.clone()).await
}
```

具体实现由 executor 核实 FRB 2.12 的 opaque 所有权生成结果后完成。

## 主仓库与 worktree

- 主仓库：`D:/Projects/CardMind`，分支 `codex/knowledge-base` 保持不动
- worktree：`D:/Projects/CardMind/.worktrees/receiver-store-borrow`
- 分支：`codex/receiver-store-borrow`

## 改动范围

- `rust-backend/src/api.rs`
- FRB 生成文件（Rust/Dart）
- `lib/bridge/sync_scheduler.dart`：仅在生成 API 调用形态变化时修改
- Rust/Flutter/平台回归测试
- 禁止修改 receiver 核心行为、TAP/网络、`.gitignore`、prototype

## TDD 验收

### 红阶段

1. `start_receiver does not consume store RustArc`：真实 FRB repository/bridge 测试：创建 SyncService + NoteStore → 调 startReceiver → 立即调用 `listPairedDevices(store)`、`runSyncCycle(store)` 或其它使用同一 Store 的 API；当前代码必须真实失败为 DroppableDisposedException。
2. `start_receiver then periodic cycle reproduces disposed arc`：Flutter SyncScheduler 使用真实 FRB API，start 后运行一个 cycle；当前实现失败，保留红输出。
3. 测试必须使用真实生成绑定和真实 RustArc，不能 fake SyncApi 代替缺陷回归。

### 绿阶段

4. Rust `start_receiver` API 边界改为借用 `&NoteStore`，内部 clone 后交给后台 receiver。
5. FRB 生成绑定确认 Dart 调用后 `_store` 仍可复用；codegen 输出中参数编码语义与借用一致。
6. `start_receiver does not consume store RustArc` 转绿：start 后至少连续调用 3 个 Store API 均成功。
7. `periodic cycle after receiver start` 转绿：start 后 runSyncCycle 不抛 disposed，正常返回。
8. `receiver stop then store reuse`：stop 后同一 Store 仍可查询/写入。
9. `receiver repeated start is idempotent and store reusable`：重复 start 不消费/释放 Store。
10. `receiver failure does not dispose store`：start 返回错误时 Store 仍可用。

### 回归与真实联调

11. `receiver_continuous_test` 14/14 全绿。
12. `cargo test` 每个测试进程 180 秒硬上限，全绿。
13. `flutter test --timeout 3m` 全绿。
14. `flutter analyze` 无 error。
15. FRB codegen 连续两次幂等。
16. 真实 Windows 平台：启动后 receiver.start success，至少两次周期 sync.cycle 不出现 DroppableDisposedException。
17. 真实 Android 模拟器（默认 NAT，启动前清除 HTTP_PROXY/HTTPS_PROXY/ALL_PROXY）：同上，不出现 disposed。
18. 两端已有配对记录条件下：Windows push → Android `sync.receive` / `sync.import` → 双方 `device.last_seen` 更新 → 设备页 5 秒内显示在线。
19. 真实 dogcloud relay 测试仍通过，3 分钟硬上限。
20. 日志脱敏不回归。
21. `git status` 只含任务范围，`.gitignore` 无差异。

## 需决策点

1. FRB 不支持 `&NoteStore` opaque 参数生成：停下报告生成器限制，提出最小替代（例如 Rust API 内通过 service 持有/获取 store handle），不得在 Dart 侧复制或绕过 disposed 检查。
2. 改为借用后仍出现 disposed，且是 `svc` 被消费：停下附生成绑定证据，不猜测。
3. 平台真实测试无法启动：明确未覆盖，不声称通过。

## 测试纪律

所有测试默认 3 分钟超时。Rust 网络/阻塞操作和 spawned task 两侧必须有 timeout；单个测试进程超过 180 秒立即停止查因。不要把编译时间和多个独立测试套件累计误判为单个测试挂死。
