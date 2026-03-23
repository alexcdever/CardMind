# Phase 2 信任优先恢复 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 以 Rust 为主实现层落地 `Phase 2` 的“信任优先恢复”基线，让系统能够稳定区分同步、查询收敛、实例连续性三类状态，并把“本地内容仍安全 / 查询尚未收敛 / 另一台设备上的 app 实例尚未恢复完成 / 当前需要什么恢复动作”如实输出给 Flutter。

**Architecture:** 严格遵守 `docs/specs/architecture.md` 与 `docs/plans/2026-03-23-phase2-trust-first-recovery-design.md`：Rust 负责归一化底层证据、定义稳定契约、输出允许/禁止操作与恢复动作；FRB 只传输稳定 DTO；Flutter 只消费 Rust 契约并映射为用户可理解文案，不自行推断业务事实。实现顺序采用 TDD：先收紧规格，再锁定 Rust contract tests，再实现 Rust 契约与 API，最后对齐 Flutter 消费与 UI 验收。

**Tech Stack:** Rust、Flutter/Dart、flutter_rust_bridge、LoroDoc、SQLite、Markdown specs/plans、`cargo test`、`flutter test`、git

---

## File Structure

- Modify: `docs/specs/architecture.md`
  - 把项目级“投影”术语收束为“查询收敛”，并明确 `LoroDoc -> SQLite` 查询侧收敛与同步分层。
- Modify: `docs/specs/ui-interaction.md`
  - 把 UI 反馈语义升级到 `Phase 2`：禁止向用户暴露“查询收敛”术语，但必须准确表达列表/结果更新中的恢复状态。
- Modify: `docs/specs/pool.md`
  - 把池域恢复语义从 `Phase 1` 最低恢复能力推进到 `Phase 2` 的信任优先恢复边界。
- Modify: `rust/src/api/mod.rs`
  - 作为当前对外同步/恢复门面，接线稳定契约 DTO，并调用专用归一化模块输出结果。
- Create: `rust/src/api/recovery_contract.rs`
  - 承载 `Phase 2` 契约字段、组合规则、恢复动作与允许/禁止操作归一化，避免继续把语义堆进 `rust/src/api/mod.rs`。
- Modify: `rust/src/models/api_error.rs`
  - 仅在需要新增稳定错误码或收紧既有错误码语义时修改。
- Modify: `rust/src/net/pool_network.rs`
  - 只保留同步相关底层状态，不再混入查询收敛语义；必要时为实例连续性与恢复动作提供底层证据。
- Modify: `rust/src/store/card_store.rs`
  - 若需要，补充查询收敛失败/恢复相关稳定证据接口。
- Modify: `rust/src/store/pool_store.rs`
  - 若需要，补充池域查询收敛失败/恢复相关稳定证据接口。
- Test: `rust/tests/contract/api/sync_api_contract.rs`
  - 锁定新的稳定契约：`sync_state / query_convergence_state / instance_continuity_state / recovery_stage / next_action / continuity_state / local_content_safety / allowed_operations / forbidden_operations`。
- Test: `rust/tests/integration/api_integration_test.rs`
  - 锁定 Rust API 面向 `LoroDoc -> SQLite` 查询收敛、同步降级、实例连续性场景的端到端语义。
- Test: `rust/tests/unit/net/pool_network_sync_test.rs`
  - 锁定 `PoolNetwork` 对同步底层状态与错误码的最小边界，不让其重新承担查询收敛判断。
- Modify: `lib/features/sync/sync_service.dart`
  - 把 Flutter 消费从 `projectionState` 迁移到 `queryConvergenceState` 等新契约字段。
- Modify: `lib/features/sync/sync_status.dart`
  - 调整前端同步/恢复状态模型，使其能表达 `查询收敛异常` 与 `实例连续性未完成`，但不直接暴露这些内部术语给用户。
- Create: `lib/features/sync/sync_status_mapper.dart`
  - 集中 DTO -> 前端 view state 的文案、动作和可用性映射，避免规则散落到 service 或 page。
- Modify: `lib/features/pool/pool_page.dart`
  - 若当前池页承担恢复反馈入口，则改为消费新的 Rust 契约语义。
- Modify: `test/widget/pages/pool_page_test.dart`
  - 迁移现有池页测试对旧 `projectionState` 的依赖。
- Modify: `test/widget/components/sync_controller_test.dart`
  - 迁移现有 sync controller 组件测试对旧 DTO 字段的依赖。
- Modify: `test/unit/presentation/sync_controller_unit_test.dart`
  - 迁移现有 sync controller 单测对旧 DTO 字段的依赖。
- Modify: `test/unit/presentation/pool_controller_test.dart`
  - 迁移现有 pool controller 单测对旧 DTO 字段的依赖。
- Test: `test/contract/api/sync_api_contract_test.dart`
  - 锁定 FRB DTO 到 Dart 侧字段名与契约语义一致。
- Test: `test/unit/presentation/sync_service_test.dart`
  - 锁定 `SyncService` 对新 DTO 的映射。
- Test: `test/unit/presentation/sync_status_test.dart`
  - 锁定前端状态模型的文案/动作分流。
- Test: `test/widget/components/sync_state_test.dart`
  - 锁定 UI 只展示“内容已保存，结果仍在更新”等用户语义，不暴露“查询收敛”。
- Test: `test/integration/features/pool_sync_test.dart`
  - 锁定池页恢复反馈的端到端呈现。
- Modify: `docs/plans/DIR.md`
  - 添加本 implementation plan 的索引条目。

---

## Chunk 1: Tighten Truth Sources And Lock Rust Contracts

### Task 1: Align project-level specs to Phase 2 terminology and boundaries

**Files:**
- Modify: `docs/specs/architecture.md`
- Modify: `docs/specs/ui-interaction.md`
- Modify: `docs/specs/pool.md`
- Reference: `docs/plans/2026-03-23-phase2-trust-first-recovery-design.md`

- [ ] **Step 1: Write the failing spec checklist**

Record this checklist before editing:

```text
1. 是否已把 “投影” 统一改为“查询收敛”，并保持含义是 LoroDoc -> SQLite 读模型收敛
2. 是否区分同步 / 查询收敛 / 设备切换（设备上的 app 实例连续性）三类状态，而不是混成一个字段
3. 是否明确用户文案不得直接暴露“查询收敛”术语
4. 是否保持 Rust 定义真相、Flutter 仅消费与呈现
5. 是否把 Phase 2 的目标收束为“内容安全信任优先”而不是功能扩张
```

- [ ] **Step 2: Verify current mismatch**

Run:

```bash
rg "投影|查询收敛|projection|SQLite|LoroDoc|设备|实例" docs/specs/architecture.md docs/specs/ui-interaction.md docs/specs/pool.md
```

Expected: 仍存在 `投影` 与 `查询收敛` 混用、以及 `设备` / `app 实例` 未按层分离的地方。

- [ ] **Step 3: Apply the minimum spec updates**

Update only the sections needed to make these constraints explicit:

- `docs/specs/architecture.md`
  - 把 `5.4 投影与同步链路` 改写为 `查询收敛与同步链路` 或等价标题
  - 明确 `LoroDoc -> SQLite` 是查询收敛，而不是跨设备同步
  - 明确 `可恢复失败` 示例动作为 `重试查询收敛 / 重试同步 / 重新查询当前状态`
