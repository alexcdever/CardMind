# Network Debug Trace Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不改变正式 join 语义的前提下，为 owner 与 joiner 增加最小调试输出，使开发者能直接从 `flutter run` 日志中拿到 invite 与真实 join 路径内的连接阶段信息。

**Architecture:** 复用现有 debug 启动参数与真实 join 路径，不新增独立诊断连接分支。Flutter 侧只负责读取调试开关、打印 invite 和承接最小调试输出；Rust 侧只在现有 invite join 路径内部补结构化 trace 采集点，并在必要时通过最小桥接把 trace 暴露回 Flutter。

**Tech Stack:** Flutter, Dart, Flutter Rust Bridge, Rust, flutter_test, cargo test

---

## 文件结构

**现有文件与职责**

- `lib/main.dart`
  - 读取全局 debug `dart-define`
  - 决定哪些 debug 能力在应用启动期可用
- `lib/features/pool/pool_page.dart`
  - 承接 auto create / auto join / invite 导出 / 状态导出逻辑
- `lib/features/pool/pool_controller.dart`
  - 承接 join 结果与 notice message 回填
- `lib/features/pool/pool_api_client.dart`
  - Flutter 调 Rust join 路径的主入口，适合承接最小调试 trace 数据
- `lib/bridge_generated/api.dart`
  - FRB 生成接口，确认需要新增哪些 Rust 暴露点
- `rust/src/api/mod.rs`
  - 对外 API 实现，已包含 `join_pool_by_invite` / `create_pool_invite`
- `rust/src/net/pool_network.rs`
  - 网络连接相关实现，若要补连接阶段 trace，大概率要落在这里或其直接调用链
- `test/unit/presentation/pool_controller_test.dart`
  - 适合锁 Flutter 层 message / trace 回填语义
- `test/contract/api/pool_api_contract_test.dart`
  - 适合锁 FRB API 与真实 invite join 相关调试输出语义
- `test/widget/pages/pool_page_test.dart`
  - 适合锁 owner invite debug 输出开关的 Flutter 入口行为
- `rust/tests/integration/sync/network_flow_test.rs`
  - 适合锁 Rust invite join 路径 trace 行为不改变原 join 语义

**预期新增文件（仅在现有链路无法承载时）**

- `rust/src/api/network_debug.rs`
  - 仅当 `api/mod.rs` 中调试 trace 逻辑会明显膨胀时再新增
- `test/unit/data/pool_api_client_debug_test.dart`
  - 仅当 `pool_api_client.dart` 的调试 trace 组装需要单独覆盖时再新增

---

## Chunk 1: Flutter Debug 开关与 Owner Invite 输出

### Task 1: 定义最小 debug 开关与运行态参数承接

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/app/app.dart`
- Modify: `lib/features/pool/pool_shell.dart`
- Possibly modify: `test/widget/pages/app_homepage_test.dart`

- [ ] **Step 1: 写一个失败测试，锁定新的 debug 开关会沿现有运行态链路传到 pool 页面**

优先在已有 Flutter 测试中补一个最小用例，锁定以下参数能从：

`main/app -> CardMindApp -> PoolShell -> PoolPage`

完成承接：

- `CARDMIND_DEBUG_PRINT_INVITE=true`
- `CARDMIND_DEBUG_JOIN_TRACE=true`

- [ ] **Step 2: 运行测试，确认先失败**

Run: `flutter test test/widget/pages/app_homepage_test.dart --plain-name "debug flags flow to pool page"`
Expected: FAIL，页面或注入对象上还看不到新的 debug 参数。

- [ ] **Step 3: 在 `lib/main.dart`、`lib/app/app.dart`、`lib/features/pool/pool_shell.dart` 增加新的 debug 参数承接**

新增最小常量：

```dart
const bool _debugPrintInvite = bool.fromEnvironment(
  'CARDMIND_DEBUG_PRINT_INVITE',
);
const bool _debugJoinTrace = bool.fromEnvironment(
  'CARDMIND_DEBUG_JOIN_TRACE',
);
```

并把它们继续向 `CardMindApp` / `PoolShell` / `PoolPage` 传递，保持与现有 debug 参数风格一致。

- [ ] **Step 4: 运行测试，确认通过**

Run: `flutter test test/widget/pages/app_homepage_test.dart --plain-name "debug flags flow to pool page"`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/main.dart lib/app/app.dart lib/features/pool/pool_shell.dart test/widget/pages/app_homepage_test.dart
git commit -m "chore(debug): add network trace flags"
```

### Task 2: owner 直接打印 invite 到 debug 输出

**Files:**
- Modify: `lib/features/pool/pool_page.dart`
- Test: `test/widget/pages/pool_page_test.dart`

