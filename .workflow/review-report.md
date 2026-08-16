# 审核子代理复验报告 — 任务 M（显示码流程启动确认方接收器）

- 审核时间: 2026-08-16
- 审核人: reviewer 子代理（独立复验，未修改任何代码；仅落盘本报告）
- worktree: `D:/Projects/CardMind/.worktrees/pairing-accept-ui`（分支 `codex/pairing-accept-ui`）
- 任务单: 任务 M — 设备页"显示配对码"流程没有启动确认方接收器
- 执行子代理报告: `.workflow/executor-report.md`（已逐条独立复验，不采信其自我评价）

---

## 一、复验环境与命令清单

| # | 命令 | 结果 |
|---|------|------|
| 1 | `git branch --show-current` | `codex/pairing-accept-ui` |
| 2 | `git status --short`（复验前） | 18 个 M + 1 个 ??，全部在任务范围（详见验收 16） |
| 3 | `git diff --stat`（对照 HEAD 0486136e） | 18 文件变更，934+/260- |
| 4 | `git diff codex/knowledge-base -- .gitignore` | 空（无差异） |
| 5 | `git status --short docs/ prototype/ .gitignore` | 空（未改动） |
| 6 | `cargo test`（rust-backend，工具级 180s 硬上限） | **73 passed; 0 failed; 1 ignored**（live_relay 按设计 ignore） |
| 7 | `flutter test --timeout 3m`（工具级 400s） | **82 passed; 0 failed; All tests passed!** |
| 8 | `flutter analyze` | **No issues found!** (ran in 21.9s) |
| 9 | `flutter_rust_bridge_codegen generate` × 2 | 幂等：第二次后 `git diff --name-only` 与第一次一致 |
| 10 | `flutter test test/pairing_accept_ui_test.dart --timeout 3m` | **+8: All tests passed!**（8/8） |
| 11 | `cargo test --test pairing_test` | **10 passed; 0 failed**（含 3 个新增有界用例） |
| 12 | `flutter test test/pairing_repository_test.dart --timeout 3m` | **2 passed**（含 FRB 桥有界超时用例） |
| 13 | `flutter test test/pairing_mdns_widget_test.dart --timeout 3m` | **7 passed**（已有配对 mDNS 测试不回归） |
| 14 | `git show HEAD:lib/pages/devices_page.dart` / `rust-backend/src/sync.rs` | 旧实现确实无 accept 调用、无有界 API → 红阶段真实 |

> 备注：本环境无 GNU `timeout`（工具权限限制），采用 bash 工具级 timeout 参数等效 180s/400s 硬上限；均未触发超时。工具链 cargo 1.94.0 / Flutter 3.47.0 (Dart 3.13.0) / FRB codegen 2.12.0。

---

## 二、验收标准逐条独立结论

### 验收 1 — show-code starts confirmer accept loop：PASS
- 复验：`flutter test test/pairing_accept_ui_test.dart --timeout 3m` → `show-code starts confirmer accept loop` 通过。
- 代码审查：`_PairingAcceptDialog.initState → _runAccept()` 调用 `repository.acceptPairingRequestWithTimeout(widget.acceptTimeout)`（devices_page.dart:338-341）。fake 断言 `acceptCalls == 1`、`acceptTimeoutArg != null`。
- 旧实现（HEAD）`_showMyCode` 只显示码+广播，无任何 accept 调用 → 测试在旧实现上真实失败（红阶段真实）。

### 验收 2 — received request confirms with displayed code：PASS
- 复验：测试 `received request confirms with displayed code` 通过；断言 `confirmCalls == 1`、`confirmCode == '289260'`（弹窗显示的码）、`confirmRequester.deviceId == 'initiator-device'`。
- 代码审查：`_runAccept` 收到 `request` 后调用 `confirmPairing(widget.code, request)`（devices_page.dart:357-360），`widget.code` 即 `_showMyCode` 传入的 6 位码。

### 验收 3 — pairing success closes or updates waiting state：PASS
- 复验：测试 `pairing success closes or updates waiting state` 通过；断言 `listPairedCalls` 增加（列表刷新）、`pair-code-display` findsNothing（弹窗关闭）、`配对成功` snackbar 出现、设备列表出现对方。
- 代码审查：confirm 成功后 `Navigator.of(context).pop(result)`（devices_page.dart:363）→ `_showMyCode` 显示 snackbar + `await _load()` 刷新（devices_page.dart:205-209）。