- `docs/specs/ui-interaction.md`
  - 在 `4.3`、`4.4`、`4.8` 补入 `Phase 2` 约束
  - 明确 Flutter 不得直接向用户展示“查询收敛”一词
  - 用户文案必须转译为“内容已保存，列表/结果/界面仍在更新”等结果导向表达
- `docs/specs/pool.md`
  - 在 `6.2`、`7`、`8.1` 补入池域 `Phase 2` 语义
  - 明确池域需要区分同步未完成、查询结果未更新、实例连续性未恢复完成

- [ ] **Step 4: Verify alignment**

Run:

```bash
rg "查询收敛|LoroDoc|SQLite|app 实例|结果仍在更新|列表正在更新" docs/specs/architecture.md docs/specs/ui-interaction.md docs/specs/pool.md
```

Expected: 命中新增语义。

Run:

```bash
rg "projection|投影失败不得伪装成业务写失败|重试投影" docs/specs/architecture.md docs/specs/ui-interaction.md docs/specs/pool.md
```

Expected: 只保留必要历史语义或已被 `查询收敛` 替代；不再把“投影”作为主术语。

- [ ] **Step 5: Run formatting verification**

Run: `git diff --check`
Expected: no whitespace or patch formatting issues

- [ ] **Step 6: Commit task 1**

```bash
git add docs/specs/architecture.md docs/specs/ui-interaction.md docs/specs/pool.md
git commit -m "docs: align phase2 trust recovery terminology"
```

### Task 2: Write failing Rust contract tests for Phase 2 stable semantics

**Files:**
- Modify: `rust/tests/contract/api/sync_api_contract.rs`
- Modify: `rust/tests/integration/api_integration_test.rs`
- Modify: `rust/tests/unit/net/pool_network_sync_test.rs`
- Reference: `docs/plans/2026-03-23-phase2-trust-first-recovery-design.md`

- [ ] **Step 1: Write the failing contract checklist**

```text
1. DTO 是否能区分 sync_state / query_convergence_state / instance_continuity_state
2. DTO 是否能区分 local_content_safety / recovery_stage / continuity_state / next_action
3. 写成功但查询结果未更新时，是否表达为“内容仍安全 + 查询收敛未完成”
4. 另一台设备上的实例未恢复时，是否表达为“内容仍安全 + 实例连续性未完成”
5. Flutter 是否无需自行推断 allowed/forbidden semantics
6. `local_content_safety = unknown` 时，是否强制进入 `recovery_stage = unsafe_unknown`
7. `next_action` 是否始终只有一个主动作
8. `continuity_state` 是否能区分 `same_path / path_at_risk / path_broken`
```

- [ ] **Step 2: Add focused failing Rust tests**

Add or extend tests in these files with executable, evidence-driven cases:

- `rust/tests/contract/api/sync_api_contract.rs`
  - 锁定 DTO 字段面、单主动作约束、Rust 直接输出 allowed/forbidden operations 约束
- `rust/tests/integration/api_integration_test.rs`
  - 锁定 `safe / read_only_risk / unknown`、`same_path / path_at_risk / path_broken`、应用重启后保守快照恢复等端到端结果
- `rust/tests/unit/net/pool_network_sync_test.rs`
  - 仅锁定 `PoolNetwork` 的同步底层状态与错误码，不扩张到查询收敛判断

- [ ] **Step 2A: Add DTO surface contract test**

In `rust/tests/contract/api/sync_api_contract.rs`, add a test that asserts the sync DTOs expose all required Phase 2 fields:

- `sync_state`
- `query_convergence_state`
- `instance_continuity_state`
- `local_content_safety`
- `recovery_stage`
- `continuity_state`
- `next_action`
- `allowed_operations`
- `forbidden_operations`

- [ ] **Step 2B: Add query-convergence pending integration test**

In `rust/tests/integration/api_integration_test.rs`, create a scenario where `LoroDoc` 已接受写入、`SQLite` 查询结果尚未收敛，并断言：

- `query_convergence_state = pending`
- `sync_state != pending`
- `local_content_safety = safe`
- `continuity_state = path_at_risk`

- [ ] **Step 2C: Add query-convergence blocked integration test**

In `rust/tests/integration/api_integration_test.rs`, create a scenario where 查询收敛被阻断，并断言：

- `query_convergence_state = blocked`
- `recovery_stage = needs_user_action`
- `next_action = retry_query_convergence`

- [ ] **Step 2D: Add read-only-risk integration test**

In `rust/tests/integration/api_integration_test.rs`, create a scenario where内容仍可读但不应继续低风险写入，并断言：

- `local_content_safety = read_only_risk`
- `continuity_state = path_at_risk`
- `allowed_operations` 仍包含 read/check actions
- `forbidden_operations` 包含正常低风险写路径

- [ ] **Step 2E: Add unknown/unsafe-unknown integration test**

In `rust/tests/integration/api_integration_test.rs`, create a scenario where本地结果已不可验证或可能回滚，并断言：

- `local_content_safety = unknown`
- `recovery_stage = unsafe_unknown`
- `next_action != none`

- [ ] **Step 2F: Add path-broken integration test**

In `rust/tests/integration/api_integration_test.rs`, create a scenario where系统要求重新初始化、重新导入或放弃当前本地内容，并断言：

- `continuity_state = path_broken`
- `forbidden_operations` 包含正常写路径继续动作

- [ ] **Step 2G: Add conservative-snapshot restart integration tests**

In `rust/tests/integration/api_integration_test.rs`, add two restart scenarios:

1. 应用重启后 Rust 尚未完成重算，但最近一次保守快照仍可读取 -> 返回该保守快照
2. 应用重启后既无法重算也无法读取最近一次保守快照 -> 返回 `local_content_safety = unknown` 与 `recovery_stage = unsafe_unknown`

- [ ] **Step 2H: Add combination contract tests**

In `rust/tests/contract/api/sync_api_contract.rs`, add tests that assert:

- all `ready` sub-states -> `recovery_stage = stable`
- any `blocked` sub-state -> `recovery_stage` 只能是 `needs_user_action` 或 `unsafe_unknown`
- `local_content_safety = safe` must never pair with `continuity_state = path_broken`

- [ ] **Step 2I: Keep PoolNetwork sync-only unit coverage**

In `rust/tests/unit/net/pool_network_sync_test.rs`, add or update one test that proves `PoolNetwork` only reports sync evidence and does not own query-convergence truth.

- [ ] **Step 3: Run focused tests to verify RED**

Run:

```bash
cargo test sync_status_should_return_structured_error_when_handle_invalid -- --exact
cargo test api_sync_status_returns_degraded_when_query_convergence_pending -- --exact
cargo test test_sync_state_priority_over_session_state -- --exact
```

Expected: 至少部分 FAIL，因为当前 Rust contract 仍使用旧的粗粒度状态语义，尚未覆盖 `查询收敛`、`read_only_risk`、`unsafe_unknown`、`path_broken`、保守快照恢复等约束。

- [ ] **Step 4: Refine tests so they describe only Phase 2**

Before touching implementation, confirm the tests do **not** require:

- 多人协作扩展能力
- Flutter 文案具体措辞
- 新的长流程恢复编排

- [ ] **Step 5: Commit task 2**

```bash
git add rust/tests/contract/api/sync_api_contract.rs rust/tests/integration/api_integration_test.rs rust/tests/unit/net/pool_network_sync_test.rs
git commit -m "test(sync): define phase2 trust-first recovery contract"
```

