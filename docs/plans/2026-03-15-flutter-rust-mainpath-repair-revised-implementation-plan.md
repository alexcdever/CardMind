# Flutter Rust Mainpath Repair Revised Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 在已移除 `CardStore/storeId` 暴露的新基线上，补齐 FRB 功能缺口、关闭 Flutter 直连查询路径，并让生产主路径完整收敛到 `FRB -> Rust`。

**Architecture:** 以 `docs/specs/architecture.md` 为最高约束，Flutter 启动时通过 `initAppConfig(appDataDir)` 完成 Rust 运行环境配置，之后 cards/pools/sync 只调用无句柄 FRB 资源 API。Flutter 生产主路径不得实例化 legacy/local client，也不得直接持有 `AppDatabase`、`Sqlite*ReadRepository` 去读取产品查询结果。

**Tech Stack:** Flutter、Dart、Rust、flutter_rust_bridge、LoroDoc、SQLite、`flutter test`、`cargo test`、Markdown docs。

---

## 执行规则（强制）

1. 执行前先阅读：
   - `docs/specs/architecture.md`
   - `docs/specs/pool.md`
   - `docs/specs/card-note.md`
   - `docs/plans/2026-03-13-flutter-rust-mainpath-repair-design.md`
   - `docs/plans/2026-03-15-remove-cardstore-handle-design.md`
2. 每个任务必须遵循 `Red -> Green -> Blue -> Commit`。
3. 生产页面默认组合层不得保留 `LegacyCardApiClient` / `LocalPoolApiClient`。
4. Flutter 不得直接读 `SQLite`，也不得直接写本地 `LoroDoc`。
5. FRB 产品主路径不得重新引入 `storeId` 或任何等价 handle。
6. 如果兼容对象必须暂留仓库，其存在位置只能是测试/fixture，不能出现在生产组合层依赖图中。

---

### Task 1: 固化架构守卫，禁止主路径回退到兼容 client 或本地查询直连

**Files:**
- Modify: `test/architecture/no_flutter_write_source_test.dart`
- Modify: `test/features/read_model/query_path_test.dart`
- Reference: `lib/features/cards/cards_page.dart`
- Reference: `lib/features/pool/pool_page.dart`
- Reference: `lib/features/cards/cards_controller.dart`
- Reference: `lib/features/pool/pool_controller.dart`

**Step 1: 写失败测试**

```dart
test('production pages and controllers should not wire local sqlite query dependencies', () {
  final cardsPage = File('lib/features/cards/cards_page.dart').readAsStringSync();
  final poolPage = File('lib/features/pool/pool_page.dart').readAsStringSync();
  final cardsController = File('lib/features/cards/cards_controller.dart').readAsStringSync();
  final poolController = File('lib/features/pool/pool_controller.dart').readAsStringSync();

  expect(cardsPage.contains('AppDatabase('), isFalse);
  expect(cardsPage.contains('SqliteCardsReadRepository'), isFalse);
  expect(poolPage.contains('SqlitePoolReadRepository'), isFalse);
  expect(cardsController.contains('CardsReadRepository'), isFalse);
  expect(poolController.contains('PoolReadRepository'), isFalse);
});
```

**Step 2: 运行测试确认 RED**

Run: `flutter test test/architecture/no_flutter_write_source_test.dart test/features/read_model/query_path_test.dart`
Expected: FAIL，因为当前 `CardsPage` 仍直接装配 `AppDatabase` 与 `SqliteCardsReadRepository`。

**Step 3: 最小更新守卫测试**

```text
- 保留已存在的“禁止 legacy/local client”和“禁止 handle 泄露”检查。
- 新增“生产页面/控制器不得直接装配本地 SQLite 读仓”的约束。
- 让 query_path_test 从“SQLite 读模型存在”转向“Flutter 主路径不再直接持有本地查询依赖”。
```

**Step 4: 运行测试确认 GREEN**

Run: `flutter test test/architecture/no_flutter_write_source_test.dart test/features/read_model/query_path_test.dart`
Expected: PASS（在 Task 4 完成后复跑通过）。

**Step 5: Blue 重构**

- 提取重复源码读取逻辑。
- 让失败信息区分“兼容 client 回退”“handle 泄露”“本地查询直连回退”。

**Step 6: 复跑验证**

Run: `flutter test test/architecture/no_flutter_write_source_test.dart test/features/read_model/query_path_test.dart`
Expected: PASS

**Step 7: Commit**

```bash
git add test/architecture/no_flutter_write_source_test.dart test/features/read_model/query_path_test.dart
git commit -m "test(architecture): forbid local query wiring in production path"
```

---

### Task 2: 补齐 FrbCardApiClient 的 delete / restore 主路径

**Files:**
- Modify: `lib/features/cards/card_api_client.dart`
- Modify: `rust/src/api.rs`
- Create: `rust/tests/card_api_delete_restore_test.rs`
- Modify: `test/features/cards/cards_api_client_test.dart`

