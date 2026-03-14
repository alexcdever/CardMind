# Remove CardStore Handle Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 移除 `CardStore/storeId` 在 FRB 产品主路径上的暴露，并改为 `initAppConfig(appDataDir)` + 无句柄资源 API。

**Architecture:** 以 `docs/specs/architecture.md` 为最高约束，Flutter 先调用 `initAppConfig(appDataDir)` 配置 Rust 运行环境，后续卡片/数据池/同步请求全部走无 `storeId` 的 FRB 资源 API。Rust 内部统一维护应用级运行上下文，不再以 `CardStore` 作为对外运行单元。

**Tech Stack:** Flutter、Dart、Rust、flutter_rust_bridge、LoroDoc、SQLite、`flutter test`、`cargo test`、Markdown docs。

---

## 执行规则（强制）

1. 执行前先阅读：
   - `docs/specs/architecture.md`
   - `docs/specs/pool.md`
   - `docs/specs/card-note.md`
   - `docs/plans/2026-03-15-remove-cardstore-handle-design.md`
2. 每个任务必须遵循 `Red -> Green -> Blue -> Commit`。
3. FRB 产品主路径不得再暴露 `storeId`。
4. Rust 主实现不得再保留 `CardStore`。
5. Flutter 页面/控制器不得感知 `storeId`、`CardStore`、`LoroDoc`、`SQLite`。
6. 若兼容对象必须暂留，只能存在于测试/fixture，不得出现在生产组合层依赖图中。

---

### Task 1: 补齐规格与桥接守卫，禁止产品路径继续暴露 store handle

**Files:**
- Modify: `test/bridge/backend_api_smoke_test.dart`
- Modify: `test/architecture/no_flutter_write_source_test.dart`
- Modify: `docs/plans/DIR.md`（仅在文档索引需补充时）

**Step 1: 写失败测试**

```dart
test('generated bridge should expose initAppConfig and handle-free backend apis', () {
  expect(frb.initAppConfig, isNotNull);
  expect(frb.createPool, isNotNull);
  expect(frb.createCardNote, isNotNull);
  expect(frb.listCardNotes, isNotNull);
});

test('production sources should not depend on storeId handle composition', () {
  final cardsPage = File('lib/features/cards/cards_page.dart').readAsStringSync();
  final poolPage = File('lib/features/pool/pool_page.dart').readAsStringSync();
  final cardApiClient = File('lib/features/cards/card_api_client.dart').readAsStringSync();
  final poolApiClient = File('lib/features/pool/pool_api_client.dart').readAsStringSync();

  expect(cardsPage.contains('storeId'), isFalse);
  expect(poolPage.contains('storeId'), isFalse);
  expect(cardApiClient.contains('initCardStore'), isFalse);
  expect(poolApiClient.contains('storeId'), isFalse);
});
```

**Step 2: 运行测试确认 RED**

Run: `flutter test test/bridge/backend_api_smoke_test.dart test/architecture/no_flutter_write_source_test.dart`
Expected: FAIL，因为当前 bridge 仍只有 `initCardStore` 且 FRB client 仍使用 `storeId`。

**Step 3: 最小更新守卫测试**

```text
- 把 bridge smoke test 从“存在旧 API”改成“存在 initAppConfig + 无句柄资源 API”。
- 把架构守卫扩展到禁止生产路径依赖 store handle 术语。
```

**Step 4: 运行测试确认 GREEN**

Run: `flutter test test/bridge/backend_api_smoke_test.dart test/architecture/no_flutter_write_source_test.dart`
Expected: PASS（在 Task 2/3/4 完成后复跑通过）。

**Step 5: Blue 重构**

- 提取重复源码读取逻辑。
- 让失败信息明确指出是“handle 泄露”还是“兼容 client 回退”。

**Step 6: 复跑验证**

Run: `flutter test test/bridge/backend_api_smoke_test.dart test/architecture/no_flutter_write_source_test.dart`
Expected: PASS

**Step 7: Commit**

```bash
git add test/bridge/backend_api_smoke_test.dart test/architecture/no_flutter_write_source_test.dart
git commit -m "test(bridge): forbid store handle product apis"
```