### Task 3: Implement the minimum Rust contract and API normalization

**Files:**
- Create: `rust/src/api/recovery_contract.rs`
- Modify: `rust/src/api/mod.rs`
- Optional Modify: `rust/src/models/api_error.rs`
- Optional Modify: `rust/src/net/pool_network.rs`
- Optional Modify: `rust/src/store/card_store.rs`
- Optional Modify: `rust/src/store/pool_store.rs`
- Optional Modify: `rust/src/store/sqlite_store.rs`
- Test: `rust/tests/contract/api/sync_api_contract.rs`
- Test: `rust/tests/integration/api_integration_test.rs`
- Test: `rust/tests/unit/net/pool_network_sync_test.rs`

- [ ] **Step 1: Re-run the failing focused suite**

Run:

```bash
cargo test sync_status_should_return_structured_error_when_handle_invalid -- --exact
cargo test api_sync_status_returns_degraded_when_query_convergence_pending -- --exact
```

Expected: FAIL

- [ ] **Step 2: Replace the old coarse-grained DTO fields**

Update `SyncStatusDto` and `SyncResultDto` so they both express the same full Phase 2 contract surface required by the spec. Remove old coarse-grained fields if they no longer carry distinct truth. Do not keep compatibility-only fields.

The required Phase 2 contract surface for both `SyncStatusDto` and `SyncResultDto` is:

```rust
pub struct SyncStatusDto {
    pub sync_state: String,
    pub query_convergence_state: String,
    pub instance_continuity_state: String,
    pub local_content_safety: String,
    pub recovery_stage: String,
    pub continuity_state: String,
    pub next_action: String,
    pub allowed_operations: Vec<String>,
    pub forbidden_operations: Vec<String>,
}
```

`SyncResultDto` MUST 与 `SyncStatusDto` 保持同一字段面；二者只允许在“调用场景不同”上有差异，不允许在契约字段上再分叉第二套恢复语义。

- [ ] **Step 3: Implement minimal normalization helpers**

Create `rust/src/api/recovery_contract.rs` and move the normalization rules there. Keep `rust/src/api/mod.rs` as a thin wiring layer.

Add focused helper functions with explicit inputs:

```rust
fn query_convergence_state(base_path: &str) -> Result<(String, Option<String>), ApiError>
fn instance_continuity_state(
    sync_state: &str,
    remote_instance_observable: bool,
    remote_instance_caught_up: bool,
) -> String
fn local_content_safety(
    query_convergence_state: &str,
    sync_state: &str,
    projection_failures_present: bool,
    local_write_risk_present: bool,
    local_content_unverifiable: bool,
) -> String
fn recovery_stage(
    local_content_safety: &str,
    sync_state: &str,
    query_convergence_state: &str,
    instance_continuity_state: &str,
) -> String
fn next_action(
    local_content_safety: &str,
    sync_state: &str,
    query_convergence_state: &str,
    instance_continuity_state: &str,
) -> String
fn continuity_state(
    local_content_safety: &str,
    sync_state: &str,
    query_convergence_state: &str,
    instance_continuity_state: &str,
) -> String
fn allowed_operations(
    local_content_safety: &str,
    recovery_stage: &str,
    continuity_state: &str,
) -> Vec<String>
fn forbidden_operations(
    local_content_safety: &str,
    recovery_stage: &str,
    continuity_state: &str,
) -> Vec<String>
fn restore_conservative_snapshot_or_unknown(
    snapshot_available: bool,
    recompute_finished: bool,
    recompute_succeeded: bool,
) -> RecoveryContractSnapshot
```

Rules must match the spec:

- `query_convergence_state` describes `LoroDoc -> SQLite` read-model convergence
- `sync_state` describes inter-instance sync
- `instance_continuity_state` describes “另一台设备上的 app 实例是否已恢复到可继续使用”
- `local_content_safety = unknown` must force `recovery_stage = unsafe_unknown`
- `next_action` stays singular
- `allowed_operations / forbidden_operations` come from Rust, not Flutter inference
- `next_action` can be `retry_query_convergence`
- local content safety must be allowed to depend on write-risk / unverifiable-local-result evidence, not only sync/query states
- restart recovery must prefer a previously persisted conservative Rust snapshot before recompute finishes
- when neither recompute nor conservative snapshot is available, the contract must fall back to `unknown + unsafe_unknown`

`recovery_contract.rs` 的单一职责约束：

- 只承载 `Phase 2` 契约归一化与规则输出
- 不承载底层 IO、SQLite 读写、LoroDoc 持久化、网络连接流程
- 底层证据采集留在 store/runtime/api wiring 层，规则归一化留在该文件

- [ ] **Step 4: Keep PoolNetwork scoped to sync evidence only**

Only change `rust/src/net/pool_network.rs` if needed to ensure it provides sync/instance evidence without re-owning query-convergence semantics.

If a new helper is needed, keep it minimal and limited to sync/instance evidence:

```rust
pub fn sync_state(&self) -> &'static str
pub fn last_sync_error_code(&self) -> Option<&str>
```

Do **not** move `SQLite` query-convergence judgment into `PoolNetwork`.

If `instance_continuity_state` cannot be derived from existing `PoolNetwork` evidence alone, explicitly add the smallest Rust-side evidence hook in a dedicated store/runtime helper rather than reusing `sync_state` as a proxy.

For this task, the default landing place is:

- `rust/src/api/recovery_contract.rs`：规则归一化
- `rust/src/store/sqlite_store.rs`：查询收敛失败/恢复相关 SQLite 证据读取
- `rust/src/store/card_store.rs` / `rust/src/store/pool_store.rs`：本地可读但不可安全写、不可验证结果等领域证据暴露
- `rust/src/api/mod.rs`：DTO 接线与对外 API 输出

Do not introduce a generic “runtime helper” file without first exhausting these existing boundaries.

- [ ] **Step 5: Run focused Rust tests to verify GREEN**

Run:

```bash
cargo test sync_status_should_return_structured_error_when_handle_invalid -- --exact
cargo test api_sync_status_returns_degraded_when_query_convergence_pending -- --exact
cargo test api_pool_network_lifecycle_and_sync_state -- --exact
cargo test test_sync_state_priority_over_session_state -- --exact
```

Expected: PASS, and the assertions added in Task 2 for `unsafe_unknown` / single `next_action` / `path_broken` / `allowed_operations` / `forbidden_operations` / `read_only_risk` / 保守快照恢复 all pass.

- [ ] **Step 6: Commit task 3**

```bash
git add rust/src/api/recovery_contract.rs rust/src/api/mod.rs rust/src/net/pool_network.rs rust/src/models/api_error.rs rust/src/store/card_store.rs rust/src/store/pool_store.rs rust/tests/contract/api/sync_api_contract.rs rust/tests/integration/api_integration_test.rs rust/tests/unit/net/pool_network_sync_test.rs
git commit -m "feat(sync): add phase2 trust-first recovery contract"
```

---

## Chunk 2: Align Flutter Consumption And End-To-End Verification

### Task 4: Regenerate FRB bindings and lock Dart-side contract tests

