input: 已批准的 Flutter/Rust 前后端分层设计与 architecture 规格约束
output: Flutter 作为前端、Rust 作为后端且遵循 LoroDoc/SQLite 读写分离的任务化实施计划
pos: Flutter-Rust 嵌入式前后端打通实施计划，执行前需先读 architecture spec 与对应设计稿
# Flutter Rust Embedded Backend Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 打通 Flutter 与 Rust 的前后端调用链，并落实 `LoroDoc` 写真源、`SQLite` 读模型、投影收敛与显式同步的第一阶段业务闭环。 

**Architecture:** 以 `docs/specs/architecture.md` 为上位约束：Flutter 只负责 UI、交互编排、展示状态与后端调用；Rust 负责业务规则、业务写入、投影驱动、同步与稳定 DTO/错误契约。所有业务写入先进入 `LoroDoc`，查询只经 `SQLite`，`LoroDoc` 变更通过投影链路更新读模型。 

**Tech Stack:** Flutter、Dart、Rust、flutter_rust_bridge、LoroDoc、SQLite、Markdown docs、`flutter test`、`cargo test`。

---

## 执行规则（强制）

1. 实现前先阅读 `docs/specs/architecture.md`、`docs/specs/shared-domain-contract.md`、`docs/specs/pool.md`、`docs/specs/card-note.md` 与 `docs/plans/2026-03-09-flutter-rust-backend-frontend-design.md`。
2. 每个任务都必须遵循 `Red -> Green -> Blue -> Commit`。
3. 所有业务写入必须先进入 Rust，再写入 `LoroDoc`；绕过 Rust 的 Flutter 写主路径为 FORBIDDEN。
4. 所有产品查询必须走 `SQLite` 读模型；把 `LoroDoc` 当产品查询主路径为 FORBIDDEN。
5. `SQLite` 投影失败与同步失败都不得伪装成业务写失败。
6. 如果某段 Flutter 旧路径确实需要短期兼容，必须用中文注释明确声明其临时性、替代路径与删除意图。

## Worktree Requirement

执行 Task 1 之前：

1. 在 `.worktrees/` 下创建独立 worktree。
2. 推荐分支名：`flutter-rust-embedded-backend`。
3. 确认当前文档与代码基线一致后再开始编辑。

Run:

```bash
git worktree add ".worktrees/flutter-rust-embedded-backend" -b "flutter-rust-embedded-backend"
git status --short
```

Expected: worktree 创建成功，且新工作目录状态可控。

---

### Task 1: 固化 Rust 读写分离契约测试

**Files:**
- Test: `rust/tests/store_architecture_contract_test.rs`
- Modify: `rust/src/store/card_store.rs`
- Modify: `rust/src/store/pool_store.rs`
- Modify: `rust/src/store/sqlite_store.rs`
- Reference: `docs/specs/architecture.md`

**Step 1: 写失败测试（先写 Loro，再由查询走 SQLite）**

```rust
use cardmind_rust::store::card_store::CardStore;

#[test]
fn create_card_should_be_observable_via_sqlite_query_after_projection() {
    let dir = tempfile::tempdir().unwrap();
    let store = CardStore::new(dir.path().to_str().unwrap()).unwrap();

    let card = store.create_card("title", "body").unwrap();
    let queried = store.get_card(&card.id).unwrap();

    assert_eq!(queried.id, card.id);
    assert_eq!(queried.title, "title");
}

#[test]
fn update_card_should_write_business_fact_before_query_refresh() {
    let dir = tempfile::tempdir().unwrap();
    let store = CardStore::new(dir.path().to_str().unwrap()).unwrap();

    let card = store.create_card("before", "body").unwrap();
    let updated = store.update_card(&card.id, "after", "body2").unwrap();
    let queried = store.get_card(&card.id).unwrap();

    assert_eq!(updated.title, "after");
    assert_eq!(queried.title, "after");
}
```

**Step 2: 运行测试确认 RED**

Run: `cargo test --test store_architecture_contract_test`  
Expected: FAIL，当前测试文件不存在或行为尚未显式覆盖架构约束。

**Step 3: 最小实现/整理写入路径约束**

需要达到的最小结果：

```text
- CardStore/PoolStore 的写路径语义明确为：先写 LoroDoc，再更新 SQLite 投影。
- 读路径继续通过 SQLite 返回结果。
- 文件头或必要注释与真实职责保持一致，不再把 SQLite 表述成写真源。
```

