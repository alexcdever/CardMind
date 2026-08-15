# 审核子代理复验报告 — 任务 J（mDNS 自动发现接线）

- 审核时间: 2026-08-15（本地时区 +0800）
- worktree: `D:/Projects/CardMind/.worktrees/pairing-mdsn`（分支 `codex/pairing-mdns`，HEAD `04e46f31`）
- 审核方式: 独立实机复验（只读代码；所有验收标准命令均重新实跑，未照抄 executor 报告）
- 任务单: `docs/task-j-pairing-mdns.md`

---

## 一、验收标准逐条复验（0-10）

### 验收 0 — 缺陷回归测试 `test_regression_empty_device_id_user_path`

**命令**：`flutter test test/pairing_mdns_widget_test.dart`
**真实输出**（节选）：
```
00:02 +7: All tests passed!
```

**测试存在性**：`test/pairing_mdns_widget_test.dart` L201-230 存在该用例。

**断言覆盖"不出现 AnyhowException 字样"核实**（逐行读文件）：
- L216 `expect(find.textContaining('未在局域网发现'), findsOneWidget, ...)` —— 走友好错误分支
- L221 `expect(find.textContaining('AnyhowException'), findsNothing, ...)` —— 明确断言 UI 不含裸异常字样
- L226 `expect(repository.connectCalls, 0, ...)` —— 空结果不得发起连接（实机缺陷路径被阻断）

**红→绿可推演性**：HEAD 旧代码无 mDNS 逻辑，设备 ID 留空时直接 `beginPairingConnect(deviceId:'')` → fake（L92-94）按真实后端语义抛 `AnyhowException('invalid target endpoint id — invalid length')` → 旧 UI 渲染 `配对失败: $error` 会同时违反 findsNothing（出现 AnyhowException 字样）与 findsOneWidget（无"未在局域网发现"）→ 旧码必红；修复后实机全绿。与任务单"先红后绿"要求一致。

**结论：PASS**

### 验收 1-5 — Flutter widget 测试（test/pairing_mdns_widget_test.dart）

**命令**：`flutter test test/pairing_mdns_widget_test.dart`
**真实输出**：
```
00:00 +0: test_regression_empty_device_id_user_path
00:00 +1: confirmer advertises while showing code
00:01 +2: requester auto-fills device id via mdns
00:01 +3: requester shows friendly error when mdns finds nothing
00:01 +4: requester uses manual device id when provided
00:01 +5: requester cancels advertising on dialog close
00:01 +6: requester shows guidance when multiple mdns devices found
00:02 +7: All tests passed!
```
7 用例全绿（验收 1-5 各 1 条 + 验收 0 回归 + 附加多台歧义用例）。逐条断言点已在阅读测试源码时核对（见审核重点 5）。

**结论：PASS**

### 验收 6 — flutter pub get && flutter test 全绿

**命令**：
```
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR=D:/Projects/CardMind/.worktrees/pairing-mdsn/rust-backend/target/debug/deps
flutter pub get
flutter test
```
**真实输出**：`flutter pub get` → `Got dependencies!`；`flutter test` → `00:08 +73: All tests passed!`

73 = 既有 66 + 新增 7，全绿，与 executor 报告一致。FRB 相关测试（api_integration / frb_note_repository）在该 env var 下正常加载 `cardmind_backend.dll`（`rust-backend/target/debug/deps/cardmind_backend.dll` 实测存在）。

**结论：PASS**

### 验收 7 — flutter analyze 无 error

**命令**：`flutter analyze`（实现改动后 + codegen 后各跑一次）
**真实输出**（两次均）：
```
Analyzing pairing-mdsn...
No issues found! (ran in 20.0s)
```
**结论：PASS**

### 验收 8 — cd rust-backend && cargo test 全绿

**命令**：`cargo test`（cargo 1.94.0 已在 PATH）
**真实输出**（逐测试文件汇总）：
```
lib unittests:                0 passed; 0 failed
autosync_test:                8 passed
connect_test:                 7 passed
discovery_test:               2 passed
integration_test:             2 passed
migration_test:               2 passed
note_crdt_test:              10 passed
pairing_test:                 7 passed   ← 6 既有 + 1 新增 test_pairing_accept_with_advertising_lifecycle
store_test:                   6 passed
sync_service_test:            5 passed
sync_test:                    1 passed
trash_test:                  13 passed
Doc-tests:                    0 passed
────────────────────────────────────────
合计 63 passed; 0 failed
```
既有 62 不回归 + 新增 1，全绿。新增用例 `test_pairing_accept_with_advertising_lifecycle` 实跑 `ok`，覆盖：6 位数字码、广播期间 discover 不报错、stop 幂等（连续两次）、再次组合调用生成新码。

