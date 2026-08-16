# Review Report — 任务 N：debug logging + 可测试 logger（审核子代理独立复验）

- worktree: `D:/Projects/CardMind/.worktrees/debug-logs`
- 分支: `codex/debug-logs`（HEAD 9034a3b4）
- 审核人: reviewer 子代理（独立实机复验，不采信 executor 自我评价）
- 日期: 2026-08-16
- 结论: **通过**（15 条验收全部通过；3 条既有环境问题/范围说明见问题清单）

## 复验环境

- OS: Windows（git-bash）
- cargo 1.94.0（已在 PATH，无需 export）
- flutter analyze / flutter test 在 worktree 根；cargo 命令在 `rust-backend/`
- 所有命令工具级 timeout：Rust ≤180000ms，Flutter ≤400000ms，均未超时

## 一、代码核查（独立阅读，非只读报告）

### 脱敏实现（验收 1）
- Flutter `lib/bridge/debug_log.dart`：`redactDeviceId` 前 8 + 后 8（≤16 字符原样）；`DebugLogger.event()` 构造入口对 `deviceIds` 一律 `.map(redactDeviceId)`；`_sanitizeFields` 对键命中 `code/key/secret/token/password/passwd/body/content` 的值替换为 `[redacted]`。
- Rust `rust-backend/src/debug_log.rs`：`redact_device_id` 前 8 + 后 8；`LogEvent::with_id` 立即脱敏（事件里永远只有 8+8 形式）；`emit_to` 包 `catch_unwind(AssertUnwindSafe)` —— 日志 sink panic 不打断主流程。
- **观察**：Rust 侧 `with_field` 无 Flutter 侧那种敏感键防御打码（依赖调用方人工保证），但核查 sync.rs 全部 `with_field` 调用键：`action/mode/notes_loaded/relay_enabled/relay_host/relay_port/enabled/port/count/candidates/peer_name/timeout_ms/outcome/direction/ok/bytes/note_count/transport/pending_*` —— 均非敏感键，值来源安全（relay_host 来自 `url.host_str()`，candidates 先 `redact_device_id` 再 join）。不构成缺陷，记录为观察项。

### relay 凭据剥离（验收 3）
- `relay_endpoint()` 只取 `url.host_str()` + `url.port()`，不含 userinfo/query/token；`relay.config` 事件只写 enabled/host/port。测试 `test_startup_emits_init_and_relay_events` 用 `https://user:secret@relay.example.com:9443/path?token=abc` 验证剥离（user/secret/token=abc/https:// 均不在事件中）。

### 日志失败兜底（验收 9）
- Rust `emit_to` 包 `catch_unwind`；`SyncService::emit_log` 先过滤 verbose 再 `emit_to`。
- Flutter `DebugLogger.emit` 包 try/catch 吞异常；`initializeBackendWithLogging` 失败路径发 failed 事件后 rethrow（启动失败仍上抛给 UI）。

### 配对埋点（验收 4/6/7，devices_page.dart）
- 手动 ID：`pairing.discovery` action=bypassed + `mdns_skipped=true` + 目标 id 脱敏；不调用 discoverPeers。
- 全链：show_code start/success/failed/cancelled、advertise start/stop(ok)、accept start/failed/timeout、request received、confirm start/success/failed、connect start(direct|relay_or_dns)/success/failed(错误链+耗时)。
- 配对码值从不写入事件字段（代码核查 + 测试断言 + 真实输出三重确认）。

### 同步埋点（验收 8/后续同步）
- Rust：sync.push initial（direction/note_count/耗时/错误链）、sync.receive（bytes/耗时）、sync.import、sync.push_pending（pending_count/ok_count）、sync.cycle、cleanup.mdns。
- Flutter：sync.trigger（reason=edit_save/manual/manual_push/cycle + pending_count）、sync.push/sync.cycle（ok/错误/耗时）。