- [ ] **Step 1: 写一个失败测试，锁定 owner 在 debug 开关开启时会输出 invite**

在 `test/widget/pages/pool_page_test.dart` 增加用例：

- 当 `autoCreatePool: true`
- 且 `debugPrintInvite: true`
- 创建完成后应触发一条可观察调试输出，前缀为 `pool_debug.invite:`

优先通过可注入 logger 或 debug sink 断言，避免直接断言 `print()` 副作用。

- [ ] **Step 2: 运行该测试，确认先失败**

Run: `flutter test test/widget/pages/pool_page_test.dart --plain-name "auto create pool prints invite in debug mode"`
Expected: FAIL，缺少调试输出。

- [ ] **Step 3: 在 `PoolPage` 增加最小 invite debug 输出**

实现约束：

- 只在 `debugPrintInvite` 开关显式开启时输出
- 不依赖文件导出
- 输出格式固定：

```text
pool_debug.invite:<invite>
```

- 优先复用或注入一个最小 logger，避免把 `print` 散落在页面逻辑里

- [ ] **Step 4: 运行测试，确认通过**

Run: `flutter test test/widget/pages/pool_page_test.dart --plain-name "auto create pool prints invite in debug mode"`
Expected: PASS

- [ ] **Step 5: 运行一组相关回归**

Run: `flutter test test/widget/pages/pool_page_test.dart --plain-name "auto create pool should create once on first render"`
Expected: PASS

- [ ] **Step 6: 提交**

```bash
git add lib/features/pool/pool_page.dart test/widget/pages/pool_page_test.dart
git commit -m "feat(debug): print owner invite to console"
```

---

## Chunk 2: 真实 Join 路径内的最小 Trace

### Task 3: 锁定 Rust invite join 路径 trace 需求

**Files:**
- Modify: `rust/tests/integration/sync/network_flow_test.rs`
- Read: `rust/src/api/mod.rs`
- Read: `rust/src/net/pool_network.rs`

- [ ] **Step 1: 写一个失败测试，锁定 invite join trace 至少包含关键锚点**

在 `rust/tests/integration/sync/network_flow_test.rs` 增加或扩展用例，要求在 debug trace 开启时能拿到：

- invite 已解析
- 目标地址列表
- 至少一条 attempt start
- 至少一条 attempt end
- final result

测试必须基于**现有真实 join 调用链**，不能构造额外诊断连接分支。

- [ ] **Step 2: 运行 Rust 测试，确认先失败**

Run: `cargo test network_flow_test -- --nocapture`
Expected: FAIL，缺少 trace 数据或相关断言。

- [ ] **Step 3: 在 Rust 真实 join 路径中补最小 trace 采集点**

实现约束：

- 不新增独立“诊断连接” API
- 不额外做第二轮连接尝试
- 只在现有 invite join 路径中记录阶段事件
- trace 结构至少能承载：
  - invite 解析结果
  - 目标 endpoint
  - 目标地址列表
  - 每次 attempt start/end
  - duration
  - final result / final message

- [ ] **Step 4: 运行 Rust 测试，确认通过**

Run: `cargo test network_flow_test -- --nocapture`
Expected: PASS

- [ ] **Step 5: 运行相关 Rust 回归，确认正式 join 语义未变**

Run: `cargo test pool_join_test -- --nocapture`
Expected: PASS

- [ ] **Step 6: 提交**

```bash
git add rust/src/api/mod.rs rust/src/net/pool_network.rs rust/tests/integration/sync/network_flow_test.rs
git commit -m "feat(debug): trace invite join attempts"
```

### Task 4: 仅在现有链路无法承载时补最小 FRB / Dart 承载

**Files:**
- Modify: `lib/features/pool/pool_api_client.dart`
- Modify: `test/contract/api/pool_api_contract_test.dart`
- Possibly modify: `rust/src/api/mod.rs`
- Possibly regenerate: `lib/bridge_generated/*`, `rust/src/frb_generated.rs`

- [ ] **Step 1: 先确认 Rust trace 是否能沿现有错误 message、日志链路或现有返回链路到达 Flutter**

检查点：

- 如果 Flutter 仅靠现有 `error.message` 就能拿到最小 trace，则不要新增 bridge 结构
- 只有 trace 无法到达 Flutter 时，才补最小 FRB 承载

- [ ] **Step 2: 若需要 bridge，再写一个失败合同测试**

在 `test/contract/api/pool_api_contract_test.dart` 增加用例，锁定：

- 开启 `debug join trace` 后
- `FrbPoolApiClient.joinByCode()` 失败时
- Flutter 侧能拿到包含 `pool_debug.join.final:` 的可观察 trace

- [ ] **Step 3: 运行测试，确认先失败**