**结论：PASS**

### 验收 9 — flutter_rust_bridge_codegen generate 成功且无未预期改动

**命令**：`flutter_rust_bridge_codegen generate`（版本 2.12.0，与 flutter_rust_bridge.yaml 配置一致）
**真实输出**：
```
[INFO ...] Has .fvmrc but no fvm binary installation, thus skip using fvm.
[INFO ...] To handle some types, `enable_lifetime: true` may need to be set...
Done!
```

**生成物一致性核查**：运行前后 `git status --short` 对比——
- 运行前已改动（executor 遗留）：`lib/src/rust/api.dart`、`frb_generated.dart`、`frb_generated.io.dart`、`frb_generated.web.dart`、`rust-backend/src/frb_generated.rs`
- 运行后新增标脏：`lib/src/rust/discovery.dart`、`store.dart`、`sync.dart` —— 但 `git diff --numstat` 为空（**内容 diff 为 0，仅行尾 LF/CRLF 字节 churn**，Windows 环境代码生成写 CRLF 所致，同现象已存在于 executor 遗留的 `frb_generated.io/web.dart`）
- `lib/src/rust/api.dart` 内容 diff = 15 增 0 删，包含 3 个新方法（`beginPairingAcceptWithAdvertising` / `stopPairingAdvertising` / `syncDiscoverPeers`，实测 grep 到），与 Rust 侧 `api.rs` 新增的 3 个导出一一对应

即：**同一 codegen 命令可复现 executor 的生成内容，无内容级未预期改动**；仅存在 Windows 行尾 churn（提交时 git 会按配置归一化，不构成内容漂移）。

**结论：PASS**（附注：合并前建议确认行尾归一化行为）

### 验收 10 — git status 改动全在范围内

**executor 遗留改动清单**（审核开始时实测 `git status --short`）：
```
 M .workflow/executor-report.md
 M lib/bridge/bridge_helper.dart
 M lib/bridge/frb_note_repository.dart
 M lib/bridge/note_repository.dart
 M lib/pages/devices_page.dart
 M lib/src/rust/api.dart
 M lib/src/rust/frb_generated.dart
 M lib/src/rust/frb_generated.io.dart
 M lib/src/rust/frb_generated.web.dart
 M rust-backend/src/api.rs
 M rust-backend/src/frb_generated.rs
 M rust-backend/src/sync.rs
 M rust-backend/tests/pairing_test.rs
 M test/mobile_ui_test.dart
 M test/sync_ui_widget_test.dart
 M test/vertical_slice_widget_test.dart
?? test/pairing_mdns_widget_test.dart
```
全部落在任务单改动范围内（`lib/src/rust/` 与 `frb_generated.rs` 为 codegen 产物，内容已由验收 9 复核）。**`docs/`、`prototype/`、`.gitignore` 均未被改动**（git status 无相关条目；`.gitignore` 内容与主仓库一致）。

**注意（非 executor 引入）**：审核人实机验证产生的副作用——
- `flutter pub get` / `flutter test` 重写了 `linux|windows/flutter/generated_plugin_registrant*`（6 个文件，审核开始时为 clean；主仓库同现象，属 Flutter 工具链环境副作用）
- 审核人跑 codegen 使 `lib/src/rust/discovery.dart`、`store.dart`、`sync.dart` 变为行尾 churn 标脏（内容 diff 为空，见验收 9）
- 审核人只读纪律，未做任何 `git checkout` 还原，以上副作用如实报告，请主代理合并时按需还原

**结论：PASS**

---

## 二、审核重点发现（问题清单）

### 审核重点 1 — Rust 侧组合的正确性

**结论：整体正确，无阻塞问题。**

