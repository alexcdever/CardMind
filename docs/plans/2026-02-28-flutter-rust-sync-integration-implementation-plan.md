input: Flutter-Rust 同步网络对接目标、架构与实施任务
output: 可执行的对接步骤与验证命令
pos: Flutter-Rust 同步网络对接实施计划（修改需同步 DIR.md）
# Flutter-Rust 同步网络对接 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 以同步网络优先方式完成 Flutter 与 Rust 的生产级对接，确保全平台下功能可用、错误可恢复、测试可维护。  
**Architecture:** Rust 在 `rust/src/net/*` 提供网络能力并由 `rust/src/api.rs` 统一对外；FRB 作为唯一跨语言边界；Flutter 通过 `SyncService`（facade 职责）+ `SyncController` + `SyncState` 驱动 UI，避免页面直接依赖 FRB。  
**Tech Stack:** Flutter、Dart、Rust、flutter_rust_bridge、tokio、flutter test、cargo test。

## 强制执行规则（TDD 红-绿-蓝）

- 本计划每个任务必须按 **Red -> Green -> Blue -> Commit** 执行。
- Red：先编写或调整失败测试，并运行确认按预期失败。
- Green：以最小实现使测试通过，并运行确认通过。
- Blue：在不改变行为前提下重构，复跑同一批测试后再继续。
- 仅当 Blue 阶段验证通过后才允许提交。

---

### Task 1: 固化 Rust 同步 API 合同与失败测试

**Files:**
- Modify: `rust/src/api.rs`
- Modify: `rust/src/models/api_error.rs`
- Create: `rust/tests/sync_api_contract_test.rs`

**Step 1: 写失败测试（同步 API 语义与错误结构）**

```rust
// rust/tests/sync_api_contract_test.rs
use cardmind_rust::api::*;

#[test]
fn sync_status_should_return_structured_error_when_handle_invalid() {
    let invalid = 999_999_u64;
    let result = sync_status(invalid);
    assert!(result.is_err());
    let err = result.err().unwrap();
    assert!(!err.code.is_empty());
    assert!(!err.message.is_empty());
}
```

**Step 2: 运行测试确认失败**

Run: `cargo test --test sync_api_contract_test`  
Expected: FAIL（`sync_status` 等接口尚未实现）

**Step 3: 在 `rust/src/api.rs` 声明同步接口与统一错误返回**

```rust
pub fn sync_status(network_id: u64) -> Result<SyncStatusDto, ApiError> {
    // 先返回 handle 校验错误，最小实现保证合同稳定
}
```

**Step 4: 在 `rust/src/models/api_error.rs` 补齐本阶段需要的错误码常量**

```rust
ApiErrorCode::NetworkUnavailable
ApiErrorCode::SyncTimeout
ApiErrorCode::InvalidHandle
```

**Step 5: 再跑测试确认通过**

Run: `cargo test --test sync_api_contract_test`  
Expected: PASS

**Step 6: Commit**

```bash
git add rust/src/api.rs rust/src/models/api_error.rs rust/tests/sync_api_contract_test.rs
git commit -m "feat(sync): define rust sync api contracts"
```

---

### Task 2: 实现 Rust 同步主链路接口最小可用版本

**Files:**
- Modify: `rust/src/api.rs`
- Modify: `rust/src/net/pool_network.rs`
- Modify: `rust/src/net/session.rs`
- Create: `rust/tests/sync_api_flow_test.rs`

**Step 1: 写失败测试（connect/join/push/pull/disconnect）**

```rust
#[test]
fn sync_flow_should_move_to_connected_and_back_to_idle() {
    // init -> connect -> disconnect
    // 断言状态迁移与错误码语义
}
```

**Step 2: 运行测试确认失败**

Run: `cargo test --test sync_api_flow_test`  
Expected: FAIL（流程接口尚未串通）

**Step 3: 最小实现 connect/disconnect/status 路径**

```rust
pub fn sync_connect(network_id: u64, target: String) -> Result<(), ApiError> { /* ... */ }
pub fn sync_disconnect(network_id: u64) -> Result<(), ApiError> { /* ... */ }
pub fn sync_status(network_id: u64) -> Result<SyncStatusDto, ApiError> { /* ... */ }
```

**Step 4: 最小实现 join/push/pull 路径与超时映射**

```rust
pub fn sync_join_pool(...) -> Result<(), ApiError> { /* ... */ }
pub fn sync_push(...) -> Result<SyncResultDto, ApiError> { /* ... */ }
pub fn sync_pull(...) -> Result<SyncResultDto, ApiError> { /* ... */ }
```

**Step 5: 跑测试确认通过**

Run: `cargo test --test sync_api_flow_test`  
Expected: PASS

**Step 6: Commit**

```bash
git add rust/src/api.rs rust/src/net/pool_network.rs rust/src/net/session.rs rust/tests/sync_api_flow_test.rs
git commit -m "feat(sync): implement minimal rust sync flow apis"
```

---

### Task 3: 生成并校验 FRB 桥接接口

**Files:**
- Modify: `rust/src/api.rs`
- Modify (generated): `lib/bridge_generated/api.dart`
- Modify (generated): `lib/bridge_generated/frb_generated.dart`
- Modify (generated): `lib/bridge_generated/frb_generated.io.dart`

**Step 1: 写失败校验（Dart 侧必须能看到新增 API）**