**Step 1: 写失败测试**

```rust
#[test]
fn delete_and_restore_card_should_roundtrip_through_backend_api() {
    // init_app_config -> create -> delete -> query deleted -> restore -> query active
}
```

```dart
test('frb card api client supports delete and restore without handle state', () async {
  final client = FrbCardApiClient();
  // call expectations or integration-backed expectations
});
```

**Step 2: 运行测试确认 RED**

Run: `cargo test --test card_api_delete_restore_test && flutter test test/features/cards/cards_api_client_test.dart`
Expected: FAIL，因为当前 `deleteCardNote` / `restoreCardNote` 仍是 `UnimplementedError`。

**Step 3: 最小实现缺失动作**

```text
- Rust API 补齐 deleteCardNote / restoreCardNote，无 `storeId` 参数。
- FrbCardApiClient 删除 `UnimplementedError`。
- 查询结果能真实反映 delete / restore 后状态。
```

**Step 4: 运行测试确认 GREEN**

Run: `cargo test --test card_api_delete_restore_test && flutter test test/features/cards/cards_api_client_test.dart`
Expected: PASS

**Step 5: Blue 重构**

- 收敛 card DTO 映射逻辑。
- 清理仍假设 Flutter 本地生成写真相的残余注释/分支。

**Step 6: 复跑验证**

Run: `cargo test --test card_api_delete_restore_test && flutter test test/features/cards/cards_api_client_test.dart`
Expected: PASS

**Step 7: Commit**

```bash
git add lib/features/cards/card_api_client.dart rust/src/api.rs rust/tests/card_api_delete_restore_test.rs test/features/cards/cards_api_client_test.dart
git commit -m "feat(cards): add frb delete and restore flow"
```

---

### Task 3: 补齐 FrbPoolApiClient 的 joinByCode 真实后端路径

**Files:**
- Modify: `lib/features/pool/pool_api_client.dart`
- Modify: `rust/src/api.rs`
- Modify: `rust/src/store/pool_store.rs`
- Create: `rust/tests/pool_join_by_code_test.rs`
- Modify: `test/features/pool/pool_api_client_test.dart`

**Step 1: 写失败测试**

```rust
#[test]
fn join_by_code_should_return_backend_result_and_attach_existing_notes() {
    // init_app_config -> create/join flow -> assert joined/error semantics and noteId attachment
}
```

```dart
test('frb pool api client maps joinByCode to backend result without handle state', () async {
  final client = FrbPoolApiClient(endpointId: 'e', nickname: 'n', os: 'macos');
  // join result expectations
});
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

### Task 4: 让 Flutter 查询只经过 Rust Query API

**Files:**
- Modify: `lib/features/cards/card_api_client.dart`
- Modify: `lib/features/pool/pool_api_client.dart`
- Modify: `lib/features/cards/cards_controller.dart`
- Modify: `lib/features/pool/pool_controller.dart`
- Modify: `lib/features/cards/cards_page.dart`
- Modify: `lib/features/pool/pool_page.dart`
- Modify: `test/features/cards/cards_page_test.dart`
- Modify: `test/features/pool/pool_page_test.dart`
- Modify: `test/features/read_model/query_path_test.dart`
- Modify: `test/architecture/no_flutter_write_source_test.dart`

**Step 1: 写失败测试**

```dart
test('flutter query refresh should call rust query apis instead of reading local sqlite directly', () async {
  // verify cards/pool controller refresh depends on ApiClient query methods
  // instead of AppDatabase/Sqlite*ReadRepository wiring
});