**Files:**
- Generated: `lib/bridge_generated/api.dart`
- Generated: `lib/bridge_generated/frb_generated.dart`
- Generated: `lib/bridge_generated/models/` 中与 `SyncStatusDto` / `SyncResultDto` 相关的生成文件（若本次生成实际产出）
- Modify: `test/contract/api/sync_api_contract_test.dart`
- Modify: `test/integration/infrastructure/sync_bridge_test.dart`
- Create: `test/support/sync_dto_fixtures.dart`
  - 统一承载 FRB 生成 `SyncStatusDto` / `SyncResultDto` 的测试构造 helper，避免测试文件互相耦合。
- Reference: `rust/src/api/mod.rs`

- [ ] **Step 1: Write the failing Dart contract checklist**

Contract naming rule for this chunk:

- Dart contract tests MUST assert FRB-generated Dart field names such as `queryConvergenceState`
- Enum/string values MUST remain aligned with Rust wire values such as `read_only_risk` / `needs_user_action` / `retry_query_convergence` / `path_broken`
- Flutter view-model tests MAY map these values later, but contract tests in this task MUST verify raw FRB contract values first

Operation-value rule for this chunk:

- Rust / FRB / Flutter 共用的 `allowedOperations` / `forbiddenOperations` 最小稳定字面量集合在本阶段固定为：
  - `read`
  - `edit`
  - `check_status`
  - `continue_low_risk_write`
- 新增操作值前，必须先在 Rust contract tests 与 Dart contract tests 同步锁定。
- 本 chunk 中所有测试、mapper 与 UI 断言都必须使用这组 snake_case wire values，不得自行发明 camelCase 变体。

- [ ] **Step 1A: Run repository-wide old-field migration guard**

Run:

```bash
rg "projectionState" lib test
```

Expected:

- Task 4 开始前：命中旧字段引用，证明迁移尚未完成
- Task 4-6 完成后：`lib/` 与 `test/` 下非生成代码不再命中 `projectionState`
- FRB 重新生成完成后：生成代码也完成切换，不再残留旧字段

Test helper constraint for Task 4:

- Define `makeGeneratedSyncStatusDto(...)` and `makeGeneratedSyncResultDto(...)` in `test/support/sync_dto_fixtures.dart`
- These helpers MUST construct actual FRB-generated DTO instances using the generated constructors available in the current codebase
- Do not introduce fake DTO classes for this task

Bridge-test helper constraint for Task 4:

- Reuse the FRB-generated DTO helpers from `test/support/sync_dto_fixtures.dart`
- Do not construct a second parallel DTO fixture path inside `test/integration/infrastructure/sync_bridge_test.dart`

```text
1. Dart DTO 是否已从 projectionState 迁移到 queryConvergenceState
2. Dart DTO 是否包含 instanceContinuityState / localContentSafety / recoveryStage / continuityState / nextAction / allowedOperations / forbiddenOperations
3. 生成绑定是否与 Rust DTO 完整对齐
```

- [ ] **Step 2: Write the failing Dart contract assertions**

Add or update assertions so the Dart contract test locks the full Phase 2 surface for both `SyncStatusDto` and `SyncResultDto`:

The assertion objects in this step MUST be actual FRB-generated `SyncStatusDto` / `SyncResultDto` instances, not custom fake DTO classes.

```dart
test('SyncStatusDto exposes full phase2 recovery fields', () {
  expect(dto.syncState, 'ready');
  expect(dto.queryConvergenceState, 'ready');
  expect(dto.instanceContinuityState, 'recovering');
  expect(dto.localContentSafety, 'safe');
  expect(dto.recoveryStage, 'waiting');
  expect(dto.continuityState, 'path_at_risk');
  expect(dto.nextAction, isNotEmpty);
  expect(dto.allowedOperations, isNotEmpty);
  expect(dto.forbiddenOperations, isNotEmpty);
});

test('SyncResultDto keeps the same phase2 contract surface', () {
  expect(result.syncState, 'ready');
  expect(result.queryConvergenceState, 'blocked');
  expect(result.instanceContinuityState, 'recovering');
  expect(result.localContentSafety, 'read_only_risk');
  expect(result.recoveryStage, 'needs_user_action');
  expect(result.continuityState, 'path_broken');
  expect(result.nextAction, 'retry_query_convergence');
  expect(result.allowedOperations, contains('read'));
  expect(result.forbiddenOperations, contains('continue_low_risk_write'));
});

test('dart contract no longer consumes projectionState', () {
  final dto = makeGeneratedSyncStatusDto(queryConvergenceState: 'ready');

  expect(() => dto.queryConvergenceState, returnsNormally);
  // This test must be paired with a grep gate in a separate tracked step.
});
```

`makeGeneratedSyncStatusDto(...)` / `makeGeneratedSyncResultDto(...)` in this task MUST return actual FRB-generated DTO instances, not custom fake DTO classes.

- [ ] **Step 2A: Run explicit old-field grep guard**

Run:

```bash
rg "projectionState" test/contract/api/sync_api_contract_test.dart lib/features/sync
```

Expected: no matches after migration

- [ ] **Step 3: Run the Dart contract test to verify RED**

Run:

```bash
flutter test test/contract/api/sync_api_contract_test.dart
```

Expected: FAIL before regeneration/alignment.

- [ ] **Step 4: Regenerate FRB bindings**

Run:

```bash
flutter_rust_bridge_codegen generate
```

Expected: binding generation succeeds and emits updated DTOs.

- [ ] **Step 4A: Add explicit bridge assertions for Phase 2 fields**

Before any post-generation PASS claim, update `test/integration/infrastructure/sync_bridge_test.dart` so it no longer只断言 API symbol 存在，而是至少新增以下可执行断言：

1. FRB 生成的 `SyncStatusDto` 可访问：
   - `syncState`
   - `queryConvergenceState`
   - `instanceContinuityState`
   - `localContentSafety`
   - `recoveryStage`
   - `continuityState`
   - `nextAction`
   - `allowedOperations`
   - `forbiddenOperations`
2. FRB 生成的 `SyncResultDto` 具备同一字段面。
3. 复用 `test/support/sync_dto_fixtures.dart` 中 helper 构造一个“Rust 保守快照语义 DTO”，并断言 Dart 侧可读取：
   - `localContentSafety = unknown`
   - `recoveryStage = unsafe_unknown`

- [ ] **Step 4B: Run bridge verification immediately after regeneration**

Run:

```bash
flutter test test/integration/infrastructure/sync_bridge_test.dart
```

Expected: PASS, proving regenerated FRB DTOs are still consumable before continuing into Flutter mapping work.

- [ ] **Step 4C: Verify generated bridge code no longer contains `projectionState`**

Run:

```bash
rg "projectionState" lib/bridge_generated
```

Expected: no matches

- [ ] **Step 5: Re-run Dart contract test to verify GREEN**

Run:

```bash
flutter test test/contract/api/sync_api_contract_test.dart
```

Expected: PASS

- [ ] **Step 6: Commit task 4**

```bash
git add lib/bridge_generated/api.dart lib/bridge_generated/frb_generated.dart test/contract/api/sync_api_contract_test.dart test/integration/infrastructure/sync_bridge_test.dart test/support/sync_dto_fixtures.dart
git commit -m "chore(frb): regenerate phase2 recovery contract bindings"
```

If `flutter_rust_bridge_codegen generate` also changes files under `lib/bridge_generated/models/`, add those exact files to the same commit.

### Task 5: Align Flutter service and status mapping to the new contract

