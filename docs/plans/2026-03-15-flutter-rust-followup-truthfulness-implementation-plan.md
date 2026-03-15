input: 已批准的 Flutter/Rust 真实性修补设计与最新架构规格
output: 用户可见行为与 Rust 后端真相一致的任务化实施计划
pos: Flutter/Rust 真实性修补实施计划，执行前需先读 truthfulness design 与 architecture spec
# Flutter Rust Follow-Up Truthfulness Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 修补 joined pool 身份、save 分流、sync 恢复动作与 card query 这四类真实性问题，使 Flutter 页面展示与 Rust 后端语义完全一致。 

**Architecture:** 继续以 `docs/specs/architecture.md` 为最高约束：Flutter 只做前端编排与展示，Rust 定义身份、查询、写入与恢复动作真相。follow-up 的重点不是再改大架构，而是清除仍残留在前端的错误推断、假动作与查询语义。 

**Tech Stack:** Flutter、Dart、Rust、flutter_rust_bridge、SQLite 读模型、LoroDoc、`flutter test`、`cargo test`。

---

## 执行规则（强制）

1. 执行前先阅读：
   - `docs/specs/architecture.md`
   - `docs/plans/2026-03-15-flutter-rust-followup-truthfulness-design.md`
   - `docs/specs/pool.md`
   - `docs/specs/card-note.md`
2. 每个任务必须遵循 `Red -> Green -> Blue -> Commit`。
3. joined pool 当前用户角色必须由 Rust 基于当前调用者身份返回，不允许 Flutter 推断。
4. save 的 create/update 分流必须在真实主路径中得到验证，不接受“编辑变创建”。
5. `retry sync` 与 `reconnect` 必须调用真实后端动作。
6. Flutter 不再承担 card query 的产品级过滤/搜索真相。

## Worktree Requirement

执行 Task 1 之前：

1. 在 `.worktrees/` 下创建独立 worktree。
2. 推荐分支名：`flutter-rust-truthfulness-repair`。
3. 确认当前主分支与文档基线一致。

Run:

```bash
git worktree add ".worktrees/flutter-rust-truthfulness-repair" -b "flutter-rust-truthfulness-repair"
git status --short
```

Expected: worktree 创建成功，新工作目录状态可控。

---

### Task 1: 修正 joined pool 当前用户角色查询为当前调用者视角

**Files:**
- Modify: `rust/src/api.rs`
- Modify: `lib/features/pool/pool_api_client.dart`
- Modify: `lib/features/pool/pool_controller.dart`
- Create: `rust/tests/current_user_pool_view_test.rs`
- Test: `test/features/pool/pool_api_client_test.dart`

**Step 1: 写失败测试**

```rust
#[test]
fn joined_pool_view_should_return_current_user_role_for_calling_endpoint() {
    // create pool as owner
    // join as another endpoint
    // query joined view for joiner
    // assert current role == member, not admin
}
```

```dart
test('joined pool view should use backend current-user role instead of first member', () async {
  // fake backend dto with current-user role
  // assert api client/controller consume dto directly
});
```

**Step 2: 运行测试确认 RED**

Run: `cargo test --test current_user_pool_view_test && flutter test test/features/pool/pool_api_client_test.dart`  
Expected: FAIL，因为当前角色仍依赖近似逻辑。

**Step 3: 最小实现当前调用者视角查询**

```text
- Rust 提供 current-user-scoped joined pool view。
- 角色基于显式调用者身份计算，不再用 members.first()。
- FrbPoolApiClient / PoolController 改为消费该后端结果。
```

**Step 4: 运行测试确认 GREEN**

Run: `cargo test --test current_user_pool_view_test && flutter test test/features/pool/pool_api_client_test.dart`  
Expected: PASS

**Step 5: Blue 重构**

- 提取 role 计算辅助函数。
- 清理旧的近似角色函数与冗余查询路径。

**Step 6: 复跑验证**

Run: `cargo test --test current_user_pool_view_test && flutter test test/features/pool/pool_api_client_test.dart`  
Expected: PASS

**Step 7: Commit**

```bash
git add rust/src/api.rs lib/features/pool/pool_api_client.dart lib/features/pool/pool_controller.dart rust/tests/current_user_pool_view_test.rs test/features/pool/pool_api_client_test.dart
git commit -m "fix(pool): return current-user joined view semantics"
```

---

### Task 2: 让 save 动作在真实主路径中严格分流 create / update

