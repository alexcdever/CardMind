input: 已批准的 Flutter/Rust 主路径修补设计与最新架构规格
output: 生产主路径完全切到 FRB/Rust、移除生产兼容层的任务化实施计划
pos: Flutter/Rust 主路径修补实施计划，执行前需先读 architecture spec 与 repair design
# Flutter Rust Mainpath Repair Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将生产页面主路径完全切换到 `FRB -> Rust`，补齐缺失 API 与真实状态语义，并移除生产兼容接线。 

**Architecture:** 以 `docs/specs/architecture.md` 为最高约束：Flutter 只通过 FRB 调用 Rust 后端，不直接读写 `LoroDoc` 或 `SQLite`。所有业务写入先进入 Rust 与 `LoroDoc`，查询由 Rust 从 `SQLite` 读模型返回 DTO；生产组合层不得再实例化 local/legacy client。 

**Tech Stack:** Flutter、Dart、Rust、flutter_rust_bridge、LoroDoc、SQLite、`flutter test`、`cargo test`、Markdown docs。

---

## 执行规则（强制）

1. 执行前先阅读：
   - `docs/specs/architecture.md`
   - `docs/plans/2026-03-13-flutter-rust-mainpath-repair-design.md`
   - `docs/specs/pool.md`
   - `docs/specs/card-note.md`
2. 每个任务必须遵循 `Red -> Green -> Blue -> Commit`。
3. 生产页面默认组合层不得保留 `LegacyCardApiClient` / `LocalPoolApiClient`。
4. Flutter 不得直接读 `SQLite`，也不得直接写本地 `LoroDoc`。
5. 如果某个兼容对象必须暂留仓库，其存在位置只能是测试/fixture，不能出现在生产组合层依赖图中。

## Worktree Requirement

执行 Task 1 之前：

1. 在 `.worktrees/` 下创建独立 worktree。
2. 推荐分支名：`flutter-rust-mainpath-repair`。
3. 确认当前主分支文档基线与代码状态一致后再开始。

Run:

```bash
git worktree add ".worktrees/flutter-rust-mainpath-repair" -b "flutter-rust-mainpath-repair"
git status --short
```

Expected: worktree 创建成功，新工作目录状态可控。

---

### Task 1: 升级架构守卫，禁止生产页面使用兼容 client

**Files:**
- Modify: `test/architecture/no_flutter_write_source_test.dart`
- Reference: `lib/features/cards/cards_page.dart`
- Reference: `lib/features/pool/pool_page.dart`
- Reference: `lib/features/cards/card_api_client.dart`
- Reference: `lib/features/pool/pool_api_client.dart`

**Step 1: 写失败测试**

```dart
test('production page composition should not instantiate legacy or local api clients', () {
  final cardsPage = File('lib/features/cards/cards_page.dart').readAsStringSync();
  final poolPage = File('lib/features/pool/pool_page.dart').readAsStringSync();

  expect(cardsPage.contains('LegacyCardApiClient'), isFalse);
  expect(poolPage.contains('LocalPoolApiClient'), isFalse);
});
```

**Step 2: 运行测试确认 RED**

Run: `flutter test test/architecture/no_flutter_write_source_test.dart`  
Expected: FAIL，因为当前生产页面仍含兼容 client 装配。

**Step 3: 最小更新守卫测试**

```text
- 让架构守卫明确覆盖：生产页面默认组合层不得实例化 legacy/local client。
- 保留对中文兼容注释的检查，但不再把它当唯一合规条件。
```

**Step 4: 运行测试确认 GREEN**

Run: `flutter test test/architecture/no_flutter_write_source_test.dart`  
Expected: PASS（在 Task 2/3 完成后复跑通过）。

**Step 5: Blue 重构**

- 提取重复文件读取逻辑。
- 让失败信息更准确，便于后续回退排查。

**Step 6: 复跑验证**

Run: `flutter test test/architecture/no_flutter_write_source_test.dart`  
Expected: PASS

**Step 7: Commit**

```bash
git add test/architecture/no_flutter_write_source_test.dart
git commit -m "test(architecture): forbid legacy production clients"
```

---

### Task 2: 切换 CardsPage 生产组合到 FrbCardApiClient