**Files:**
- Modify: `lib/features/sync/sync_service.dart`
- Modify: `lib/features/sync/sync_status.dart`
- Create: `lib/features/sync/sync_status_mapper.dart`
- Test: `test/unit/presentation/sync_service_test.dart`
- Test: `test/unit/presentation/sync_status_test.dart`
- Create or Modify: `test/support/sync_dto_fixtures.dart`

- [ ] **Step 1: Write failing Flutter unit tests**

Output: 在 `test/unit/presentation/sync_service_test.dart` 与 `test/unit/presentation/sync_status_test.dart` 中新增可直接运行的 RED 测试。

Test helper constraint for Task 5:

- Define `makeSyncStatusDto(...)` in `test/support/sync_dto_fixtures.dart`
- This helper may wrap FRB-generated DTO construction for brevity, but MUST still return actual FRB-generated `SyncStatusDto` instances
- `mapSyncStatusDto(...)` assertions MUST target the real mapper output shape, not ad-hoc maps or fake view objects
- Snapshot fallback / replacement behavior MUST be tested in `test/unit/presentation/sync_service_test.dart`, not in mapper-only tests
- In `test/support/sync_dto_fixtures.dart`, default fixtures MUST explicitly declare default `allowedOperations` / `forbiddenOperations`; do not let tests depend on hidden defaults.
- If `FakeSyncGateway.sequence(...)`, `throwApiError(...)`, or `networkId` helpers do not already exist, define them in `test/unit/presentation/sync_service_test.dart` or a shared helper already used by that file; do not invent ad-hoc helpers in unrelated test files.

Add focused tests that lock the new mapping behavior:

```dart
test('maps query convergence blocked to local-safe updating state', () async {
  final dto = makeSyncStatusDto(
    queryConvergenceState: 'blocked',
    localContentSafety: 'safe',
    recoveryStage: 'needs_user_action',
    nextAction: 'retry_query_convergence',
  );

  final status = mapSyncStatusDto(dto);

  expect(status.summaryText, '内容已保存，但需要你手动继续恢复');
  expect(status.primaryAction, 'retry_query_convergence');
});

test('maps query convergence pending to local-safe updating state', () async {
  final dto = makeSyncStatusDto(
    queryConvergenceState: 'pending',
    localContentSafety: 'safe',
    recoveryStage: 'waiting',
    nextAction: 'none',
  );

  final status = mapSyncStatusDto(dto);

  expect(status.summaryText, '内容已保存，结果仍在更新');
  expect(status.primaryAction, isNull);
});

test('maps retrying stage to still-recovering copy without implying failure', () async {
  final dto = makeSyncStatusDto(
    queryConvergenceState: 'pending',
    localContentSafety: 'safe',
    recoveryStage: 'retrying',
    nextAction: 'none',
  );

  final status = mapSyncStatusDto(dto);

  expect(status.summaryText, '内容已保存，系统仍在继续恢复');
  expect(status.isError, isFalse);
});

test('maps instance continuity recovering separately from sync failure', () async {
  final dto = makeSyncStatusDto(
    instanceContinuityState: 'recovering',
    localContentSafety: 'safe',
    syncState: 'ready',
  );

  final status = mapSyncStatusDto(dto);

  expect(status.summaryText, '内容已保存，另一台设备上的内容仍在恢复');
  expect(status.isError, isFalse);
});

test('maps retry_sync as a single primary recovery action', () async {
  final dto = makeSyncStatusDto(
    localContentSafety: 'safe',
    recoveryStage: 'needs_user_action',
    nextAction: 'retry_sync',
  );

  final status = mapSyncStatusDto(dto);

  expect(status.primaryAction, 'retry_sync');
  expect(status.hasMultiplePrimaryActions, isFalse);
});

test('maps reconnect_instance as a single primary recovery action', () async {
  final dto = makeSyncStatusDto(
    localContentSafety: 'safe',
    recoveryStage: 'needs_user_action',
    nextAction: 'reconnect_instance',
  );

  final status = mapSyncStatusDto(dto);

  expect(status.primaryAction, 'reconnect_instance');
  expect(status.hasMultiplePrimaryActions, isFalse);
});

test('maps read-only-risk to restricted local editing state', () async {
  final dto = makeSyncStatusDto(
    localContentSafety: 'read_only_risk',
    allowedOperations: ['read', 'check_status'],
    forbiddenOperations: ['continue_low_risk_write'],
  );

  final status = mapSyncStatusDto(dto);

  expect(status.allowedActions, contains('check_status'));
  expect(status.forbiddenActions, contains('continue_low_risk_write'));
});

test('never exposes internal term query convergence in user-facing text model', () {
  final dto = makeSyncStatusDto(queryConvergenceState: 'pending');
  final status = mapSyncStatusDto(dto);

  expect(status.summaryText.contains('查询收敛'), isFalse);
});

test('shows only one primary recovery action in the UI', () {
  final dto = makeSyncStatusDto(nextAction: 'recheck_status');
  final status = mapSyncStatusDto(dto);

  expect(status.primaryAction, 'recheck_status');
  expect(status.hasMultiplePrimaryActions, isFalse);
});

test('keeps local safe actions available even when needs_user_action is present', () {
  final dto = makeSyncStatusDto(
    localContentSafety: 'safe',
    recoveryStage: 'needs_user_action',
    nextAction: 'retry_query_convergence',
    allowedOperations: ['read', 'edit'],
  );

  final status = mapSyncStatusDto(dto);

  expect(status.allowedActions, contains('read'));
  expect(status.allowedActions, contains('edit'));
  expect(status.primaryAction, 'retry_query_convergence');
});

test('consumes rust-returned conservative snapshot when status API yields it', () async {
  final gateway = FakeSyncGateway.sequence([
    // Rust directly returns a conservative snapshot DTO
    makeSyncStatusDto(
      localContentSafety: 'unknown',
      recoveryStage: 'unsafe_unknown',
      nextAction: 'recheck_status',
    ),
  ]);
  final service = SyncService(gateway: gateway, networkId: networkId);

  final status = await service.status();

  expect(status.summaryText, '当前无法确认内容安全，请先检查状态');
  expect(status.primaryAction, 'recheck_status');
  // The source of truth remains the Rust-returned conservative snapshot DTO.
});

test('falls back to rust-provided conservative snapshot when latest snapshot read fails but rust still has one', () async {
  final gateway = FakeSyncGateway.sequence([
    throwApiError('REQUEST_TIMEOUT'),
    makeSyncStatusDto(
      localContentSafety: 'unknown',
      recoveryStage: 'unsafe_unknown',
      nextAction: 'recheck_status',
    ),
  ]);
  final service = SyncService(gateway: gateway, networkId: networkId);

  final status = await service.status();

  expect(status.summaryText, '当前无法确认内容安全，请先检查状态');
  expect(status.primaryAction, 'recheck_status');
});

test('falls back to unknown and unsafe_unknown when neither latest snapshot nor rust conservative snapshot is available', () async {
  final gateway = FakeSyncGateway.sequence([
    throwApiError('REQUEST_TIMEOUT'),
    throwApiError('NO_CONSERVATIVE_SNAPSHOT'),
  ]);
  final service = SyncService(gateway: gateway, networkId: networkId);

  final status = await service.status();

  expect(status.summaryText, '当前无法确认内容安全，请先检查状态');
  expect(status.primaryAction, 'recheck_status');
  expect(status.localContentSafety, 'unknown');
  expect(status.recoveryStage, 'unsafe_unknown');
});

test('replaces prior mapped state once a newer rust snapshot arrives', () async {
  final gateway = FakeSyncGateway.sequence([
    makeSyncStatusDto(
      localContentSafety: 'unknown',
      recoveryStage: 'unsafe_unknown',
      nextAction: 'recheck_status',
    ),
    makeSyncStatusDto(
      localContentSafety: 'safe',
      queryConvergenceState: 'pending',
      recoveryStage: 'waiting',
      nextAction: 'none',
    ),
  ]);
  final service = SyncService(gateway: gateway, networkId: networkId);

  final oldStatus = await service.status();
  final newStatus = await service.status();

  expect(oldStatus.summaryText, '当前无法确认内容安全，请先检查状态');
  expect(newStatus.summaryText, '内容已保存，结果仍在更新');
});
```

