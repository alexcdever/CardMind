# Executor Report — 任务 M：显示码流程启动确认方接收器

- worktree: `D:/Projects/CardMind/.worktrees/pairing-accept-ui`
- 分支: `codex/pairing-accept-ui`
- 日期: 2026-08-16
- 执行人: executor 子代理（TDD 红-绿-蓝）

## 一、完成内容

### 缺陷根因
`lib/pages/devices_page.dart::_showMyCode()` 只调用 `beginPairingAcceptAndAdvertise()` 生成码并展示弹窗，
**没有启动确认方接收器**（不调用 `acceptPairingRequest()`），也没有在收到请求后调用
`confirmPairing(code, requester)` → 发起方经 relay 发出请求后确认方无人消费 → `connect to confirmer -> timed out`。

### 改动文件清单（16 个内容变更 + 1 个新增测试文件）

| 文件 | 改动点 |
|------|--------|
| `lib/pages/devices_page.dart` | ① `_showMyCode()` 重写：显示码后进入确认方等待状态——弹窗生命周期内启动有界接收器；配对成功 pop 结果 → 成功提示 + `_load()` 刷新设备列表；`finally` 停止广播（保留）。② 新增 `_PairingAcceptDialog` StatefulWidget：`initState` 启动 `acceptPairingRequestWithTimeout`（有界）；收到请求 → `confirmPairing(displayedCode, requester)` → 成功关闭弹窗；超时/异常 → 可读错误 + 立即 `stopPairingAdvertising()`；`dispose()` 置 `_cancelled`，每个 await 后 `mounted`/`_cancelled` 守卫（取消后不 confirm、不 setState 已卸载 widget）。③ 新增 `DevicesPage.pairingAcceptTimeout = 3 分钟`（确认方等待总时限）。 |
| `lib/bridge/note_repository.dart` | 接口新增 `Future<PairingRequest?> acceptPairingRequestWithTimeout(Duration timeout)`（有界等待契约，注释说明决策点 1 落点） |
| `lib/bridge/frb_note_repository.dart` | 实现 `acceptPairingRequestWithTimeout` → `api.acceptPairingRequestWithTimeout(svc, timeout)` |
| `lib/bridge/bridge_helper.dart` | 委托实现 `acceptPairingRequestWithTimeout` → `_delegate` |
| `rust-backend/src/sync.rs` | `accept_pairing_request` 重构为委托有界核心；新增 `SyncService::accept_pairing_request_with_timeout(&mut self, timeout) -> Result<Option<PairingRequest>>`：deadline 到点返回 `Ok(None)`，每次 accept 窗口 `remaining.min(500ms)` 且被 `tokio::time::timeout` 保护（阻塞网络操作有界），推送帧仍导入不丢失（M1 语义保留） |
| `rust-backend/src/api.rs` | 新增 FRB 导出 `accept_pairing_request_with_timeout(svc, timeout: chrono::Duration) -> Result<Option<PairingRequest>>`（chrono::Duration → Dart Duration，FRB 2.12 原生映射；`to_std()` 转换后调 sync 方法） |
| `rust-backend/src/frb_generated.rs`、`lib/src/rust/api.dart`、`lib/src/rust/frb_generated.dart/.io/.web` | `flutter_rust_bridge_codegen generate` 自动生成（新增函数 + funcId 顺移，内容确定） |
| `rust-backend/tests/pairing_test.rs` | 新增 3 个有界等待测试（验收 9：超时/取消/成功三路径，spawn 两侧均 tokio::time::timeout 保护） |
| `test/pairing_accept_ui_test.dart` | **新增**：8 个 widget 测试（验收 1–8），专用 fake repository |
| `test/pairing_repository_test.dart` | 新增 1 个真实 FRB 桥测试：`acceptPairingRequestWithTimeout(100ms)` → null（验证 chrono::Duration→Dart Duration 映射 + FRB 超时路径） |
| `test/pairing_mdns_widget_test.dart`、`test/sync_ui_widget_test.dart` | 两个现有 fake 补 `acceptPairingRequestWithTimeout` 返回永不完成 future（显示码测试保持"等待中"，不破坏现有用例） |
| `test/mobile_ui_test.dart`、`test/vertical_slice_widget_test.dart` | 两个不用显示码流程的 fake 补 `acceptPairingRequestWithTimeout` 桩（UnimplementedError） |