**Files:**
- Modify: `lib/features/cards/cards_page.dart`
- Modify: `lib/features/cards/cards_controller.dart`
- Modify: `lib/features/cards/card_api_client.dart`
- Test: `test/features/cards/cards_page_test.dart`
- Test: `test/features/cards/cards_api_client_test.dart`

**Step 1: 写失败测试**

```dart
testWidgets('cards page production composition should use FRB api client', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: CardsPage()));
  // 断言页面主路径不再依赖 LegacyCardApiClient 兼容实现
});
```

**Step 2: 运行测试确认 RED**

Run: `flutter test test/features/cards/cards_page_test.dart test/features/cards/cards_api_client_test.dart test/architecture/no_flutter_write_source_test.dart`  
Expected: FAIL

**Step 3: 最小实现生产接线切换**

```text
- CardsPage 默认组合层改为使用 FrbCardApiClient。
- 不再在页面主路径上 new LegacyCardApiClient.inMemory(...)
- 如需页面初始化 store/network 句柄，收敛到清晰的前端组合入口。
```

**Step 4: 运行测试确认 GREEN**

Run: `flutter test test/features/cards/cards_page_test.dart test/features/cards/cards_api_client_test.dart test/architecture/no_flutter_write_source_test.dart`  
Expected: PASS

**Step 5: Blue 重构**

- 收敛页面组合代码，避免初始化细节散落在 widget 内。
- 删除主路径不再需要的兼容字段/依赖。

**Step 6: 复跑验证**

Run: `flutter test test/features/cards/cards_page_test.dart test/features/cards/cards_api_client_test.dart test/architecture/no_flutter_write_source_test.dart`  
Expected: PASS

**Step 7: Commit**

```bash
git add lib/features/cards/cards_page.dart lib/features/cards/cards_controller.dart lib/features/cards/card_api_client.dart test/features/cards/cards_page_test.dart test/features/cards/cards_api_client_test.dart test/architecture/no_flutter_write_source_test.dart
git commit -m "feat(cards): switch production flow to frb client"
```

---

### Task 3: 补齐 FrbCardApiClient 的 delete / restore / query 动作

**Files:**
- Modify: `lib/features/cards/card_api_client.dart`
- Modify: `rust/src/api.rs`
- Modify: `rust/src/store/card_store.rs`
- Create: `rust/tests/card_api_delete_restore_test.rs`
- Test: `test/features/cards/cards_api_client_test.dart`

**Step 1: 写失败测试**

```rust
#[test]
fn delete_and_restore_card_should_roundtrip_through_backend_api() {
    // create -> delete -> query deleted -> restore -> query active
}
```

```dart
test('frb card api client supports delete and restore', () async {
  // fake or integration-backed client call expectations
});
```

**Step 2: 运行测试确认 RED**

Run: `cargo test --test card_api_delete_restore_test && flutter test test/features/cards/cards_api_client_test.dart`  
Expected: FAIL，因为当前 delete/restore 仍是 `UnimplementedError`。

**Step 3: 最小实现缺失动作**

```text
- Rust API 补齐 deleteCardNote / restoreCardNote。
- FrbCardApiClient 删除 `UnimplementedError`。
- 查询 API 能返回 delete/restore 后的真实结果。
```

**Step 4: 运行测试确认 GREEN**

Run: `cargo test --test card_api_delete_restore_test && flutter test test/features/cards/cards_api_client_test.dart`  
Expected: PASS

**Step 5: Blue 重构**

- 收敛 card DTO 映射逻辑。
- 清理仍假设 Flutter 本地生成真相的代码。

**Step 6: 复跑验证**

Run: `cargo test --test card_api_delete_restore_test && flutter test test/features/cards/cards_api_client_test.dart`  
Expected: PASS

**Step 7: Commit**

```bash
git add lib/features/cards/card_api_client.dart rust/src/api.rs rust/src/store/card_store.rs rust/tests/card_api_delete_restore_test.rs test/features/cards/cards_api_client_test.dart
git commit -m "feat(cards): add frb delete and restore flow"
```

---

### Task 4: 切换 PoolPage 生产组合到 FrbPoolApiClient

**Files:**
- Modify: `lib/features/pool/pool_page.dart`
- Modify: `lib/features/pool/pool_controller.dart`
- Modify: `lib/features/pool/pool_api_client.dart`
- Test: `test/features/pool/pool_page_test.dart`
- Test: `test/features/pool/pool_api_client_test.dart`
- Test: `test/architecture/no_flutter_write_source_test.dart`