**Step 4: 运行测试确认 GREEN**

Run: `cargo test --test store_architecture_contract_test`  
Expected: PASS

**Step 5: Blue 重构**

- 抽取重复的“写 Loro -> 更新 SQLite”辅助逻辑。
- 清理会误导为“双写真源”的命名或注释。

**Step 6: 复跑验证**

Run: `cargo test --test store_architecture_contract_test`  
Expected: PASS

**Step 7: Commit**

```bash
git add rust/tests/store_architecture_contract_test.rs rust/src/store/card_store.rs rust/src/store/pool_store.rs rust/src/store/sqlite_store.rs
git commit -m "test(store): lock write-read split contracts"
```

---

### Task 2: 建立 Rust 投影驱动与投影失败语义

**Files:**
- Create: `rust/tests/projection_flow_test.rs`
- Modify: `rust/src/store/card_store.rs`
- Modify: `rust/src/store/pool_store.rs`
- Modify: `rust/src/store/sqlite_store.rs`
- Modify: `rust/src/models/error.rs`

**Step 1: 写失败测试（业务成功与投影失败分离）**

```rust
#[test]
fn projection_failure_should_not_disguise_business_write_success() {
    // 准备一个可注入 projection 失败的 store
    // 断言：Loro 写入已成功，查询侧暂未收敛，返回可恢复失败语义
}
```

**Step 2: 运行测试确认 RED**

Run: `cargo test --test projection_flow_test`  
Expected: FAIL

**Step 3: 最小实现投影状态分离**

```text
- 引入可表达 projection 未收敛/失败的稳定错误或状态语义。
- Rust 内部把业务写成功与 SQLite 投影失败分开处理。
- 不回滚已成功的 Loro 写入。
```

**Step 4: 运行测试确认 GREEN**

Run: `cargo test --test projection_flow_test`  
Expected: PASS

**Step 5: Blue 重构**

- 收敛 projection 相关错误映射。
- 清理重复状态判断。

**Step 6: 复跑验证**

Run: `cargo test --test projection_flow_test`  
Expected: PASS

**Step 7: Commit**

```bash
git add rust/tests/projection_flow_test.rs rust/src/store/card_store.rs rust/src/store/pool_store.rs rust/src/store/sqlite_store.rs rust/src/models/error.rs
git commit -m "feat(store): separate projection failure from write success"
```

---

### Task 3: 扩展 Rust API 为面向用例的稳定后端契约

**Files:**
- Modify: `rust/src/api.rs`
- Modify: `rust/src/models/api_error.rs`
- Create: `rust/tests/backend_api_contract_test.rs`
- Reference: `docs/specs/architecture.md`
- Reference: `docs/specs/pool.md`
- Reference: `docs/specs/card-note.md`

**Step 1: 写失败测试（后端用例 API 契约）**

```rust
#[test]
fn create_pool_should_return_stable_pool_dto() {
    // 调用 create_pool 用例 API
    // 断言返回 dto 字段稳定可用
}

#[test]
fn create_card_note_should_return_stable_card_dto() {
    // 调用 create_card_note 用例 API
    // 断言返回 dto 字段稳定可用
}
```

**Step 2: 运行测试确认 RED**

Run: `cargo test --test backend_api_contract_test`  
Expected: FAIL，相关 API/DTO 尚未完整存在。

**Step 3: 最小实现后端用例 API**

```text
- 添加或收敛 createPool / joinPool / listPools / getPoolDetail。
- 添加或收敛 createCardNote / updateCardNote / listCardNotes / getCardNoteDetail。
- 返回稳定 DTO 与稳定错误码，不泄露内部存储细节。
```

**Step 4: 运行测试确认 GREEN**

Run: `cargo test --test backend_api_contract_test`  
Expected: PASS

**Step 5: Blue 重构**

- 合并重复 DTO 映射逻辑。
- 清理基于异常文本的错误判断。

**Step 6: 复跑验证**

Run: `cargo test --test backend_api_contract_test`  
Expected: PASS

**Step 7: Commit**

```bash
git add rust/tests/backend_api_contract_test.rs rust/src/api.rs rust/src/models/api_error.rs
git commit -m "feat(api): add stable backend use case contracts"
```

---

### Task 4: 实现加入池自动挂接已有笔记与创建笔记自动挂接新引用

