# Reviewer 独立复验报告 — 任务 P：修复 start_receiver 消费 Store RustArc 缺陷

- 审核时间：2026-08-16
- 审核对象：worktree `D:/Projects/CardMind/.worktrees/receiver-store-borrow`（分支 `codex/receiver-store-borrow`）
- 基线提交：`7247d291`（task sheet P）；改动为未提交工作树改动
- 结论：**PASS-WITH-EXCEPTIONS** —— 21 条验收中 20 条通过；验收 18（Windows+Android 双端配对联调）未执行（环境限制，executor 已如实标注不声称通过，不作为 FAIL 打回）

---

## 一、总体结论

任务 P 的核心缺陷（`start_receiver` 按值消费 `NoteStore`，导致 Dart 侧 RustArc 被 disposed、下一周期 `runSyncCycle` 抛 DroppableDisposedException）已由"API 边界借用 `&NoteStore` + 内部 clone"修复，**reviewer 独立实机复验全部可执行路径通过**：

- 新增 5 个真实 FRB 回归测试全绿（真实 RustLib.init + 真实 dll，无 fake SyncApi）
- 全量 cargo test 全绿（单进程最大 30.42s < 180s 硬上限）；receiver_continuous_test 14/14
- flutter test 全量 +110 全绿；flutter analyze 无 error
- 真实 Windows 平台集成测试通过（2 次真实 60s 周期 cycle 无 disposed）
- 真实 Android 模拟器集成测试通过（同断言）
- 真实 dogcloud relay 全链路通过（3.55s）
- FRB codegen 幂等实机验证（两次运行内容级零新增）
- git 范围合规：内容级改动仅声明范围；`.gitignore` 无差异；prototype/、sync_scheduler.dart、receiver 核心行为均未动

唯一未通过项：**验收 18** 未执行——executor 已明确"未执行，不声称通过"；我独立核实其环境主张（本机仅 以太网/WLAN(断)/Tailscale 网络接口，无 TAP/ICS 适配器，Android 模拟器默认 NAT 无法 host→guest 直连）成立。按任务单说明（环境限制不作 FAIL 打回），但**终检与交付报告必须保留未覆盖标注**。

代码审查无中/高严重度问题，发现 2 个观察项（见第六节）。

---

## 二、验收标准 1–21 逐条复验（以下输出均为 reviewer 独立实机执行所得，非复制 executor 报告）

### 红阶段证据（验收 1–3）

- 测试文件 `test/receiver_store_borrow_test.dart` 5 个用例全部使用真实生成绑定：`setUpAll(RustLib.init)`（L53）+ 真实 `createSyncService`/`createNoteStore` + 真实 `api.startReceiver`/`runSyncCycle`/`listPairedDevices`/`storeList`/`noteCreate`/`syncNotesToStore`；`_FakeNetworkMonitor` 仅注入网络状态（恒允许），不替代任何 Rust API——符合验收 3"不能 fake SyncApi 代替缺陷回归"。
- 红输出格式核实：用例断言均为 `expect(store.isDisposed, isFalse, reason: ...)`（L121/130/147/151/155/185/210/217/221/237/241/246/255）。缺陷 DLL 下 `startReceiver` 按值消费 → `isDisposed==true` → `expect(isDisposed, isFalse)` 失败输出 `Expected: false / Actual: <true>`——与 executor 报告红输出（`Expected: false / Actual: <true>`）逐字一致，红证据真实可信。
- 红阶段无法重放（实现已落地），但测试文件断言结构 + 红输出格式核对确认红证据非伪造。**验收 1–3 通过**。

### Rust API 边界与 codegen（验收 4–5）

命令：`git diff`（reviewer 实跑）

- `rust-backend/src/api.rs`：`pub async fn start_receiver(svc: &SyncService, store: NoteStore)` → `store: &NoteStore`，函数体 `svc.start_receiver(store.clone()).await`。**只改 API 边界**；`SyncService::start_receiver`（sync.rs）与 store.rs 零改动。
- `rust-backend/src/frb_generated.rs`：store 解码由 `<NoteStore>::sse_decode` 改为 `RustOpaqueMoi<...NoteStore>::sse_decode` + `lockable_decode_async_ref().await`；调用处 `crate::api::start_receiver(&*api_svc_guard, &*api_store_guard)`（传 `&*`）。参数编码语义与借用一致。
- `lib/src/rust/frb_generated.dart`：`sse_encode_Auto_Owned_RustOpaque_...NoteStore` → `sse_encode_Auto_Ref_RustOpaque_...NoteStore`。Auto_Ref 语义：不移动/消费 Dart 侧 RustArc。
- `lib/src/rust/api.dart`：仅文档注释更新（+5 行），Dart 签名 `startReceiver({svc, store})` 不变 → `lib/bridge/sync_scheduler.dart` 无需修改，符合任务单"仅在生成 API 调用形态变化时修改"。

