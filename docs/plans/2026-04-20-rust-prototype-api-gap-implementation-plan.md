# Rust Prototype API Gap Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 仅在 Rust 层新增最小一组展示型 API，补齐 Pencil 原型中成员运行态、池级统计和邀请管理的后端缺口。

**Architecture:** 保持现有 `PoolDto / PoolDetailDto / PoolMemberDto` 职责不变，在 `api/mod.rs` 新增独立运行态 DTO 和 FFI 门面；由 `pool_network.rs` 提供最小连接 / 活跃状态信号，由 `pool_store.rs` 提供 invite 持久化和列表视图；通过独立测试锁定状态语义与邀请闭环，不扩展到 Flutter、FRB 或成员管理。

**Tech Stack:** Rust、iroh、serde、现有 PoolStore / CardNoteRepository / PoolNetwork、cargo test、Markdown

---

## File Structure

- Create: `rust/src/models/pool_runtime.rs`
  - 定义内部运行态模型和状态枚举，避免继续膨胀 `models/pool.rs`
- Modify: `rust/src/models/mod.rs`
  - 导出新增 `pool_runtime` 模块
- Modify: `rust/src/api/mod.rs`
  - 新增 DTO、序列化映射和 4 个 FFI API 门面函数
- Modify: `rust/src/net/pool_network.rs`
  - 增加最小运行态采集能力：最近活跃时间、连接 alive 判断、同步中状态读取
- Modify: `rust/src/store/pool_store.rs`
  - 增加 invite 持久化、列表和撤销能力
- Test: `rust/tests/unit/api_runtime_view_test.rs`
  - 锁定 DTO 映射与状态归一化
- Test: `rust/tests/unit/pool_invite_store_test.rs`
  - 锁定 invite 创建 / 列表 / 撤销闭环
- Test: `rust/tests/integration/api_runtime_view_integration_test.rs`
  - 锁定 API 层运行态视图与 summary 结果

---

## Chunk 1: Define Runtime Models And Invite Storage

### Task 1: Add runtime model module

**Files:**
- Create: `rust/src/models/pool_runtime.rs`
- Modify: `rust/src/models/mod.rs`
- Test: `rust/tests/unit/api_runtime_view_test.rs`

- [ ] **Step 1: Write the failing unit test**

Add tests covering:

```rust
#[test]
fn member_runtime_status_should_render_connected_syncing_offline() {}

#[test]
fn current_device_flag_should_be_true_only_for_matching_endpoint() {}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cargo test api_runtime_view_test -- --nocapture`
Expected: FAIL with missing module / missing type definitions

- [ ] **Step 3: Write minimal implementation**

Create `rust/src/models/pool_runtime.rs` with:

- `MemberRuntimeStatus`
- `PoolMemberRuntime`
- `PoolRuntimeSummary`

Update `rust/src/models/mod.rs` to export the new module.

- [ ] **Step 4: Run test to verify it passes**

Run: `cargo test api_runtime_view_test -- --nocapture`
Expected: PASS or reduced failure surface to remaining unmapped API code

- [ ] **Step 5: Commit**

```bash
git add rust/src/models/pool_runtime.rs rust/src/models/mod.rs rust/tests/unit/api_runtime_view_test.rs
git commit -m "feat: add pool runtime models"
```

### Task 2: Add invite persistence primitives

**Files:**
- Modify: `rust/src/store/pool_store.rs`
- Test: `rust/tests/unit/pool_invite_store_test.rs`

- [ ] **Step 1: Write the failing unit test**

Add tests covering:

```rust
#[test]
fn active_invites_should_include_newly_created_invite() {}

#[test]
fn revoked_invite_should_not_appear_in_active_invites() {}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cargo test pool_invite_store_test -- --nocapture`
Expected: FAIL with missing invite list / revoke methods

- [ ] **Step 3: Write minimal implementation**

Extend `PoolStore` to support:

- persist invite metadata
- list active invites
- revoke invite

Keep implementation local to `pool_store.rs`; do not add a new service layer.

- [ ] **Step 4: Run test to verify it passes**

Run: `cargo test pool_invite_store_test -- --nocapture`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add rust/src/store/pool_store.rs rust/tests/unit/pool_invite_store_test.rs
git commit -m "feat: add pool invite persistence"
```

---

## Chunk 2: Expose Runtime Signals From PoolNetwork

### Task 3: Add minimal runtime signal accessors in PoolNetwork

**Files:**
- Modify: `rust/src/net/pool_network.rs`
- Test: `rust/tests/unit/api_runtime_view_test.rs`

- [ ] **Step 1: Write the failing test**

Add tests covering:

```rust
#[test]
fn pool_network_should_report_syncing_state_during_active_sync() {}

