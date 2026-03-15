input: 已批准的 Flutter/Rust 最终契约收尾设计与当前主分支代码基线
output: caller-scoped role 与 card query 最终后端化的任务化实施计划
pos: Flutter/Rust 最终契约收尾实施计划，执行前需先读 final contract cleanup design 与 architecture spec
# Flutter Rust Final Contract Cleanup Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 完成最后一轮契约收尾，使所有带 `current_user_role` 的 pool API 都 caller-scoped，并把 card query 默认列表/搜索语义彻底收回 Rust。 

**Architecture:** 保持 `docs/specs/architecture.md` 的边界不变：Flutter 只表达用户意图并消费 Rust DTO，Rust 定义身份、查询和错误真相。最后一轮的重点不是新增功能，而是清除契约剩余漂移点：pool 角色字段统一 caller-scoped，card query 不再由 Flutter 传产品语义开关。 

**Tech Stack:** Flutter、Dart、Rust、flutter_rust_bridge、SQLite、LoroDoc、`flutter test`、`cargo test`。

---

## 执行规则（强制）

1. 执行前先阅读：
   - `docs/specs/architecture.md`
   - `docs/plans/2026-03-15-flutter-rust-final-contract-cleanup-design.md`
   - `docs/specs/pool.md`
   - `docs/specs/card-note.md`
2. 每个任务必须遵循 `Red -> Green -> Blue -> Commit`。
3. 所有带 `current_user_role` 的 pool API 必须显式 caller-scoped；lookup miss 必须报错。
4. Flutter 不得继续传 `includeDeleted` 这种会影响产品语义的参数。
5. card list 默认语义必须固定为 `deleted = false`，搜索也必须在该集合基础上继续过滤。

## Worktree Requirement

执行 Task 1 之前：

1. 在 `.worktrees/` 下创建独立 worktree。
2. 推荐分支名：`flutter-rust-final-contract-cleanup`。
3. 确认主分支文档与代码基线一致。

Run:

```bash
git worktree add ".worktrees/flutter-rust-final-contract-cleanup" -b "flutter-rust-final-contract-cleanup"
git status --short
```

Expected: worktree 创建成功，新工作目录状态可控。

---

### Task 1: 让 joined pool caller lookup miss 返回明确错误

**Files:**
- Modify: `rust/src/api.rs`
- Modify: `rust/src/models/api_error.rs`
- Modify: `lib/features/pool/pool_api_client.dart`
- Modify: `rust/tests/current_user_pool_view_test.rs`
- Test: `test/features/pool/pool_api_client_test.dart`

**Step 1: 写失败测试**

```rust
#[test]
fn joined_pool_view_should_fail_when_endpoint_is_not_a_member() {
    // create pool
    // query joined view with unknown endpoint
    // assert explicit error instead of fabricated member role
}
```

```dart
test('frb pool api client should surface explicit not-member error for unknown caller', () async {
  // assert ApiError is surfaced instead of silently treating caller as member
});
```

**Step 2: 运行测试确认 RED**

Run: `cargo test --test current_user_pool_view_test && flutter test test/features/pool/pool_api_client_test.dart`  
Expected: FAIL，因为当前 lookup miss 仍可能伪造 `member`。

**Step 3: 最小实现 caller miss 报错**

```text
- Rust current_user_role lookup 改为 Result 风格，而不是 fallback member。
- get_joined_pool_view 对未知 endpoint 返回稳定错误码。
- Flutter pool api client 透传该后端错误语义。
```

**Step 4: 运行测试确认 GREEN**

Run: `cargo test --test current_user_pool_view_test && flutter test test/features/pool/pool_api_client_test.dart`  
Expected: PASS

**Step 5: Blue 重构**

- 合并 role lookup 与错误映射代码。
- 删除不再需要的 fallback 辅助逻辑。

**Step 6: 复跑验证**

Run: `cargo test --test current_user_pool_view_test && flutter test test/features/pool/pool_api_client_test.dart`  
Expected: PASS

**Step 7: Commit**

```bash
git add rust/src/api.rs rust/src/models/api_error.rs lib/features/pool/pool_api_client.dart rust/tests/current_user_pool_view_test.rs test/features/pool/pool_api_client_test.dart
git commit -m "fix(pool): reject non-member caller in joined view"
```

---

### Task 2: 把 getPoolDetail 也收敛为 caller-scoped current_user_role 契约

