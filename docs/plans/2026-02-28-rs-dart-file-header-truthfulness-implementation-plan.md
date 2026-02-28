input: rs/dart 文件头真实性治理目标与实施任务
output: 可执行的清查与修正步骤
pos: rs/dart 文件头真实性实施计划（修改需同步 DIR.md）
# Rs/Dart File Header Truthfulness Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 全仓清查并修正所有带文件头的 `.rs/.dart` 文件，使 `input/output/pos` 三行与文件真实职责一致，彻底移除复制粘贴式模板描述。

**Architecture:** 采用逐文件深读、逐文件改写的单文件闭环策略（read -> rewrite header -> self-check）。按目录分批提交，先 Rust 源码与测试，再 Flutter 业务与测试，最后工具脚本，避免大批量改动难以审阅。每批次完成后执行最小回归与治理校验，确保仅注释变化且无行为回归。

**Tech Stack:** Rust、Dart/Flutter、cargo test、flutter test、ripgrep、Fractal 文档校验脚本。

## 强制执行规则（TDD 红-绿-蓝）

- 本计划每个任务必须按 **Red -> Green -> Blue -> Commit** 执行。
- Red：先编写或调整失败测试，并运行确认按预期失败。
- Green：以最小实现使测试通过，并运行确认通过。
- Blue：在不改变行为前提下重构，复跑同一批测试后再继续。
- 仅当 Blue 阶段验证通过后才允许提交。

---

### Task 1: 建立基线与清查清单

**Files:**
- Create: `docs/plans/2026-02-28-rs-dart-file-header-truthfulness-filelist.md`
- Modify: `docs/plans/2026-02-28-rs-dart-file-header-truthfulness-design.md`
- Test: `tool/fractal_doc_check.dart`

**Step 1: 记录当前待修复文件清单（初稿）**

```markdown
# Rs/Dart 文件头清查清单

## rust/src
- rust/src/lib.rs
- rust/src/api.rs
...
```

**Step 2: 运行模板化语句扫描，确认当前基线存在问题**

Run: `rg -n "用户操作、外部参数或依赖返回|保持行为不变|Rust 测试模块，验证关键行为、边界条件与错误路径" rust lib test tool --glob "*.rs" --glob "*.dart"`
Expected: 命中多条结果（作为“待修复”基线证据）

**Step 3: 记录自动生成文件排除项**

```markdown
排除项：rust/src/frb_generated.rs、lib/**.g.dart、lib/**.freezed.dart、build/**、rust/target/**
```

**Step 4: Commit**

```bash
git add docs/plans/2026-02-28-rs-dart-file-header-truthfulness-filelist.md docs/plans/2026-02-28-rs-dart-file-header-truthfulness-design.md
git commit -m "docs(plan): add file header audit baseline and file list"
```

---

### Task 2: 修正 Rust `src` 文件头（逐文件深读）

**Files:**
- Modify: `rust/src/lib.rs`
- Modify: `rust/src/api.rs`
- Modify: `rust/src/models/mod.rs`
- Modify: `rust/src/models/card.rs`
- Modify: `rust/src/models/error.rs`
- Modify: `rust/src/models/pool.rs`
- Modify: `rust/src/models/api_error.rs`
- Modify: `rust/src/net/mod.rs`
- Modify: `rust/src/net/codec.rs`
- Modify: `rust/src/net/messages.rs`
- Modify: `rust/src/net/endpoint.rs`
- Modify: `rust/src/net/session.rs`
- Modify: `rust/src/net/pool_network.rs`
- Modify: `rust/src/net/sync.rs`
- Modify: `rust/src/store/mod.rs`
- Modify: `rust/src/store/path_resolver.rs`
- Modify: `rust/src/store/card_store.rs`
- Modify: `rust/src/store/pool_store.rs`
- Modify: `rust/src/store/loro_store.rs`
- Modify: `rust/src/store/sqlite_store.rs`
- Modify: `rust/src/utils/mod.rs`
- Modify: `rust/src/utils/uuid_v7.rs`
- Test: `rust/tests/api_handle_test.rs`
- Test: `rust/tests/pool_network_flow_test.rs`

**Step 1: 逐文件改写头注释（只改前三行）**

```rust
// input: 来自上层 API 调用参数与底层依赖返回（按本文件真实来源填写）。
// output: 对外返回值、状态推进或副作用（按本文件真实行为填写）。
// pos: 在当前子模块中的职责边界。修改本文件需同步更新文件头与所属 DIR.md。
```

**Step 2: 扫描 rust/src，确认旧模板语句已清除**

Run: `rg -n "用户操作、外部参数或依赖返回|保持行为不变|Rust 存储模块，负责本地数据读写与持久化|Rust 网络与同步模块，负责连接、会话与消息流转" rust/src --glob "*.rs"`
Expected: 无输出

