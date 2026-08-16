# Executor 自检报告 — 任务 P：修复 start_receiver 消费 Store RustArc 缺陷

- worktree：`D:/Projects/CardMind/.worktrees/receiver-store-borrow`（分支 `codex/receiver-store-borrow`）
- 执行时间：2026-08-16
- 结论：**21 条验收中 20 条通过；验收 18（Windows+Android 双端配对联调）未执行（环境无 TAP/ICS 测试网络、模拟器 NAT 阻断 host→emulator iroh 直连，与任务 O 相同限制，明确报告不声称通过）**

---

## 一、完成内容

### 根因与修复
`rust-backend/src/api.rs::start_receiver(svc: &SyncService, store: NoteStore)` 的 `store` 按值跨 FRB 边界，FRB 2.12 生成绑定把 Dart `_store` 视为 move/消费（`Auto_Owned` 编码）：调用返回后 Dart 侧 RustArc 已 disposed，下一周期 `runSyncCycle(svc, store)` 抛 `DroppableDisposedException`（Windows + Android 双端复现）。

修复（仅改 API 边界，receiver 核心行为不动）：

```rust
pub async fn start_receiver(svc: &SyncService, store: &NoteStore) -> anyhow::Result<()> {
    svc.start_receiver(store.clone()).await
}
```

接收器内部仍持有自己的 `store.clone()`（`SyncService::start_receiver` 内 clone 进 `ReceiverContext`），语义不变。

### 改动文件（git status 最终仅以下 6 项）
| 文件 | 说明 |
|---|---|
| `rust-backend/src/api.rs` | start_receiver 参数 `NoteStore` → `&NoteStore`，内部 clone |
| `rust-backend/src/frb_generated.rs` | FRB codegen：store 解码由 owned 改为 `lockable_decode_async_ref` |
| `lib/src/rust/frb_generated.dart` | FRB codegen：`Auto_Owned_...NoteStore` → `Auto_Ref_...NoteStore` |
| `lib/src/rust/api.dart` | FRB codegen：startReceiver 文档注释更新（签名不变） |
| `test/receiver_store_borrow_test.dart` | **新增**：5 个真实 FRB 回归测试（红→绿） |
| `integration_test/receiver_platform_test.dart` | **新增**：真实 Windows/Android 平台回归测试 |

`lib/bridge/sync_scheduler.dart` **未修改**——生成 API 调用形态（Dart 侧签名 `startReceiver({svc, store})`）未变，仅编码语义从 owned 变 ref。`.gitignore`、prototype/、TAP/网络、receiver 核心行为均未触碰。

---

## 二、红阶段红输出证据（真实命令输出）

红阶段先落盘 5 个真实 FRB 回归测试（`RustLib.init` + 真实 cardmind_backend.dll + 真实 RustArc，无 fake SyncApi），对缺陷 DLL 实机运行全部失败：

```
$ timeout 180 flutter test test/receiver_store_borrow_test.dart
Shell: [cardmind:log] ... event=receiver.start stage=receiver duration_ms=0 action=success
00:00 +0 -1: start_receiver does not consume store RustArc [E]
  Expected: false
    Actual: <true>
  startReceiver 不得消费 Store RustArc
00:00 +0 -2: start_receiver then periodic cycle does not dispose store [E]
  Expected: false
    Actual: <true>
  调度器启动接收器后 Store 不得被消费
00:00 +0 -3: receiver stop then store reuse [E]       Expected: false / Actual: <true>
00:00 +0 -4: receiver repeated start is idempotent and store reusable [E]  Expected: false / Actual: <true>
00:01 +0 -5: receiver failure does not dispose store [E]  Expected: false / Actual: <true>
00:01 +0 -5: Some tests failed.
```

关键证据：`receiver.start action=success` 正常发出，但紧接着 `store.isDisposed == true`——Dart 侧 `_store` 已被消费，与缺陷现场日志一致（下一周期 `sync.cycle` 报 `DroppableDisposedException`）。

---

## 三、验收标准 1–21 逐条核对 + 测试映射

