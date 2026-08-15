# 审核子代理复验报告 — 任务 L（EndpointAddr 未附加 relay URL 跨网段连接缺陷修复）

- 审核时间: 2026-08-16（本地时区 +0800）
- 审核人: reviewer 子代理（独立复验，未修改任何代码）
- worktree: `D:/Projects/CardMind/.worktrees/relay-connect-fix`（分支 `codex/relay-connect-fix`，HEAD `9eb1a6ba`）
- 任务单: 任务 L（跨网段连接缺陷——EndpointAddr 未附加 relay URL）
- 执行子代理报告: `.workflow/executor-report.md`（已逐条核对）

---

## 结论：PASS（全部 8 条验收复验通过；无 BLOCKER / MAJOR；1 条复验副作用备注，非代码问题）

---

## 一、验收标准逐条独立复验

### 验收 0 — 缺陷回归（红阶段复现 + 修复后转绿）

**复验方式**：reviewer 纪律禁止回退代码，无法独立重跑红阶段；改为审查 executor 报告中红阶段证据（第 45-63 行）与任务单背景的一致性，并以修复后实机转绿（验收 5）反证。

**红阶段证据审查**：
- executor 报告修复前（git stash 后）实机输出：`connect to confirmer / Caused by: 0: No addressing information available / 1: No addressing information available / 2: All address lookup services failed or produced no results / Service 'dns' failed: no calls succeeded: [Failed to resolve TXT record x7]`，且进程挂死（60s+ 不退出，timeout 200s 强杀 exit 143）。
- 与任务单背景（Hermes 实机验证）错误链逐段一致：`No addressing information available` + `Service 'dns' failed: Failed to resolve TXT record` + 挂死现象。证据可信、时间线合理。
- 修复后转绿：本次独立实机复验确认（见验收 5，真实输出 3.45s 全绿）。

**结论：PASS**（红阶段证据与背景一致、可信；修复后转绿独立确认）

### 验收 1 — `test_endpoint_addr_carries_relay_url` ✅ PASS

**命令**：`cargo test --test relay_config_test`（rust-backend/ 下，worktree 内）
**真实输出**：
```
running 7 tests
test test_invalid_relay_url_fails_fast ... ok
test test_memory_service_never_reads_relay_file ... ok
test test_endpoint_addr_no_relay_stays_dns_only ... ok
test test_no_relay_file_disables_relay ... ok
test test_empty_relay_file_disables ... ok
test test_relay_file_enables_custom_mode ... ok
test test_endpoint_addr_carries_relay_url ... ok
test result: ok. 7 passed; 0 failed
```
**断言合理性核查**（读测试代码 relay_config_test.rs:116-139）：写入 `RELAY_URL` 到 relay.txt → `new_persistent`（Custom）→ `build_connect_addr(node_id, &[])` → 断言 `addr.relay_urls()` 恰好 1 个且与 relay.txt 内容一致（`trim_end_matches('/')` 容差）。真实覆盖"有 relay 时地址含 relay URL"语义。

### 验收 2 — `test_endpoint_addr_no_relay_stays_dns_only` ✅ PASS

**命令**：同上（7 passed，含本用例）
**断言合理性核查**（relay_config_test.rs:144-171）：不写 relay.txt → Disabled → 空 ips 地址 `relay_urls()` 为空（DNS-only 不变）；ips 非空直连路径同样不含 relay URL（行为不变）。真实覆盖"无 relay 时行为不变"语义。

### 验收 3 — `live_pairing_and_sync_over_dogcloud_relay` ✅ PASS（实机，见验收 5）

### 验收 4 — `cd rust-backend && cargo test` 全绿 ✅ PASS