**Files:**
- Modify: `rust/src/api.rs`
- Modify: `lib/bridge_generated/api.dart`
- Modify: `lib/features/pool/pool_api_client.dart`
- Create: `rust/tests/pool_detail_contract_test.rs`
- Test: `test/features/pool/pool_api_client_test.dart`

**Step 1: 写失败测试**

```rust
#[test]
fn pool_detail_should_compute_current_user_role_from_calling_endpoint() {
    // owner queries detail -> admin
    // joiner queries detail -> member
}
```

```dart
test('pool detail api should pass endpoint identity for current_user_role semantics', () async {
  // assert frb call includes caller identity
});
```

**Step 2: 运行测试确认 RED**

Run: `cargo test --test pool_detail_contract_test && flutter test test/features/pool/pool_api_client_test.dart`  
Expected: FAIL，因为当前 get_pool_detail 仍非 caller-scoped。

**Step 3: 最小实现 caller-scoped pool detail**

```text
- Rust get_pool_detail 加入 caller identity 输入。
- current_user_role 由调用者身份计算。
- Flutter pool api client 在调用 detail API 时显式传 endpointId。
```

**Step 4: 运行测试确认 GREEN**

Run: `cargo test --test pool_detail_contract_test && flutter test test/features/pool/pool_api_client_test.dart`  
Expected: PASS

**Step 5: Blue 重构**

- 合并 joined view / pool detail 的 caller-scoped role lookup。
- 更新 DTO 契约注释，避免再出现多语义字段。

**Step 6: 复跑验证**

Run: `cargo test --test pool_detail_contract_test && flutter test test/features/pool/pool_api_client_test.dart`  
Expected: PASS

**Step 7: Commit**

```bash
git add rust/src/api.rs lib/bridge_generated/api.dart lib/features/pool/pool_api_client.dart rust/tests/pool_detail_contract_test.rs test/features/pool/pool_api_client_test.dart
git commit -m "refactor(pool): make pool detail caller scoped"
```

---

### Task 3: 删除 Flutter 侧 includeDeleted 产品语义参数

**Files:**
- Modify: `lib/features/cards/card_api_client.dart`
- Modify: `lib/features/cards/cards_controller.dart`
- Modify: `test/features/read_model/query_path_test.dart`
- Modify: `test/architecture/followup_truthfulness_guard_test.dart`

**Step 1: 写失败测试**

```dart
test('card query path should not expose includeDeleted in production flutter api', () {
  // source guard / API surface guard
});
```

**Step 2: 运行测试确认 RED**

Run: `flutter test test/features/read_model/query_path_test.dart test/architecture/followup_truthfulness_guard_test.dart`  
Expected: FAIL，因为当前仍存在 includeDeleted 参数与调用。

**Step 3: 最小实现参数收口**

```text
- 从 CardApiClient.listCardSummaries(...) 移除 includeDeleted。
- CardsController 只传 query 或默认列表意图。
- 守卫测试改为明确禁止 includeDeleted 回流。
```

**Step 4: 运行测试确认 GREEN**

Run: `flutter test test/features/read_model/query_path_test.dart test/architecture/followup_truthfulness_guard_test.dart`  
Expected: PASS

**Step 5: Blue 重构**

- 清理所有已无意义的 includeDeleted 测试夹具与命名。
- 保持 Flutter API 表意清晰：默认列表/搜索，而不是 deleted 过滤策略。

**Step 6: 复跑验证**

Run: `flutter test test/features/read_model/query_path_test.dart test/architecture/followup_truthfulness_guard_test.dart`  
Expected: PASS

**Step 7: Commit**

```bash
git add lib/features/cards/card_api_client.dart lib/features/cards/cards_controller.dart test/features/read_model/query_path_test.dart test/architecture/followup_truthfulness_guard_test.dart
git commit -m "refactor(cards): remove flutter deleted filter switch"
```

---

### Task 4: 把 card 默认列表与搜索语义完全固定在 Rust

**Files:**
- Modify: `rust/src/api.rs`
- Modify: `rust/src/store/card_store.rs`
- Modify: `rust/src/store/sqlite_store.rs`
- Modify: `rust/tests/card_query_contract_test.rs`
- Modify: `lib/features/cards/card_api_client.dart`
- Test: `test/features/read_model/query_path_test.dart`

**Step 1: 写失败测试**