---

### Task 2: 引入 initAppConfig 与应用级运行配置错误语义

**Files:**
- Modify: `rust/src/api.rs`
- Modify: `rust/src/models/api_error.rs`
- Create: `rust/tests/app_config_api_test.rs`

**Step 1: 写失败测试**

```rust
#[test]
fn init_app_config_should_be_idempotent_for_same_directory() {
    // init once -> init same dir again -> ok
}

#[test]
fn init_app_config_should_fail_for_different_directory_after_configured() {
    // init dir A -> init dir B -> stable error
}

#[test]
fn product_api_should_fail_before_app_config_is_initialized() {
    // call list_card_notes or create_pool before initAppConfig -> stable error
}
```

**Step 2: 运行测试确认 RED**

Run: `cargo test --test app_config_api_test`
Expected: FAIL，因为当前只有 `init_card_store`，没有 app-level config API 与对应错误语义。

**Step 3: 最小实现 initAppConfig 与未配置错误**

```text
- 在 Rust API 中新增 app-level 配置入口 `init_app_config(app_data_dir)`。
- 新增“未完成应用配置”和“配置目录冲突”的稳定错误码。
- 让资源 API 在未配置时返回稳定错误，而不是依赖缺失 handle。
```

**Step 4: 运行测试确认 GREEN**

Run: `cargo test --test app_config_api_test`
Expected: PASS

**Step 5: Blue 重构**

- 收敛 app config 读取与校验逻辑。
- 清理 `api.rs` 里与 app config 无关的重复错误映射分支。

**Step 6: 复跑验证**

Run: `cargo test --test app_config_api_test`
Expected: PASS

**Step 7: Commit**

```bash
git add rust/src/api.rs rust/src/models/api_error.rs rust/tests/app_config_api_test.rs
git commit -m "feat(api): add app config initialization contract"
```

---

### Task 3: 将卡片与数据池 FRB API 改为无 storeId 契约

**Files:**
- Modify: `rust/src/api.rs`
- Modify: `lib/bridge_generated/api.dart`
- Modify: `lib/bridge_generated/frb_generated.dart`
- Modify: `rust/src/frb_generated.rs`
- Modify: `rust/tests/backend_api_contract_test.rs`
- Modify: `rust/tests/pool_note_attachment_test.rs`
- Modify: `test/bridge/flutter_rust_flow_smoke_test.dart`

**Step 1: 写失败测试**

```rust
#[test]
fn create_pool_and_card_apis_should_work_without_store_handle() {
    // init_app_config -> create_pool/create_card_note/list/get/update without store_id
}
```

```dart
test('flutter FRB flow should work after initAppConfig without storeId', () async {
  // initAppConfig -> createPool/createCardNoteInPool/listCardNotes/getPoolDetail
});
```

**Step 2: 运行测试确认 RED**

Run: `cargo test --test backend_api_contract_test --test pool_note_attachment_test && flutter test test/bridge/flutter_rust_flow_smoke_test.dart`
Expected: FAIL，因为现有 Rust/FRB 签名仍要求 `storeId`。

**Step 3: 最小实现无句柄 API**

```text
- Rust `create_pool`、`join_pool`、`list_pools`、`get_pool_detail`、`create_card_note`、`create_card_note_in_pool`、`update_card_note`、`list_card_notes`、`get_card_note_detail` 不再接收 `store_id`。
- 这些 API 统一从 app-level configured runtime 取依赖。
- 重新生成 FRB bridge，使 Dart 顶层 API 也不再带 `storeId`。
```

**Step 4: 运行测试确认 GREEN**

Run: `cargo test --test backend_api_contract_test --test pool_note_attachment_test && flutter test test/bridge/flutter_rust_flow_smoke_test.dart`
Expected: PASS

**Step 5: Blue 重构**

- 统一无句柄 API 的内部依赖获取入口。
- 清理生成代码周边已失效的参数顺序假设与旧注释。

**Step 6: 复跑验证**

Run: `cargo test --test backend_api_contract_test --test pool_note_attachment_test && flutter test test/bridge/flutter_rust_flow_smoke_test.dart`
Expected: PASS