**Files:**
- Modify: `lib/features/cards/cards_controller.dart`
- Modify: `lib/features/cards/cards_page.dart`
- Modify: `lib/features/cards/card_api_client.dart`
- Test: `test/features/cards/cards_page_test.dart`
- Test: `test/features/cards/cards_api_client_test.dart`

**Step 1: 写失败测试**

```dart
testWidgets('saving an existing selected card should call update not create', (tester) async {
  // select existing card in desktop flow
  // edit content
  // save
  // assert same id updated, no new card created
});
```

**Step 2: 运行测试确认 RED**

Run: `flutter test test/features/cards/cards_page_test.dart test/features/cards/cards_api_client_test.dart`  
Expected: FAIL，因为当前已有卡片保存仍可能走 create 语义。

**Step 3: 最小实现 save 分流**

```text
- CardsController 增加统一 save(...) 编排入口。
- 若存在 cardId 则调用 updateCardNote。
- 若不存在 cardId 则调用 createCardNote。
- CardsPage 桌面/移动保存路径统一走 save(...)。
```

**Step 4: 运行测试确认 GREEN**

Run: `flutter test test/features/cards/cards_page_test.dart test/features/cards/cards_api_client_test.dart`  
Expected: PASS

**Step 5: Blue 重构**

- 清理页面中重复的 create 调用路径。
- 收敛保存后刷新逻辑。

**Step 6: 复跑验证**

Run: `flutter test test/features/cards/cards_page_test.dart test/features/cards/cards_api_client_test.dart`  
Expected: PASS

**Step 7: Commit**

```bash
git add lib/features/cards/cards_controller.dart lib/features/cards/cards_page.dart lib/features/cards/card_api_client.dart test/features/cards/cards_page_test.dart test/features/cards/cards_api_client_test.dart
git commit -m "fix(cards): split save into create and update paths"
```

---

### Task 3: 把 card query 产品语义收回 Rust Query API

**Files:**
- Modify: `rust/src/api.rs`
- Modify: `rust/src/store/card_store.rs`
- Modify: `rust/src/store/sqlite_store.rs`
- Modify: `lib/features/cards/card_api_client.dart`
- Modify: `lib/features/cards/cards_controller.dart`
- Create: `rust/tests/card_query_contract_test.rs`
- Test: `test/features/read_model/query_path_test.dart`

**Step 1: 写失败测试**

```rust
#[test]
fn card_query_api_should_apply_search_and_deleted_filters_in_backend() {
    // seed cards including deleted and different titles
    // query with keyword/includeDeleted variants
    // assert backend result semantics
}
```

```dart
test('flutter should consume backend-filtered card summaries instead of local filtering', () async {
  // assert api client no longer applies query/includeDeleted semantics in Dart
});
```

**Step 2: 运行测试确认 RED**

Run: `cargo test --test card_query_contract_test && flutter test test/features/read_model/query_path_test.dart`  
Expected: FAIL，因为当前仍在 Dart 侧做过滤。

**Step 3: 最小实现后端 query API**

```text
- Rust 增加 card query/search API，直接返回筛选好的 summaries/DTO。
- Flutter 改为调用 Rust query API，不再本地 where/filter。
- 排序与删除态语义由 Rust 统一定义。
```

**Step 4: 运行测试确认 GREEN**

Run: `cargo test --test card_query_contract_test && flutter test test/features/read_model/query_path_test.dart`  
Expected: PASS

**Step 5: Blue 重构**

- 清理 Dart 侧残留 query 过滤逻辑。
- 合并 Rust 查询 DTO 映射代码。

**Step 6: 复跑验证**

Run: `cargo test --test card_query_contract_test && flutter test test/features/read_model/query_path_test.dart`  
Expected: PASS

**Step 7: Commit**

```bash
git add rust/src/api.rs rust/src/store/card_store.rs rust/src/store/sqlite_store.rs lib/features/cards/card_api_client.dart lib/features/cards/cards_controller.dart rust/tests/card_query_contract_test.rs test/features/read_model/query_path_test.dart
git commit -m "refactor(cards): move query semantics into rust api"
```

---

### Task 4: 把 retry sync 和 reconnect 接到真实后端动作

**Files:**
- Modify: `lib/features/pool/pool_controller.dart`
- Modify: `lib/features/sync/sync_service.dart`
- Modify: `lib/features/sync/sync_api_client.dart`
- Modify: `lib/features/pool/pool_page.dart`
- Test: `test/features/sync/sync_state_semantics_test.dart`
- Test: `test/features/pool/pool_page_test.dart`

**Step 1: 写失败测试**