### 验收 4 — cancel stops advertising and accept task：PASS（真实链路有已知延迟，见问题清单 M-1）
- 复验：测试 `cancel stops advertising and accept task` 通过；断言取消后 `advertisingStopped == true`、accept 晚到请求 `confirmCalls == 0`、`tester.takeException() == null`（无向已卸载 widget setState）。
- 代码审查：`dispose() → _cancelled = true`；每个 await 后有 `!mounted || _cancelled` 守卫（devices_page.dart:344/352/357/361）。`_showMyCode` finally 调 `stopPairingAdvertising()`（devices_page.dart:210-217）。
- 真实链路延迟见问题清单 M-1（executor 已披露）。

### 验收 5 — accept failure is visible and recoverable：PASS
- 复验：测试 `accept failure is visible and recoverable` 通过；断言错误 Key `pair-accept-error` 出现、文本可读（不含裸 AnyhowException）、`advertisingStopped == true`、重新发起 `acceptCalls == 2`。
- 代码审查：`_runAccept` catch 分支 `await _stopAdvertisingQuietly()` → setState `_error='等待配对请求失败，请关闭后重试'`（devices_page.dart:344-352）。

### 验收 6 — accept timeout is bounded：PASS
- 复验：widget 测试 `accept timeout is bounded` 通过（fake 返回 null 模拟超时 → 显示"等待配对超时" + 停广播，00:01 内完成，无 fake timer 无限问题）。
- Rust 有界性：`cargo test --test pairing_test` → `test_accept_pairing_request_with_timeout_returns_none_on_timeout`（外层 5s timeout，内部 200ms 时限）与 `..._zero_returns_immediately`（0ms 立即返回）通过。
- FRB 桥：`flutter test test/pairing_repository_test.dart` → `bounded accept times out through FRB bridge`（100ms → null）通过。
- 代码审查：sync.rs:490-533 每个 accept 窗口 `window = remaining.min(500ms)`，`tokio::time::timeout(window, self.endpoint.accept())`；deadline 到点 `return Ok(None)`。测试总时长远小于 3 分钟。

### 验收 7 — reopen does not duplicate accept loops：PASS
- 复验：测试 `reopen does not duplicate accept loops` 通过；断言第一次打开 acceptCalls==1，关闭后第二次打开 acceptCalls==2，两个挂起 accept future 完成后只有活弹窗 confirm（confirmCalls==1）。
- 代码审查：每次打开新建 `_PairingAcceptDialog`（新 State），dispose 置 `_cancelled` 的旧弹窗收到请求后不 confirm。真实 FRB 路径同一 SyncService 的 RwLock 写锁串行化，不会真正并发两个 accept（见 M-1 的锁语义）。

### 验收 8 — manual relay pairing UI path：PASS
- 复验：测试 `manual relay pairing UI path` 通过；断言确认方 accept/confirm 调用链完整，发起方填 device ID 后 `discoverCalls == 0`（不走 mDNS）、`connectCalls == 1`、`connectTarget.deviceId` 为手动填写值、`connectCode == '289260'`。
- 代码审查：`_enterPeerCode` 中 `manualId.isNotEmpty` 分支直接构造 `PairingTarget(deviceId: manualId)` 跳过 discoverPeers（devices_page.dart:307-311）。

### 验收 9 — opaque pairing accept lifecycle is bounded：PASS
- 复验：`cargo test --test pairing_test` 3 个新增用例全过（超时 None / 0ms 立即返回 / 成功 Some + confirm + 自动推送）。FRB 桥 100ms 超时测试过。
- 代码审查（sync.rs:490-533）：
  - 三路径返回：成功 `Ok(Some)`（pending 或 accept 到配对帧）、超时 `Ok(None)`、异常经 `?` 传播。
  - 每次 accept 窗口 `window = remaining.min(500ms)` 且被 `tokio::time::timeout` 包裹（阻塞网络操作有界）。
  - spawn 两侧：测试中 confirmer/initiator 两个 spawn task 的 JoinHandle 均被 `tokio::time::timeout(20s)` 包裹（两侧都有兜底）；task 内部 begin_pairing_connect / accept_push 也各有 10s timeout。
  - 推送帧不丢失：`accept_incoming_routed` 返回 Some(data) → `import_all`（sync.rs:513-521），M1 语义保留。
  - `accept_pairing_request` 委托有界核心（24h 边界），语义兼容，已有测试绿。