```rust
#[test]
fn card_query_api_should_default_to_non_deleted_cards_without_flutter_flags() {
    // create active + deleted cards
    // default list returns only active
    // keyword search also returns only active matches
}
```

```dart
test('flutter card query should call rust default list/search APIs without deleted policy flags', () {
  // assert no includeDeleted parameter remains in production path
});
```

**Step 2: 运行测试确认 RED**

Run: `cargo test --test card_query_contract_test && flutter test test/features/read_model/query_path_test.dart`  
Expected: FAIL

**Step 3: 最小实现 Rust 固定语义**

```text
- Rust query API 直接把默认列表与搜索语义固定为 deleted=false。
- 若仍保留 queryCardNotes 之类统一入口，其 deleted 过滤不再由 Flutter 参数决定。
- Flutter 只传空 query 或关键字 query。
```

**Step 4: 运行测试确认 GREEN**

Run: `cargo test --test card_query_contract_test && flutter test test/features/read_model/query_path_test.dart`  
Expected: PASS

**Step 5: Blue 重构**

- 抽取 Rust 查询构建逻辑，减少 duplicated filters。
- 清理生成桥接与 Dart 侧命名，使之更符合“固定产品语义”。

**Step 6: 复跑验证**

Run: `cargo test --test card_query_contract_test && flutter test test/features/read_model/query_path_test.dart`  
Expected: PASS

**Step 7: Commit**

```bash
git add rust/src/api.rs rust/src/store/card_store.rs rust/src/store/sqlite_store.rs rust/tests/card_query_contract_test.rs lib/features/cards/card_api_client.dart test/features/read_model/query_path_test.dart
git commit -m "refactor(cards): fix backend default query semantics"
```

---

### Task 5: 增强最终回退防护测试

**Files:**
- Modify: `test/architecture/followup_truthfulness_guard_test.dart`
- Create: `test/architecture/final_contract_cleanup_guard_test.dart`

**Step 1: 写失败测试**

```dart
test('pool role contracts must not fall back to first-member ordering', () {
  // source guard
});

test('flutter must not reintroduce includeDeleted query switches', () {
  // source guard
});
```

**Step 2: 运行测试确认 RED**

Run: `flutter test test/architecture/followup_truthfulness_guard_test.dart test/architecture/final_contract_cleanup_guard_test.dart`  
Expected: FAIL

**Step 3: 最小实现回退防护**

```text
- 增加对 first-member 角色推断、lookup miss 伪造 member、includeDeleted 回流的守卫。
- 让未来任何契约漂移都能直接红灯。
```

**Step 4: 运行测试确认 GREEN**

Run: `flutter test test/architecture/followup_truthfulness_guard_test.dart test/architecture/final_contract_cleanup_guard_test.dart`  
Expected: PASS

**Step 5: Blue 重构**

- 合并源码读取 helper。
- 优化断言文案，提高回归定位效率。

**Step 6: 复跑验证**

Run: `flutter test test/architecture/followup_truthfulness_guard_test.dart test/architecture/final_contract_cleanup_guard_test.dart`  
Expected: PASS

**Step 7: Commit**

```bash
git add test/architecture/followup_truthfulness_guard_test.dart test/architecture/final_contract_cleanup_guard_test.dart
git commit -m "test(architecture): guard final contract cleanup"
```

---

### Task 6: 跑最终门禁并确认契约完全收口

**Files:**
- Reference: `tool/quality.dart`
- Reference: `docs/specs/architecture.md`
- Reference: `docs/plans/2026-03-15-flutter-rust-final-contract-cleanup-design.md`

**Step 1: 运行 Flutter 门禁**

Run: `dart run tool/quality.dart flutter`  
Expected: PASS

**Step 2: 运行 Rust 门禁**

Run: `dart run tool/quality.dart rust`  
Expected: PASS

**Step 3: 运行关键契约测试**

Run: `flutter test test/features/pool/pool_api_client_test.dart test/features/read_model/query_path_test.dart test/architecture/final_contract_cleanup_guard_test.dart && cargo test --test current_user_pool_view_test && cargo test --test pool_detail_contract_test && cargo test --test card_query_contract_test`  
Expected: PASS

**Step 4: Blue 收尾**

- 删除临时调试代码。
- 再次确认 Flutter 不再保留 pool role/query 语义开关。

**Step 5: 最终 Commit**

```bash
git add .
git commit -m "fix: complete flutter rust contract cleanup"
```