- [ ] **Step 2: Run focused Flutter unit tests to verify RED**

Run:

```bash
flutter test test/unit/presentation/sync_service_test.dart test/unit/presentation/sync_status_test.dart
```

Expected: FAIL because the current mapping still keys off `projectionState` and older actions.

- [ ] **Step 3: Implement the smallest Flutter alignment**

In `lib/features/sync/sync_status_mapper.dart`:

- implement the pure `mapSyncStatusDto(...)` mapping function
- map raw FRB DTO fields into Flutter view-state shape
- choose result-oriented user copy
- derive primary action visibility from Rust `allowedOperations` / `forbiddenOperations` and raw `nextAction`

In `lib/features/sync/sync_status.dart`:

- keep only the front-end state shape that widgets consume
- add or refine states needed to express:
  - 内容仍安全，但查询结果仍在更新
  - 内容仍安全，但另一台设备上的 app 实例尚未恢复完成
  - 本地内容可读，但不应继续低风险写入
  - 当前无法确认内容安全
- do not let this file own DTO parsing or Rust-field interpretation

In `lib/features/sync/sync_service.dart`:

- stop branching on `dto.projectionState`
- consume `dto.queryConvergenceState`, `dto.instanceContinuityState`, `dto.localContentSafety`, `dto.allowedOperations`, `dto.forbiddenOperations`
- consume `dto.recoveryStage`, `dto.continuityState`, `dto.nextAction`
- call `mapSyncStatusDto(...)` instead of owning the mapping logic directly
- keep business truth in Rust; only orchestrate calls and return mapped view state
- when a newer Rust snapshot arrives, discard any previously mapped stale state immediately and return the newly mapped Rust output
- when the latest snapshot read fails, retry through the same Rust/FRB `status()` path only if Rust is defined to return a conservative snapshot on that path; do not invent a second Flutter-owned snapshot API in this chunk
- if Rust cannot provide either a latest snapshot or a conservative snapshot, map the Rust fallback snapshot with `local_content_safety = unknown` and `recovery_stage = unsafe_unknown`

Across these files:

- keep user-facing labels/result descriptions free of `查询收敛` technical wording unless explicitly marked as internal/debug text
- centralize copy selection, action mapping, and availability mapping in `lib/features/sync/sync_status_mapper.dart`; do not let these rules drift back into `sync_service.dart` or `pool_page.dart`
- if `lib/features/sync/sync_status_mapper.dart` starts to mix pure field mapping with large copy tables, split the copy table into a focused helper in the same directory before the file becomes unwieldy

CTA precedence rule:

- when `nextAction != none`, the single primary recovery CTA is determined by `nextAction`
- `allowedOperations` governs normal user actions such as `read`, `edit`, `check_status`, `continue_low_risk_write`
- `nextAction` governs the single recovery CTA and is a separate Rust contract field, not an element that must also appear inside `allowedOperations`

- [ ] **Step 3A: Migrate remaining non-generated Dart references away from `projectionState`**

Update these existing tests so they stop constructing DTOs with `projectionState` and switch to the new contract fields:

- `test/widget/pages/pool_page_test.dart`
- `test/widget/components/sync_controller_test.dart`
- `test/unit/presentation/sync_controller_unit_test.dart`
- `test/unit/presentation/pool_controller_test.dart`

Task boundary note:

- In Task 5, these files only migrate DTO field names, raw wire values, and mapper/controller consumption boundaries.
- In Task 6, these files only adjust user-facing copy, key assertions, and interaction visibility after the feedback widget extraction.

Run:

```bash
rg "projectionState" lib test
```

Expected: after this migration pass, no non-generated Dart files under `lib/` or `test/` still reference `projectionState`.

That pure mapper MUST be named `mapSyncStatusDto(...)` so unit tests can target a fixed implementation surface.

- [ ] **Step 4: Re-run focused Flutter unit tests to verify GREEN**

Run:

```bash
flutter test test/unit/presentation/sync_service_test.dart test/unit/presentation/sync_status_test.dart
```

Expected: PASS

- [ ] **Step 4A: Run migrated legacy Flutter tests after removing `projectionState`**

Run:

```bash
flutter test test/widget/pages/pool_page_test.dart test/widget/components/sync_controller_test.dart test/unit/presentation/sync_controller_unit_test.dart test/unit/presentation/pool_controller_test.dart
```

Expected: PASS, proving the old Dart test surfaces were fully migrated off `projectionState`.

- [ ] **Step 5: Commit task 5**

```bash
git add lib/features/sync/sync_service.dart lib/features/sync/sync_status.dart lib/features/sync/sync_status_mapper.dart test/unit/presentation/sync_service_test.dart test/unit/presentation/sync_status_test.dart test/support/sync_dto_fixtures.dart test/widget/pages/pool_page_test.dart test/widget/components/sync_controller_test.dart test/unit/presentation/sync_controller_unit_test.dart test/unit/presentation/pool_controller_test.dart
git commit -m "feat(flutter): align sync status with phase2 recovery contract"
```

### Task 6: Lock UI and feature integration behavior

**Files:**
- Modify: `lib/features/pool/pool_page.dart`
- Create: `lib/features/pool/widgets/pool_sync_feedback.dart`
- Modify: `lib/features/sync/sync_status_mapper.dart`
- Test: `test/widget/components/sync_state_test.dart`
- Test: `test/integration/features/pool_sync_test.dart`
- Modify: `test/widget/pages/pool_page_test.dart`
- Modify: `test/widget/components/sync_controller_test.dart`
- Modify: `test/unit/presentation/sync_controller_unit_test.dart`
- Modify: `test/unit/presentation/pool_controller_test.dart`

Component boundary for Task 6:

- `lib/features/pool/widgets/pool_sync_feedback.dart` 只消费前端状态模型（来自 `mapSyncStatusDto(...)` 的结果），不直接解析 FRB DTO
- `lib/features/pool/pool_page.dart` 只负责把当前页面状态与反馈组件接线，不再持有详细反馈分支渲染

- [ ] **Step 1: Add failing widget/integration scenarios**

Test helper constraint for Task 6:

- Define `buildSyncStateTestApp(...)` and any DTO factory helpers in `test/widget/components/sync_state_test.dart`
- Reuse existing test scaffolding if already present in that file or nearby shared test helpers; do not invent a second parallel widget harness
- Extract `_buildLocalSyncFeedback(...)` into `lib/features/pool/widgets/pool_sync_feedback.dart`; this extracted widget becomes the single owner of the keys and feedback rendering asserted in this chunk