### 验收 10 — existing pairing integration remains green：PASS
- 复验：`cargo test` 全量 73 passed（connect/discovery/pairing/sync/autosync/live_relay(ignored) 全部绿）；`flutter test` 全量 82 passed（含 pairing_mdns 7、pairing_repository 真实 FRB、api_integration 等）。专门复跑 `flutter test test/pairing_mdns_widget_test.dart` → 7 passed。

### 验收 11 — timeout 3m cargo test：PASS
- 复验：`cargo test` 在 180s 工具级硬上限内完成，73 passed; 0 failed。（本环境无 GNU timeout，用等效 180s 上限。）

### 验收 12 — flutter test --timeout 3m：PASS
- 复验：`flutter test --timeout 3m` → 82 passed; 0 failed; All tests passed!（400s 工具上限内，含 pub get 与编译时间）。

### 验收 13 — flutter analyze：PASS
- 复验：`flutter analyze` → `No issues found! (ran in 21.9s)`。

### 验收 14 — flutter_rust_bridge_codegen generate 幂等：PASS
- 复验：连续运行两次 `flutter_rust_bridge_codegen generate`，第二次后 `git diff --name-only` 与第一次一致（无新增内容变更）；生成文件 `frb_generated.rs/.dart/.io/.web`、`api.dart` 与源（api.rs 新函数、sync.rs 新方法）一致，funcId 顺移正常。

### 验收 15 — 真实双端 UI 验证：**未验证（按决策点 3 报告）**
- 无法在当前环境执行 Android↔Windows 真机双端 relay 配对联调（需新平台自动化能力）。未覆盖项与 executor 报告一致：真机日志不再出现 `connect to confirmer -> timed out`、两端设备列表互现。**不声称 UI 通过**。

### 验收 16 — git status 范围 / .gitignore：PASS（附复验副作用说明）
- 复验前 `git status --short`：18 个 M + 1 个 ??（`test/pairing_accept_ui_test.dart` 新增），全部在任务单改动范围（lib/pages、lib/bridge、lib/src/rust 生成、rust-backend/src、rust-backend/tests、test/）。
- `git diff codex/knowledge-base -- .gitignore`：空。`docs/`、`prototype/`：`git status --short` 与 `git diff --name-only` 均为空。
- ⚠️ 复验副作用（非 executor 改动）：复验期间 `flutter test` 自动 pub get 将 `pubspec.lock` 的 url 从 `pub.flutter-io.cn` 改为 `pub.dev`（116 行镜像地址差异），codegen 重写了 `lib/src/rust/discovery.dart/store.dart/sync.dart` 与 `linux|windows/flutter/generated_plugin_registrant.*`（内容 hash 与 HEAD 相同，仅行尾/stat 噪音）。这些是 reviewer 复验动作引入的工作区噪音，**合并前需还原**（`git checkout --` 上述文件），不属于 executor 越界。

---

## 三、代码审查发现（问题清单）

### CRITICAL
无。

### MAJOR
- **M-1【真实链路：取消后广播停止延迟最长 3 分钟；executor 已披露，需主代理知悉并评估】**
  - 位置：`lib/pages/devices_page.dart` `_showMyCode` finally + `_PairingAcceptDialog` 生命周期；`rust-backend/src/sync.rs` `accept_pairing_request_with_timeout`。
  - 证据：FRB 2.12 `RustAutoOpaqueInner<T>` 内部是 `tokio::sync::RwLock<T>`（已读 crate 源码 rust_auto_opaque/inner.rs 确认）。`accept_pairing_request_with_timeout(svc: &mut SyncService)` 生成代码走 `lockable_decode_async_ref_mut`（**写锁**），`stop_pairing_advertising(svc: &SyncService)` 走 `lockable_decode_async_ref`（**读锁**）。用户关闭显示码弹窗（取消）时 `_showMyCode` finally 调 `stopPairingAdvertising()`，但若 accept 写锁仍在飞（最长 3 分钟），该读锁调用会排队等待 → **真实环境中取消后 mDNS 广播不会立即停止**，最长延迟至 accept 超时（3 分钟）。
  - executor 已在其"已知限制"中如实披露（"有界等待在飞时持有 SyncService FRB opaque 锁最长 3 分钟；期间 stopPairingAdvertising/同步调度器等待该锁"）。披露真实准确。
  - 影响评估：不违反"不得留下永久阻塞任务"（3 分钟有界，最终自释）；但验收 4 的"取消后停止广播"在真实 FRB 路径存在最长 3 分钟延迟，widget 测试用 fake（立即返回）无法暴露该时序。若主代理认为不可接受，后续可缩短 `pairingAcceptTimeout` 或改为非阻塞轮询（超本任务范围）。
  - 判定：不构成打回（任务单预授权有界 API 方案、限制已披露、有界非永久）；列入 MAJOR 供主代理决策。