**Step 3: 运行最小 Rust 回归测试**

Run: `cargo test api_handle_test pool_network_flow_test`
Expected: PASS

**Step 4: Commit**

```bash
git add rust/src
git commit -m "docs(rust): rewrite src file headers with truthful responsibilities"
```

---

### Task 3: 修正 Rust `tests` 文件头（逐文件深读）

**Files:**
- Modify: `rust/tests/smoke_test.rs`
- Modify: `rust/tests/api_error_test.rs`
- Modify: `rust/tests/api_handle_test.rs`
- Modify: `rust/tests/card_model_test.rs`
- Modify: `rust/tests/card_store_test.rs`
- Modify: `rust/tests/card_store_persist_test.rs`
- Modify: `rust/tests/loro_store_test.rs`
- Modify: `rust/tests/loro_persist_test.rs`
- Modify: `rust/tests/path_resolver_test.rs`
- Modify: `rust/tests/pool_net_codec_test.rs`
- Modify: `rust/tests/pool_net_endpoint_test.rs`
- Modify: `rust/tests/pool_net_session_test.rs`
- Modify: `rust/tests/pool_network_flow_test.rs`
- Modify: `rust/tests/pool_store_test.rs`
- Modify: `rust/tests/pool_store_persist_test.rs`
- Modify: `rust/tests/pool_sync_test.rs`
- Modify: `rust/tests/sqlite_store_test.rs`
- Modify: `rust/tests/sqlite_store_cards_test.rs`
- Modify: `rust/tests/sqlite_store_pool_test.rs`
- Modify: `rust/tests/sync_api_contract_test.rs`
- Modify: `rust/tests/sync_api_flow_test.rs`
- Modify: `rust/tests/uuid_v7_test.rs`
- Test: `rust/tests/DIR.md`

**Step 1: 逐文件重写测试文件头，强调“构造输入 + 断言输出 + 场景定位”**

```rust
// input: 测试构造数据、夹具环境与被测 API 参数。
// output: 对返回值、状态变化与错误分支的断言结果。
// pos: 覆盖 <具体场景> 的回归测试。修改本文件需同步更新文件头与所属 DIR.md。
```

**Step 2: 扫描 rust/tests 模板残留**

Run: `rg -n "Rust 测试模块，验证关键行为、边界条件与错误路径|用户操作、外部参数或依赖返回|保持行为不变" rust/tests --glob "*.rs"`
Expected: 无输出

**Step 3: 运行 Rust 全量测试回归**

Run: `cargo test`
Expected: PASS

**Step 4: Commit**

```bash
git add rust/tests
git commit -m "docs(rust-test): rewrite test file headers by concrete test intent"
```

---