```dart
// test/bridge/sync_bridge_api_smoke_test.dart
test('generated bridge should expose sync APIs', () {
  expect(initPoolNetwork, isNotNull);
  expect(syncConnect, isNotNull);
  expect(syncStatus, isNotNull);
});
```

**Step 2: 运行测试确认失败**

Run: `flutter test test/bridge/sync_bridge_api_smoke_test.dart`  
Expected: FAIL（桥接尚未生成）

**Step 3: 运行 FRB 代码生成**

Run: `flutter_rust_bridge_codegen generate`

**Step 4: 再跑测试确认通过**

Run: `flutter test test/bridge/sync_bridge_api_smoke_test.dart`  
Expected: PASS

**Step 5: Commit**

```bash
git add rust/src/api.rs lib/bridge_generated test/bridge/sync_bridge_api_smoke_test.dart
git commit -m "chore(frb): generate sync bridge apis"
```

---

### Task 4: 建立 Flutter 同步域（SyncService/Controller/State）

**Files:**
- Create: `lib/features/sync/sync_service.dart`
- Create: `lib/features/sync/sync_controller.dart`
- Modify: `lib/features/sync/sync_status.dart`
- Create: `test/features/sync/sync_controller_test.dart`

**Step 1: 写失败测试（状态迁移与错误映射）**

```dart
test('retry after error should move to connecting then connected', () async {
  // fake service 返回 error 再 success
});
```

**Step 2: 运行测试确认失败**

Run: `flutter test test/features/sync/sync_controller_test.dart`  
Expected: FAIL（`SyncService/SyncController` 尚不存在）

**Step 3: 最小实现 `SyncStatus` 状态集**

```dart
enum SyncStatusKind { idle, connecting, connected, syncing, degraded, error }
```

**Step 4: 最小实现 `SyncService`（facade 职责）与 `SyncController`**

```dart
class SyncService { /* frb 调用 + code 映射 */ }
class SyncController extends ChangeNotifier { /* action -> state */ }
```

**Step 5: 跑测试确认通过**

Run: `flutter test test/features/sync/sync_controller_test.dart`  
Expected: PASS

**Step 6: Commit**

```bash
git add lib/features/sync/sync_service.dart lib/features/sync/sync_controller.dart lib/features/sync/sync_status.dart test/features/sync/sync_controller_test.dart
git commit -m "feat(sync): add flutter sync domain facade and controller"
```

---

### Task 5: 接入页面交互并补齐 UI 组件/交互测试

**Files:**
- Modify: `lib/features/pool/pool_page.dart`
- Modify: `lib/features/sync/sync_banner.dart`
- Modify: `lib/features/pool/pool_controller.dart`
- Create: `test/features/sync/sync_banner_test.dart`
- Create: `test/features/pool/pool_sync_interaction_test.dart`

**Step 1: 写失败测试（错误态可恢复动作）**

```dart
testWidgets('sync error should show retry and reconnect actions', (tester) async {
  // 断言按钮可点击且触发 controller action
});
```

**Step 2: 运行测试确认失败**

Run: `flutter test test/features/sync/sync_banner_test.dart test/features/pool/pool_sync_interaction_test.dart`  
Expected: FAIL

**Step 3: 实现页面接线与反馈规则**

```dart
// pool_page.dart: 注入 SyncController 状态
// sync_banner.dart: error/degraded 的文案 + retry/reconnect
```

**Step 4: 再跑测试确认通过**

Run: `flutter test test/features/sync/sync_banner_test.dart test/features/pool/pool_sync_interaction_test.dart`  
Expected: PASS

**Step 5: 跑交互守卫测试**

Run: `flutter test test/interaction_guard_test.dart`  
Expected: PASS（无空交互、无无说明禁用交互）

**Step 6: Commit**

```bash
git add lib/features/pool/pool_page.dart lib/features/sync/sync_banner.dart lib/features/pool/pool_controller.dart test/features/sync/sync_banner_test.dart test/features/pool/pool_sync_interaction_test.dart
git commit -m "feat(sync-ui): wire sync states and recovery interactions"
```

---

### Task 6: 文档治理对齐与全量门禁验证

**Files:**
- Modify: `docs/plans/2026-02-27-ui-interaction-governance-design.md`
- Modify: `docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md`
- Modify: `docs/plans/2026-02-27-ui-interaction-release-gate.md`
- Modify: `docs/plans/DIR.md`

**Step 1: 更新治理文档三件套（同步交互新增项）**

```markdown
- 同步错误态必须提供 retry/reconnect。
- degraded 状态不阻断本地操作。
```

**Step 2: 更新 `docs/plans/DIR.md` 索引**

```markdown
- 2026-02-28-flutter-rust-sync-integration-design.md
- 2026-02-28-flutter-rust-sync-integration-implementation-plan.md
```

**Step 3: 跑文档治理测试**

Run: `flutter test test/ui_interaction_governance_docs_test.dart`  
Expected: PASS

**Step 4: 跑全量门禁**

Run: `flutter analyze && flutter test && cargo test`  
Expected: PASS

**Step 5: Commit**

```bash
git add docs/plans/2026-02-27-ui-interaction-governance-design.md docs/plans/2026-02-27-ui-interaction-acceptance-matrix.md docs/plans/2026-02-27-ui-interaction-release-gate.md docs/plans/DIR.md
git commit -m "docs(governance): align sync integration interaction gates"
```