**Step 7: Commit**

```bash
git add rust/src/api.rs rust/src/frb_generated.rs lib/bridge_generated/api.dart lib/bridge_generated/frb_generated.dart rust/tests/backend_api_contract_test.rs rust/tests/pool_note_attachment_test.rs test/bridge/flutter_rust_flow_smoke_test.dart
git commit -m "refactor(frb): remove store handle from product apis"
```

---

### Task 4: 删除 CardStore 与 Rust handle map 机制

**Files:**
- Modify: `rust/src/api.rs`
- Modify: `rust/src/store/card_store.rs`
- Modify: `rust/src/store/mod.rs`
- Modify: `rust/tests/api_handle_test.rs`

**Step 1: 写失败测试**

```rust
#[test]
fn app_config_should_replace_card_store_handle_lifecycle() {
    // init_app_config succeeds and there is no card store init/close lifecycle left in product API
}
```

**Step 2: 运行测试确认 RED**

Run: `cargo test --test api_handle_test`
Expected: FAIL，因为当前测试和主实现仍围绕 `init_card_store/close_card_store`。

**Step 3: 最小实现删除 handle 机制**

```text
- 删除 `CARD_STORE_SEQ`、`CARD_STORES`、`with_card_store(store_id, ...)` 等 handle map 机制。
- 删除或改写 `CardStore`，让其不再作为 Rust 主实现类型存在。
- 把句柄生命周期测试改为 app config 生命周期/幂等语义测试。
```

**Step 4: 运行测试确认 GREEN**

Run: `cargo test --test api_handle_test`
Expected: PASS

**Step 5: Blue 重构**

- 收敛 app runtime/config 内部帮助函数命名。
- 清理 `store/mod.rs` 中只服务旧 `CardStore` 暴露的导出。

**Step 6: 复跑验证**

Run: `cargo test --test api_handle_test`
Expected: PASS

**Step 7: Commit**

```bash
git add rust/src/api.rs rust/src/store/card_store.rs rust/src/store/mod.rs rust/tests/api_handle_test.rs
git commit -m "refactor(rust): remove card store handle runtime"
```

---

### Task 5: 更新 Dart API client 与应用启动组合到 initAppConfig

**Files:**
- Modify: `lib/features/cards/card_api_client.dart`
- Modify: `lib/features/pool/pool_api_client.dart`
- Modify: `lib/app/app.dart`
- Modify: `lib/main.dart`
- Test: `test/features/cards/cards_api_client_test.dart`
- Test: `test/features/pool/pool_api_client_test.dart`

**Step 1: 写失败测试**

```dart
test('frb card api client should call handle-free card APIs after app config', () async {
  // no storeId in client constructor or call path
});

test('frb pool api client should call handle-free pool APIs after app config', () async {
  // no storeId in client constructor or call path
});
```

**Step 2: 运行测试确认 RED**

Run: `flutter test test/features/cards/cards_api_client_test.dart test/features/pool/pool_api_client_test.dart`
Expected: FAIL，因为当前 FRB client 构造与调用仍绑定 `storeId`。

**Step 3: 最小实现 Dart 侧切换**

```text
- 移除 `FrbCardApiClient`、`FrbPoolApiClient` 的 `storeId` 构造参数。
- Flutter 启动阶段显式调用 `initAppConfig(appDataDir)`。
- 客户端直接调用无句柄资源 API。
```

**Step 4: 运行测试确认 GREEN**

Run: `flutter test test/features/cards/cards_api_client_test.dart test/features/pool/pool_api_client_test.dart`
Expected: PASS

**Step 5: Blue 重构**

- 收敛应用启动时的 app config 初始化入口，避免散落在页面中。
- 清理旧 `storeId` 注释与过时兼容说明。

**Step 6: 复跑验证**

Run: `flutter test test/features/cards/cards_api_client_test.dart test/features/pool/pool_api_client_test.dart`
Expected: PASS

**Step 7: Commit**