**命令**：`cargo test`（rust-backend/ 下）
**真实输出汇总**：
```
autosync_test.rs      8 passed
connect_test.rs       7 passed
discovery_test.rs     2 passed
integration_test.rs   2 passed
live_relay_test.rs    0 passed; 1 ignored   ← #[ignore] 不参与默认
migration_test.rs     2 passed
note_crdt_test.rs    10 passed
pairing_test.rs       7 passed
relay_config_test.rs  7 passed
store_test.rs         6 passed
sync_service_test.rs  5 passed
sync_test.rs          1 passed
trash_test.rs        13 passed
```
**合计 70 passed, 0 failed, 1 ignored**（原 68 + 新增 2；live 正确 ignore）。与 executor 声称一致。

### 验收 5 — `cargo test --test live_relay_test -- --ignored --nocapture` 实机 ✅ PASS

**命令**：`cargo test --test live_relay_test -- --ignored --nocapture`（rust-backend/ 下）
**真实输出**：
```
running 1 test
[live] confirmer id: 3be716f27569c630d630a59246010a98cffbcd2c5cdd53da2642022b7a584e40
[live] initiator id: b6b4c389d8af1d5fe96f27a7532fcdb72c3d509d793944650fe734a84adba306
[live] pairing code: 777683
[live] paired: 3be716f27569c630d630a59246010a98cffbcd2c5cdd53da2642022b7a584e40 <-> b6b4c389d8af1d5fe96f27a7532fcdb72c3d509d793944650fe734a84adba306
[live] ✅ 配对 + 首次同步经 dogcloud relay 全链路成功
test live_pairing_and_sync_over_dogcloud_relay ... ok
test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 3.45s
```
**实机判定**：经真实 dogcloud relay（relay.alexc.cn:9443，两端各带 relay.txt）完成 配对 → 双方持久化对端 → 首次全量同步（发起方收到 n1）→ 3.45s 正常退出，无挂死。**最重要的实机复验通过**。

### 验收 6 — `flutter test` 全绿（73 不回归） ✅ PASS

**命令**：`flutter test`（worktree 根）
**真实输出**：`00:14 +73: All tests passed!`
未回归（73 = 任务单要求）。dll 已由 executor 的 release 构建就位，本次直接全绿。

### 验收 7 — `flutter analyze` 无 error ✅ PASS

**命令**：`flutter analyze`（worktree 根）
**真实输出**：`No issues found! (ran in 18.5s)`

### 验收 8 — `git status` 改动全在范围内 ✅ PASS（附复验副作用备注）

**命令**：`git status --short`、`git diff --stat codex/knowledge-base`（worktree 内）
**executor 改动（4 个文件，全在范围内）**：
```
 M .workflow/executor-report.md        （任务指定报告路径）
 M rust-backend/src/sync.rs
 M rust-backend/tests/live_relay_test.rs
 M rust-backend/tests/relay_config_test.rs
```
未动 `lib/`、`docs/`、`prototype/`、`.gitignore`。**范围核查 PASS**。

**⚠️ 复验副作用备注（非 executor 引入，需主代理/executor 处理）**：
本次复验执行 `flutter analyze`/`flutter test` 时触发 pub get（analyze 输出 `Changed 115 dependencies!`），在 worktree 工作区额外产生 7 个未提交改动：
```
 M pubspec.lock                            （pub 源 URL：pub.flutter-io.cn → pub.dev）
 M linux/flutter/generated_plugin_registrant.cc/.h  （无内容差异，仅重新生成/CRLF）
 M linux/flutter/generated_plugins.cmake
 M windows/flutter/generated_plugin_registrant.cc/.h
 M windows/flutter/generated_plugins.cmake
```
其中 6 个生成文件 `git diff` 无内容差异（纯重新生成/行尾），pubspec.lock 仅 URL 源替换。**这是 reviewer 复验动作的环境副作用，不属于 executor 的代码改动**（executor 报告第 147 行已声明其完成时已 `git checkout` 恢复同类文件）。reviewer 纪律禁止修改文件，无法自行恢复——请主代理安排 executor 在合并前 `git checkout` 恢复这 7 个文件。

---

## 二、代码审查结论（sync.rs diff，对照 codex/knowledge-base）