**Files:**
- Create: `rust/tests/pool_note_attachment_test.rs`
- Modify: `rust/src/store/pool_store.rs`
- Modify: `rust/src/store/card_store.rs`
- Modify: `rust/src/api.rs`

**Step 1: 写失败测试（自动挂接规则）**

```rust
#[test]
fn join_pool_should_attach_existing_notes_including_soft_deleted() {
    // 创建多张笔记，其中至少一张已软删除
    // join 后断言 pool metadata 包含全部 noteId
}

#[test]
fn update_card_should_not_create_duplicate_note_reference() {
    // 创建卡片并挂接
    // 更新卡片后断言 noteId 集合没有重复
}
```

**Step 2: 运行测试确认 RED**

Run: `cargo test --test pool_note_attachment_test`  
Expected: FAIL

**Step 3: 最小实现自动挂接规则**

```text
- join pool 时自动收集本地已有 noteId（含软删除）。
- create card in pool context 时新增引用。
- update/delete/restore 不新增重复引用。
```

**Step 4: 运行测试确认 GREEN**

Run: `cargo test --test pool_note_attachment_test`  
Expected: PASS

**Step 5: Blue 重构**

- 抽取 note reference set 维护逻辑。
- 清理重复集合去重代码。

**Step 6: 复跑验证**

Run: `cargo test --test pool_note_attachment_test`  
Expected: PASS

**Step 7: Commit**

```bash
git add rust/tests/pool_note_attachment_test.rs rust/src/store/pool_store.rs rust/src/store/card_store.rs rust/src/api.rs
git commit -m "feat(pool): enforce note attachment rules"
```

---

### Task 5: 生成并校验 FRB 后端 API 暴露

**Files:**
- Modify: `rust/src/api.rs`
- Modify (generated): `lib/bridge_generated/api.dart`
- Modify (generated): `lib/bridge_generated/frb_generated.dart`
- Modify (generated): `lib/bridge_generated/frb_generated.io.dart`
- Create: `test/bridge/backend_api_smoke_test.dart`

**Step 1: 写失败测试（Flutter 能看到新增后端 API）**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cardmind/bridge_generated/api.dart' as frb;

