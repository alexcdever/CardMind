# Rust/Flutter 中文注释补齐 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 Rust 与 Flutter 手写业务代码及测试补齐中文关键注释，并同步满足 Fractal 文档规范（文件头与目录说明）。

**Architecture:** 本次只做文档性增强，不改业务行为。按目录分批执行：先 Rust（src/tests），再 Flutter（lib/test），每批完成后立即运行守卫测试与文档校验，保证改动可回归、可回滚。注释策略统一为“关键点注释”：解释职责、边界、状态流和错误处理原因，避免逐行翻译。

**Tech Stack:** Dart/Flutter、Rust、flutter_test、cargo test、Fractal 文档校验脚本。

---

### Task 1: 建立基线与目标文件清单

**Files:**
- Modify: `docs/plans/2026-02-28-rust-flutter-chinese-comments-design.md`
- Create: `docs/plans/2026-02-28-rust-flutter-chinese-comments-filelist.md`
- Test: `test/fractal_doc_checker_test.dart`

**Step 1: 写失败检查清单（先记录“未覆盖文件”）**

```markdown
# 注释补齐文件清单（初稿）

## rust/src
- rust/src/api.rs
- rust/src/lib.rs
- rust/src/models/api_error.rs
...

## lib
- lib/main.dart
- lib/app/app.dart
- lib/features/sync/sync_controller.dart
...
```

**Step 2: 运行文档校验确认当前存在未补齐项**

Run: `dart run tool/fractal_doc_check.dart --base HEAD~1`  
Expected: FAIL 或存在需修正提示（用于建立基线）

**Step 3: 固化本次排除项说明（生成文件/构建产物）**

```markdown
排除：lib/bridge_generated/**、rust/src/frb_generated.rs、build/**、rust/target/**
```

**Step 4: 再跑守卫测试确认工具链可用**

Run: `flutter test test/fractal_doc_checker_test.dart`  
Expected: PASS

**Step 5: Commit**

```bash
git add docs/plans/2026-02-28-rust-flutter-chinese-comments-design.md docs/plans/2026-02-28-rust-flutter-chinese-comments-filelist.md
git commit -m "docs(plan): add chinese comments scope file list"
```

---

### Task 2: 补齐 Rust 核心文件头与关键中文注释（入口 + models + utils）

**Files:**
- Modify: `rust/src/lib.rs`
- Modify: `rust/src/api.rs`
- Modify: `rust/src/models/mod.rs`
- Modify: `rust/src/models/card.rs`
- Modify: `rust/src/models/error.rs`
- Modify: `rust/src/models/pool.rs`
- Modify: `rust/src/models/api_error.rs`
- Modify: `rust/src/utils/mod.rs`
- Modify: `rust/src/utils/uuid_v7.rs`
- Test: `rust/tests/card_model_test.rs`
- Test: `rust/tests/api_error_test.rs`
- Test: `rust/tests/uuid_v7_test.rs`

**Step 1: 先写失败测试（确保关键模型行为未被注释改动破坏）**

```bash
cargo test card_model_test api_error_test uuid_v7_test
```

Expected: 如出现失败，记录失败原因并先修复基线问题。

**Step 2: 为每个文件补齐/修正文件头三行**

```rust
// input: 上游调用参数/依赖
// output: 对外返回结构或副作用
// pos: 该文件在模块中的职责与定位（修改需同步更新文件头与所属 DIR.md）
```

**Step 3: 为关键类型与复杂函数增加中文注释（不逐行）**

```rust
/// 统一描述 API 错误码到前端可恢复动作的映射依据，避免跨层语义漂移。
pub enum ApiErrorCode { /* ... */ }
```

**Step 4: 回归测试**

Run: `cargo test card_model_test api_error_test uuid_v7_test`  
Expected: PASS

**Step 5: Commit**

```bash
git add rust/src/lib.rs rust/src/api.rs rust/src/models rust/src/utils
git commit -m "docs(rust): add chinese key comments for core models"
```

---

### Task 3: 补齐 Rust 网络与存储层中文注释（net + store）

**Files:**
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
- Test: `rust/tests/pool_network_flow_test.rs`
- Test: `rust/tests/pool_net_codec_test.rs`
- Test: `rust/tests/sqlite_store_test.rs`

**Step 1: 运行失败前置测试（网络 + 存储主链路）**

Run: `cargo test pool_network_flow_test pool_net_codec_test sqlite_store_test`  
Expected: PASS（作为注释改动前基线）

**Step 2: 补文件头并标注跨层数据流注释**

```rust
/// 数据流：Flutter -> FRB -> Rust API -> net/store。
/// 这里负责网络会话状态推进，不持有 UI 层语义。
```

**Step 3: 为错误分支补“可恢复/不可恢复”注释**

```rust
// 可恢复错误：上层可触发重试或重连。
// 不可恢复错误：直接返回并终止本次同步流程。
```

**Step 4: 回归测试**

Run: `cargo test pool_network_flow_test pool_net_codec_test sqlite_store_test`  
Expected: PASS

**Step 5: Commit**