**Step 1: 写失败测试**

```dart
testWidgets('pool page production composition should use FRB api client', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: PoolPage(state: PoolState.notJoined())));
  // 断言默认组合不再依赖 LocalPoolApiClient
});
```

**Step 2: 运行测试确认 RED**

Run: `flutter test test/features/pool/pool_page_test.dart test/features/pool/pool_api_client_test.dart test/architecture/no_flutter_write_source_test.dart`  
Expected: FAIL

**Step 3: 最小实现生产接线切换**

```text
- PoolPage 默认组合层改为使用 FrbPoolApiClient。
- PoolController 主路径不再依赖本地模拟创建/加入逻辑。
```

**Step 4: 运行测试确认 GREEN**

Run: `flutter test test/features/pool/pool_page_test.dart test/features/pool/pool_api_client_test.dart test/architecture/no_flutter_write_source_test.dart`  
Expected: PASS

**Step 5: Blue 重构**

- 抽取页面到控制器的组合初始化。
- 清理主路径不再需要的本地模拟状态字段。

**Step 6: 复跑验证**

Run: `flutter test test/features/pool/pool_page_test.dart test/features/pool/pool_api_client_test.dart test/architecture/no_flutter_write_source_test.dart`  
Expected: PASS

**Step 7: Commit**

```bash
git add lib/features/pool/pool_page.dart lib/features/pool/pool_controller.dart lib/features/pool/pool_api_client.dart test/features/pool/pool_page_test.dart test/features/pool/pool_api_client_test.dart test/architecture/no_flutter_write_source_test.dart
git commit -m "feat(pool): switch production flow to frb client"
```

---

### Task 5: 补齐 FrbPoolApiClient 的 joinByCode 真实后端路径

**Files:**
- Modify: `lib/features/pool/pool_api_client.dart`
- Modify: `rust/src/api.rs`
- Modify: `rust/src/store/pool_store.rs`
- Create: `rust/tests/pool_join_by_code_test.rs`
- Test: `test/features/pool/pool_api_client_test.dart`

**Step 1: 写失败测试**

```rust
#[test]
fn join_by_code_should_return_backend_result_and_attach_existing_notes() {
    // 调用 join_by_code，断言返回 joined / error 语义，并验证 noteId 挂接
}
```

**Step 2: 运行测试确认 RED**

Run: `cargo test --test pool_join_by_code_test && flutter test test/features/pool/pool_api_client_test.dart`  
Expected: FAIL，因为当前 `joinByCode` 仍未实现真实 FRB 映射。

**Step 3: 最小实现真实 joinByCode**

```text
- Rust 提供 join_by_code 或等价真实后端动作。
- FrbPoolApiClient 把 code 加入流映射到真实后端结果。
- 保持当前 UI 语义，不扩成审批流。
```

**Step 4: 运行测试确认 GREEN**

Run: `cargo test --test pool_join_by_code_test && flutter test test/features/pool/pool_api_client_test.dart`  
Expected: PASS

**Step 5: Blue 重构**

- 抽取 join 错误码映射，避免散落在多层。
- 清理本地模拟残余逻辑。

**Step 6: 复跑验证**

Run: `cargo test --test pool_join_by_code_test && flutter test test/features/pool/pool_api_client_test.dart`  
Expected: PASS

**Step 7: Commit**

```bash
git add lib/features/pool/pool_api_client.dart rust/src/api.rs rust/src/store/pool_store.rs rust/tests/pool_join_by_code_test.rs test/features/pool/pool_api_client_test.dart
git commit -m "feat(pool): add frb join by code flow"
```

---

### Task 6: 让 Flutter 查询只经过 Rust Query API

**Files:**
- Modify: `lib/features/cards/card_api_client.dart`
- Modify: `lib/features/pool/pool_api_client.dart`
- Modify: `lib/features/cards/cards_controller.dart`
- Modify: `lib/features/pool/pool_controller.dart`
- Test: `test/features/read_model/query_path_test.dart`
- Test: `test/architecture/no_flutter_write_source_test.dart`

**Step 1: 写失败测试**

