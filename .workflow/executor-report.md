# Executor Report — 任务 N：app 日志与测试钩子（debug logging + 可测试 logger）

- worktree: `D:/Projects/CardMind/.worktrees/debug-logs`
- 分支: `codex/debug-logs`
- 日期: 2026-08-16
- 执行人: executor 子代理（TDD 红-绿-蓝）

## 一、完成内容

为 Android 模拟器与 Windows app 增加结构化、脱敏的调试日志与可测试 logger 接口。
**未修改任何 Windows 网卡 / TAP / 路由 / 防火墙配置**（主代理职责，本轮未做）。

### 改动文件清单

| 文件 | 改动点 |
|------|--------|
| `lib/bridge/debug_log.dart`（新增） | 共享日志模块：`DebugEvent`（时间戳/平台/事件名/阶段/脱敏 device id/错误链/耗时/字段）、`DebugSink` 接口、默认 `PlatformDebugSink`（→ `debugPrint`）、`DebugLogger` 单例（sink 注入/重置、平台注入、verbose 开关、`redactDeviceId` 8+8、敏感字段键防御性打码 `[redacted]`）、`initializeBackendWithLogging`（启动事件包装） |
| `lib/main.dart` | `initializeCardMindBackend` 改走 `initializeBackendWithLogging`：RustLib/Bridge 初始化成功/失败各有可断言事件 |
| `lib/bridge/bridge_helper.dart` | `init()` 记录 `startup.sync_service` start/success/failed + `identity.device_id`（脱敏） |
| `lib/bridge/frb_note_repository.dart` | `acceptAndImportPush` 记录 `sync.initial`（方向=import，start/success/failed，耗时） |
| `lib/bridge/sync_scheduler.dart` | `noteEdited`/`syncNow`/`pushNow`/`_runCycle` 记录 `sync.trigger`（触发原因 edit_save/manual/cycle/manual_push）+ `sync.push`/`sync.cycle`（ok/failed、待同步数、耗时） |
| `lib/pages/devices_page.dart` | 配对全生命周期事件：显示码 start/success/failed/cancelled、广播 start/stop（清理）、accept start/failed/timeout、请求 received、confirm start/success/failed、discovery start/result(count+耗时)/failed/bypassed(mdns_skipped)、connect start(direct|relay_or_dns)/success/failed(错误链+耗时)；原 `debugPrint('[pairing]...')` 全部替换为结构化事件 |
| `rust-backend/src/debug_log.rs`（新增） | 与 Flutter 对齐的 Rust 日志模块：`LogEvent`、`LogSink` trait、`PlatformSink`（tracing + eprintln 双输出）、`CollectingSink`/`PanickingSink`（测试）、`redact_device_id`、`set_global_sink`/`emit_global`（构造前失败兜底）、`emit_to` 包 `catch_unwind`（日志失败不打断主流程） |
| `rust-backend/src/lib.rs` | 注册 `pub mod debug_log;` |
| `rust-backend/src/sync.rs` | `SyncService` 增 `log: Arc<dyn LogSink>` + `log_verbose`；构造器重构成 `build(path, log)`，新增测试钩子 `new_persistent_with_log_sink`/`new_with_log_sink`；`set_log_verbose`；全流程埋点：启动（startup.sync_service / relay.config / identity.device_id）、配对（show_code / advertise / accept / request / confirm / connect start(direct|relay|dns) success/failed）、发现（discovery start/result count+耗时/failed，verbose 附候选脱敏 id）、同步（sync.push start/success/failed、sync.import、sync.receive、sync.cycle、sync.push_pending、cleanup.mdns）；**原 `eprintln!` 中的完整 device id（pairing initial sync / push failed）替换为脱敏事件** |
| `rust-backend/src/api.rs` | `create_sync_service`/`create_persistent_sync_service` 失败时经全局 sink 发 `startup.sync_service failed` 事件（不改变 FRB 函数签名） |
| `rust-backend/Cargo.toml` / `Cargo.lock` | 新增 `tracing = "0.1"`（已在 lock 中的传递依赖，无网络拉取） |
| `rust-backend/tests/debug_log_test.rs`（新增） | 10 个 Rust 验收测试（见测试清单） |
| `test/debug_log_test.dart`（新增） | 10 个 Flutter 单测（见测试清单） |
| `test/pairing_log_events_test.dart`（新增） | 8 个配对 UI 事件 widget 测试（见测试清单） |
| `test/platform_log_capture_test.dart`（新增） | Windows/Android 平台日志采集验证（见测试清单） |