### 范围外文件合理性
- `lib/main.dart`（9 行）：`initializeBackendWithLogging` 包装 RustLib/Bridge 初始化 —— 验收 2 启动事件必需。
- `lib/bridge/sync_scheduler.dart`（81 行）：SyncService 启动/触发/周期事件 —— 日志要求"启动（SyncService）、后续同步（触发原因/待同步数量/成功失败+耗时）"必需。
- `rust-backend/src/lib.rs`（1 行 `pub mod debug_log;`）、`Cargo.toml`（tracing 依赖）、`Cargo.lock`（1 行锁更新）—— Rust 侧日志模块注册与依赖，必需。
- `rust-backend/src/debug_log.rs`（新增）—— 任务要求 Rust 侧日志，必需。

## 二、验收标准逐条复验（命令 + 真实输出）

### 1. debug logger redacts device ids — ✅ 通过
- 命令：`cargo test --test debug_log_test`（已含在全量跑中，10/10 绿）+ `flutter test --timeout 3m`（+101 全绿）
- 真实输出（flutter test 中 Rust dylib 经 stderr 输出）：`event=startup.sync_service ... ids=[1a9a6111…eb8f9fce]` —— 8+8 脱敏形式，完整 id 未出现。
- 测试断言（真实值断言，非空断言）：
  - `test_redact_device_id`：`redact_device_id("abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGH") == "abcdefgh…ABCDEFGH"`，且断言不含中间部分、不含完整 id。
  - `test_events_never_contain_sensitive_data`：构造后断言事件文本不含完整 device id、SecretKey hex（读 device.key）、笔记正文（TOP-SECRET-NOTE-BODY-CONTENT / ANOTHER-PRIVATE-BODY）、api_key、配对码值；且断言脱敏形式出现。
  - Flutter `sensitive field keys ... are redacted`：`289260/sk-live-abc123/s3cret/tok-1/TOP-SECRET-NOTE-BODY/PRIVATE-CONTENT` 均不在 `toLine()+toString()` 中；`code/apiKey` 值为 `[redacted]`。
- 判定：通过

### 2. startup emits initialization events — ✅ 通过
- 命令：`flutter test --timeout 3m test/debug_log_test.dart` + `cargo test`（含 `test_startup_emits_init_and_relay_events`、`test_startup_failure_emits_event`）
- 真实输出：`test_startup_emits_init_and_relay_events ... ok`、`test_startup_failure_emits_event ... ok`（全量 10/10 绿）；Flutter 3 个 startup 测试绿。
- 断言：成功路径 `startup.rustlib:start/success`、`startup.bridge:start/success`；失败路径 `startup.bridge:failed`（error=StateError、errorChain 含 'bridge exploded'）并 rethrow；Rust 启动失败（无效 relay URL）经全局 sink 发 `startup.sync_service failed` + 错误链。
- 判定：通过

### 3. relay config emits safe endpoint event — ✅ 通过
- 命令：`cargo test --test debug_log_test`（`test_startup_emits_init_and_relay_events` + `test_relay_config_event_disabled_case`）
- 真实输出：均 ok。断言 `relay.config` 含 `enabled=true`、`relay_host=relay.example.com`、`relay_port=9443`；带凭据 URL `https://user:secret@relay.example.com:9443/path?token=abc` 时事件不含 user/secret/token=abc/https://；无 relay.txt → enabled=false 且无 host/port。
- 判定：通过

### 4. manual pairing emits discovery-bypass event — ✅ 通过
- 命令：`flutter test --timeout 3m`（`pairing_log_events_test.dart: manual pairing emits discovery-bypass event` 绿）
- 真实输出（flutter test 中 debugPrint）：`event=pairing.discovery ids=[manual-device-id] action=bypassed mdns_skipped=true`
- 断言：`discoverCalls == 0`（跳过 mDNS）、`mdns_skipped=true`、目标 id 以 `DebugLogger.redactDeviceId(...)` 形式记录。
- 判定：通过