Run: `flutter test test/contract/api/pool_api_contract_test.dart --plain-name "frb pool api client exposes join trace in debug mode"`
Expected: FAIL

- [ ] **Step 4: 只补满足当前目标的最小桥接**

约束：

- 不新增长期调试领域模型
- 优先把 trace 当作最小字符串列表或最小可打印结构传回 Dart
- 不改正式 join 成功/失败语义

- [ ] **Step 5: 运行测试，确认通过**

Run: `flutter test test/contract/api/pool_api_contract_test.dart --plain-name "frb pool api client exposes join trace in debug mode"`
Expected: PASS

- [ ] **Step 6: 提交**

```bash
git add lib/features/pool/pool_api_client.dart test/contract/api/pool_api_contract_test.dart lib/bridge_generated rust/src/frb_generated.rs rust/src/api/mod.rs
git commit -m "feat(debug): surface join trace to flutter"
```

---

## Chunk 3: Flutter 日志整合与最终验证

### Task 5: joiner 将 trace 输出到 debug console

**Files:**
- Modify: `lib/features/pool/pool_api_client.dart`
- Modify: `lib/features/pool/pool_page.dart`
- Test: `test/contract/api/pool_api_contract_test.dart`

- [ ] **Step 1: 写一个失败测试，锁定 join 失败时 trace 会打印到 debug 输出**

增加单测，要求：

- 开启 `debugJoinTrace`
- join 失败返回 trace 或现有链路可观察 trace
- Flutter 侧主路径输出包含以下锚点：
  - `pool_debug.join.invite_parsed:`
  - `pool_debug.join.target_addrs:`
  - `pool_debug.join.final:`

- [ ] **Step 2: 运行测试，确认先失败**

Run: `flutter test test/contract/api/pool_api_contract_test.dart --plain-name "frb pool api client prints join trace when debug enabled"`
Expected: FAIL

- [ ] **Step 3: 补最小 Flutter 调试输出整合**

约束：

- 只在 `debugJoinTrace` 开启时打印
- 输出统一使用 `pool_debug.` 前缀
- 不影响 `noticeMessage` 与正式状态机
- 优先把输出责任放在 `PoolPage` / `PoolApiClient` 边界，不把展示性日志塞进 `PoolController`

- [ ] **Step 4: 运行测试，确认通过**

Run: `flutter test test/contract/api/pool_api_contract_test.dart --plain-name "frb pool api client prints join trace when debug enabled"`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/features/pool/pool_api_client.dart lib/features/pool/pool_page.dart test/contract/api/pool_api_contract_test.dart
git commit -m "feat(debug): print join trace to console"
```

### Task 6: 执行最终回归与真实验证脚本

**Files:**
- Read: `docs/plans/2026-04-14-network-diagnostic-debug-plan.md`
- Possibly modify: `docs/memory/2026-04-14.md`
- Possibly modify: `docs/progress.md`

- [ ] **Step 1: 跑 Dart / Flutter 相关回归**

Run: `flutter test test/integration/infrastructure/build_cli_test.dart test/unit/presentation/pool_controller_test.dart test/contract/api/pool_api_contract_test.dart`
Expected: PASS

- [ ] **Step 2: 跑 Rust 相关回归**

Run: `cargo test network_flow_test -- --nocapture && cargo test pool_join_test -- --nocapture`
Expected: PASS

- [ ] **Step 3: 执行一次 owner debug 输出验证**

Run: `flutter run -d macos --dart-define=CARDMIND_DEBUG_START_IN_POOL=true --dart-define=CARDMIND_DEBUG_AUTO_CREATE_POOL=true --dart-define=CARDMIND_DEBUG_PIN=1234 --dart-define=CARDMIND_DEBUG_PRINT_INVITE=true`
Expected: 控制台出现 `pool_debug.invite:`

- [ ] **Step 4: 执行一次 joiner trace 输出验证**

Run: `flutter run -d <device> --dart-define=CARDMIND_DEBUG_START_IN_POOL=true --dart-define=CARDMIND_DEBUG_PIN=1234 --dart-define=CARDMIND_DEBUG_JOIN_CODE=<invite> --dart-define=CARDMIND_DEBUG_JOIN_TRACE=true`
Expected: 控制台出现：

```text
pool_debug.join.invite_parsed:
pool_debug.join.target_addrs:
pool_debug.join.attempt_start:
pool_debug.join.attempt_end:
pool_debug.join.final:
```

- [ ] **Step 5: 如真实验证结论发生变化，再更新存档文档**

如果真实验证结论有新增信息，更新：

- `docs/memory/2026-04-14.md`
- `docs/progress.md`

- [ ] **Step 6: 如有文档更新，再提交**

```bash
git add docs/memory/2026-04-14.md docs/progress.md
git commit -m "docs: record network debug trace verification"
```