```bash
git add lib/features/cards/card_api_client.dart lib/features/pool/pool_api_client.dart lib/app/app.dart lib/main.dart test/features/cards/cards_api_client_test.dart test/features/pool/pool_api_client_test.dart
git commit -m "feat(app): initialize app config for handle-free frb clients"
```

---

### Task 6: 恢复主路径修补基线，确保页面组合不再依赖 handle 或兼容 client

**Files:**
- Modify: `lib/features/cards/cards_page.dart`
- Modify: `lib/features/pool/pool_page.dart`
- Modify: `lib/features/cards/cards_controller.dart`
- Modify: `lib/features/pool/pool_controller.dart`
- Test: `test/features/cards/cards_page_test.dart`
- Test: `test/features/pool/pool_page_test.dart`
- Test: `test/architecture/no_flutter_write_source_test.dart`

**Step 1: 写失败测试**

```dart
testWidgets('cards page production composition should use handle-free FRB client', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: CardsPage()));
  // verify no legacy client and no store handle composition
});

testWidgets('pool page production composition should use handle-free FRB client', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: PoolPage(state: PoolState.notJoined())));
  // verify no local client and no store handle composition
});
```

**Step 2: 运行测试确认 RED**

Run: `flutter test test/features/cards/cards_page_test.dart test/features/pool/pool_page_test.dart test/architecture/no_flutter_write_source_test.dart`
Expected: FAIL，因为当前页面默认组合仍未切到最终主路径。

**Step 3: 最小实现主路径修补续接**

```text
- CardsPage 默认组合层改为使用 handle-free `FrbCardApiClient`。
- PoolPage 默认组合层改为使用 handle-free `FrbPoolApiClient`。
- 控制器主路径不再依赖 local/legacy client，也不感知 app config 以外的 Rust 内部细节。
```

**Step 4: 运行测试确认 GREEN**

Run: `flutter test test/features/cards/cards_page_test.dart test/features/pool/pool_page_test.dart test/architecture/no_flutter_write_source_test.dart`
Expected: PASS

**Step 5: Blue 重构**

- 抽取页面到控制器的 FRB 组合入口。
- 删除主路径不再需要的兼容字段和残余本地接线。

**Step 6: 复跑验证**

Run: `flutter test test/features/cards/cards_page_test.dart test/features/pool/pool_page_test.dart test/architecture/no_flutter_write_source_test.dart`
Expected: PASS

**Step 7: Commit**

```bash
git add lib/features/cards/cards_page.dart lib/features/pool/pool_page.dart lib/features/cards/cards_controller.dart lib/features/pool/pool_controller.dart test/features/cards/cards_page_test.dart test/features/pool/pool_page_test.dart test/architecture/no_flutter_write_source_test.dart
git commit -m "feat(mainpath): resume frb production composition without handles"
```

---

### Task 7: 全量验证并收尾当前修订基线

**Files:**
- Modify: `docs/plans/DIR.md`（如需补充索引）
- Reference: `docs/plans/2026-03-15-remove-cardstore-handle-design.md`

**Step 1: 写失败检查清单**

```text
- bridge/generated API 中不再出现产品路径 `storeId`
- Rust 主实现不再存在 `CardStore`
- Flutter 页面/控制器不再出现 `storeId`
- cards/pools/sync 主链路测试通过
```

**Step 2: 运行全量验证确认当前状态**

Run: `flutter test && cargo test`
Expected: 若仍有遗漏，FAIL 并暴露剩余依赖点。

**Step 3: 最小补齐遗漏**

```text
- 修复残余 handle 术语、生成绑定遗漏、测试假设未更新之处。
- 保持改动只围绕 handle 去除与主路径对齐，不顺手扩功能。
```

**Step 4: 运行全量验证确认 GREEN**

Run: `flutter test && cargo test`
Expected: PASS

**Step 5: Blue 重构**

- 统一注释、文件头和目录索引中的旧 handle 表述。
- 清理已无意义的兼容残留与过时文档引用。

**Step 6: 复跑验证**

Run: `dart run tool/quality.dart all`
Expected: PASS

**Step 7: Commit**

```bash
git add .
git commit -m "refactor(runtime): remove card store handle boundary"
```