### 关键设计（决策点 1 落点）
- **有界等待**：`acceptPairingRequestWithTimeout` 保证在时限内返回（超时返回 null）。Flutter 侧单次调用，总时限 = `DevicesPage.pairingAcceptTimeout`（3 分钟）。
- **取消**：弹窗 `dispose()` 置 `_cancelled`；挂起等待完成后 `_runAccept` 检查 `mounted/_cancelled` → 不 confirm、不 setState。底层 FRB 调用自释（有界），不留下永久阻塞任务。
- 无永久线程、无静态全局状态（决策点 1 约束）。

## 二、验收标准逐条结果

### 验收 1–8（Flutter widget 测试，`test/pairing_accept_ui_test.dart`）
```
00:01 +8: All tests passed!   （8/8 通过）
```

### 验收 9（Rust/FRB 有界生命周期 + 超时铁律）
```
cargo test --test pairing_test   → 10 passed; 0 failed（含 3 个新增）
test_accept_pairing_request_with_timeout_returns_none_on_timeout  ... ok
test_accept_pairing_request_with_timeout_zero_returns_immediately  ... ok
test_accept_pairing_request_with_timeout_returns_request           ... ok
flutter test test/pairing_repository_test.dart → 2 passed（含 FRB 桥超时测试）
```

### 验收 10（已有 pairing/connect/live relay 不回归）
```
cargo test 全量 → 73 passed; 0 failed（pairing/connect/live_relay/sync 等全部绿）
flutter test 全量 → 82 passed; 0 failed（含 pairing_repository 真实 FRB 全链路）
```

### 验收 11（cargo test 3 分钟上限）
```
timeout 180 cargo test   → 73 passed; 0 failed; 0 ignored; 完成（全部在 180s 内）
```

### 验收 12（flutter test --timeout 3m）
```
timeout 400 flutter test --timeout 3m → 82 passed; 0 failed; All tests passed!
```

### 验收 13（flutter analyze）
```
flutter analyze → No issues found! (ran in 19.3s)
```

### 验收 14（FRB codegen 幂等）
```
flutter_rust_bridge_codegen generate 连续跑两次：
第一次后 git status 26 个文件；第二次后仍 26 个文件（无新增内容变更）→ 幂等 ✓
```

### 验收 15（真实双端 UI 验证）— **未执行，按决策点 3 报告**
无法在当前环境执行 Android/Windows 真实双端 UI 测试（需新平台自动化能力）。
已执行的后端/Flutter 测试见上；具体未覆盖项：
- Android 日志不再出现 `connect to confirmer -> timed out`（需真机双端联调）
- 配对成功后两端设备列表出现对方（需真机双端联调）
**不声称 UI 通过。**

### 验收 16（git status 范围 / .gitignore）
```
git status --short → 16 个修改 + 1 个新增（全部在任务单改动范围：lib/pages、lib/bridge、
lib/src/rust（生成）、rust-backend/src、rust-backend/tests、test/）
git diff .gitignore → 0 行差异
docs/、prototype/ 未改动
```

## 三、TDD 证据

### 红阶段（真实失败输出）

**Rust 红**（新 API 不存在，编译失败）：
```
error[E0599]: no method named `accept_pairing_request_with_timeout` found for struct `SyncService` in the current scope
error: could not compile `cardmind-backend` (test "pairing_test") due to 7 previous errors
```

**Flutter 红**（当前 `_showMyCode()` 不启动接收器，8/8 失败，核心断言均为
`acceptPairingRequestWithTimeout` 未被调用 → acceptCalls 0）：
```
The following TestFailure was thrown running a test:
Expected: <1>
  Actual: <0>
（8 个测试全部失败；典型 reason: '显示码后应启动确认方接收器（acceptPairingRequestWithTimeout）'）
```

### 绿阶段（真实输出）
```
cargo test --test pairing_test → 10 passed; 0 failed; finished in 6.18s
flutter test test/pairing_accept_ui_test.dart --timeout 3m → +8: All tests passed!
```

### 蓝阶段（重构说明）
- 删除 `_PairingAcceptDialogState._waiting` 死字段（赋值但从未读取；错误状态由 `_error != null` 表达）。
- 重构后全部测试保持绿：`flutter test`（pairing_accept 8 + pairing_mdns 7 + sync_ui 10 + 全量 82）与 `cargo test`（73）均通过。
- 生命周期审查：单次弹窗只启动一个接收器；`dispose → _cancelled` 防止取消后 confirm/setState；重复打开/关闭不叠加并发接收器（验收 7 验证）；有界等待保证无永久阻塞任务。

