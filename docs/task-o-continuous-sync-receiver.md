## 任务 O

修复 CardMind **配对后双方持续显示离线、周期同步 push 超时** 的真实双端缺陷。

## 实机证据（任务 N 结构化日志）

配对记录已经成功写入，但 Windows 周期同步失败：

```text
platform=windows event=sync.trigger reason=cycle
platform=windows event=sync.push ids=[88807ca2…fae303d5,e61e52c2…57acfe42]
  error="push timeout after 10s" duration_ms=10001 action=failed
platform=windows event=sync.cycle action=push_failed_silent ok=false
```

Android 同期只有启动事件，没有：

- `sync.receive`
- `sync.import`
- `sync.cycle accepted_push=true`

因此 `paired_devices.last_seen` 没更新，设备页按 5 分钟窗口显示离线。离线是结果，不是根因。

## 根因

现有 `run_sync_cycle` 顺序：

1. 向所有对端 push（每台最多等待 10 秒）
2. push 完成后才调用 `try_accept_push(SYNC_ACCEPT_WINDOW)`

两端都采用“先发后收”，周期时间错开时，A push 期间 B 尚未进入 accept 窗口；A 超时后才进入 accept。B 同理，双方可能长期互相错过。

`SyncScheduler` 没有独立接收循环；应用启动后只启动周期 Timer。

## 设计目标

1. 应用运行期间必须持续提供**有界、可停止、不阻塞编辑/推送**的 push 接收能力。
2. 收到 push 后立即 import、刷新 SQLite 投影并更新对应设备 `last_seen`。
3. 配对握手成功后双方设备记录应立即进入“近期在线”状态，不能必须等下一次同步。
4. 设备页能在后台状态变化后刷新，而不是只在页面首次进入/配对返回时加载一次。
5. 同步调度器停止/应用关闭时接收循环必须在 3 秒内停止，不留下永久 task。
6. 保持现有 relay、直连、mDNS 和配对功能不回归。

## 架构约束

### FRB opaque 锁风险

禁止在 Dart 侧简单 `while(true) await acceptPush()`，因为 FRB opaque `SyncService` 锁可能在整个 await 期间持有写锁，从而阻塞 create/edit/push/close。

executor 必须先做红色并发测试验证：

- 接收等待期间，创建/编辑笔记仍能在 1 秒内完成；
- 主动 push 仍可执行；
- stop 能在 3 秒内返回。

如果 Dart 常驻 await 会占锁，优先在 Rust 内部启动拥有 endpoint clone/独立 channel 的接收任务，或拆分出不需要持有整个 `SyncService` 写锁的接收器。不得用长时间 FRB write lock 作为实现。

### 推荐职责拆分

- 主动周期任务：push pending / 健康检查
- 被动接收任务：短 accept 窗口循环（例如 250–500ms），收到 push 即 import/project/update_last_seen
- 配对帧与 push 帧仍使用统一路由，不丢帧、不互抢
- 接收循环 start 幂等、stop 幂等、重复初始化不产生多个 listener

具体 API 由 executor 根据 iroh/FRB 生命周期设计，但必须满足测试与停止语义。

## 主仓库与 worktree

- 主仓库：`D:/Projects/CardMind`，分支 `codex/knowledge-base` 保持不动
- worktree：`D:/Projects/CardMind/.worktrees/continuous-receiver`
- 分支：`codex/continuous-receiver`
- 创建后验证 `git worktree list`

## 改动范围

- `rust-backend/src/sync.rs`
- `rust-backend/src/api.rs`
- `rust-backend/src/store.rs`（仅 last_seen 更新需要）
- FRB 生成文件（如新增 API）
- `lib/bridge/sync_scheduler.dart`
- `lib/bridge/bridge_helper.dart` / repository 接口与实现（如需）
- `lib/pages/devices_page.dart`（状态刷新）
- 相关 Rust/Flutter 测试

禁止修改 TAP/网卡/ICS/默认路由、防火墙、`.gitignore`、prototype 和产品文档。