### MINOR
- **m-1【注释与实现不一致：文档声称"10s 轮询"，实际单次 3 分钟调用】**
  - `lib/bridge/note_repository.dart`、`rust-backend/src/api.rs`、`rust-backend/src/sync.rs` 的注释均写"UI 侧显示码流程以短窗口（10s）轮询调用本方法"，但 `_PairingAcceptDialog` 实际以 `pairingAcceptTimeout = 3 分钟` 单次调用 `acceptPairingRequestWithTimeout`。注释是设计初稿残留，与实现不符，易误导后续维护。建议主代理安排修正注释（非功能缺陷）。
- **m-2【复验副作用污染工作区】**
  - `pubspec.lock`（pub.get 镜像地址 116 行）、`lib/src/rust/discovery.dart/store.dart/sync.dart`、`linux|windows/flutter/generated_plugin_registrant.*` 为 reviewer 复验命令（flutter test 自动 pub get + codegen）产生的噪音，需在合并前 `git checkout --` 还原。非 executor 越界。

### NIT
- **n-1【`_PairingAcceptDialog._stopAdvertisingQuietly` 与页面 finally 双停广播】**：超时/异常路径 `_stopAdvertisingQuietly` 停一次，页面 finally 再停一次（幂等、有 catch，无实际危害）。可接受。
- **n-2【红阶段证据为间接推断】**：审核未回滚代码重跑红阶段（纪律禁止改文件），但 HEAD 快照确认旧 `_showMyCode` 无任何 accept 调用、旧 `sync.rs` 无有界 API → 新测试在旧实现上必然失败（acceptCalls=0 / 编译错误），红阶段真实可锁定缺陷。

---

## 四、对 executor 已知限制的独立判断

1. **决策点 1（有界 API 替代无法取消的 FRB opaque 等待）**：独立确认合理且必要。FRB `RustAutoOpaqueInner` 用 `tokio::sync::RwLock`，`accept_pairing_request`（`&mut`）在旧实现中无限循环持有写锁，确实无法被 Flutter 侧取消；新增 `accept_pairing_request_with_timeout` 是任务单预授权的最小方案。三路径（成功/取消(0ms)/超时）均有测试且返回有界；spawn 两侧 timeout 满足超时铁律。
2. **3 分钟锁持有是否构成新问题**：构成**真实的行为延迟**（M-1：取消后广播停止延迟最长 3 分钟、期间 stopPairingAdvertising/同步调度器等待），但**不构成永久阻塞**（有界自释），不违反"不得留下永久阻塞任务"。已如实披露。判定为 MAJOR 已知限制而非 CRITICAL 缺陷。
3. **决策点 2（dispose → _cancelled 守卫）**：实现正确，`mounted/_cancelled` 双守卫覆盖所有 await 后路径，无向已卸载 widget setState 路径（验收 4 实测 `takeException() == null`）。
4. **决策点 3（真实双端 UI 无法执行）**：按任务单要求如实报告未覆盖，未声称 UI 通过。正确。

---

## 五、总体结论：**通过（PASS）**

全部 16 条验收标准独立复验结果：**15 条 PASS，1 条（验收 15 真实双端 UI）按决策点 3 如实报告未验证**。无 CRITICAL / 必须修复项。

**须主代理知悉/跟进（非打回项）：**
1. **M-1**：真实 FRB 路径取消后广播停止最长延迟 3 分钟（executor 已披露，本报告独立确认锁机制），请主代理决策是否接受或后续缩短时限。
2. **m-2**：合并前需还原 reviewer 复验产生的 `pubspec.lock` 与生成文件行尾噪音（`git checkout --` 还原），避免误入库。
3. **m-1**：`10s 轮询` 注释与 3 分钟单次调用实现不一致，建议后续修正注释。
4. 验收 15 未覆盖项保留，交付 Hermes 终审时如实标注。