### Task 4: 修正 Flutter `lib` 文件头（逐文件深读）

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/app/app.dart`
- Modify: `lib/app/layout/adaptive_shell.dart`
- Modify: `lib/app/navigation/app_section.dart`
- Modify: `lib/features/cards/card_summary.dart`
- Modify: `lib/features/cards/cards_controller.dart`
- Modify: `lib/features/cards/cards_desktop_interactions.dart`
- Modify: `lib/features/cards/cards_page.dart`
- Modify: `lib/features/editor/editor_controller.dart`
- Modify: `lib/features/editor/editor_page.dart`
- Modify: `lib/features/onboarding/onboarding_controller.dart`
- Modify: `lib/features/onboarding/onboarding_page.dart`
- Modify: `lib/features/onboarding/onboarding_state.dart`
- Modify: `lib/features/pool/join_error_mapper.dart`
- Modify: `lib/features/pool/pool_controller.dart`
- Modify: `lib/features/pool/pool_page.dart`
- Modify: `lib/features/pool/pool_state.dart`
- Modify: `lib/features/settings/settings_controller.dart`
- Modify: `lib/features/settings/settings_page.dart`
- Modify: `lib/features/sync/sync_banner.dart`
- Modify: `lib/features/sync/sync_controller.dart`
- Modify: `lib/features/sync/sync_service.dart`
- Modify: `lib/features/sync/sync_status.dart`
- Test: `test/features/sync/sync_controller_test.dart`
- Test: `test/features/pool/pool_page_test.dart`

**Step 1: 按“输入来源/输出表现/页面或控制器定位”重写每个文件头**

```dart
// input: 页面交互事件、控制器调用参数与服务层返回。
// output: UI 状态刷新、导航动作或对桥接层调用结果。
// pos: <具体 feature> 的 <具体职责>。修改本文件需同步更新文件头与所属 DIR.md。
```

**Step 2: 扫描 lib 模板残留**

Run: `rg -n "用户操作、外部参数或依赖返回|保持行为不变|Rust|测试模块" lib --glob "*.dart"`
Expected: 无输出

**Step 3: 运行关键 Flutter 测试回归**

Run: `flutter test test/features/sync/sync_controller_test.dart test/features/pool/pool_page_test.dart`
Expected: PASS

**Step 4: Commit**

```bash
git add lib
git commit -m "docs(flutter): rewrite lib file headers with concrete responsibilities"
```

---

### Task 5: 修正 Flutter `test` 文件头（逐文件深读）

**Files:**
- Modify: `test/widget_test.dart`
- Modify: `test/build_cli_test.dart`
- Modify: `test/fractal_doc_checker_test.dart`
- Modify: `test/interaction_guard_test.dart`
- Modify: `test/ui_interaction_governance_docs_test.dart`
- Modify: `test/app/adaptive_shell_test.dart`
- Modify: `test/bridge/sync_bridge_api_smoke_test.dart`
- Modify: `test/features/cards/cards_desktop_interactions_test.dart`
- Modify: `test/features/cards/cards_page_test.dart`
- Modify: `test/features/cards/cards_sync_navigation_test.dart`
- Modify: `test/features/editor/editor_page_test.dart`
- Modify: `test/features/editor/editor_shortcuts_test.dart`
- Modify: `test/features/onboarding/onboarding_page_test.dart`
- Modify: `test/features/pool/join_error_mapper_test.dart`
- Modify: `test/features/pool/pool_page_test.dart`
- Modify: `test/features/pool/pool_sync_interaction_test.dart`
- Modify: `test/features/settings/settings_page_test.dart`
- Modify: `test/features/sync/sync_banner_test.dart`
- Modify: `test/features/sync/sync_controller_test.dart`

**Step 1: 按“测试输入构造/断言输出/测试定位”重写文件头**

```dart
// input: Widget 测试环境、模拟依赖与交互事件。
// output: 对 UI 可观察结果、状态文案与导航行为的断言。
// pos: 覆盖 <具体功能> 的交互与回归用例。修改本文件需同步更新文件头与所属 DIR.md。
```

**Step 2: 扫描 test 模板残留**

Run: `rg -n "用户操作、外部参数或依赖返回|保持行为不变|测试模块" test --glob "*.dart"`
Expected: 无输出

**Step 3: 运行治理守卫测试**

Run: `flutter test test/ui_interaction_governance_docs_test.dart test/interaction_guard_test.dart`
Expected: PASS

**Step 4: Commit**

```bash
git add test
git commit -m "docs(flutter-test): rewrite test file headers by scenario intent"
```

---

### Task 6: 修正 `tool` 脚本文件头并做全仓校验

**Files:**
- Modify: `tool/fractal_doc_bootstrap.dart`
- Modify: `tool/fractal_doc_check.dart`
- Modify: `tool/fractal_doc_checker.dart`
- Test: `test/fractal_doc_checker_test.dart`

**Step 1: 深读三个工具脚本并重写文件头（禁止空 input）**

```dart
// input: CLI 参数、仓库文件系统状态与待校验路径。
// output: 校验报告、退出码与错误提示信息。
// pos: Fractal 文档校验工具链中的 <具体脚本职责>。修改本文件需同步更新文件头与所属 DIR.md。
```

**Step 2: 运行工具链测试**

Run: `flutter test test/fractal_doc_checker_test.dart`
Expected: PASS

**Step 3: 运行 Fractal 校验（以当前变更基线）**

Run: `dart run tool/fractal_doc_check.dart --base HEAD~1`
Expected: PASS

**Step 4: Commit**

```bash
git add tool
git commit -m "docs(tool): rewrite fractal tooling file headers with real I/O"
```

---

### Task 7: 全仓最终验收与交付清单

**Files:**
- Modify: `docs/plans/2026-02-28-rs-dart-file-header-truthfulness-filelist.md`
- Modify: `docs/plans/2026-02-28-rs-dart-file-header-truthfulness-design.md`

**Step 1: 全仓扫描，确认模板语句清零**

Run: `rg -n "用户操作、外部参数或依赖返回|保持行为不变|Rust 测试模块，验证关键行为、边界条件与错误路径" rust lib test tool --glob "*.rs" --glob "*.dart"`
Expected: 无输出

**Step 2: 抽样复读（每目录至少 20%）并登记结果**

```markdown
## 抽样复读记录
- rust/src: 5/22 通过
- rust/tests: 5/22 通过
- lib: 5/23 通过
- test: 4/19 通过
- tool: 1/3 通过
```

**Step 3: 更新交付清单（已修复/例外/二次确认）**

```markdown
## 已修复
- ...

## 例外（自动生成）
- rust/src/frb_generated.rs

## 二次确认
- 无
```

**Step 4: Commit**

```bash
git add docs/plans/2026-02-28-rs-dart-file-header-truthfulness-filelist.md docs/plans/2026-02-28-rs-dart-file-header-truthfulness-design.md
git commit -m "docs(plan): finalize truthful rs-dart header audit report"
```