```dart
test('flutter query refresh should call rust query apis instead of reading local sqlite directly', () async {
  // 验证 controller 刷新依赖 ApiClient query，而不是 AppDatabase/readRepository 直连
});
```

**Step 2: 运行测试确认 RED**

Run: `flutter test test/features/read_model/query_path_test.dart test/architecture/no_flutter_write_source_test.dart`  
Expected: FAIL

**Step 3: 最小实现查询边界收口**

```text
- Flutter 通过 FrbCardApiClient / FrbPoolApiClient 查询接口拿数据。
- Rust 查询 API 再从 SQLite 读模型返回 DTO。
- 清理 Flutter 生产主路径直接持有本地查询读仓的做法。
```

**Step 4: 运行测试确认 GREEN**

Run: `flutter test test/features/read_model/query_path_test.dart test/architecture/no_flutter_write_source_test.dart`  
Expected: PASS

**Step 5: Blue 重构**

- 收敛 controller 的刷新逻辑。
- 清理主路径不再需要的本地数据库装配。

**Step 6: 复跑验证**

Run: `flutter test test/features/read_model/query_path_test.dart test/architecture/no_flutter_write_source_test.dart`  
Expected: PASS

**Step 7: Commit**

```bash
git add lib/features/cards/card_api_client.dart lib/features/pool/pool_api_client.dart lib/features/cards/cards_controller.dart lib/features/pool/pool_controller.dart test/features/read_model/query_path_test.dart test/architecture/no_flutter_write_source_test.dart
git commit -m "refactor(query): route flutter queries through rust apis"
```

---

### Task 7: 让 Rust 返回真实 write / projection / sync 状态语义

**Files:**
- Modify: `rust/src/api.rs`
- Modify: `rust/src/models/api_error.rs`
- Modify: `rust/src/store/sqlite_store.rs`
- Modify: `lib/features/sync/sync_service.dart`
- Modify: `lib/features/sync/sync_status.dart`
- Test: `rust/tests/sync_api_flow_test.rs`
- Test: `test/features/sync/sync_state_semantics_test.dart`

**Step 1: 写失败测试**

```rust
#[test]
fn sync_status_should_expose_real_projection_and_sync_semantics() {
    // 断言不是硬编码 ready / write_saved，而是来自真实状态
}
```

```dart
test('frontend should map real backend write projection and sync states', () async {
  // 通过真实 FRB 或更接近真实 DTO 的输入验证状态映射
});
```

**Step 2: 运行测试确认 RED**

Run: `cargo test --test sync_api_flow_test && flutter test test/features/sync/sync_state_semantics_test.dart`  
Expected: FAIL

**Step 3: 最小实现真实状态语义**

```text
- SyncStatusDto / SyncResultDto 由真实后端状态派生。
- 至少区分：write_saved、projection_pending/projection_failed、sync_failed/degraded。
- Flutter 不再依赖占位常量判断恢复语义。
```

**Step 4: 运行测试确认 GREEN**

Run: `cargo test --test sync_api_flow_test && flutter test test/features/sync/sync_state_semantics_test.dart`  
Expected: PASS

**Step 5: Blue 重构**

- 合并重复状态映射逻辑。
- 移除硬编码占位值。

**Step 6: 复跑验证**

Run: `cargo test --test sync_api_flow_test && flutter test test/features/sync/sync_state_semantics_test.dart`  
Expected: PASS

**Step 7: Commit**

```bash
git add rust/src/api.rs rust/src/models/api_error.rs rust/src/store/sqlite_store.rs lib/features/sync/sync_service.dart lib/features/sync/sync_status.dart rust/tests/sync_api_flow_test.rs test/features/sync/sync_state_semantics_test.dart
git commit -m "feat(sync): return real backend status semantics"
```

---

### Task 8: 删除生产兼容层并把 local/legacy client 收缩到测试用途

**Files:**
- Modify/Delete: `lib/features/cards/card_api_client.dart`
- Modify/Delete: `lib/features/pool/pool_api_client.dart`
- Modify: `test/features/cards/cards_api_client_test.dart`
- Modify: `test/features/pool/pool_api_client_test.dart`
- Modify: `test/architecture/no_flutter_write_source_test.dart`

**Step 1: 写失败测试**

```dart
test('production reachable api clients should not expose legacy or local fallback paths', () {
  // 断言生产可达 client 类型只剩 FRB 主路径
});
```