void main() {
  test('generated bridge should expose backend use case apis', () {
    expect(frb.createPool, isNotNull);
    expect(frb.createCardNote, isNotNull);
    expect(frb.listCardNotes, isNotNull);
  });
}
```

**Step 2: 运行测试确认 RED**

Run: `flutter test test/bridge/backend_api_smoke_test.dart`  
Expected: FAIL

**Step 3: 生成 FRB 并最小修正暴露面**

Run: `flutter_rust_bridge_codegen generate`

**Step 4: 运行测试确认 GREEN**

Run: `flutter test test/bridge/backend_api_smoke_test.dart`  
Expected: PASS

**Step 5: Blue 重构**

- 清理未使用生成物引用。
- 确认命名与后端 API 语义一致。

**Step 6: 复跑验证**

Run: `flutter test test/bridge/backend_api_smoke_test.dart`  
Expected: PASS

**Step 7: Commit**

```bash
git add rust/src/api.rs lib/bridge_generated test/bridge/backend_api_smoke_test.dart
git commit -m "chore(frb): generate backend use case apis"
```

---

### Task 6: 建立 Flutter ApiClient 层并切断直接写入主路径

**Files:**
- Create: `lib/features/cards/card_api_client.dart`
- Create: `lib/features/pool/pool_api_client.dart`
- Create: `lib/features/sync/sync_api_client.dart`
- Modify: `lib/features/cards/cards_controller.dart`
- Modify: `lib/features/pool/pool_controller.dart`
- Create: `test/features/cards/cards_api_client_test.dart`
- Create: `test/features/pool/pool_api_client_test.dart`

**Step 1: 写失败测试（Flutter 只通过 ApiClient 调后端）**

```dart
test('cards controller should create through api client then reload query', () async {
  // fake api client
  // 断言 controller 不再直接调用 write repository
});
```

**Step 2: 运行测试确认 RED**

Run: `flutter test test/features/cards/cards_api_client_test.dart test/features/pool/pool_api_client_test.dart`  
Expected: FAIL

**Step 3: 最小实现 ApiClient 与控制器改接**

```text
- 为 cards/pool/sync 提供薄 ApiClient。
- CardsController/PoolController 改为调 ApiClient + 查询刷新。
- 若必须短期保留旧路径，添加中文临时兼容注释。
```

**Step 4: 运行测试确认 GREEN**

Run: `flutter test test/features/cards/cards_api_client_test.dart test/features/pool/pool_api_client_test.dart`  
Expected: PASS

**Step 5: Blue 重构**

- 删除主流程上不再需要的直接写仓依赖。
- 抽取共用的错误码到用户提示映射。

**Step 6: 复跑验证**

Run: `flutter test test/features/cards/cards_api_client_test.dart test/features/pool/pool_api_client_test.dart`  
Expected: PASS

**Step 7: Commit**

```bash
git add lib/features/cards/card_api_client.dart lib/features/pool/pool_api_client.dart lib/features/sync/sync_api_client.dart lib/features/cards/cards_controller.dart lib/features/pool/pool_controller.dart test/features/cards/cards_api_client_test.dart test/features/pool/pool_api_client_test.dart
git commit -m "feat(flutter): route page actions through api clients"
```

---

### Task 7: 让 Flutter 查询只走 SQLite 读模型结果

**Files:**
- Modify: `lib/features/cards/data/sqlite_cards_read_repository.dart`
- Modify: `lib/features/pool/data/sqlite_pool_read_repository.dart`
- Modify: `lib/features/shared/data/app_database.dart`
- Modify: `lib/features/shared/projection/loro_projection_worker.dart`
- Create: `test/features/read_model/query_path_test.dart`

**Step 1: 写失败测试（查询路径只走读模型）**

```dart
test('card and pool queries should be served from sqlite read model only', () async {
  // 通过投影写入数据
  // 断言查询仓只返回读模型结果
});
```

**Step 2: 运行测试确认 RED**

Run: `flutter test test/features/read_model/query_path_test.dart`  
Expected: FAIL

**Step 3: 最小实现/收敛查询路径**

```text
- 继续使用 SQLite 读仓作为 Flutter 查询主路径。
- 清理或封住会绕过读模型的查询入口。
- 明确 projection worker 负责把写侧变化投影到查询侧。
```

**Step 4: 运行测试确认 GREEN**

Run: `flutter test test/features/read_model/query_path_test.dart`  
Expected: PASS

**Step 5: Blue 重构**

- 清理重复查询辅助逻辑。
- 修正误导性注释与命名。

**Step 6: 复跑验证**

Run: `flutter test test/features/read_model/query_path_test.dart`  
Expected: PASS

**Step 7: Commit**

```bash
git add lib/features/cards/data/sqlite_cards_read_repository.dart lib/features/pool/data/sqlite_pool_read_repository.dart lib/features/shared/data/app_database.dart lib/features/shared/projection/loro_projection_worker.dart test/features/read_model/query_path_test.dart
git commit -m "refactor(query): keep flutter reads on sqlite model"
```

---

### Task 8: 实现显式同步与“已保存但未同步/未投影”状态表达

**Files:**
- Modify: `lib/features/sync/sync_service.dart`
- Modify: `lib/features/sync/sync_controller.dart`
- Modify: `lib/features/sync/sync_status.dart`
- Create: `test/features/sync/sync_state_semantics_test.dart`
- Modify: `rust/src/api.rs`
- Modify: `rust/tests/sync_api_flow_test.rs`

**Step 1: 写失败测试（三类状态分离）**

```dart
test('frontend should distinguish write success projection pending and sync failure', () async {
  // fake backend responses
  // 断言状态不被混淆
});
```

**Step 2: 运行测试确认 RED**

Run: `flutter test test/features/sync/sync_state_semantics_test.dart && cargo test --test sync_api_flow_test`  
Expected: FAIL

**Step 3: 最小实现状态语义**

```text
- SyncStatus/DTO 至少能区分：业务写成功、投影未收敛、同步失败。
- Flutter 能映射为用户可理解的恢复动作。
- Rust API 返回稳定状态语义。
```

**Step 4: 运行测试确认 GREEN**

Run: `flutter test test/features/sync/sync_state_semantics_test.dart && cargo test --test sync_api_flow_test`  
Expected: PASS

**Step 5: Blue 重构**

- 合并重复状态转换逻辑。
- 清理基于文本字符串的脆弱判断。

**Step 6: 复跑验证**

Run: `flutter test test/features/sync/sync_state_semantics_test.dart && cargo test --test sync_api_flow_test`  
Expected: PASS

**Step 7: Commit**

```bash
git add lib/features/sync/sync_service.dart lib/features/sync/sync_controller.dart lib/features/sync/sync_status.dart test/features/sync/sync_state_semantics_test.dart rust/src/api.rs rust/tests/sync_api_flow_test.rs
git commit -m "feat(sync): separate write projection and sync states"
```

---

### Task 9: 走通跨语言主链路烟测

**Files:**
- Create: `test/bridge/flutter_rust_flow_smoke_test.dart`
- Reference: `rust/src/api.rs`
- Reference: `lib/bridge_generated/api.dart`

**Step 1: 写失败测试（创建池、创建笔记、查询、同步）**

```dart
test('flutter should complete pool-card-sync smoke flow through frb', () async {
  // init backend
  // create pool
  // create card
  // run sync
  // query via read model api
});
```

**Step 2: 运行测试确认 RED**

Run: `flutter test test/bridge/flutter_rust_flow_smoke_test.dart`  
Expected: FAIL

**Step 3: 最小补齐桥接缺口**

```text
- 修补 FRB 参数、DTO 或初始化链路缺口。
- 保证 smoke flow 能穿过真实 Rust 后端与查询 API。
```

**Step 4: 运行测试确认 GREEN**

Run: `flutter test test/bridge/flutter_rust_flow_smoke_test.dart`  
Expected: PASS

**Step 5: Blue 重构**

- 减少测试样板与重复初始化代码。

**Step 6: 复跑验证**

Run: `flutter test test/bridge/flutter_rust_flow_smoke_test.dart`  
Expected: PASS

**Step 7: Commit**

```bash
git add test/bridge/flutter_rust_flow_smoke_test.dart
git commit -m "test(bridge): verify flutter rust smoke flow"
```

---

### Task 10: 删除或标注 Flutter 旧写真源主路径

**Files:**
- Modify/Delete: `lib/features/cards/data/cards_write_repository.dart`
- Modify/Delete: `lib/features/pool/data/pool_write_repository.dart`
- Modify/Delete: `lib/features/shared/storage/*.dart`
- Modify/Delete: `lib/features/*/application/*.dart`
- Create: `test/architecture/no_flutter_write_source_test.dart`

**Step 1: 写失败测试/检查（前端不再作为写真源）**

```dart
test('main page flows should not depend on flutter-side business write source', () {
  // 断言主流程依赖图不再要求旧写仓
});
```

**Step 2: 运行测试确认 RED**

Run: `flutter test test/architecture/no_flutter_write_source_test.dart`  
Expected: FAIL

**Step 3: 最小实现删除或临时兼容标注**

```text
- 删除已不再被主流程依赖的 Flutter 旧写真源代码。
- 对确实一时删不掉但仍存在的兼容代码，添加明确中文注释：临时兼容、替代路径、后续必须删除。
```

**Step 4: 运行测试确认 GREEN**

Run: `flutter test test/architecture/no_flutter_write_source_test.dart`  
Expected: PASS

**Step 5: Blue 重构**

- 清理未使用依赖与导入。
- 更新注释与命名保持真实。

**Step 6: 复跑验证**

Run: `flutter test test/architecture/no_flutter_write_source_test.dart`  
Expected: PASS

**Step 7: Commit**

```bash
git add lib/features/cards/data lib/features/pool/data lib/features/shared/storage lib/features/*/application test/architecture/no_flutter_write_source_test.dart
git commit -m "refactor(flutter): remove legacy write source paths"
```

---

### Task 11: 跑全量门禁并收尾

**Files:**
- Reference: `tool/quality.dart`
- Reference: `docs/specs/architecture.md`
- Reference: `docs/plans/2026-03-09-flutter-rust-backend-frontend-design.md`

**Step 1: 运行 Flutter 质量门禁**

Run: `dart run tool/quality.dart flutter`  
Expected: PASS

**Step 2: 运行 Rust 质量门禁**

Run: `dart run tool/quality.dart rust`  
Expected: PASS

**Step 3: 运行关键桥接与交互补充测试**

Run: `flutter test test/bridge/backend_api_smoke_test.dart test/bridge/flutter_rust_flow_smoke_test.dart test/interaction_guard_test.dart`  
Expected: PASS

**Step 4: Blue 收尾**

- 删除临时调试代码。
- 确认所有临时兼容注释仍然真实且没有继续扩散。

**Step 5: 最终 Commit**

```bash
git add .
git commit -m "feat: complete flutter rust embedded backend flow"
```