#[test]
fn pool_network_should_expose_last_active_timestamp_after_sync_event() {}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cargo test api_runtime_view_test -- --nocapture`
Expected: FAIL with missing runtime signal accessors

- [ ] **Step 3: Write minimal implementation**

In `pool_network.rs`, add only the minimal signals needed by API aggregation:

- last active timestamp tracking
- current syncing flag or derived getter
- active connection liveness getter

Do not build a full presence subsystem.

- [ ] **Step 4: Run test to verify it passes**

Run: `cargo test api_runtime_view_test -- --nocapture`
Expected: PASS or remaining failures limited to API aggregation layer

- [ ] **Step 5: Commit**

```bash
git add rust/src/net/pool_network.rs rust/tests/unit/api_runtime_view_test.rs
git commit -m "feat: expose pool network runtime signals"
```

---

## Chunk 3: Add API DTOs And FFI Endpoints

### Task 4: Add runtime / invite DTOs and mapping code

**Files:**
- Modify: `rust/src/api/mod.rs`
- Test: `rust/tests/unit/api_runtime_view_test.rs`

- [ ] **Step 1: Write the failing test**

Add tests covering:

```rust
#[test]
fn runtime_view_dto_should_mark_current_device() {}

#[test]
fn summary_dto_should_return_expected_text_fields() {}

#[test]
fn invite_view_dto_should_exclude_revoked_invites() {}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cargo test api_runtime_view_test -- --nocapture`
Expected: FAIL with missing DTOs / mapping functions

- [ ] **Step 3: Write minimal implementation**

In `api/mod.rs`, add:

- `PoolMemberRuntimeDto`
- `PoolMembersRuntimeViewDto`
- `PoolRuntimeSummaryDto`
- `PoolInviteDto`
- `PoolInvitesViewDto`

Also add internal mapping helpers from store/network models to DTOs.

- [ ] **Step 4: Run test to verify it passes**

Run: `cargo test api_runtime_view_test -- --nocapture`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add rust/src/api/mod.rs rust/tests/unit/api_runtime_view_test.rs
git commit -m "feat: add runtime and invite DTOs"
```

### Task 5: Add the 4 new Rust API functions

**Files:**
- Modify: `rust/src/api/mod.rs`
- Test: `rust/tests/integration/api_runtime_view_integration_test.rs`

- [ ] **Step 1: Write the failing integration test**

Add tests covering:

```rust
#[test]
fn get_pool_members_runtime_view_returns_member_runtime_rows() {}

#[test]
fn get_pool_runtime_summary_returns_pool_summary_fields() {}

#[test]
fn list_active_invites_and_revoke_invite_form_a_closed_loop() {}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cargo test api_runtime_view_integration_test -- --nocapture`
Expected: FAIL with missing public API functions

- [ ] **Step 3: Write minimal implementation**

Add:

- `get_pool_members_runtime_view`
- `get_pool_runtime_summary`
- `list_active_invites`
- `revoke_invite`

Requirements:

- reuse existing `configured_app_data_dir`, `PoolStore`, and network handle map
- do not change existing pool detail APIs
- keep errors mapped through existing `ApiError` conventions

- [ ] **Step 4: Run test to verify it passes**

Run: `cargo test api_runtime_view_integration_test -- --nocapture`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add rust/src/api/mod.rs rust/tests/integration/api_runtime_view_integration_test.rs
git commit -m "feat: add runtime summary APIs"
```

---

## Chunk 4: Regression And Quality Gate

### Task 6: Run focused regression for existing pool and note flows

**Files:**
- Verify only; no intended code changes

- [ ] **Step 1: Run pool API regression**

Run: `cargo test api_pool -- --nocapture`
Expected: PASS

- [ ] **Step 2: Run note API regression**

Run: `cargo test api_card -- --nocapture`
Expected: PASS

- [ ] **Step 3: Run sync regression**

Run: `cargo test sync_ -- --nocapture`
Expected: PASS or only unrelated existing failures

- [ ] **Step 4: Run full Rust test suite**

Run: `cargo test`
Expected: PASS

- [ ] **Step 5: Run formatting and lint verification**

Run: `cargo fmt --check`
Expected: PASS

Run: `cargo clippy --all-targets --all-features -- -D warnings`
Expected: PASS

- [ ] **Step 6: Commit final verification-safe state**

```bash
git add rust/src/api/mod.rs rust/src/net/pool_network.rs rust/src/store/pool_store.rs rust/src/models/pool_runtime.rs rust/src/models/mod.rs rust/tests/unit/api_runtime_view_test.rs rust/tests/unit/pool_invite_store_test.rs rust/tests/integration/api_runtime_view_integration_test.rs
git commit -m "feat: fill prototype runtime API gaps"
```

---

## Notes

- 本计划只覆盖 Rust API 最小缺口补齐
- 不在本计划中实现 Flutter 调用、FRB 接线或页面适配
- 不在本计划中扩展成员管理能力
- `history` 保持待定，不在本轮实现范围内