### 5. mdns discovery emits count and duration — ✅ 通过
- 命令：`cargo test --test debug_log_test`（`test_mdns_discovery_emits_count_and_duration`，真实 mDNS 扫描）+ flutter 全量
- 真实输出：Rust 测试 ok（真实扫描，count 与 `peers.len()` 相等、duration_ms 存在）；flutter debugPrint 可见 `event=pairing.discovery duration_ms=0 action=result count=0`、`count=1`、`count=2`（空/单/多候选都记录数量）。
- 判定：通过

### 6. pairing accept lifecycle emits all stages — ✅ 通过
- 命令：`cargo test`（`test_pairing_accept_lifecycle_emits_all_stages`，真实双端配对）+ flutter 全量（8 个配对日志事件测试绿）
- 真实输出（flutter test 中 debugPrint）：`pairing.show_code action=start/success`、`pairing.advertise action=start`、`pairing.accept action=start timeout_ms=180000`、`pairing.request action=received`、`pairing.confirm action=start/success`、`pairing.accept action=end outcome=request_received`、`pairing.accept action=timeout`、`pairing.show_code action=cancelled` + `pairing.advertise action=stop ok=true`。
- 断言：配对码值（289260）不出现在任何事件字段值中；confirm success 含脱敏对端 id。
- 判定：通过

### 7. relay connection emits transport and error chain — ✅ 通过
- 命令：`cargo test`（`test_connect_emits_transport_and_error_chain`）+ flutter 全量
- 真实输出：Rust 断言 connect start transport=direct（ips 非空）、relay 配置 + 空 ips → transport=relay；失败事件含 error_chain + duration_ms。Flutter 断言 transport=direct / relay_or_dns；失败 errorChain 含 'refused'。flutter debugPrint 可见 `pairing.connect ids=[88807ca2…fae303d5] action=start transport=relay_or_dns`、`action=success transport=direct`。
- 判定：通过

### 8. initial sync emits counts only — ✅ 通过
- 命令：`cargo test`（`test_initial_sync_emits_counts_only`，真实双端配对 + 首次全量同步）
- 真实输出：`sync.import` success（direction=import、note_count=2、duration_ms）；`sync.push` success（direction=push、note_count=2）；事件文本不含 `SECRET-BODY-1/2`。flutter 真实 dylib 输出可见 `event=sync.import ... direction=import action=success note_count=1 bytes=347`（只记数量/字节/耗时）。
- 判定：通过

### 9. logger failure does not break flow — ✅ 通过
- 命令：`cargo test`（`test_logger_failure_does_not_break_flow`）+ flutter 全量（`throwing sink does not propagate`、`logger failure does not break pairing flow`）
- 真实输出：PanickingSink 下 create_note/import/begin_pairing_accept（返回 6 位码）/push_pending 全成功；Flutter ThrowingSink 下配对 UI 仍显示"配对成功"、confirmCalls=1。
- 判定：通过

### 10. cargo test 全绿，外层 180 秒硬上限 — ✅ 通过
- 命令：`cargo test`（工具级 timeout 180000ms）
- 真实输出：全部 test binary 0 failed；debug_log_test 10/10、pairing_test 10/10、connect_test 7/7、relay_config_test 7/7 等；`live_relay_test: 1 ignored`（`live_pairing_and_sync_over_dogcloud_relay`）。编译 37.38s + 测试约 30s，全程在 180s 内完成。
- 判定：通过

### 11. flutter test --timeout 3m 全绿 — ✅ 通过
- 命令：`flutter test --timeout 3m`（工具级 timeout 400000ms）
- 真实输出：`00:10 +101: All tests passed!`
- 判定：通过

### 12. flutter analyze 无 error — ✅ 通过
- 命令：`flutter analyze`
- 真实输出：`No issues found! (ran in 15.8s)`
- 判定：通过