实读 `rust-backend/src/sync.rs` L344-407 与 `discovery.rs` 全文件：
- `begin_pairing_accept_with_advertising`：先 `begin_pairing_accept()?`（生成码+清 pending），再 `endpoint_listen_port()` 取端口，锁内惰性创建 `DiscoveryService` 并 `start_advertising(&self.device_id(), port)`。组合语义正确（码与广播同调用内完成）。
- port 取值 `self.endpoint.addr().ip_addrs().next().port()` 与 `local_addrs()` 同源（sync.rs L304-311），即本端点实际监听端口；对端 `beginPairingConnect` 在 `target.ips` 非空时直连，取真实端口合理。
- `tokio::sync::Mutex<Option<DiscoveryService>>`：用 tokio Mutex 原因（跨 await 持锁需 Send future）成立。惰性创建无问题；`SyncService` Drop 时 `DiscoveryService` Drop 会停广播（discovery.rs L155-160），无资源泄漏。
- 无死锁：当前 UI 流程（弹窗模态互斥）不存在 discover（持锁 3s）与 advertise/stop 并发；`start_advertising` 非 await，锁不跨 await。

**MINOR-1（锁竞争窗口）**：`discover_peers`（sync.rs L398-407）跨 `await` 持锁最长 3 秒，期间同服务并发调用 `begin_pairing_accept_with_advertising` / `stop_pairing_advertising` 会被阻塞。当前 UI 无并发路径可达，不构成缺陷；若未来出现后台扫描场景需注意。

**MINOR-2（port 回退 0）**：`endpoint_listen_port` 在 `ip_addrs()` 为空时回退 0 → mDNS 广播 port 0 → 发起方自动填充得到 `ip:0` 无法直连。局域网直连场景下 endpoint 必有本地地址，概率极低；但 relay-only 或地址暂未就绪的窗口期可能出现。

### 审核重点 2 — 生命周期

**结论：确认方弹窗关闭（含异常路径）的 stop 语义正确。**

实读 `devices_page.dart` L170-228：
- `try { showDialog } finally { stopPairingAdvertising }` —— Dart `finally` 在 `return`（L183 `if (!mounted) return`）、异常、barrier 点按关闭（`showDialog` 默认 `barrierDismissible: true`）等所有路径都会执行，stop 保证被调。
- stop 自身异常被捕获并 `debugPrint`，不向上抛。
- 配对码过期（10 分钟）后广播不自动停止：executor 已按需决策点 2 报告。核对结论：码校验在 Rust 侧仍拒绝过期码，无配对正确性风险；仅"设备持续可被发现"（广播仅含 device_id+port，无敏感数据）。当前确认方 UI 无配对完成接线（既有行为），弹窗关闭是唯一停止点——可接受，建议主代理确认。

**MINOR-3（组合 API 失败路径不防御性 stop）**：`beginPairingAcceptAndAdvertise()` 抛错时（L174-181 catch）直接 `return`，未调用 stop。Rust 实现中 `begin_pairing_accept` 成功后才可能 `start_advertising` 失败，此时 pairing_session 已生成但广播可能半启动。概率低、无直接错误连接风险；防御性 stop 更稳妥。

### 审核重点 3 — UI 错误脱敏

**结论：发起方（输入码）分支脱敏完整。**

实读 `devices_page.dart` L368-375：
- 配对失败 → `debugPrint('[pairing] beginPairingConnect failed: $error')` 保留原始错误，UI 显示固定文案"配对失败：无法连接到对方设备。请确认两台设备在同一网络后重试"，无裸 AnyhowException。
- discover 失败（L330-334）→ debugPrint 后按空结果走友好提示，不泄露异常。
- stop 失败（L225）→ debugPrint 吞掉。
- widget 测试 L220-224 显式断言 `find.textContaining('AnyhowException') findsNothing`。

**MINOR-4（确认方 SnackBar 仍可能暴露裸错误）**：`_showMyCode` 的 catch（L178）显示 `'生成配对码失败: $error'`——该文案为 HEAD 预存在（`git show HEAD:lib/pages/devices_page.dart` L173 核实），非本任务引入；但本任务把该分支改为调用新组合 API（mDNS 失败会抛 anyhow 链），使裸错误通过此文案的暴露面变宽。建议顺带脱敏（不在本任务验收范围内，仅提示）。

### 审核重点 4 — 多台设备分支

**结论：实现与测试一致，但需主代理拍板设计冲突。**

executor 按需决策点 1（"不要静默取第一台"）实现：`peers.length > 1` → 显示"在局域网发现多台 CardMind 设备，无法自动确定配对对象。请手动填写对方设备 ID"，`connectCalls == 0`（devices_page.dart L345-352）。widget 测试 L365-389 覆盖。任务单设计需求 2 与需决策点 1 存在文字冲突（取第一台 vs 不要静默取第一台），executor 选择更安全路径并在报告中显式上报——符合"触发需决策点必须报告"纪律。