1. **核心修复正确**：新增 `SyncService::build_connect_addr(node_id, ips)`（sync.rs:604-627）：
   - 空 ips → `EndpointAddr::new(node_id)`，有 relay 配置（Custom）时 `with_relay_url(首个 URL)`；无 relay（Disabled，`relay_map().urls()` 空）时不附加 → **行为不变**。✅
   - ips 非空 → `EndpointAddr::from_parts` 直连路径，**原样保留**（含"无效 IP 报错"逻辑）。✅
   - 错误消息统一为 `no valid IPs provided`（原 `no valid target/peer IPs provided`；已 grep 确认无测试断言旧消息，行为兼容）。✅
2. **三处调用点全覆盖**（grep `EndpointAddr::new` 确认 sync.rs 中仅 helper 内部 610 行一处直接构造）：
   - `begin_pairing_connect`（sync.rs:644，原 612）✅
   - `push_to_peer`（sync.rs:1033，原 1015）✅
   - `push_to_peer_once`（sync.rs:1120，原 1125，自动同步内部路径——任务单未列出但属同一缺陷第三实例，executor 一并修复合理）✅
3. **relay_map API 形态**（需决策点 1）：未触发，且被实机证据支持——编译通过 + 单测 `test_endpoint_addr_carries_relay_url` 证明 Custom（relay.txt）下 `relay_map().urls()` 非空、`Disabled` 下为空且安全（不 panic）。executor 声称已在 iroh 1.0.2 源码核实，与其代码注释一致。
4. **live_relay_test.rs 挂死修复核查**（验收标准 2 要求）：
   - confirmer 侧 `accept_pairing_request`+`confirm_pairing` 用 `tokio::time::timeout(Duration::from_secs(120), ...)` 包裹，超时 panic 输出诊断（live_relay_test.rs:63-79）✅
   - 测试结束 `remove_dir_all` 清理临时目录（live_relay_test.rs:143-144）✅
   - `accept_push` 结果 `import_all` 导入（live_relay_test.rs:93-99）：修复测试自身逻辑缺陷（此前 `let _` 丢弃），实机全绿证明正确且必要。✅
5. **范围核查**：`git diff --stat codex/knowledge-base` 仅 4 个任务内文件 + 报告文件，无越界改动。`cargo clippy --all-targets` 无警告（本次复验实跑确认）。
6. **需决策点 2/3**：executor 报告称决策点 2 曾触发（配对成功但同步断言失败），根因为测试自身 `accept_push` 未 import，修复后全绿——与本次实机全绿一致；决策点 3（挂死根因）与红阶段证据吻合。未发现 mock 绕过。✅

---

## 三、问题清单

| # | 级别 | 位置 / 证据 | 说明 |
|---|------|-------------|------|
| 1 | INFO（复验副作用，非代码问题） | worktree 工作区：`pubspec.lock` + `linux/flutter/` x3 + `windows/flutter/` x3 | 本次复验 flutter analyze/test 触发 pub get 产生的未提交改动，非 executor 引入。reviewer 不能修改文件，请主代理/executor 合并前 `git checkout` 恢复 |
| 2 | INFO | `build_connect_addr` 错误消息统一为 `no valid IPs provided` | 与任务单字面"行为不变"无冲突（grep 确认无测试断言旧消息）；记录供追溯 |

**无 BLOCKER / MAJOR / MINOR 代码问题。** 全部 8 条验收标准复验通过。

---

## 四、审核方式说明

- 全部 Rust/Flutter 命令在 worktree `D:/Projects/CardMind/.worktrees/relay-connect-fix` 内独立实跑（未照抄 executor 报告）。
- reviewer 未修改任何代码/文件（写入本报告除外）；红阶段因纪律未回退复现，采用证据审查 + 修复后转绿反证。
- 主仓库 `D:/Projects/CardMind` 未受影响（其工作区 pre-existing 改动与本任务无关，本次审核未触碰）。