Operation-to-key mapping for this task:

- `read` -> `openDetailAction`
- `edit` -> `continueEditAction`
- `check_status` -> `checkStatusAction`
- `continue_low_risk_write` -> `continueLowRiskWriteAction`
- recovery CTA from `nextAction` -> `primaryRecoveryAction`

Operation-to-UI rendering policy for this chunk:

- `read`: render and keep enabled whenever present in `allowedOperations`
- `edit`: render and keep enabled whenever present in `allowedOperations`
- `check_status`: render as a normal secondary action when present in `allowedOperations`
- `continue_low_risk_write`: render only when present in `allowedOperations`; hide it when listed in `forbiddenOperations`
- actions in `forbiddenOperations`: default to hidden in this chunk; do not use disabled rendering

Add or extend tests for these observable outcomes:

```dart
testWidgets('shows saved-but-updating feedback when query results are still converging', (tester) async {
  await tester.pumpWidget(buildSyncStateTestApp(dto: makeSyncStatusDto(
    queryConvergenceState: 'pending',
    localContentSafety: 'safe',
  )));

  expect(find.text('内容已保存，结果仍在更新'), findsOneWidget);
  expect(find.textContaining('查询收敛'), findsNothing);
});

testWidgets('shows another device app instance not ready without implying data loss', (tester) async {
  await tester.pumpWidget(buildSyncStateTestApp(dto: makeSyncStatusDto(
    instanceContinuityState: 'recovering',
    localContentSafety: 'safe',
  )));

  expect(find.text('内容已保存，另一台设备上的内容仍在恢复'), findsOneWidget);
  expect(find.textContaining('内容已丢失'), findsNothing);
});

testWidgets('shows retrying stage as still recovering without failure wording', (tester) async {
  await tester.pumpWidget(buildSyncStateTestApp(dto: makeSyncStatusDto(
    queryConvergenceState: 'pending',
    localContentSafety: 'safe',
    recoveryStage: 'retrying',
  )));

  expect(find.text('内容已保存，系统仍在继续恢复'), findsOneWidget);
  expect(find.textContaining('失败'), findsNothing);
});

testWidgets('does not block local actions when content is still safe', (tester) async {
  await tester.pumpWidget(buildSyncStateTestApp(dto: makeSyncStatusDto(
    localContentSafety: 'safe',
    nextAction: 'none',
  )));

  expect(find.byKey(const Key('openDetailAction')), findsOneWidget);
  expect(find.byKey(const Key('continueEditAction')), findsOneWidget);
  expect(find.byKey(const Key('primaryRecoveryAction')), findsNothing);
});

testWidgets('shows explicit recovery action when content safety is unknown', (tester) async {
  await tester.pumpWidget(buildSyncStateTestApp(dto: makeSyncStatusDto(
    localContentSafety: 'unknown',
    nextAction: 'recheck_status',
  )));

  expect(find.byKey(const Key('primaryRecoveryAction')), findsOneWidget);
  expect(find.byKey(const Key('continueLowRiskWriteAction')), findsNothing);
});

testWidgets('restricts low-risk write continuation when content is read-only-risk', (tester) async {
  await tester.pumpWidget(buildSyncStateTestApp(dto: makeSyncStatusDto(
    localContentSafety: 'read_only_risk',
    allowedOperations: ['read', 'check_status'],
    forbiddenOperations: ['continue_low_risk_write'],
  )));

  expect(find.byKey(const Key('checkStatusAction')), findsOneWidget);
  expect(find.byKey(const Key('continueLowRiskWriteAction')), findsNothing);
});

testWidgets('renders only one primary recovery action', (tester) async {
  await tester.pumpWidget(buildSyncStateTestApp(dto: makeSyncStatusDto(
    nextAction: 'retry_query_convergence',
  )));

  expect(find.byKey(const Key('primaryRecoveryAction')), findsOneWidget);
  expect(find.byKey(const Key('secondaryPrimaryAction')), findsNothing);
});

testWidgets('shows retry_sync as the only primary recovery action', (tester) async {
  await tester.pumpWidget(buildSyncStateTestApp(dto: makeSyncStatusDto(
    localContentSafety: 'safe',
    recoveryStage: 'needs_user_action',
    nextAction: 'retry_sync',
  )));

  expect(find.byKey(const Key('primaryRecoveryAction')), findsOneWidget);
  expect(find.textContaining('重试同步'), findsOneWidget);
  expect(find.byKey(const Key('secondaryPrimaryAction')), findsNothing);
});

testWidgets('shows reconnect_instance as the only primary recovery action', (tester) async {
  await tester.pumpWidget(buildSyncStateTestApp(dto: makeSyncStatusDto(
    localContentSafety: 'safe',
    recoveryStage: 'needs_user_action',
    nextAction: 'reconnect_instance',
  )));

  expect(find.byKey(const Key('primaryRecoveryAction')), findsOneWidget);
  expect(find.textContaining('重新连接'), findsOneWidget);
  expect(find.byKey(const Key('secondaryPrimaryAction')), findsNothing);
});

testWidgets('keeps local safe actions available when needs_user_action is present', (tester) async {
  await tester.pumpWidget(buildSyncStateTestApp(dto: makeSyncStatusDto(
    localContentSafety: 'safe',
    recoveryStage: 'needs_user_action',
    nextAction: 'retry_query_convergence',
    allowedOperations: ['read', 'edit'],
  )));

  expect(find.byKey(const Key('openDetailAction')), findsOneWidget);
  expect(find.byKey(const Key('continueEditAction')), findsOneWidget);
  expect(find.byKey(const Key('primaryRecoveryAction')), findsOneWidget);
});

testWidgets('shows path-broken state without weak recovery wording', (tester) async {
  await tester.pumpWidget(buildSyncStateTestApp(dto: makeSyncStatusDto(
    continuityState: 'path_broken',
    localContentSafety: 'unknown',
    nextAction: 'return_to_source_instance',
  )));

  expect(find.text('当前已不再是同一路径上的继续恢复'), findsOneWidget);
  expect(find.textContaining('仍在恢复'), findsNothing);
  expect(find.byKey(const Key('continueLowRiskWriteAction')), findsNothing);
});
```

In `test/integration/features/pool_sync_test.dart`, add at least these end-to-end scenarios:

1. pool page receives a Phase 2 `safe + pending` status and shows “内容已保存，结果仍在更新” without technical wording
2. pool page receives `safe + needs_user_action + retry_sync` and keeps local read/edit actions available while showing exactly one primary recovery action
3. pool page receives `path_broken` and stops rendering normal write continuation

- [ ] **Step 1A: Migrate existing legacy Flutter tests that still touch sync feedback paths**

Apply these exact migrations:

- `test/widget/pages/pool_page_test.dart`
  - 只迁移页面级 key/文案断言，从旧 `projectionState` DTO 输入切到新前端状态模型或新 DTO helper
- `test/widget/components/sync_controller_test.dart`
  - 只验证 controller 不再依赖旧字段名，且不会回退到 Flutter 自推断恢复语义
- `test/unit/presentation/sync_controller_unit_test.dart`
  - 只迁移旧 DTO 字段名与动作值，不新增产品范围
- `test/unit/presentation/pool_controller_test.dart`
  - 只验证 pool controller 消费新恢复状态后仍把反馈交给页面/反馈组件，不自行发明恢复判断