**未改动**：`.gitignore`、Windows 网卡/TAP/路由/防火墙、`lib/src/rust/*` 生成代码（无 FRB surface 变更，未跑 codegen）。

## 二、验收标准逐条结果

> 验证命令均在 worktree 根/rust-backend 下实机执行；输出为真实命令输出摘要。

### 1. `debug logger redacts device ids` — ✅ 通过
验证：`timeout 180 cargo test --test debug_log_test`（`test_redact_device_id` / `test_events_never_contain_sensitive_data`）+ `flutter test --timeout 3m test/debug_log_test.dart`（`redacts long device ids...` / `event() always redacts...` / `sensitive field keys... are redacted`）。
真实输出（Rust 10/10 全绿，其中关键断言）：
```
test test_redact_device_id ... ok
test test_events_never_contain_sensitive_data ... ok
test result: ok. 10 passed; 0 failed
```
断言点：`redact_device_id("abcdefghijklmnopqrstuvwxyz0123456789ABCDEF") == "abcdefgh…ABCDEF"`；完整 device id / `device.key` SecretKey hex / 配对码 / 笔记正文 / API key 均不出现在任何事件中；脱敏形式（8+8）出现。Flutter 侧字段键防御打码：`code/apiKey/secret/token/body/content` 值替换为 `[redacted]`。

### 2. `startup emits initialization events` — ✅ 通过
验证：`flutter test --timeout 3m test/debug_log_test.dart`（`startup success...` / `startup failure...` / `rustlib init failure...`）+ Rust `test_startup_emits_init_and_relay_events` + `test_startup_failure_emits_event`。
真实输出：10/10 全绿（Rust 同文件 10/10 全绿）。
断言点：成功路径发出 `startup.rustlib:start/success`、`startup.bridge:start/success`；失败路径发出 `startup.bridge:failed`（error=StateError、errorChain 含消息）并 rethrow；Rust 侧 `startup.sync_service`（action=success、notes_loaded、relay_enabled、脱敏 id）与启动失败（无效 relay URL → `startup.sync_service failed` + 错误链）均有事件。

### 3. `relay config emits safe endpoint event` — ✅ 通过
验证：`timeout 180 cargo test --test debug_log_test`（`test_startup_emits_init_and_relay_events` / `test_relay_config_event_disabled_case`）。
真实输出：全绿。断言点：`relay.config` 事件含 `enabled=true`、`relay_host=relay.example.com`、`relay_port=9443`；URL 带凭据（`https://user:secret@relay.example.com:9443/path?token=abc`）时事件不含 `user/secret/token=abc/https://`（只输出 host:port）；无 relay.txt → `enabled=false` 且无 host/port 字段。实机日志样例（flutter test 中真实 dylib 输出）：
```
[cardmind:log] ... event=relay.config stage=sync.init ids=[9342a5d9…30e8e3b3] enabled=false
```

### 4. `manual pairing emits discovery-bypass event` — ✅ 通过
验证：`flutter test --timeout 3m test/pairing_log_events_test.dart`（`manual pairing emits discovery-bypass event`）。
真实输出：8/8 全绿。断言点：手动填写 device ID 路径发出 `pairing.discovery` action=bypassed、`mdns_skipped=true`、目标 id 脱敏（`FULLDEVI…89ABCDEF` 形式）；`discoverPeers` 调用数 = 0（跳过 mDNS）。

### 5. `mdns discovery emits count and duration` — ✅ 通过
验证：Rust `test_mdns_discovery_emits_count_and_duration`（真实 mDNS 扫描）+ Flutter `mdns discovery emits count and duration`。
真实输出：Rust 10/10 全绿、Flutter 8/8 全绿。断言点：`discovery.mdns` start 事件 + result 事件（count=实际发现数、duration_ms 存在）；空结果/多候选同样记录数量（Flutter 侧 widget 测试断言 count=1；Rust 侧真实扫描返回 0 也记录）。