testWidgets('cards page production composition should not create AppDatabase for product query path', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: CardsPage()));
  // verify handle-free FRB composition and no local query repository wiring
});
```

**Step 2: 运行测试确认 RED**

Run: `flutter test test/features/read_model/query_path_test.dart test/features/cards/cards_page_test.dart test/features/pool/pool_page_test.dart test/architecture/no_flutter_write_source_test.dart`
Expected: FAIL，因为当前页面和控制器仍依赖本地 SQLite 读仓刷新。

**Step 3: 最小实现查询边界收口**

```text
- CardApiClient / PoolApiClient 增加 query/list/detail 刷新入口。
- Flutter 控制器通过 FrbCardApiClient / FrbPoolApiClient 查询接口拿数据。
- Rust 查询 API 从 SQLite 读模型返回 DTO。
- 清理 CardsPage / PoolPage 生产主路径直接持有 AppDatabase / Sqlite*ReadRepository 的做法。
```

**Step 4: 运行测试确认 GREEN**

Run: `flutter test test/features/read_model/query_path_test.dart test/features/cards/cards_page_test.dart test/features/pool/pool_page_test.dart test/architecture/no_flutter_write_source_test.dart`
Expected: PASS

**Step 5: Blue 重构**

- 收敛 controller 的刷新逻辑。
- 抽取页面到 controller/client 的生产组合入口，避免页面内散落初始化细节。

**Step 6: 复跑验证**

Run: `flutter test test/features/read_model/query_path_test.dart test/features/cards/cards_page_test.dart test/features/pool/pool_page_test.dart test/architecture/no_flutter_write_source_test.dart`
Expected: PASS

**Step 7: Commit**

```bash
git add lib/features/cards/card_api_client.dart lib/features/pool/pool_api_client.dart lib/features/cards/cards_controller.dart lib/features/pool/pool_controller.dart lib/features/cards/cards_page.dart lib/features/pool/pool_page.dart test/features/read_model/query_path_test.dart test/features/cards/cards_page_test.dart test/features/pool/pool_page_test.dart test/architecture/no_flutter_write_source_test.dart
git commit -m "refactor(query): route flutter refresh through rust apis"
```

---

### Task 5: 让 Rust 返回真实 write / projection / sync 状态语义

**Files:**
- Modify: `rust/src/api.rs`
- Modify: `rust/src/models/api_error.rs`
- Modify: `rust/src/store/sqlite_store.rs`
- Modify: `lib/features/sync/sync_service.dart`
- Modify: `lib/features/sync/sync_status.dart`
- Modify: `test/features/sync/sync_state_semantics_test.dart`
- Modify: `rust/tests/sync_api_flow_test.rs`

**Step 1: 写失败测试**

```rust
#[test]
fn sync_status_should_expose_real_projection_and_sync_semantics() {
    // assert status is derived from real backend state, not hard-coded ready/write_saved
}
```

```dart
test('frontend should map real backend write projection and sync states', () async {
  // verify frontend distinguishes write saved, projection pending/failed, sync failed/degraded
});
```

**Step 2: 运行测试确认 RED**

Run: `cargo test --test sync_api_flow_test && flutter test test/features/sync/sync_state_semantics_test.dart`
Expected: FAIL，因为当前 `SyncStatusDto` / `SyncResultDto` 仍带占位语义。

**Step 3: 最小实现真实状态语义**

```text
- SyncStatusDto / SyncResultDto 由真实后端状态派生。
- 至少区分：write_saved、projection_pending/projection_failed、sync_failed/degraded。
- Flutter 只消费稳定状态，不自行猜测真假。
```

**Step 4: 运行测试确认 GREEN**

Run: `cargo test --test sync_api_flow_test && flutter test test/features/sync/sync_state_semantics_test.dart`
Expected: PASS

**Step 5: Blue 重构**

- 抽取状态映射帮助函数，避免状态字符串散落。
- 清理旧占位常量与误导性注释。

**Step 6: 复跑验证**

Run: `cargo test --test sync_api_flow_test && flutter test test/features/sync/sync_state_semantics_test.dart`
Expected: PASS

**Step 7: Commit**

```bash
git add rust/src/api.rs rust/src/models/api_error.rs rust/src/store/sqlite_store.rs lib/features/sync/sync_service.dart lib/features/sync/sync_status.dart test/features/sync/sync_state_semantics_test.dart rust/tests/sync_api_flow_test.rs
git commit -m "feat(sync): expose real backend status semantics"
```

---

### Task 6: 全量验证并确认主路径修补完成

**Files:**
- Modify: `docs/plans/DIR.md`（如需补充索引）
- Reference: `docs/plans/2026-03-13-flutter-rust-mainpath-repair-design.md`
- Reference: `docs/plans/2026-03-15-remove-cardstore-handle-design.md`

**Step 1: 写失败检查清单**

```text
- 生产页面默认组合不再实例化 LegacyCardApiClient / LocalPoolApiClient
- FrbCardApiClient / FrbPoolApiClient 不再残留 UnimplementedError 于生产可达路径
- Flutter 生产主路径不再直接装配 AppDatabase / Sqlite*ReadRepository
- Flutter 读写全部通过 FRB -> Rust API
- sync/projection/write 状态语义来自真实后端
```

**Step 2: 运行全量验证确认当前状态**

Run: `flutter test && cargo test`
Expected: 若仍有残余缺口，FAIL 并暴露最后未对齐项。

**Step 3: 最小补齐遗漏**

```text
- 修复残余 UnimplementedError、旧查询接线、状态映射遗漏与注释失真。
- 保持改动只围绕主路径修补，不顺手扩 scope。
```

**Step 4: 运行全量验证确认 GREEN**

Run: `flutter test && cargo test`
Expected: PASS

**Step 5: Blue 重构**

- 统一文件头与目录索引中对主路径、查询路径、无句柄 FRB 的表述。
- 清理已无意义的兼容残留与过时计划引用。

**Step 6: 复跑验证**

Run: `dart run tool/quality.dart all`
Expected: PASS

**Step 7: Commit**

```bash
git add .
git commit -m "feat(mainpath): complete handle-free flutter rust production flow"
```