| # | 验收 | 结果 | 证据 |
|---|---|---|---|
| 1 | 红：start_receiver 不消费 Store（真实 FRB） | ✅ | `test/receiver_store_borrow_test.dart::start_receiver does not consume store RustArc` 红阶段真实失败为 disposed（isDisposed=true） |
| 2 | 红：start 后周期 cycle 复现 disposed | ✅ | `test/receiver_store_borrow_test.dart::start_receiver then periodic cycle does not dispose store`（SyncScheduler + 真实 FrbSyncApi）红阶段失败 |
| 3 | 测试用真实绑定/真实 RustArc | ✅ | 全部用例 `RustLib.init()` + 真实 dll；monitor 用 fake 仅注入网络状态，Rust API 全真实 |
| 4 | Rust API 边界借用 `&NoteStore` + 内部 clone | ✅ | `rust-backend/src/api.rs` diff 见上；`SyncService::start_receiver` 未改（内部 clone 进 ReceiverContext） |
| 5 | codegen 输出与借用一致 | ✅ | `frb_generated.dart` L1846 由 `sse_encode_Auto_Owned_...NoteStore` → `sse_encode_Auto_Ref_...NoteStore`；`frb_generated.rs` `api_store.lockable_decode_async_ref().await` + `crate::api::start_receiver(&*api_svc_guard, &*api_store_guard)` |
| 6 | start 后连续 3 个 Store API 成功 | ✅ | 同用例绿阶段：`listPairedDevices` + `storeList` + `runSyncCycle` 均成功 |
| 7 | 周期 cycle 后不抛 disposed | ✅ | 同用例绿阶段：SyncScheduler.syncNow 两次 + 断言 `sync.cycle ok=true`、无 DroppableDisposedException |
| 8 | stop 后 Store 可查询/写入 | ✅ | `::receiver stop then store reuse`：stop 后 storeList + noteCreate + syncNotesToStore + 读回 |
| 9 | 重复 start 幂等且 Store 可复用 | ✅ | `::receiver repeated start is idempotent and store reusable`：3 次 start，receiver_running=true，Store 全程可用 |
| 10 | receiver 失败不 dispose Store | ✅ | `::receiver failure does not dispose store`：start→stop→cycle 生命周期各步 isDisposed=false 且可查询/写入（说明：`start_receiver` Rust 侧对合法输入无可达 Err 路径——启动只 clone store + spawn 不触 SQLite，故按借用不变式验证生命周期错误路径） |
| 11 | receiver_continuous_test 14/14 | ✅ | `timeout 180 cargo test --test receiver_continuous_test` → `test result: ok. 14 passed; 0 failed; finished in 10.73s` |
| 12 | cargo test 每进程 180s 全绿 | ✅ | `timeout 180 cargo test` → 全部 `test result: ok`，单进程最大 30.43s（connect_test） |
| 13 | flutter test --timeout 3m 全绿 | ✅ | `timeout 400 flutter test --timeout 3m` → `00:18 +110: All tests passed!` |
| 14 | flutter analyze 无 error | ✅ | `flutter analyze` → `No issues found!` |
| 15 | FRB codegen 连续两次幂等 | ✅ | 第 2、3 次运行 `flutter_rust_bridge_codegen generate` 后 md5 对比零变化：`CODEGEN IDEMPOTENT` |
| 16 | 真实 Windows 平台无 disposed | ✅ | `flutter test integration_test/receiver_platform_test.dart -d windows` → `02:03 +1: All tests passed!`（receiver.start success + 真实 60s 周期 Timer 两次 sync.cycle，断言 ok=true 无 disposed） |
| 17 | 真实 Android 模拟器无 disposed | ✅ | 清除 HTTP_PROXY/HTTPS_PROXY/ALL_PROXY 后 `flutter test integration_test/receiver_platform_test.dart -d emulator-5554` → `02:04 +1: All tests passed!`（同上） |
| 18 | 双端配对 push/receive/last_seen/设备页在线 | ⚠️ **未执行** | 见"问题未决 1"；与任务 O 验收 18 相同限制（无 TAP/ICS 测试网络） |
| 19 | 真实 dogcloud relay 3 分钟上限 | ✅ | `timeout 180 cargo test --test live_relay_test -- --ignored --nocapture` → `test result: ok. 1 passed; finished in 3.54s`（`[live] ✅ 配对 + 首次同步经 dogcloud relay 全链路成功`） |
| 20 | 日志脱敏不回归 | ✅ | Rust `debug_log_test.rs` 10/10（含 `test_redact_device_id`）；Flutter `test/debug_log_test.dart` 10/10；新测试日志 id 均为 `前8…后8` 脱敏形式 |
| 21 | git status 仅任务范围 + .gitignore 无差异 | ✅ | `git status --short` 仅 6 项（见上）；`git diff -- .gitignore` 为空 |

---

## 四、真实命令输出摘录

### 绿阶段单元/集成测试（验收 6-10）
```
$ timeout 180 flutter test test/receiver_store_borrow_test.dart
00:10 +5: All tests passed!
```

### cargo test（验收 12，180s 外层兜底）
```
$ timeout 180 cargo test
Running tests\autosync_test.rs ...   8 passed; finished in 10.27s
Running tests\connect_test.rs ...    7 passed; finished in 30.43s
Running tests\debug_log_test.rs ... 10 passed; finished in 30.18s
Running tests\discovery_test.rs ...  2 passed; finished in 6.05s
Running tests\integration_test.rs ... 2 passed; finished in 0.11s
Running tests\migration_test.rs ...  2 passed; finished in 0.14s
Running tests\note_crdt_test.rs ... 10 passed; finished in 0.01s
Running tests\pairing_test.rs ...   10 passed; finished in 6.23s
Running tests\receiver_continuous_test.rs ... 14 passed; finished in 10.61s
Running tests\relay_config_test.rs ... 7 passed; finished in 0.13s
Running tests\store_test.rs ...      6 passed; finished in 0.01s
Running tests\sync_service_test.rs ... 5 passed; finished in 0.18s
Running tests\sync_test.rs ...       1 passed; finished in 0.15s
Running tests\trash_test.rs ...     13 passed; finished in 0.25s
（全部 0 failed）
```