### 6. `pairing accept lifecycle emits all stages` — ✅ 通过
验证：Rust `test_pairing_accept_lifecycle_emits_all_stages`（真实双端配对）+ Flutter `pairing accept lifecycle emits all stages` / `pairing accept timeout emits timeout event` / `pairing show-code cancel emits cancelled event`。
真实输出：Rust 10/10 全绿、Flutter 8/8 全绿。断言点：事件链完整——显示码 start/success、广播 start、accept start/end、request received、confirm start/success（Rust 侧含 confirm 失败/超时路径事件；Flutter 侧含 timeout/cancelled/清理 stop 事件）；配对码值不出现在任何事件字段。

### 7. `relay connection emits transport and error chain` — ✅ 通过
验证：Rust `test_connect_emits_transport_and_error_chain` + Flutter `connect failure emits transport and error chain` / `connect with empty ips records relay_or_dns transport`。
真实输出：Rust 10/10 全绿、Flutter 8/8 全绿。断言点：`pairing.connect` start 事件区分 transport（ips 非空→`direct`；空 ips + relay.txt→`relay`；空 ips 无 relay→`dns`；Flutter 侧手动路径→`relay_or_dns`）；失败事件含 `error`、`error_chain`（含 "refused" 等）、`duration_ms`。

### 8. `initial sync emits counts only` — ✅ 通过
验证：Rust `test_initial_sync_emits_counts_only`（真实双端配对 + 首次全量同步）。
真实输出：10/10 全绿。断言点：确认方 `sync.push` success 事件（direction=push、note_count=2、耗时）；发起方 `sync.import` success 事件（direction=import、note_count=2、耗时）；事件文本不含笔记正文（`SECRET-BODY-1/2` 均未出现）。

### 9. `logger failure does not break flow` — ✅ 通过
验证：Rust `test_logger_failure_does_not_break_flow`（`PanickingSink`）+ Flutter `throwing sink does not propagate from event()` / `logger failure does not break pairing flow`。
真实输出：Rust 10/10 全绿、Flutter 8/8 + 10/10 全绿。断言点：`PanickingSink`/`ThrowingSink` 下 create_note/import/begin_pairing_accept/push_pending 全部成功、配对 UI 完成（'配对成功' SnackBar 出现、confirm 被调用）；`emit_to` 包 `catch_unwind`、`DebugLogger.emit` 包 try/catch。

### 10. `cargo test` 全绿，外层默认 180 秒硬上限 — ✅ 通过
验证：`timeout 180 cargo test`（rust-backend）。
真实输出：
```
test result: ok. 10 passed; 0 failed ... (debug_log_test)
test result: ok. 10 passed; 0 failed ... (pairing_test)
...（全部二进制 0 failed）
EXIT: 0   （完整耗时 ~88s，含调试构建；在 180s 硬上限内）
```
注：`live_relay_test.rs` 中 `#[ignore]` 测试为**既有**（"需要公网 + relay 服务，手动运行"），非本次引入；真实 relay 验收由 `relay_config_test.rs`（真实 relay URL 配置解析）+ `connect_test.rs`（本地 relay 服务器连通）覆盖，均全绿。

### 11. `flutter test --timeout 3m` 全绿 — ✅ 通过
验证：`flutter test --timeout 3m`（worktree 根）。
真实输出：
```
00:14 +101: All tests passed!
EXIT_CODE=0
```
另：默认文件发现对本仓既有 `mobile_ui_test.dart`、`sync_scheduler_test.dart` 以及新增 `platform_log_capture_test.dart` 存在**跳过**现象——在主仓库同一 commit 上复现（既有环境行为，非本次改动引入）；三者单独显式执行均通过：
```
flutter test --timeout 3m test/sync_scheduler_test.dart test/mobile_ui_test.dart
00:02 +10: All tests passed!
flutter test --timeout 3m test/platform_log_capture_test.dart
00:00 +1: All tests passed!
```

### 12. `flutter analyze` 无 error — ✅ 通过
验证：`flutter analyze`。
真实输出：`No issues found!`（期间修复过 1 处 `@visibleForTesting` 误用于生产代码的 warning）。