## TDD 验收标准

### 红阶段

1. `receiver absent causes push timeout`：复现当前两实例启动调度器后，A push 时 B 没有 accept，10 秒超时；保留红输出。
2. `paired device remains offline without last_seen`：配对成功后 `last_seen` 仍为空或 UI 显示离线，锁定当前缺陷。
3. `symmetric cycles can miss each other`：两端“先 push 后 accept”的周期错位可稳定复现至少一次互相超时。

### 接收循环

4. `receiver starts once and is idempotent`：重复 start 只有一个接收器。
5. `receiver continuously accepts push`：不依赖周期相位，A 在任意时间 push，B 在 10 秒内 receive/import。
6. `receiver stop is bounded`：stop 在 3 秒内返回，停止后不再处理新 push。
7. `receiver does not block edits`：接收等待期间 create/edit 在 1 秒内完成。
8. `receiver does not block outbound push`：接收等待期间仍可主动 push。
9. `pairing and push routing coexist`：配对请求、确认帧、push 帧不会被错误消费者吞掉；现有 pending_pairing 路由不回归。
10. `receiver failure is recoverable`：单次 accept/import 失败记录日志并继续下一窗口；不会永久退出或 busy loop。

### last_seen / 在线状态

11. `pairing success updates both last_seen`：confirm/connect 成功后双方 paired row 的 last_seen 非空、在当前时间窗口内。
12. `received push updates sender last_seen`：接收并导入后更新发送方 last_seen。
13. `successful outbound push updates peer last_seen`：现有成功 push 更新保持正确。
14. `failed push does not mark online`：超时/失败不能错误刷新 last_seen。
15. `devices page refreshes status`：页面保持打开时，后台 last_seen 更新后在合理时间内（≤5 秒）从离线变在线；页面 dispose 后不再刷新。

### 真实链路与回归

16. `two live schedulers sync independent of phase`：两个真实 SyncService + store + relay/直连，启动接收器后，随机错开周期，编辑后 10 秒内同步成功。
17. `live relay test` 真实 dogcloud relay 仍通过，外层 3 分钟硬超时。
18. Windows + Android 模拟器真实联调：使用当前 TAP/ICS 测试网络，两端配对记录已有；Windows 周期 push 不再出现 `push timeout after 10s`，Android 出现 `sync.receive` 和 `sync.import`，两端设备页在 5 秒内显示在线。
19. `cargo test` 外层 180 秒硬超时，全绿。
20. `flutter test --timeout 3m` 全绿。
21. `flutter analyze` 无 error。
22. FRB codegen 幂等（如新增 API）。
23. 日志保持脱敏，不输出配对码、完整 device ID、密钥和正文。
24. `git status` 只含任务范围文件，`.gitignore` 无差异。

## 日志验收

必须利用任务 N 的结构化日志证明：

- receiver start/stop/restart
- accept window start/end（verbose 可选）
- sync.receive success/failed + duration + bytes
- sync.import success/failed + note_count（不含正文）
- last_seen update 的触发原因（pairing/outbound_push/inbound_push）
- 在线状态刷新

## 测试纪律

- 所有测试默认 3 分钟超时。
- Rust 网络/阻塞操作及 spawned task 两侧必须 `tokio::time::timeout`。
- cargo test 外层 180 秒硬超时；Flutter `--timeout 3m`。
- 超过 3 分钟立即停止查因，禁止无限等待。

## 需决策点

1. FRB opaque 锁无法支持接收器与编辑/推送并发，且无法通过 endpoint clone/channel 拆分：停下报告锁图和最小架构选项。
2. iroh Endpoint 同时 accept 的多个消费者无法安全统一路由：停下报告，不用竞争式多个 accept loop。
3. 无法识别 inbound push 的发送方，因而不能精确更新 last_seen：停下报告协议缺失；提出在 push frame 增加 sender_id 的最小兼容方案，不能猜 peer。
4. 真实 Windows/Android 联调未执行：明确报告，不声称通过。