```bash
git add rust/src/net rust/src/store
git commit -m "docs(rust): annotate network and store flows in chinese"
```

---

### Task 4: 补齐 Rust 测试文件中文注释（场景意图 + 断言原因）

**Files:**
- Modify: `rust/tests/smoke_test.rs`
- Modify: `rust/tests/api_handle_test.rs`
- Modify: `rust/tests/sync_api_contract_test.rs`
- Modify: `rust/tests/sync_api_flow_test.rs`
- Modify: `rust/tests/pool_sync_test.rs`
- Modify: `rust/tests/pool_net_session_test.rs`
- Modify: `rust/tests/pool_net_endpoint_test.rs`
- Modify: `rust/tests/pool_store_test.rs`
- Modify: `rust/tests/pool_store_persist_test.rs`
- Modify: `rust/tests/sqlite_store_cards_test.rs`
- Modify: `rust/tests/sqlite_store_pool_test.rs`
- Modify: `rust/tests/loro_store_test.rs`
- Modify: `rust/tests/loro_persist_test.rs`
- Modify: `rust/tests/path_resolver_test.rs`
- Modify: `rust/tests/card_store_test.rs`
- Modify: `rust/tests/card_store_persist_test.rs`
- Modify: `rust/tests/card_model_test.rs`
- Modify: `rust/tests/sqlite_store_test.rs`
- Modify: `rust/tests/uuid_v7_test.rs`
- Test: `rust/tests/DIR.md`

**Step 1: 先跑全量 Rust 测试基线**

Run: `cargo test`  
Expected: PASS

**Step 2: 为每个测试文件补中文“用例意图”注释**

```rust
// 场景：首次初始化后应返回空集合，确保冷启动状态可预测。
#[test]
fn should_return_empty_pool_on_first_load() { /* ... */ }
```

**Step 3: 为关键断言补“断言原因”注释**

```rust
// 这里要求错误码稳定，避免 Flutter 侧映射分支失效。
assert_eq!(err.code, "INVALID_HANDLE");
```

**Step 4: 回归测试**

Run: `cargo test`  
Expected: PASS

**Step 5: Commit**

```bash
git add rust/tests
git commit -m "docs(rust-test): add chinese intent comments for test scenarios"
```

---