### 13. 现有真实 relay 测试仍通过 — ✅ 通过
验证：`timeout 180 cargo test --test relay_config_test --test connect_test`。
真实输出：`relay_config_test` 7 passed、`connect_test` 2 passed（0 failed）。`live_relay_test` 的 `#[ignore]` 为既有标记未改动；未引入任何 mock 替代真实 relay 验收。

### 14. Windows/Android 各至少一条集成测试或平台日志采集验证 — ✅ 通过（覆盖范围如实说明）
- **Windows（实机执行）**：`test/platform_log_capture_test.dart` 在本机（Windows 宿主）加载真实 `cardmind_backend.dll`（`RustLib.init` → 真实 `FrbNoteRepository.open`），验证：
  - Rust 侧 `PlatformSink` 经 stderr 输出真实启动事件（flutter test 中可见 `event=startup.sync_service ... ids=[9342a5d9…30e8e3b3]`）；
  - DebugLogger 默认 `debugPrint` 通道输出格式化单行（`[cardmind:log] ... platform=windows event=identity.device_id ids=[8+8]`），真实完整 device id 不出现、8+8 脱敏形式出现；
  - `Platform.isWindows` → `platform=windows` 断言。执行结果：`All tests passed!`（1/1）。
  - 另整个 `cargo test`（88s）与 FRB 集成测试（pairing_repository/api_integration/frb_note_repository）都在 Windows 宿主实机运行，属平台级验证。
- **Android（已编写、未在本环境执行）**：同一 `platform_log_capture_test.dart` 在 Android 模拟器/真机上运行时 `Platform.isAndroid` 分支生效（断言 `platform=android`，debugPrint → logcat）。本环境无 Android 模拟器，未执行——如实说明覆盖范围。测试文件已就绪，`flutter analyze` 通过。

### 15. `git status` 改动只在任务范围内；未改 `.gitignore` — ✅ 通过
验证：`git status --short` + `git diff --stat -- .gitignore` + `git diff --stat`。
真实输出（最终状态）：
```
 M lib/bridge/bridge_helper.dart
 M lib/bridge/frb_note_repository.dart
 M lib/bridge/sync_scheduler.dart
 M lib/main.dart
 M lib/pages/devices_page.dart
 M rust-backend/Cargo.lock
 M rust-backend/Cargo.toml
 M rust-backend/src/api.rs
 M rust-backend/src/lib.rs
 M rust-backend/src/sync.rs
?? lib/bridge/debug_log.dart
?? rust-backend/src/debug_log.rs
?? rust-backend/tests/debug_log_test.rs
?? test/debug_log_test.dart
?? test/pairing_log_events_test.dart
?? test/platform_log_capture_test.dart
```
`.gitignore` diff 为空（`git diff --stat -- .gitignore` 无输出）。期间 `flutter pub get`/`flutter test` 工具链自动改动的 `pubspec.lock`（registry URL 镜像→pub.dev）与 `windows|linux/flutter/generated_plugin_registrant.*` 等**越界文件已全部 revert**，不在最终 diff 中。无 TAP/网卡/路由/防火墙/凭据文件写入。

## 三、新增测试清单

### Rust `rust-backend/tests/debug_log_test.rs`（10 个，全绿）
| 用例 | 覆盖点 |
|------|--------|
| `test_redact_device_id` | 脱敏函数：长 id → 前 8+后 8；短 id 原样；不含中间部分 |
| `test_events_never_contain_sensitive_data` | 完整 device id / SecretKey hex / 配对码 / 笔记正文 / API key 不进入事件；脱敏形式出现 |
| `test_startup_emits_init_and_relay_events` | 启动成功事件 + relay.config（enabled/host/port）；凭据/完整 URL 剥离 |
| `test_relay_config_event_disabled_case` | 无 relay.txt → enabled=false 且无 host/port |
| `test_startup_failure_emits_event` | 无效 relay URL → 全局 sink 收到 startup failed + 错误链 |
| `test_mdns_discovery_emits_count_and_duration` | 真实 mDNS 扫描：start/result 事件、count、duration_ms |
| `test_pairing_accept_lifecycle_emits_all_stages` | 真实双端配对：show_code/advertise/accept/request/confirm 事件完整 |
| `test_connect_emits_transport_and_error_chain` | direct vs relay transport；失败事件含错误链+耗时 |
| `test_initial_sync_emits_counts_only` | 首次全量同步 push/import 只记录 direction/note_count/耗时，无正文 |
| `test_logger_failure_does_not_break_flow` | PanickingSink 下主流程（建笔记/导入/配对码/push）仍成功 |