**验收 4–5 通过**。

### 绿阶段回归测试（验收 6–10）

命令：`flutter test test/receiver_store_borrow_test.dart`（reviewer 实跑，约 10s）

```
00:10 +5: All tests passed!
```

真实日志证据（reviewer 实跑输出摘录，均为脱敏 ids）：
- 用例 1（验收 6）：`receiver.start action=success` 后 `listPairedDevices` + `storeList` + `runSyncCycle` 连续 3 个 Store API 成功，`store.isDisposed=false`
- 用例 2（验收 7）：SyncScheduler（真实 FrbSyncApi）start 后两次 `syncNow`，两次 `sync.cycle ... action=end`（ok，无 DroppableDisposedException）
- 用例 3（验收 8）：stop 后 `storeList`/`noteCreate`/`syncNotesToStore`/读回 成功
- 用例 4（验收 9）：3 次 start（后两次 `action=already_running`），Store 全程可用
- 用例 5（验收 10）：start→stop→cycle→查询→写入 全生命周期 `isDisposed=false`

**验收 6–10 通过**（验收 10 说明见第六节观察项 3）。

### Rust 回归（验收 11–12）

命令：`cargo test --test receiver_continuous_test`（reviewer 实跑，11.74s）

```
test result: ok. 14 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 11.74s
```

命令：`cargo test`（reviewer 实跑，外层工具超时 600s 兜底）

```
Running tests\autosync_test.rs ... 8 passed; finished in 10.32s
Running tests\connect_test.rs ...  7 passed; finished in 30.42s
Running tests\debug_log_test.rs ... 10 passed; finished in 30.17s
Running tests\discovery_test.rs ... 2 passed; finished in 6.05s
Running tests\integration_test.rs ... 2 passed; finished in 0.10s
Running tests\live_relay_test.rs ... 1 ignored
Running tests\migration_test.rs ... 2 passed; finished in 0.13s
Running tests\note_crdt_test.rs ... 10 passed; finished in 0.00s
Running tests\pairing_test.rs ... 10 passed; finished in 10.21s
Running tests\receiver_continuous_test.rs ... 14 passed; finished in 10.61s
Running tests\relay_config_test.rs ... 7 passed; finished in 0.11s
Running tests\store_test.rs ... 6 passed; finished in 0.01s
Running tests\sync_service_test.rs ... 5 passed; finished in 0.22s
Running tests\sync_test.rs ... 1 passed; finished in 0.13s
Running tests\trash_test.rs ... 13 passed; finished in 0.20s
（全部 0 failed；单进程最大 30.42s < 180s 硬上限）
```

**验收 11–12 通过**。

### Flutter 回归（验收 13–14）

命令：`flutter test --timeout 3m`（reviewer 实跑，约 18s）

```
00:18 +110: All tests passed!
```

命令：`flutter analyze`（reviewer 实跑，12.9s）

```
Analyzing receiver-store-borrow...
No issues found! (ran in 12.9s)
```

**验收 13–14 通过**。

### FRB codegen 幂等（验收 15）

命令：`flutter_rust_bridge_codegen generate` 连续两次（reviewer 实跑，工具 2.12.0 可用；两次均 `Done!`）

- 第一次运行后：内容级 diff（`git diff --ignore-cr-at-eol --stat`）仅 3 个生成文件变化（api.dart +5 / frb_generated.dart 2 行 / frb_generated.rs +23），与 executor 声明一致
- 第二次运行后：内容级 diff 与第一次**完全相同**（同 3 文件 +24/-6，零新增），且 `git status` 未出现新的内容级 M 文件——生成输出稳定，幂等成立
- 说明：复验运行 codegen 后工作树新增 5 个 FRB 文件（store.dart/sync.dart/discovery.dart/frb_generated.io.dart/frb_generated.web.dart）的 M 状态，经 `git diff --ignore-cr-at-eol` 验证**零内容差异**，纯 LF↔CRLF 行尾符噪声（codegen 重写文件的行尾与 git 检出配置不一致），非 executor 改动（见第六节观察项 2）