**Step 2: 运行测试确认 RED**

Run: `flutter test test/features/cards/cards_api_client_test.dart test/features/pool/pool_api_client_test.dart test/architecture/no_flutter_write_source_test.dart`  
Expected: FAIL

**Step 3: 最小实现删除与收缩**

```text
- 从生产可达路径中删除 LegacyCardApiClient / LocalPoolApiClient。
- 如测试仍需要 fake/local 行为，把它们迁入测试专用文件或测试 fixture。
- 生产代码中不再保留“短期兼容”注释，因为生产兼容层目标是被删除。
```

**Step 4: 运行测试确认 GREEN**

Run: `flutter test test/features/cards/cards_api_client_test.dart test/features/pool/pool_api_client_test.dart test/architecture/no_flutter_write_source_test.dart`  
Expected: PASS

**Step 5: Blue 重构**

- 清理未使用导入和死代码。
- 更新测试命名，反映“测试 fixture”而非“生产兼容”。

**Step 6: 复跑验证**

Run: `flutter test test/features/cards/cards_api_client_test.dart test/features/pool/pool_api_client_test.dart test/architecture/no_flutter_write_source_test.dart`  
Expected: PASS

**Step 7: Commit**

```bash
git add lib/features/cards/card_api_client.dart lib/features/pool/pool_api_client.dart test/features/cards/cards_api_client_test.dart test/features/pool/pool_api_client_test.dart test/architecture/no_flutter_write_source_test.dart
git commit -m "refactor(api): remove production compatibility clients"
```

---

### Task 9: 跑通完整 FRB 主路径集成测试

**Files:**
- Modify: `test/bridge/flutter_rust_flow_smoke_test.dart`
- Create: `test/bridge/flutter_rust_mainpath_actions_test.dart`
- Reference: `lib/features/cards/cards_page.dart`
- Reference: `lib/features/pool/pool_page.dart`

**Step 1: 写失败测试**

```dart
test('frb mainpath should support pool join create edit delete restore query and sync', () async {
  // create pool
  // join by code
  // create/edit/delete/restore card
  // query via rust query api
  // explicit sync
});
```

**Step 2: 运行测试确认 RED**

Run: `flutter test test/bridge/flutter_rust_flow_smoke_test.dart test/bridge/flutter_rust_mainpath_actions_test.dart`  
Expected: FAIL

**Step 3: 最小补齐主路径缺口**

```text
- 修补 FRB 参数、DTO 或初始化缺口。
- 覆盖主路径所有核心用户动作。
```

**Step 4: 运行测试确认 GREEN**

Run: `flutter test test/bridge/flutter_rust_flow_smoke_test.dart test/bridge/flutter_rust_mainpath_actions_test.dart`  
Expected: PASS

**Step 5: Blue 重构**

- 减少测试样板。
- 合并重复初始化逻辑。

**Step 6: 复跑验证**

Run: `flutter test test/bridge/flutter_rust_flow_smoke_test.dart test/bridge/flutter_rust_mainpath_actions_test.dart`  
Expected: PASS

**Step 7: Commit**

```bash
git add test/bridge/flutter_rust_flow_smoke_test.dart test/bridge/flutter_rust_mainpath_actions_test.dart
git commit -m "test(bridge): verify repaired flutter rust mainpath"
```

---

### Task 10: 运行最终门禁并确认无回退

**Files:**
- Reference: `tool/quality.dart`
- Reference: `docs/specs/architecture.md`
- Reference: `docs/plans/2026-03-13-flutter-rust-mainpath-repair-design.md`

**Step 1: 运行 Flutter 门禁**

Run: `dart run tool/quality.dart flutter`  
Expected: PASS

**Step 2: 运行 Rust 门禁**

Run: `dart run tool/quality.dart rust`  
Expected: PASS

**Step 3: 运行关键架构与桥接测试**

Run: `flutter test test/architecture/no_flutter_write_source_test.dart test/bridge/flutter_rust_flow_smoke_test.dart test/bridge/flutter_rust_mainpath_actions_test.dart`  
Expected: PASS

**Step 4: Blue 收尾**

- 删除临时调试代码。
- 确认生产组合层只剩 FRB 主路径。

**Step 5: 最终 Commit**

```bash
git add .
git commit -m "feat: repair flutter rust production mainpath"
```