## 四、新增测试清单

| 文件 | 用例名 | 验收标准 |
|------|--------|----------|
| `test/pairing_accept_ui_test.dart` | show-code starts confirmer accept loop | 验收 1 |
| 〃 | received request confirms with displayed code | 验收 2 |
| 〃 | pairing success closes or updates waiting state | 验收 3 |
| 〃 | cancel stops advertising and accept task | 验收 4 |
| 〃 | accept failure is visible and recoverable | 验收 5 |
| 〃 | accept timeout is bounded | 验收 6 |
| 〃 | reopen does not duplicate accept loops | 验收 7 |
| 〃 | manual relay pairing UI path | 验收 8 |
| `rust-backend/tests/pairing_test.rs` | test_accept_pairing_request_with_timeout_returns_none_on_timeout | 验收 9（超时） |
| 〃 | test_accept_pairing_request_with_timeout_zero_returns_immediately | 验收 9（取消释放语义） |
| 〃 | test_accept_pairing_request_with_timeout_returns_request | 验收 9（成功） |
| `test/pairing_repository_test.dart` | bounded accept times out through FRB bridge | 验收 9（FRB 映射） |

## 五、问题未决 / 需决策点

1. **决策点 1（已遇到，按任务单预定义设计解决，未引入永久线程/静态全局状态）**：
   现有 `acceptPairingRequest()` 在 FRB opaque 上无法安全取消且无 timeout/cancel API（阻塞循环持有 `&mut` 锁，
   FRB 无法中断）。任务单 改动范围 明确"仅当现有 FRB opaque 生命周期无法安全取消时修改 api.rs/sync.rs"（条件满足），
   验收 9 明确"新增的 Rust/FRB 等待或取消 API 在成功、取消、超时三种路径都能返回"。因此按任务单设计新增
   `accept_pairing_request_with_timeout`（有界，超时返回 None；每个 accept 窗口 tokio::time::timeout 保护；
   现有 `accept_pairing_request` 委托有界核心、24h 边界保持原语义，已有测试全绿）。
   **已知限制（请主代理知悉）**：有界等待在飞时持有 SyncService FRB opaque 锁，取消弹窗后底层调用自释最长
   3 分钟（`pairingAcceptTimeout`）；期间 `stopPairingAdvertising`/同步调度器等待该锁。不留下永久阻塞任务（设计目标 5 满足），
   但 3 分钟锁持有是 FRB opaque 约束下的折衷。如需更短释放，可后续缩短时限或改用非阻塞轮询方案（超本任务范围，未做）。
2. **决策点 2（未触发，已以最小方案解决）**：弹窗关闭通过 `dispose() → _cancelled` 可靠通知 Dart 侧等待任务停止
   （await 后守卫），不 confirm、不 setState 已卸载 widget（验收 4/7 实测）。底层 Rust 调用无法中断但有界自释。
3. **决策点 3（触发，按指示停下报告）**：真实双端 UI 验证（验收 15）无法在当前环境执行；已执行全部后端/Flutter 测试
   （73 Rust + 82 Flutter 全绿，含真实 FRB 配对全链路 pairing_repository_test 与 FRB 桥超时测试），未覆盖项为真机
   Android↔Windows relay 配对联调。不声称 UI 通过。

## 六、回归验证真实输出摘要

| 命令 | 结果 |
|------|------|
| `timeout 180 cargo test` | 73 passed; 0 failed（全部在 180s 内） |
| `timeout 400 flutter test --timeout 3m` | 82 passed; 0 failed; All tests passed! |
| `flutter analyze` | No issues found! |
| `flutter_rust_bridge_codegen generate`（连续两次） | 幂等：第二次无新增内容变更 |
| `git status --short` | 16 修改 + 1 新增，全部在任务范围 |
| `git diff .gitignore` | 0 行差异 |
| GitNexus `detect_changes` | 变更符号全部在预期范围（lib/bridge、lib/pages、lib/src/rust 生成、rust-backend、test）；风险符号为 FRB 生成 funcId 顺移所致，功能改动经 `impact` 评估为 LOW |