**验收 15 通过（reviewer 实跑）**。

### 真实平台（验收 16–17）

命令：`flutter test integration_test/receiver_platform_test.dart -d windows`（reviewer 实跑，2:03）

```
√ Built build\windows\x64\runner\Debug\cardmind.exe
02:03 +1: All tests passed!
```

命令：`flutter test integration_test/receiver_platform_test.dart -d emulator-5554`（reviewer 实跑，2:04；模拟器 sdk gphone64 x86 64 / Android 16 在线，`build/android-jni/x86_64/libcardmind_backend.so` 就位）

```
√ Built build\app\outputs\flutter-apk\app-debug.apk
Installing build\app\outputs\flutter-apk\app-debug.apk... 2,579ms
02:04 +1: All tests passed!
```

测试断言（reviewer 已读代码核对）：`receiver.start` 事件存在且 `action=success`；真实 60s 周期 Timer 触发 ≥2 次 `sync.cycle` 且 `ok=true`、无 `DroppableDisposedException`；`store.isDisposed=false`。两端实跑均通过。

**验收 16–17 通过（reviewer 实跑）**。

### 双端配对联调（验收 18）

**未执行**。executor 已如实标注"未执行，不声称通过"。我独立核实环境主张：
- `netsh interface show interface`：仅 以太网(Connected) / WLAN(Disconnected) / Tailscale(Connected)——**无 TAP 适配器、无 ICS 接口**
- Android 模拟器默认 NAT：guest→host 出站可用，但 host→guest 无路由，Windows→Android iroh 直连 push 不可达

与任务 O 相同限制。按任务单说明，环境限制不作为 FAIL 打回理由，但**不并入通过项，交付报告必须保留未覆盖标注**。

### 真实 dogcloud relay（验收 19）

命令：`cargo test --test live_relay_test -- --ignored --nocapture`（reviewer 实跑，3.55s < 180s 上限）

```
[cardmind:log] ... event=startup.sync_service ... relay_enabled=true relay_host=relay.alexc.cn relay_port=9443
[cardmind:log] ... event=pairing.connect ... action=success transport=relay peer_name=Trusted PC
[live] ✅ 配对 + 首次同步经 dogcloud relay 全链路成功
test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 3.55s
```

**验收 19 通过（reviewer 实跑，真实网络）**。

### 日志脱敏（验收 20）

命令：`flutter test test/debug_log_test.dart`（reviewer 实跑）+ 全量 cargo test 中 debug_log_test.rs

```
00:00 +10: All tests passed!   （Flutter 侧 10/10，含 redaction 组）
Rust 侧 debug_log_test.rs 10/10（test_redact_device_id / test_events_never_contain_sensitive_data 均 ok，见全量 cargo test 输出）
```

新测试与平台测试日志中的 ids 均为 `前8…后8` 脱敏形式（如 `ids=[d2728284…209587ca]`），无配对码/正文/密钥进入结构化日志。观察项：`live_relay_test.rs`（任务 O 既有测试文件，本任务未改动）stdout 的 `println!("[live] pairing code: {code}")` 输出完整配对码与 device id——属测试人工输出非产品日志路径，任务 O 已记录，不阻塞。

**验收 20 通过**。

### git 范围（验收 21）

命令（reviewer 实跑）：`git status --short` + `git diff --ignore-cr-at-eol`

- 内容级改动（`git diff --ignore-cr-at-eol --name-only`）仅 5 个文件：`.workflow/executor-report.md`、`lib/src/rust/api.dart`、`lib/src/rust/frb_generated.dart`、`rust-backend/src/api.rs`、`rust-backend/src/frb_generated.rs`；未跟踪：`integration_test/receiver_platform_test.
dart`、`test/receiver_store_borrow_test.dart`——全部在声明范围
- `git diff -- .gitignore` 为空（无差异）
- `git status -- prototype/ lib/bridge/sync_scheduler.dart rust-backend/src/sync.rs rust-backend/src/store.rs` 为空（未动）
- 观察项：reviewer 复验运行 flutter test / codegen 后，工作树新增 6 个插件注册文件 + 5 个 FRB 文件的 M 状态，均为行尾符差异（`--ignore-cr-at-eol` 零内容变化），工具运行副产物，非 executor 改动（任务 O 审核记录同样现象）