```dart
test('retrySync should invoke backend retry action and refresh from backend status', () async {
  // fake sync gateway with call counters
  // assert retry triggers backend call
});

test('reconnectSync should invoke backend reconnect action and refresh from backend status', () async {
  // fake sync gateway with connect/disconnect call counters
  // assert reconnect triggers backend flow
});
```

**Step 2: 运行测试确认 RED**

Run: `flutter test test/features/sync/sync_state_semantics_test.dart test/features/pool/pool_page_test.dart`  
Expected: FAIL，因为当前动作仍只是本地状态切换。

**Step 3: 最小实现真实恢复动作**

```text
- PoolController.retrySync() 调用 SyncService.retry()。
- PoolController.reconnectSync() 调用 SyncService.reconnect(...)。
- 页面只展示后端返回的新状态，不预设成功。
```

**Step 4: 运行测试确认 GREEN**

Run: `flutter test test/features/sync/sync_state_semantics_test.dart test/features/pool/pool_page_test.dart`  
Expected: PASS

**Step 5: Blue 重构**

- 清理本地假动作残余代码。
- 抽取页面与控制器之间的同步恢复辅助逻辑。

**Step 6: 复跑验证**

Run: `flutter test test/features/sync/sync_state_semantics_test.dart test/features/pool/pool_page_test.dart`  
Expected: PASS

**Step 7: Commit**

```bash
git add lib/features/pool/pool_controller.dart lib/features/sync/sync_service.dart lib/features/sync/sync_api_client.dart lib/features/pool/pool_page.dart test/features/sync/sync_state_semantics_test.dart test/features/pool/pool_page_test.dart
git commit -m "fix(sync): wire recovery actions to backend"
```

---

### Task 5: 增强回退防护测试，防止错误实现回流

**Files:**
- Modify: `test/architecture/no_flutter_write_source_test.dart`
- Create: `test/architecture/followup_truthfulness_guard_test.dart`

**Step 1: 写失败测试**

```dart
test('frontend must not infer joined pool role from member ordering', () {
  // source guard
});

test('save path must not route existing card saves through create', () {
  // source guard
});

test('sync recovery actions must not be local-only state mutations', () {
  // source guard
});
```

**Step 2: 运行测试确认 RED**

Run: `flutter test test/architecture/no_flutter_write_source_test.dart test/architecture/followup_truthfulness_guard_test.dart`  
Expected: FAIL

**Step 3: 最小实现回退防护**

```text
- 增加针对身份推断、save 误走 create、sync 假动作、query 本地过滤的守卫。
- 让错误实现回流时直接红灯。
```

**Step 4: 运行测试确认 GREEN**

Run: `flutter test test/architecture/no_flutter_write_source_test.dart test/architecture/followup_truthfulness_guard_test.dart`  
Expected: PASS

**Step 5: Blue 重构**

- 提取源码读取工具，减少测试重复。
- 优化断言文案，便于以后定位回退点。

**Step 6: 复跑验证**

Run: `flutter test test/architecture/no_flutter_write_source_test.dart test/architecture/followup_truthfulness_guard_test.dart`  
Expected: PASS

**Step 7: Commit**

```bash
git add test/architecture/no_flutter_write_source_test.dart test/architecture/followup_truthfulness_guard_test.dart
git commit -m "test(architecture): guard truthfulness repairs"
```

---

### Task 6: 跑最终门禁并确认 follow-up 修补成立

**Files:**
- Reference: `tool/quality.dart`
- Reference: `docs/specs/architecture.md`
- Reference: `docs/plans/2026-03-15-flutter-rust-followup-truthfulness-design.md`

**Step 1: 运行 Flutter 门禁**

Run: `dart run tool/quality.dart flutter`  
Expected: PASS

**Step 2: 运行 Rust 门禁**

Run: `dart run tool/quality.dart rust`  
Expected: PASS

**Step 3: 运行关键 follow-up 测试**

Run: `flutter test test/features/cards/cards_page_test.dart test/features/pool/pool_api_client_test.dart test/features/sync/sync_state_semantics_test.dart test/architecture/followup_truthfulness_guard_test.dart && cargo test --test current_user_pool_view_test && cargo test --test card_query_contract_test`  
Expected: PASS

**Step 4: Blue 收尾**

- 删除临时调试代码。
- 再次检查生产页面路径是否仍然只消费 Rust 真相。

**Step 5: 最终 Commit**

```bash
git add .
git commit -m "fix: complete flutter rust truthfulness repairs"
```