**确认请求（非缺陷）**：请主代理确认"多台 → 提示手动填写（不自动连接）"为最终行为，或改为"取第一台"/用户选择 UI（改动集中在 `peers.length > 1` 分支）。

### 审核重点 5 — 测试质量

**结论：fake 忠实反映接口契约，断言点充分，非空转。**

- fake `PairingMdnsRepository`（L28-168）完整实现 `NoteRepository`；`beginPairingConnect` 对空 deviceId 抛与真实后端一致的 `AnyhowException('invalid target endpoint id — invalid length')`，使回归测试真实复现实机缺陷路径。
- 断言强度核实（逐条读测试源码）：
  - 验收 1（L233-254）：`acceptCodeCalls==1` + `advertisingStarted==true` + 码文本可见 + 关闭后 `advertisingStopped==true` —— 覆盖开始与停止两向。
  - 验收 2（L257-287）：`discoverCalls==1`、`connectCalls==1`、`connectTarget.deviceId=='mdns-found-device'`、`connectTarget.ips==['192.168.1.42:11223']` —— 同时验证 deviceId 与 ip:port 直连地址拼装，强断言。
  - 验收 3（L290-315）：友好文案 + 无 AnyhowException 字样 + `connectCalls==0`。
  - 验收 4（L318-347）：`discoverCalls==0` + 用手动值 —— 强断言"跳过 discover"。
  - 验收 5（L350-362）：直接关闭 → `advertisingStopped==true`。
- 回归测试（L201-230）断言"不发起连接"，证明 UI 不再走空 deviceId 的必败路径。

**MINOR-5（扫描失败分支未测试）**：fake 的 `discoverError` 字段（L42）可实现 discover 抛错，但 7 个用例均未覆盖"discover 抛错 → 按空结果友好提示"（UI L330-334 已实现该路径）。建议补一条用例。

**NIT-1（sync_ui_widget_test 死仪器）**：`test/sync_ui_widget_test.dart` L83-84 新增 `advertisingStarted/advertisingStopped` 字段并赋值（L104-112），但该文件无任何断言使用它们（grep 证实），属未使用仪器；不影响正确性。

### 审核重点 6 — 改动范围

**结论：无越界改动；有少量格式 churn。**

- 逐文件 diff 核对：所有改动均服务于任务 J 目标。
- 接口扩展连锁：`NoteRepository` 抽象新增 3 方法 → 3 个既有测试文件（mobile_ui / sync_ui / vertical_slice）的 fake 补齐实现，属必要连锁改动；`rust-backend/tests/pairing_test.rs` 新增 Rust 集成测试（任务单"test/ — widget 测试"字面未含 Rust 集成测试，但属新 Rust API 的配套测试，合理范围内）。
- **NIT-2（格式 churn）**：`frb_note_repository.dart` L271-277 `confirmPairing` 调用被重排（与任务无关的格式化）；`devices_page.dart` L176-178 / L384-386 / L398-400 有 `ScaffoldMessenger.of(context)` 与 `ListView(children:[for...])` 的格式化重排。均为纯格式、无行为差异。
- `.gitignore`、`docs/`、`prototype/` 零改动（git status + 内容比对核实）。

---

## 三、结论

**全部验收标准 PASS（0-10），无 BLOCKER / MAJOR 问题。**

待主代理确认/知悉（不阻塞合并）：
1. 多台设备分支行为（需决策点 1 vs 设计需求 2 冲突的拍板）——见审核重点 4。
2. 配对码过期后广播不自动停（需决策点 2 状态机确认）——见审核重点 2。
3. 审核人实机验证的副作用（plugin registrant 6 文件 + 3 个 codegen 行尾 churn），合并前按需还原——见验收 10 附注。

MINOR 建议（可后续迭代，均不阻塞）：
- MINOR-1：discover 持锁 3s 的并发窗口（当前 UI 不可达）。
- MINOR-2：port 回退 0 的极端窗口。
- MINOR-3：组合 API 失败路径缺防御性 stop。
- MINOR-4：确认方 SnackBar `$error` 预存在文案暴露面变宽。
- MINOR-5：discover 抛错分支缺测试。

NIT：
- NIT-1：sync_ui_widget_test 未使用的 advertising 字段。
- NIT-2：少量与任务无关的格式化 churn（frb_note_repository.confirmPairing / devices_page 两处）。