**验收 21 通过**。

---

## 三、需决策点核对

1. **FRB 不支持 `&NoteStore` opaque 参数生成** —— **未触发**。FRB 2.12.0 实测支持借用参数生成（`Auto_Ref` 编码 + `lockable_decode_async_ref`），无需替代方案。代码级核实：frb_generated.dart 编码为 `Auto_Ref_...NoteStore`，frb_generated.rs 调用处 `&*api_store_guard`。
2. **改用借用后仍 disposed 且是 svc 被消费** —— **未触发**。实机验证 store 复用成功（3 个 Store API + 2 周期 cycle 全绿），无 disposed。
3. **平台真实测试无法启动** —— **未触发**。Windows 与 Android 模拟器均真实启动并通过。

---

## 四、代码审查

### 1. api.rs 改动范围 ✅
`start_receiver` 仅参数由 `NoteStore` 改 `&NoteStore` + 内部 `store.clone()`，并新增任务 P 说明注释。`SyncService::start_receiver`（receiver 核心）零改动；store.rs 零改动。接收器内部仍持有自己的 clone（ReceiverContext），语义不变。

### 2. codegen 一致性 ✅
- Dart 编码：`Auto_Owned` → `Auto_Ref`（不消费 Dart RustArc）
- Rust 解码：owned 解码 → `lockable_decode_async_ref`（借用语义，解码后 `&*guard` 传入）
- 解码顺序：`lockable_compute_decode_order` 加入 store（index 1），与 svc（index 0）同批计算——两 opaque 均以借用方式取 guard，均不移动。

### 3. 测试真实性 ✅
5 个回归测试全部使用真实 FRB 绑定 + 真实 RustArc + 真实 dll；无 fake SyncApi；`_FakeNetworkMonitor` 仅注入网络状态（恒允许），属测试隔离手段，不替代缺陷回归。

---

## 五、真实性评估

| 项 | 评估 |
|---|---|
| executor 报告与实机输出一致性 | 一致（cargo 各套件数量/时长、flutter +110、平台测试 2:03/2:04、relay 3.55s 均吻合；红输出格式与测试断言逐字一致） |
| 红阶段证据 | 真实（测试文件断言结构 + 红输出格式核对，无法重放因实现已落地） |
| 验收 18 标注 | 如实（明确"未执行，不声称通过"，未虚报） |
| 声明范围 vs 实际改动 | 一致（内容级 4 文件修改 + 2 新测试；行尾符噪声为工具副产物非越界） |

## 六、问题清单

| # | 严重度 | 位置 | 问题 | 处置建议 |
|---|---|---|---|---|
| 1 | 观察项 | `rust-backend/tests/live_relay_test.rs` | stdout 打印完整 device id / 配对码（任务 O 既有测试文件，非本任务引入、非产品日志路径） | 后续任务清理，不阻塞本次 |
| 2 | 观察项 | worktree 工作树 | 复验运行 flutter test/codegen 后 6 个插件注册文件 + 5 个 FRB 文件出现行尾符 M（`--ignore-cr-at-eol` 零内容差异） | 提交时按内容级范围 staging；非 executor 改动 |
| 3 | 说明项 | 验收 10 | `start_receiver` Rust 侧对合法输入无可达 Err 路径（启动仅 clone store + spawn），用例按借用不变式验证完整生命周期下 isDisposed 恒 false | executor 已如实披露，符合任务单"start 返回错误时 Store 仍可用"的回归意图 |
| 4 | 说明项 | 验收 18 | Windows+Android 双端配对联调未执行（环境无 TAP/ICS、NAT 阻断 host→guest） | 需在具备双端 TAP/ICS 测试网络的环境复验，不并入本次通过项 |

## 七、结论

**PASS-WITH-EXCEPTIONS**：21 条验收中 20 条通过（其中验收 15/16/17/19 reviewer 均实机复跑确认）；验收 18 未执行且 executor 如实标注，本环境限制不作 FAIL 打回，但**终检与交付报告必须明确保留"验收 18 未覆盖"标注**。实现正确、测试真实、无越界改动、无中高严重度问题。**可以进入主代理终检**。