### 真实 Windows 平台（验收 16）
```
$ flutter test integration_test/receiver_platform_test.dart -d windows
√ Built build\windows\x64\runner\Debug\cardmind.exe
02:03 +1: All tests passed!
```
（测试断言：`receiver.start` 事件存在且 action=success；真实 60s 周期 Timer 触发 ≥2 次 `sync.cycle` 且 `ok=true`、无 DroppableDisposedException；`store.isDisposed=false`）

### 真实 Android 模拟器（验收 17，默认 NAT，已清代理）
```
$ unset HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy
$ flutter test integration_test/receiver_platform_test.dart -d emulator-5554
√ Built build\app\outputs\flutter-apk\app-debug.apk
Installing build\app\outputs\flutter-apk\app-debug.apk... 3.6s
02:04 +1: All tests passed!
```

### live relay（验收 19，真实 dogcloud）
```
$ timeout 180 cargo test --test live_relay_test -- --ignored --nocapture
[live] ✅ 配对 + 首次同步经 dogcloud relay 全链路成功
test result: ok. 1 passed; 0 failed; finished in 3.54s
```

### FRB codegen 幂等（验收 15）
```
$ flutter_rust_bridge_codegen generate && md5sum ... > before
$ flutter_rust_bridge_codegen generate && md5sum ... > after
$ diff before after && echo "CODEGEN IDEMPOTENT (3rd run produced zero content changes)"
```

---

## 五、新增测试清单

| 文件 | 用例 | 覆盖点 |
|---|---|---|
| `test/receiver_store_borrow_test.dart` | start_receiver does not consume store RustArc | 验收 1/6：start 后连续 3 个 Store API（listPairedDevices/storeList/runSyncCycle）均成功，isDisposed=false |
| | start_receiver then periodic cycle does not dispose store | 验收 2/7：SyncScheduler（真实 FrbSyncApi）start 后两次 syncNow，断言 sync.cycle ok=true 且无 DroppableDisposedException |
| | receiver stop then store reuse | 验收 8：stop 后查询+写入+读回 |
| | receiver repeated start is idempotent and store reusable | 验收 9：3 次 start 幂等，receiver_running=true，Store 全程可用 |
| | receiver failure does not dispose store | 验收 10：start→stop→cycle 生命周期各步 isDisposed=false，Store 可查询/写入 |
| `integration_test/receiver_platform_test.dart` | real platform: receiver.start success + at least two periodic sync.cycle without disposed | 验收 16/17：真实平台（Windows/Android）上真实 60s 周期 Timer 触发 ≥2 次 sync.cycle，receiver.start success，无 disposed |

Rust 侧无新增测试：api.rs 的改动是 FRB 边界层，纯 Rust 测试无法覆盖 FRB opaque 所有权语义；边界行为由上述真实 FRB Dart 测试完整覆盖（`receiver_continuous_test.rs` 等核心行为测试 14/14 回归全绿）。

---

## 六、需决策点 / 问题未决

1. **验收 18（Windows+Android 双端配对联调）未执行**——环境与任务 O 相同限制：
   - 无任务 N 的 TAP 适配器/ICS 测试网络；
   - Android 模拟器为默认 NAT：guest→host 出站可用，但 host→guest 无路由（10.0.2.15 不可从宿主路由），Windows→Android 的 iroh 直连 push 不可达；adb 不在 PATH，无可靠端口转发通道；
   - 双端配对握手 + 设备页 5 秒在线刷新需真实 UI 双端同步驱动，单机环境无法可靠建立。
   已完成的最近替代：验收 16/17（两端各自真实平台 2 周期无 disposed）、验收 11（`receiver_continuous_test` 双活调度器 last_seen/同步闭环 14/14）、验收 19（真实 dogcloud relay 全链路）。
2. **验收 10 的说明**：`start_receiver`（Rust 侧）对合法输入无可达的 Err 路径（启动仅 clone store + spawn，不触碰 SQLite），故用例按借用不变式验证完整生命周期（start→stop→cycle→查询→写入）下 Store 永不被消费，并断言 isDisposed 恒 false。start 返回错误路径本身无法经公开 API 构造。
3. **FRB 决策点未触发**：FRB 2.12 支持 `&NoteStore` opaque 参数生成（`Auto_Ref` 编码），无需替代方案；改用借用后实测无 disposed，且是 store 复用成功，非 svc 被消费。
4. **平台测试基础设施说明**：Windows/Android 集成测试需将 `cardmind_backend.dll/.so` 放到运行路径（Windows：exe 同级目录；Android：`build/android-jni/<abi>`）——这是现有部署约定（AGENTS.md 运行态动态库一节），非本任务改动。

---

## 七、提交建议

建议提交信息：`fix(task-p): borrow NoteStore in start_receiver FRB boundary to stop consuming Dart RustArc`

改动：4 文件修改（api.rs + frb_generated.rs + 2 个 Dart 生成文件）+ 2 个新测试文件；工作树干净，`.gitignore` 无差异。