- [ ] **Step 2: Run focused UI tests to verify RED**

Run:

```bash
flutter test test/widget/components/sync_state_test.dart test/integration/features/pool_sync_test.dart
```

Expected: FAIL because current UI wording and status mapping are still Phase 1-oriented.

- [ ] **Step 3: Apply the minimal UI update**

Update UI only where needed so the observable behavior matches the spec:

- result-oriented wording such as:
  - `内容已保存，结果仍在更新`
  - `内容已保存，但需要你手动继续恢复`
  - `内容已保存，另一台设备上的内容仍在恢复`
  - `当前内容可查看，但请先不要继续低风险写入`
  - `当前无法确认内容安全，请先检查状态`
- no direct user-facing `查询收敛` technical label
- local actions remain enabled when `local_content_safety = safe`
- low-risk write continuation is restricted when `local_content_safety = read_only_risk`
- `continuity_state = path_broken` must use explicit broken-path wording and must not be rendered as “仍在恢复”
- action visibility / disabled state MUST be driven directly by Rust `allowedOperations` / `forbiddenOperations`, not by Flutter-side inference
- UI rendering rule for `allowedOperations` / `forbiddenOperations`:
  - primary recovery action: show exactly one CTA when `nextAction != none`
  - allowed normal actions: render and keep enabled
  - forbidden normal actions: hide the action entirely in this chunk
- UI must interpret operation values using the fixed snake_case wire names from this chunk, e.g. `check_status`, `continue_low_risk_write`

- [ ] **Step 4: Re-run focused UI tests to verify GREEN**

Run:

```bash
flutter test test/widget/components/sync_state_test.dart test/integration/features/pool_sync_test.dart
```

Expected: PASS

- [ ] **Step 4A: Confirm page/widget responsibility split stays bounded**

After the extraction, verify:

- `lib/features/pool/pool_page.dart` no longer owns the detailed recovery-feedback rendering branches
- `lib/features/pool/widgets/pool_sync_feedback.dart` owns the feedback copy, action visibility, and stable test keys for this chunk

- [ ] **Step 5: Commit task 6**

```bash
git add lib/features/pool/pool_page.dart lib/features/pool/widgets/pool_sync_feedback.dart lib/features/sync/sync_status_mapper.dart test/widget/components/sync_state_test.dart test/integration/features/pool_sync_test.dart test/widget/pages/pool_page_test.dart test/widget/components/sync_controller_test.dart test/unit/presentation/sync_controller_unit_test.dart test/unit/presentation/pool_controller_test.dart
git commit -m "test(ui): lock phase2 trust-first recovery feedback"
```

### Task 7: Run full verification and update plan index

**Files:**
- Modify: `docs/plans/DIR.md`
- Verify: `rust/tests/contract/api/sync_api_contract.rs`
- Verify: `rust/tests/integration/api_integration_test.rs`
- Verify: `test/contract/api/sync_api_contract_test.dart`
- Verify: `test/unit/presentation/sync_service_test.dart`
- Verify: `test/unit/presentation/sync_status_test.dart`
- Verify: `test/widget/components/sync_state_test.dart`
- Verify: `test/integration/features/pool_sync_test.dart`
- Modify: `test/integration/infrastructure/sync_bridge_test.dart`

- [ ] **Step 1: Add plan index entry**

Append one line to `docs/plans/DIR.md`:

```text
2026-03-23-phase2-trust-first-recovery-implementation-plan.md - 实现计划 - Phase 2 信任优先恢复实施（同步 / 查询收敛 / 实例连续性分层与信任优先恢复契约）
```

- [ ] **Step 2: Run focused Rust verification**

Run:

```bash
cargo test sync_status_should_return_structured_error_when_handle_invalid -- --exact
cargo test api_sync_status_returns_degraded_when_query_convergence_pending -- --exact
cargo test api_pool_network_lifecycle_and_sync_state -- --exact
```

Expected: PASS

- [ ] **Step 3: Re-run bridge verification after the explicit assertions added in Task 4 Step 4A**

Run:

```bash
flutter test test/integration/infrastructure/sync_bridge_test.dart
```

Expected: PASS

- [ ] **Step 3A: Run focused Flutter verification**

Run:

```bash
flutter test test/contract/api/sync_api_contract_test.dart test/unit/presentation/sync_service_test.dart test/unit/presentation/sync_status_test.dart test/widget/components/sync_state_test.dart test/integration/features/pool_sync_test.dart test/widget/pages/pool_page_test.dart test/widget/components/sync_controller_test.dart test/unit/presentation/sync_controller_unit_test.dart test/unit/presentation/pool_controller_test.dart
```

Expected: PASS

- [ ] **Step 3C: Treat bridge verification as part of Flutter verification completion**

Do not mark Flutter verification complete until both Step 3 and Step 3A pass.

- [ ] **Step 4: Run repo-level quality verification for touched surfaces**

Run:

```bash
git diff --check
flutter analyze
dart run tool/quality.dart all
cargo test
```

Expected:

- `git diff --check`: no issues
- `flutter analyze`: no issues
- `dart run tool/quality.dart all`: PASS，并生成边界扫描报告 `/tmp/cardmind_test_boundary_report.md`
- `cargo test`: PASS（作为额外原始输出兜底验证，即使 `dart run tool/quality.dart all` 已覆盖 Rust 测试，仍保留一次独立运行）

- [ ] **Step 4A: Inspect boundary scan report**

Read `/tmp/cardmind_test_boundary_report.md` and confirm:

- 本轮新增或修改的 Rust / Flutter 关键边界没有出现新的高优先级未覆盖项
- 若有未覆盖项，必须在继续前补测试；如果需要记录原因，则在执行实现时另外更新当天工作日志，而不是把该日志更新纳入本计划提交范围
- 将每一条新增高优先级未覆盖项与一个具体补测文件一一对应，避免只记录结论不落到测试入口

- [ ] **Step 4A-1: If boundary report requires extra tests, add them before moving on**

If `/tmp/cardmind_test_boundary_report.md` shows new high-priority uncovered boundaries, first update the affected Rust or Flutter test files, then re-run the impacted verification commands from Step 2, Step 3, or Step 4 before continuing.

- [ ] **Step 4B: Verify Flutter/Rust bridge is still consumable end-to-end**

Run:

```bash
dart run tool/build.dart lib
flutter test test/contract/api/sync_api_contract_test.dart test/integration/infrastructure/sync_bridge_test.dart
```

Expected:

- `dart run tool/build.dart lib`: PASS
- FRB contract test and bridge integration test: PASS

- [ ] **Step 5: Commit task 7**

```bash
git add docs/plans/DIR.md test/integration/infrastructure/sync_bridge_test.dart test/contract/api/sync_api_contract_test.dart test/unit/presentation/sync_service_test.dart test/unit/presentation/sync_status_test.dart test/widget/components/sync_state_test.dart test/integration/features/pool_sync_test.dart rust/tests/contract/api/sync_api_contract.rs rust/tests/integration/api_integration_test.rs rust/tests/unit/net/pool_network_sync_test.rs lib/features/sync/sync_service.dart lib/features/sync/sync_status.dart lib/features/sync/sync_status_mapper.dart lib/features/pool/pool_page.dart
git commit -m "feat: align phase2 trust-first recovery verification surfaces"
```

If Step 4A-1 added any extra verification tests beyond the list above, include those files in the same commit.