### Flutter `test/debug_log_test.dart`（10 个，全绿）
| 用例 | 覆盖点 |
|------|--------|
| `redacts long device ids to first-8 + last-8` | 脱敏函数 |
| `event() always redacts deviceIds before emit` | 事件构造入口强制脱敏 |
| `sensitive field keys ... are redacted` | code/key/secret/token/body/content 字段值打码 |
| `events carry timestamp/platform/event/stage fields` | 必含字段 |
| `startup success emits rustlib and bridge success events` | 启动成功事件 |
| `startup failure emits failed event and rethrows` | bridge 失败事件 + rethrow |
| `rustlib init failure emits rustlib failed event and rethrows` | rustlib 失败事件 + rethrow |
| `throwing sink does not propagate from event()` | 日志失败吞掉 |
| `verbose events are skipped unless verbose flag is on` | verbose 开关 |
| `default sink emits formatted line via debugPrint (Windows host)` | 平台日志采集：格式化单行 + 脱敏 |

### Flutter `test/pairing_log_events_test.dart`（8 个，全绿）
| 用例 | 覆盖点 |
|------|--------|
| `manual pairing emits discovery-bypass event` | 手动 ID → bypassed/mdns_skipped/脱敏目标 id；discover 调用数 0 |
| `mdns discovery emits count and duration` | discovery start/result(count=1/durationMs) |
| `pairing accept lifecycle emits all stages` | show_code/advertise/accept/request/confirm 全链；配对码不入事件 |
| `pairing accept timeout emits timeout event` | accept timeout 事件 + 广播停止 + UI 超时提示 |
| `pairing show-code cancel emits cancelled event` | cancelled + advertise stop(ok=true) |
| `connect failure emits transport and error chain` | mDNS 路径 transport=direct；失败事件 error/chain/durationMs |
| `connect with empty ips records relay_or_dns transport` | 手动路径 transport=relay_or_dns |
| `logger failure does not break pairing flow` | ThrowingSink 下配对仍完成 |

### Flutter `test/platform_log_capture_test.dart`（1 个，Windows 实机全绿）
| 用例 | 覆盖点 |
|------|--------|
| `real Rust backend emits safe logs via default platform sink` | 真实 dylib 启动 + debugPrint 平台通道格式化输出 + 真实 device id 脱敏 + 平台字段（Windows=windows / Android=android） |

## 四、问题未决

1. **`flutter test`（不带参数）默认文件发现会跳过 `mobile_ui_test.dart`、`sync_scheduler_test.dart`、`platform_log_capture_test.dart`**：在**主仓库同一 commit** 上复现（既有环境行为，非本次改动引入）。三者单独显式执行全部通过。若后续流水线要求"所有测试文件都被无参 `flutter test` 跑到"，需主代理/管理员确认是否排查该 flutter 工具行为（可能与本机多 worktree / 缓存有关）。
2. **Android 平台日志采集未实机执行**：本环境无 Android 模拟器/真机。测试文件已编写并通过 analyze，`Platform.isAndroid` 分支待真机/模拟器验证（详见验收 14）。
3. `live_relay_test.rs` 的 `#[ignore]`（需公网 relay）为既有标记，未纳入自动回归；真实 relay 由 relay_config_test/connect_test 覆盖。
4. 日志默认 `verbose=false`：候选 mDNS 设备列表等 verbose 事件需 `SyncService::set_log_verbose(true)` / `DebugLogger.verbose = true` 才输出（release 默认更安静，敏感内容按构造脱敏，即使开启也安全）。

## 五、平台日志采集验证（覆盖范围说明）

- **Windows**：`platform_log_capture_test.dart` 实机执行通过（真实 `cardmind_backend.dll` 加载、真实 device id 脱敏、`debugPrint` 平台通道格式化输出、`platform=windows` 断言）；整个 Rust 测试套件（88s）与 FRB 集成测试均在 Windows 宿主实机运行。
- **Android**：同一测试文件的 `Platform.isAndroid` 分支已编写（`platform=android`、logcat 通道），**未在本环境执行**（无模拟器）；已如实标注。