### 13. 现有真实 relay 测试仍通过，未用 mock 替代 — ✅ 通过
- 命令：`cargo test --test debug_log_test --test relay_config_test --test connect_test`
- 真实输出：relay_config_test 7/7、connect_test 7/7、debug_log_test 10/10，0 failed。
- 核查：`git diff HEAD -- rust-backend/tests/relay_config_test.rs connect_test.rs live_relay_test.rs` 为空（既有未改动）。`test_relay_cross_network_connect` 用 `iroh::test_utils::run_relay_server()` 启动**真实本地 relay 服务器** + 真实 Endpoint 经 relay 中转传数据，非 mock；`live_relay_test` 的 `#[ignore]` 为既有标记（需公网）。
- 判定：通过

### 14. Windows/Android 平台日志采集 — ✅ 通过（覆盖范围如实）
- Windows（本机实机）：`flutter test --timeout 3m test/platform_log_capture_test.dart` → `00:00 +1: All tests passed!`。加载真实 cardmind_backend.dll（RustLib.init → FrbNoteRepository.open），真实 device id（>16 字符）断言 `line.contains(realId) == false`、`line.contains(redactDeviceId(realId)) == true`；`platform=windows` 断言。Rust 侧真实启动事件经 stderr 输出可见（`ids=[61598e4a…e6fbacb3]` 8+8）。
- Android：同一文件 `Platform.isAndroid` 分支已编写（断言 platform=android，debugPrint→logcat），**本环境无模拟器未实机执行**——executor 报告已如实说明，测试文件本身可运行性由 analyze + Windows 分支验证。任务要求明确报告实际覆盖范围，已满足。
- 判定：通过（覆盖范围：Windows 实机 / Android 仅代码就绪）

### 15. git status 改动只在任务范围内；未改 .gitignore — ✅ 通过
- 命令：`git status --short`、`git diff HEAD -- .gitignore`（无输出）、`git diff HEAD --stat`
- 真实输出：变更文件 = 任务列出的 7 个核心文件 + 4 个合理延伸（main.dart 启动包装、sync_scheduler.dart 触发事件、lib.rs 模块注册、Cargo.toml/lock 依赖）+ 新增 debug_log.rs/debug_log_test.rs/3 个 Flutter 测试 + .workflow 报告文件。无 .gitignore 改动、无 TAP/网卡/路由/防火墙/凭据文件、无 SecretKey/API key 写入。
- 判定：通过

## 三、问题清单

无阻断问题。以下为观察项 / 环境说明（不影响验收通过）：

1. **[观察] Rust 侧 `LogEvent::with_field` 无敏感键防御打码**（Flutter 侧有 `_sanitizeFields`）。当前所有调用点人工保证安全（键与值来源均核查过），且有 `test_events_never_contain_sensitive_data` 守护。建议后续若加 `with_field` 调用时保持审查。非缺陷。
2. **[环境] 无参 `flutter test` 跳过 `mobile_ui_test.dart` / `sync_scheduler_test.dart` / `platform_log_capture_test.dart`**：已在主仓库同一 commit 复现（既有 flutter 工具行为，非本次改动引入）。三个文件单独显式执行全部通过（11/2/1）。已在报告记录。
3. **[环境] Android 平台日志采集未实机执行**（本机无 Android 模拟器/真机）；Windows 实机已验证。覆盖范围已如实说明。
4. `live_relay_test` 的 `#[ignore]`（需公网 relay）为既有标记，不在自动回归内；真实 relay 验收由 relay_config_test/connect_test（真实本地 relay 服务器）覆盖。

## 四、最终结论

**通过。** 15 条验收标准全部实机复验通过；代码核查确认脱敏（8+8）、敏感字段防御、catch_unwind/try-catch 日志失败兜底、relay 凭据剥离、配对/同步/发现/清理全事件链均满足任务单要求；测试断言为真实值断言（非空断言）；范围纪律合格（无 .gitignore/TAP/凭据改动）。executor 自检报告与实机复验结果一致。