### Task 5: 补齐 Flutter 业务代码中文注释（app + features）

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/app/app.dart`
- Modify: `lib/app/navigation/app_section.dart`
- Modify: `lib/app/layout/adaptive_shell.dart`
- Modify: `lib/features/onboarding/onboarding_state.dart`
- Modify: `lib/features/onboarding/onboarding_controller.dart`
- Modify: `lib/features/onboarding/onboarding_page.dart`
- Modify: `lib/features/cards/card_summary.dart`
- Modify: `lib/features/cards/cards_controller.dart`
- Modify: `lib/features/cards/cards_desktop_interactions.dart`
- Modify: `lib/features/cards/cards_page.dart`
- Modify: `lib/features/editor/editor_controller.dart`
- Modify: `lib/features/editor/editor_page.dart`
- Modify: `lib/features/pool/pool_state.dart`
- Modify: `lib/features/pool/join_error_mapper.dart`
- Modify: `lib/features/pool/pool_controller.dart`
- Modify: `lib/features/pool/pool_page.dart`
- Modify: `lib/features/settings/settings_controller.dart`
- Modify: `lib/features/settings/settings_page.dart`
- Modify: `lib/features/sync/sync_status.dart`
- Modify: `lib/features/sync/sync_service.dart`
- Modify: `lib/features/sync/sync_controller.dart`
- Modify: `lib/features/sync/sync_banner.dart`
- Test: `test/features/sync/sync_controller_test.dart`
- Test: `test/features/pool/join_error_mapper_test.dart`

**Step 1: 先跑核心 Flutter 单测基线**

Run: `flutter test test/features/sync/sync_controller_test.dart test/features/pool/join_error_mapper_test.dart`  
Expected: PASS

**Step 2: 补齐文件头三行并声明维护约束**

```dart
// input: 来自页面事件、仓储/服务返回或上游状态
// output: 提供状态更新、界面渲染输入或副作用触发
// pos: 位于 Flutter 业务层（修改需同步更新文件头与所属 DIR.md）
```

**Step 3: 对 controller/service/mapper 等复杂点补中文注释**

```dart
/// 只根据稳定错误码做分支，避免直接依赖后端文案导致行为漂移。
JoinErrorViewModel mapJoinError(ApiError error) { /* ... */ }
```

**Step 4: 回归测试**

Run: `flutter test test/features/sync/sync_controller_test.dart test/features/pool/join_error_mapper_test.dart`  
Expected: PASS

**Step 5: Commit**

```bash
git add lib/main.dart lib/app lib/features
git commit -m "docs(flutter): add chinese key comments for app and features"
```

---

### Task 6: 补齐 Flutter 测试代码中文注释

**Files:**
- Modify: `test/widget_test.dart`
- Modify: `test/build_cli_test.dart`
- Modify: `test/interaction_guard_test.dart`
- Modify: `test/ui_interaction_governance_docs_test.dart`
- Modify: `test/fractal_doc_checker_test.dart`
- Modify: `test/bridge/sync_bridge_api_smoke_test.dart`
- Modify: `test/app/adaptive_shell_test.dart`
- Modify: `test/features/onboarding/onboarding_page_test.dart`
- Modify: `test/features/cards/cards_page_test.dart`
- Modify: `test/features/cards/cards_desktop_interactions_test.dart`
- Modify: `test/features/cards/cards_sync_navigation_test.dart`
- Modify: `test/features/editor/editor_page_test.dart`
- Modify: `test/features/editor/editor_shortcuts_test.dart`
- Modify: `test/features/settings/settings_page_test.dart`
- Modify: `test/features/pool/pool_page_test.dart`
- Modify: `test/features/pool/join_error_mapper_test.dart`
- Modify: `test/features/pool/pool_sync_interaction_test.dart`
- Modify: `test/features/sync/sync_controller_test.dart`
- Modify: `test/features/sync/sync_banner_test.dart`

**Step 1: 跑 Flutter 全量测试基线**

Run: `flutter test`  
Expected: PASS

**Step 2: 为测试场景和关键断言补中文注释**

```dart
// 场景：同步失败后必须展示可恢复动作，避免用户停留在不可操作状态。
testWidgets('shows retry action on sync error', (tester) async { /* ... */ });
```

**Step 3: 统一术语（连接/重连/重试/降级）并复查冗余注释**

```dart
// 使用“重试”表示同条件重做；“重连”表示先恢复连接再继续业务动作。
```

**Step 4: 回归测试**

Run: `flutter test`  
Expected: PASS

**Step 5: Commit**

```bash
git add test
git commit -m "docs(flutter-test): add chinese scenario comments"
```

---

### Task 7: 同步更新 DIR.md 并执行最终门禁

**Files:**
- Modify: `DIR.md`
- Modify: `rust/DIR.md`
- Modify: `rust/src/DIR.md`
- Modify: `rust/src/models/DIR.md`
- Modify: `rust/src/net/DIR.md`
- Modify: `rust/src/store/DIR.md`
- Modify: `rust/src/utils/DIR.md`
- Modify: `rust/tests/DIR.md`
- Modify: `lib/DIR.md`
- Modify: `lib/app/layout/DIR.md`
- Modify: `lib/features/onboarding/DIR.md`
- Modify: `lib/features/cards/DIR.md`
- Modify: `lib/features/editor/DIR.md`
- Modify: `lib/features/pool/DIR.md`
- Modify: `lib/features/settings/DIR.md`
- Modify: `lib/features/sync/DIR.md`
- Modify: `test/DIR.md`
- Modify: `test/app/DIR.md`
- Modify: `test/features/onboarding/DIR.md`
- Modify: `test/features/cards/DIR.md`
- Modify: `test/features/editor/DIR.md`
- Modify: `test/features/pool/DIR.md`
- Modify: `test/features/settings/DIR.md`
- Modify: `test/features/sync/DIR.md`

**Step 1: 为每个受影响目录补“中文注释维护约束”说明**

```markdown
目录变更需更新本文件。
本目录代码以关键点中文注释维护：修改职责边界、状态流或错误处理时需同步更新注释。
```

**Step 2: 逐项核对 DIR.md 文件索引与实际文件一致**

Run: `dart run tool/fractal_doc_check.dart --base HEAD~1`  
Expected: PASS

**Step 3: 跑治理门禁测试**

Run: `flutter test test/ui_interaction_governance_docs_test.dart`  
Expected: PASS

**Step 4: 跑交互守卫测试**

Run: `flutter test test/interaction_guard_test.dart`  
Expected: PASS

**Step 5: 跑全量回归测试**

Run: `flutter analyze && flutter test && cargo test`  
Expected: PASS

**Step 6: Commit**

```bash
git add DIR.md rust lib test
git commit -m "docs(governance): align chinese comments and dir metadata"
```

---

### Task 8: 交付核对与变更说明

**Files:**
- Modify: `docs/plans/2026-02-28-rust-flutter-chinese-comments-design.md`
- Create: `docs/plans/2026-02-28-rust-flutter-chinese-comments-report.md`

**Step 1: 汇总变更文件与门禁结果**

```markdown
## 校验结果
- fractal_doc_check: PASS
- ui_interaction_governance_docs_test: PASS
- interaction_guard_test: PASS
- flutter analyze / flutter test / cargo test: PASS
```

**Step 2: 给出注释覆盖说明（目录级）**

```markdown
- Rust src: 已覆盖（关键类型/复杂函数）
- Rust tests: 已覆盖（场景意图/断言原因）
- Flutter lib: 已覆盖（状态流/错误映射/组件职责）
- Flutter tests: 已覆盖（场景意图/回归动机）
```

**Step 3: Commit**

```bash
git add docs/plans/2026-02-28-rust-flutter-chinese-comments-design.md docs/plans/2026-02-28-rust-flutter-chinese-comments-report.md
git commit -m "docs(report): add chinese comments rollout verification report"
```
